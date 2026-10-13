use flclash_control::{
    peer_owned, read_discovery, read_frame_deadline, runtime_dir, verify_owned, write_frame,
};
use std::fs::File;
use std::io::{self, BufRead, Read, Write};
use std::os::fd::AsRawFd;
use std::os::unix::net::UnixStream;
use std::sync::atomic::{AtomicI32, Ordering};
use std::time::Duration;

static TERMINAL_FD: AtomicI32 = AtomicI32::new(-1);
static mut TERMINAL_STATE: std::mem::MaybeUninit<libc::termios> = std::mem::MaybeUninit::uninit();

extern "C" fn interrupt_password(signal: i32) {
    let fd = TERMINAL_FD.load(Ordering::Acquire);
    unsafe {
        if fd >= 0 {
            libc::tcsetattr(
                fd,
                libc::TCSAFLUSH,
                std::ptr::addr_of!(TERMINAL_STATE).cast::<libc::termios>(),
            );
        }
        libc::_exit(128 + signal);
    }
}

fn password_line(mut input: impl BufRead) -> Result<String, &'static str> {
    let mut bytes = Vec::new();
    input
        .by_ref()
        .take(1026)
        .read_until(b'\n', &mut bytes)
        .map_err(|_| "password_input_failed")?;
    if bytes.last() == Some(&b'\n') {
        bytes.pop();
        if bytes.last() == Some(&b'\r') {
            bytes.pop();
        }
    }
    let value = String::from_utf8(bytes).map_err(|_| "invalid_password")?;
    if !(12..=128).contains(&value.chars().count()) || value.chars().any(char::is_control) {
        return Err("invalid_password");
    }
    Ok(value)
}

struct EchoGuard {
    fd: i32,
    original: libc::termios,
    signals: Vec<(i32, libc::sigaction)>,
}
impl Drop for EchoGuard {
    fn drop(&mut self) {
        unsafe {
            libc::tcsetattr(self.fd, libc::TCSAFLUSH, &self.original);
            TERMINAL_FD.store(-1, Ordering::Release);
            for (signal, action) in &self.signals {
                libc::sigaction(*signal, action, std::ptr::null_mut());
            }
        }
    }
}
fn terminal_password() -> Result<String, &'static str> {
    let mut tty = std::fs::OpenOptions::new()
        .read(true)
        .write(true)
        .open("/dev/tty")
        .map_err(|_| "terminal_unavailable_use_password_stdin")?;
    let fd = tty.as_raw_fd();
    let mut original: libc::termios = unsafe { std::mem::zeroed() };
    if unsafe { libc::tcgetattr(fd, &mut original) } != 0 {
        return Err("password_input_failed");
    }
    let mut signals = Vec::new();
    unsafe {
        std::ptr::addr_of_mut!(TERMINAL_STATE)
            .cast::<libc::termios>()
            .write(original);
        TERMINAL_FD.store(fd, Ordering::Release);
        for signal in [libc::SIGINT, libc::SIGTERM, libc::SIGHUP, libc::SIGQUIT] {
            let mut action: libc::sigaction = std::mem::zeroed();
            let mut previous: libc::sigaction = std::mem::zeroed();
            action.sa_sigaction = interrupt_password as *const () as usize;
            libc::sigemptyset(&mut action.sa_mask);
            if libc::sigaction(signal, &action, &mut previous) == 0 {
                signals.push((signal, previous));
            }
        }
    }
    let guard = EchoGuard {
        fd,
        original,
        signals,
    };
    let mut masked = original;
    masked.c_lflag &= !libc::ECHO;
    if unsafe { libc::tcsetattr(fd, libc::TCSAFLUSH, &masked) } != 0 {
        return Err("password_input_failed");
    }
    tty.write_all(b"Password: ")
        .map_err(|_| "password_input_failed")?;
    let result = password_line(io::BufReader::new(&tty));
    drop(guard);
    let _ = tty.write_all(b"\n");
    result
}

fn run() -> Result<bool, &'static str> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.is_empty() || args == ["--help"] || args == ["help"] {
        println!("flclashctl [--password-stdin | --password-fd FD] [--idempotency-key KEY] <status|capabilities|start|stop|restart|invoke COMMAND [JSON]>\nEvery application command requires a password. Password arguments and environment variables are unsupported.\nExample: flclashctl --password-stdin invoke operation_query '{{\"operationId\":\"...\"}}'");
        return Ok(true);
    }
    if args == ["--version"] {
        println!("flclashctl 1.0.0 (protocol 1)");
        return Ok(true);
    }
    let mut cursor = 0;
    let mut input_fd = None;
    let mut stdin_password = false;
    let mut idempotency = None;
    while cursor < args.len() && args[cursor].starts_with("--") {
        match args[cursor].as_str() {
            "--password-stdin" if !stdin_password && input_fd.is_none() => stdin_password = true,
            "--password-fd" if !stdin_password && input_fd.is_none() => {
                cursor += 1;
                input_fd = Some(
                    args.get(cursor)
                        .ok_or("invalid_arguments")?
                        .parse::<i32>()
                        .map_err(|_| "invalid_arguments")?,
                );
            }
            "--idempotency-key" if idempotency.is_none() => {
                cursor += 1;
                let key = args.get(cursor).ok_or("invalid_arguments")?;
                if key.is_empty() || key.len() > 128 {
                    return Err("invalid_arguments");
                }
                idempotency = Some(key.clone());
            }
            _ => return Err("invalid_arguments"),
        }
        cursor += 1;
    }
    let running = match args.get(cursor).map(String::as_str) {
        Some("start") => Some(true),
        Some("stop") => Some(false),
        _ => None,
    };
    let command = match args.get(cursor).map(String::as_str) {
        Some("status") => "runtime_read".to_owned(),
        Some("capabilities") => "capabilities_list".to_owned(),
        Some("start") => "connection_set".to_owned(),
        Some("stop") => "connection_set".to_owned(),
        Some("restart") => "core_restart".to_owned(),
        Some("invoke") => {
            cursor += 1;
            args.get(cursor).ok_or("invalid_arguments")?.clone()
        }
        _ => return Err("invalid_arguments"),
    };
    cursor += 1;
    let mut params: serde_json::Value = if let Some(value) = args.get(cursor) {
        cursor += 1;
        serde_json::from_str(value).map_err(|_| "invalid_arguments")?
    } else {
        serde_json::json!({})
    };
    if cursor != args.len() || !params.is_object() || command.len() > 128 {
        return Err("invalid_arguments");
    }
    if let Some(running) = running {
        if params != serde_json::json!({}) {
            return Err("invalid_arguments");
        }
        params = serde_json::json!({"running":running});
    }
    let directory = runtime_dir();
    verify_owned(&directory, 0o700, false).map_err(|_| "app_not_running")?;
    verify_owned(&directory.join("instance.json"), 0o600, false).map_err(|_| "unsafe_endpoint")?;
    verify_owned(&directory.join("control.sock"), 0o600, true).map_err(|_| "app_not_running")?;
    let discovery =
        read_discovery(&directory.join("instance.json")).map_err(|_| "invalid_discovery")?;
    if !discovery["instanceId"].is_string() {
        return Err("invalid_discovery");
    }
    if discovery["version"] != 1 {
        return Err("protocol_mismatch");
    }
    let password = if stdin_password {
        password_line(io::stdin().lock())?
    } else if let Some(fd) = input_fd {
        if fd < 0 {
            return Err("invalid_arguments");
        }
        let duplicate = unsafe { libc::dup(fd) };
        if duplicate < 0 {
            return Err("password_input_failed");
        }
        use std::os::fd::FromRawFd;
        password_line(io::BufReader::new(unsafe { File::from_raw_fd(duplicate) }))?
    } else {
        terminal_password()?
    };
    let mut stream =
        UnixStream::connect(directory.join("control.sock")).map_err(|_| "app_not_running")?;
    peer_owned(&stream).map_err(|_| "peer_rejected")?;
    stream
        .set_read_timeout(Some(Duration::from_secs(35)))
        .map_err(|_| "connection_failed")?;
    stream
        .set_write_timeout(Some(Duration::from_secs(5)))
        .map_err(|_| "connection_failed")?;
    let mut entropy = [0; 16];
    File::open("/dev/urandom")
        .and_then(|mut f| f.read_exact(&mut entropy))
        .map_err(|_| "random_unavailable")?;
    let request_id = entropy
        .iter()
        .map(|v| format!("{v:02x}"))
        .collect::<String>();
    let mut request = serde_json::json!({"version":1,"instanceId":discovery["instanceId"],"requestId":request_id,"command":command,"auth":{"password":password},"params":params});
    if let Some(key) = idempotency {
        request["idempotencyKey"] = serde_json::Value::String(key);
    }
    write_frame(&mut stream, request.to_string().as_bytes()).map_err(|_| "request_failed")?;
    let response = read_frame_deadline(&mut stream, Duration::from_secs(35))
        .map_err(|_| "response_timeout_or_disconnect_query_operation_before_retry")?;
    let result: serde_json::Value =
        serde_json::from_slice(&response).map_err(|_| "invalid_response")?;
    if result["requestId"] != request_id {
        if result["requestId"].is_null()
            && matches!(
                result["errorCode"].as_str(),
                Some("server_busy" | "queue_timeout" | "shutting_down")
            )
        {
            eprintln!("{}", result["errorCode"].as_str().unwrap());
            return Ok(false);
        }
        return Err("invalid_response");
    }
    println!("{}", result);
    Ok(!matches!(
        result["status"].as_str(),
        Some("failed" | "rejected" | "conflict")
    ))
}
fn main() {
    match run() {
        Ok(true) => (),
        Ok(false) => std::process::exit(2),
        Err(code) => {
            eprintln!("{code}");
            std::process::exit(1);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn unicode_and_spaces_are_preserved() {
        assert_eq!(
            password_line("  密码安全测试１２３４５６  \n".as_bytes()).unwrap(),
            "  密码安全测试１２３４５６  "
        );
    }
    #[test]
    fn rejects_controls_and_large_input() {
        assert!(password_line(b"abcdefghijkl\t\n".as_slice()).is_err());
        assert!(password_line("x".repeat(129).as_bytes()).is_err());
    }
}
