use std::collections::HashMap;
use std::ffi::{CStr, CString};
use std::fs::{self, File, OpenOptions};
use std::io::{self, Read, Write};
use std::os::fd::{AsRawFd, RawFd};
use std::os::unix::fs::{DirBuilderExt, MetadataExt, OpenOptionsExt, PermissionsExt};
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, AtomicU64, AtomicUsize, Ordering};
use std::sync::{mpsc, Arc, Mutex, OnceLock};
use std::thread;
use std::time::{Duration, Instant};

pub const MAX_FRAME: usize = 1024 * 1024;
pub const MAX_CLIENTS: usize = 8;
pub const MAX_QUEUE: usize = 16;
const WAIT: Duration = Duration::from_secs(5);

pub fn runtime_dir() -> PathBuf {
    PathBuf::from(format!("/private/tmp/flclashctl-{}", unsafe {
        libc::geteuid()
    }))
}

pub fn verify_owned(path: &Path, mode: u32, socket: bool) -> io::Result<()> {
    let meta = fs::symlink_metadata(path)?;
    if meta.file_type().is_symlink()
        || meta.uid() != unsafe { libc::geteuid() }
        || meta.mode() & 0o777 != mode
        || (socket && !std::os::unix::fs::FileTypeExt::is_socket(&meta.file_type()))
    {
        return Err(io::Error::new(
            io::ErrorKind::PermissionDenied,
            "unsafe_endpoint",
        ));
    }
    Ok(())
}

pub fn read_discovery(path: &Path) -> io::Result<serde_json::Value> {
    verify_owned(path, 0o600, false)?;
    let file = OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_NOFOLLOW | libc::O_CLOEXEC | libc::O_NONBLOCK)
        .open(path)?;
    let meta = file.metadata()?;
    if !meta.is_file()
        || meta.uid() != unsafe { libc::geteuid() }
        || meta.mode() & 0o777 != 0o600
        || meta.nlink() != 1
    {
        return Err(io::ErrorKind::PermissionDenied.into());
    }
    serde_json::from_reader(file.take(4096)).map_err(io::Error::other)
}

pub fn peer_owned(stream: &UnixStream) -> io::Result<()> {
    #[cfg(target_os = "macos")]
    {
        let mut uid = 0;
        let mut gid = 0;
        if unsafe { libc::getpeereid(stream.as_raw_fd(), &mut uid, &mut gid) } != 0
            || uid != unsafe { libc::geteuid() }
        {
            return Err(io::Error::new(
                io::ErrorKind::PermissionDenied,
                "peer_rejected",
            ));
        }
    }
    #[cfg(target_os = "linux")]
    {
        let mut cred: libc::ucred = unsafe { std::mem::zeroed() };
        let mut len = std::mem::size_of::<libc::ucred>() as libc::socklen_t;
        if unsafe {
            libc::getsockopt(
                stream.as_raw_fd(),
                libc::SOL_SOCKET,
                libc::SO_PEERCRED,
                &mut cred as *mut _ as *mut libc::c_void,
                &mut len,
            )
        } != 0
            || cred.uid != unsafe { libc::geteuid() }
        {
            return Err(io::Error::new(
                io::ErrorKind::PermissionDenied,
                "peer_rejected",
            ));
        }
    }
    Ok(())
}

pub fn read_frame(stream: &mut impl Read) -> io::Result<Vec<u8>> {
    let mut header = [0; 4];
    stream.read_exact(&mut header)?;
    let size = u32::from_le_bytes(header) as usize;
    if size == 0 || size > MAX_FRAME {
        return Err(io::Error::new(io::ErrorKind::InvalidData, "invalid_frame"));
    }
    let mut data = vec![0; size];
    stream.read_exact(&mut data)?;
    Ok(data)
}

pub fn read_frame_deadline(stream: &mut UnixStream, timeout: Duration) -> io::Result<Vec<u8>> {
    let deadline = Instant::now() + timeout;
    fn exact(stream: &mut UnixStream, mut bytes: &mut [u8], deadline: Instant) -> io::Result<()> {
        while !bytes.is_empty() {
            let remaining = deadline
                .checked_duration_since(Instant::now())
                .ok_or(io::ErrorKind::TimedOut)?;
            stream.set_read_timeout(Some(remaining))?;
            let count = stream.read(bytes)?;
            if count == 0 {
                return Err(io::ErrorKind::UnexpectedEof.into());
            }
            bytes = &mut bytes[count..];
        }
        Ok(())
    }
    let mut header = [0; 4];
    exact(stream, &mut header, deadline)?;
    let size = u32::from_le_bytes(header) as usize;
    if size == 0 || size > MAX_FRAME {
        return Err(io::ErrorKind::InvalidData.into());
    }
    let mut body = vec![0; size];
    exact(stream, &mut body, deadline)?;
    Ok(body)
}

pub fn write_frame(stream: &mut impl Write, data: &[u8]) -> io::Result<()> {
    if data.is_empty() || data.len() > MAX_FRAME {
        return Err(io::Error::new(io::ErrorKind::InvalidData, "invalid_frame"));
    }
    stream.write_all(&(data.len() as u32).to_le_bytes())?;
    stream.write_all(data)
}

struct Packet {
    token: u64,
    body: String,
    enqueued_at: Instant,
}
struct EndpointGuard {
    path: PathBuf,
    inode: u64,
    armed: bool,
}
impl Drop for EndpointGuard {
    fn drop(&mut self) {
        if self.armed
            && fs::symlink_metadata(&self.path).is_ok_and(|meta| {
                meta.ino() == self.inode
                    && std::os::unix::fs::FileTypeExt::is_socket(&meta.file_type())
            })
        {
            let _ = fs::remove_file(&self.path);
        }
    }
}
struct Server {
    directory: PathBuf,
    socket_inode: u64,
    discovery_inode: u64,
    instance: String,
    _lock: File,
    receiver: Mutex<mpsc::Receiver<Packet>>,
    replies: Arc<Mutex<HashMap<u64, mpsc::SyncSender<String>>>>,
    stopped: Arc<AtomicBool>,
    sockets: Arc<Mutex<HashMap<u64, RawFd>>>,
}
static SERVER: OnceLock<Mutex<Option<Server>>> = OnceLock::new();
static SEQUENCE: AtomicU64 = AtomicU64::new(1);
fn state() -> &'static Mutex<Option<Server>> {
    SERVER.get_or_init(|| Mutex::new(None))
}

fn private_file(path: &Path) -> io::Result<File> {
    if let Ok(meta) = fs::symlink_metadata(path) {
        if !meta.is_file()
            || meta.file_type().is_symlink()
            || meta.uid() != unsafe { libc::geteuid() }
            || meta.mode() & 0o777 != 0o600
            || meta.nlink() != 1
        {
            return Err(io::ErrorKind::PermissionDenied.into());
        }
    }
    OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .mode(0o600)
        .custom_flags(libc::O_NOFOLLOW | libc::O_CLOEXEC | libc::O_NONBLOCK)
        .open(path)
}

fn start(directory: PathBuf, instance: String) -> io::Result<Server> {
    match fs::DirBuilder::new().mode(0o700).create(&directory) {
        Ok(()) => (),
        Err(e) if e.kind() == io::ErrorKind::AlreadyExists => (),
        Err(e) => return Err(e),
    }
    verify_owned(&directory, 0o700, false)?;
    if !fs::symlink_metadata(&directory)?.is_dir() {
        return Err(io::ErrorKind::PermissionDenied.into());
    }
    let lock = private_file(&directory.join("owner.lock"))?;
    verify_owned(&directory.join("owner.lock"), 0o600, false)?;
    if unsafe { libc::flock(lock.as_raw_fd(), libc::LOCK_EX | libc::LOCK_NB) } != 0 {
        return Err(io::Error::new(io::ErrorKind::AddrInUse, "instance_running"));
    }
    let socket = directory.join("control.sock");
    let discovery = directory.join("instance.json");
    let has_previous_instance = discovery.exists();
    if discovery.exists() {
        let value = read_discovery(&discovery)?;
        let old_pid = value["pid"]
            .as_i64()
            .and_then(|pid| libc::pid_t::try_from(pid).ok())
            .ok_or(io::ErrorKind::InvalidData)?;
        if old_pid <= 0 {
            return Err(io::ErrorKind::InvalidData.into());
        }
        if old_pid != std::process::id() as libc::pid_t
            && (unsafe { libc::kill(old_pid, 0) } == 0
                || io::Error::last_os_error().raw_os_error() == Some(libc::EPERM))
        {
            return Err(io::Error::new(io::ErrorKind::AddrInUse, "instance_running"));
        }
    }
    if fs::symlink_metadata(&socket).is_ok() {
        if !has_previous_instance {
            return Err(io::Error::new(
                io::ErrorKind::PermissionDenied,
                "unverifiable_stale_endpoint",
            ));
        }
        verify_owned(&socket, 0o600, true)?;
        fs::remove_file(&socket)?;
    }
    let listener = UnixListener::bind(&socket)?;
    let socket_inode = fs::symlink_metadata(&socket)?.ino();
    let mut endpoint_guard = EndpointGuard {
        path: socket.clone(),
        inode: socket_inode,
        armed: true,
    };
    fs::set_permissions(&socket, fs::Permissions::from_mode(0o600))?;
    listener.set_nonblocking(true)?;
    let mut file = private_file(&discovery)?;
    let discovery_inode = file.metadata()?.ino();
    file.set_len(0)?;
    file.write_all(
        serde_json::json!({"version":1,"instanceId":instance,"pid":std::process::id()})
            .to_string()
            .as_bytes(),
    )?;
    file.sync_all()?;
    let (sender, receiver) = mpsc::sync_channel(MAX_QUEUE);
    let replies = Arc::new(Mutex::new(HashMap::<u64, mpsc::SyncSender<String>>::new()));
    let stopped = Arc::new(AtomicBool::new(false));
    let sockets = Arc::new(Mutex::new(HashMap::new()));
    let (thread_replies, thread_stopped, thread_sockets) =
        (replies.clone(), stopped.clone(), sockets.clone());
    thread::spawn(move || {
        let count = Arc::new(AtomicUsize::new(0));

        while !thread_stopped.load(Ordering::Acquire) {
            let (mut stream, _) = match listener.accept() {
                Ok(v) => v,
                Err(e) if e.kind() == io::ErrorKind::WouldBlock => {
                    thread::sleep(Duration::from_millis(10));
                    continue;
                }
                Err(_) => break,
            };
            if thread_stopped.load(Ordering::Acquire)
                || count.load(Ordering::Acquire) >= MAX_CLIENTS
                || peer_owned(&stream).is_err()
            {
                continue;
            }
            if stream.set_nonblocking(false).is_err() {
                continue;
            }
            count.fetch_add(1, Ordering::AcqRel);
            let token = SEQUENCE.fetch_add(1, Ordering::Relaxed);
            let (sender, replies, stopped, sockets, count) = (
                sender.clone(),
                thread_replies.clone(),
                thread_stopped.clone(),
                thread_sockets.clone(),
                count.clone(),
            );
            sockets.lock().unwrap().insert(token, stream.as_raw_fd());
            thread::spawn(move || {
                let _ = stream.set_read_timeout(Some(WAIT));
                let _ = stream.set_write_timeout(Some(WAIT));
                while !stopped.load(Ordering::Acquire) {
                    let body = match read_frame_deadline(&mut stream, WAIT).and_then(|b| {
                        String::from_utf8(b).map_err(|_| io::ErrorKind::InvalidData.into())
                    }) {
                        Ok(v) => v,
                        Err(_) => break,
                    };
                    let (reply_sender, reply_receiver) = mpsc::sync_channel(1);
                    replies.lock().unwrap().insert(token, reply_sender);
                    if sender
                        .try_send(Packet {
                            token,
                            body,
                            enqueued_at: Instant::now(),
                        })
                        .is_err()
                    {
                        replies.lock().unwrap().remove(&token);
                        let _ = write_frame(
                            &mut stream,
                            br#"{"status":"rejected","errorCode":"server_busy"}"#,
                        );
                        break;
                    }
                    match reply_receiver.recv_timeout(Duration::from_secs(35)) {
                        Ok(response) => {
                            if write_frame(&mut stream, response.as_bytes()).is_err() {
                                break;
                            }
                        }
                        Err(_) => break,
                    }
                    replies.lock().unwrap().remove(&token);
                }
                replies.lock().unwrap().remove(&token);
                sockets.lock().unwrap().remove(&token);
                count.fetch_sub(1, Ordering::AcqRel);
            });
        }
    });
    endpoint_guard.armed = false;
    Ok(Server {
        directory,
        socket_inode,
        discovery_inode,
        instance,
        _lock: lock,
        receiver: Mutex::new(receiver),
        replies,
        stopped,
        sockets,
    })
}

fn output(value: String) -> *mut libc::c_char {
    CString::new(value).unwrap().into_raw()
}
unsafe fn input(value: *const libc::c_char) -> Option<String> {
    if value.is_null() {
        None
    } else {
        CStr::from_ptr(value).to_str().ok().map(str::to_owned)
    }
}

#[no_mangle]
pub unsafe extern "C" fn fl_control_start(instance: *const libc::c_char) -> i32 {
    let Some(instance) = input(instance) else {
        return -1;
    };
    let mut guard = state().lock().unwrap();
    if guard.is_some() {
        return -2;
    }
    match start(runtime_dir(), instance) {
        Ok(server) => {
            *guard = Some(server);
            0
        }
        Err(_) => -3,
    }
}

#[no_mangle]
pub extern "C" fn fl_control_poll() -> *mut libc::c_char {
    let guard = state().lock().unwrap();
    let Some(server) = guard.as_ref() else {
        return std::ptr::null_mut();
    };
    let packet = server.receiver.lock().unwrap().try_recv();
    match packet {
        Ok(packet) => {
            if packet.enqueued_at.elapsed() > Duration::from_secs(10) {
                if let Some(sender) = server.replies.lock().unwrap().remove(&packet.token) {
                    let _ = sender.try_send(
                        "{\"status\":\"rejected\",\"errorCode\":\"queue_timeout\"}".into(),
                    );
                }
                return std::ptr::null_mut();
            }
            output(serde_json::json!({"token":packet.token,"body":packet.body}).to_string())
        }
        Err(_) => std::ptr::null_mut(),
    }
}

#[no_mangle]
pub unsafe extern "C" fn fl_control_reply(token: u64, body: *const libc::c_char) {
    let Some(body) = input(body) else {
        return;
    };
    if body.len() > MAX_FRAME {
        return;
    }
    if let Some(server) = state().lock().unwrap().as_ref() {
        if let Some(sender) = server.replies.lock().unwrap().remove(&token) {
            let _ = sender.try_send(body);
        }
    }
}

#[no_mangle]
pub extern "C" fn fl_control_stop() {
    let Some(server) = state().lock().unwrap().take() else {
        return;
    };
    shutdown(server);
}

fn shutdown(server: Server) {
    server.stopped.store(true, Ordering::Release);
    for sender in server.replies.lock().unwrap().drain().map(|(_, s)| s) {
        let _ = sender.try_send("{\"status\":\"rejected\",\"errorCode\":\"shutting_down\"}".into());
    }
    for fd in server.sockets.lock().unwrap().values() {
        unsafe {
            libc::shutdown(*fd, libc::SHUT_RDWR);
        }
    }
    let socket = server.directory.join("control.sock");
    if verify_owned(&socket, 0o600, true).is_ok()
        && fs::symlink_metadata(&socket).is_ok_and(|m| m.ino() == server.socket_inode)
    {
        let _ = fs::remove_file(socket);
    }
    let discovery = server.directory.join("instance.json");
    if verify_owned(&discovery, 0o600, false).is_ok()
        && fs::symlink_metadata(&discovery).is_ok_and(|meta| meta.ino() == server.discovery_inode)
    {
        if let Ok(value) = read_discovery(&discovery) {
            if value["instanceId"] == server.instance {
                let _ = fs::remove_file(discovery);
            }
        }
    }
}

#[no_mangle]
pub unsafe extern "C" fn fl_control_free(value: *mut libc::c_char) {
    if !value.is_null() {
        drop(CString::from_raw(value));
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn deadline_bounds_partial_frame() {
        let (mut a, mut b) = UnixStream::pair().unwrap();
        b.write_all(&[1]).unwrap();
        let started = Instant::now();
        assert!(read_frame_deadline(&mut a, Duration::from_millis(30)).is_err());
        assert!(started.elapsed() < Duration::from_millis(300));
    }
    #[test]
    fn private_endpoint_instance_lock_and_replaced_file_cleanup() {
        let directory =
            std::env::temp_dir().join(format!("control-instance-test-{}", std::process::id()));
        let _ = fs::remove_dir_all(&directory);
        let server = start(directory.clone(), "instance-one".into()).unwrap();
        verify_owned(&directory, 0o700, false).unwrap();
        verify_owned(&directory.join("control.sock"), 0o600, true).unwrap();
        verify_owned(&directory.join("instance.json"), 0o600, false).unwrap();
        assert!(start(directory.clone(), "instance-two".into()).is_err());
        let mut connection = UnixStream::connect(directory.join("control.sock")).unwrap();
        write_frame(&mut connection, b"{}").unwrap();
        let packet = server
            .receiver
            .lock()
            .unwrap()
            .recv_timeout(Duration::from_secs(1))
            .unwrap();
        server
            .replies
            .lock()
            .unwrap()
            .remove(&packet.token)
            .unwrap()
            .send("{}".into())
            .unwrap();
        assert_eq!(read_frame_deadline(&mut connection, WAIT).unwrap(), b"{}");
        let clients: Vec<_> = (0..7)
            .map(|_| UnixStream::connect(directory.join("control.sock")).unwrap())
            .collect();
        let deadline = Instant::now() + Duration::from_secs(1);
        while server.sockets.lock().unwrap().len() < MAX_CLIENTS && Instant::now() < deadline {
            thread::sleep(Duration::from_millis(10));
        }
        assert_eq!(server.sockets.lock().unwrap().len(), MAX_CLIENTS);
        let mut excess = UnixStream::connect(directory.join("control.sock")).unwrap();
        excess
            .set_read_timeout(Some(Duration::from_secs(1)))
            .unwrap();
        assert_eq!(excess.read(&mut [0]).unwrap(), 0);
        drop(clients);
        fs::remove_file(directory.join("control.sock")).unwrap();
        File::create(directory.join("control.sock")).unwrap();
        shutdown(server);
        assert!(directory.join("control.sock").is_file());
        assert!(!directory.join("instance.json").exists());
        fs::remove_dir_all(directory).unwrap();
    }
    #[test]
    fn stale_endpoint_cleanup_requires_dead_instance() {
        let directory =
            std::env::temp_dir().join(format!("control-stale-test-{}", std::process::id()));
        let _ = fs::remove_dir_all(&directory);
        fs::DirBuilder::new()
            .mode(0o700)
            .create(&directory)
            .unwrap();
        drop(UnixListener::bind(directory.join("control.sock")).unwrap());
        fs::set_permissions(
            directory.join("control.sock"),
            fs::Permissions::from_mode(0o600),
        )
        .unwrap();
        let mut discovery = private_file(&directory.join("instance.json")).unwrap();
        discovery
            .write_all(br#"{"version":1,"instanceId":"old","pid":1}"#)
            .unwrap();
        assert!(start(directory.clone(), "new".into()).is_err());
        assert!(directory.join("control.sock").exists());
        discovery.set_len(0).unwrap();
        use std::io::Seek;
        discovery.rewind().unwrap();
        discovery
            .write_all(br#"{"version":1,"instanceId":"old","pid":2147483647}"#)
            .unwrap();
        let server = start(directory.clone(), "new".into()).unwrap();
        shutdown(server);
        assert!(!directory.join("control.sock").exists());
        fs::remove_dir_all(directory).unwrap();
    }

    #[test]
    fn rejects_large_and_empty_frames_before_allocation() {
        for size in [0, MAX_FRAME as u32 + 1, u32::MAX] {
            assert!(read_frame(&mut size.to_le_bytes().as_slice()).is_err());
        }
    }
    #[test]
    fn roundtrips_frame_and_rejects_truncation() {
        let mut bytes = Vec::new();
        write_frame(&mut bytes, b"{} ").unwrap();
        assert_eq!(read_frame(&mut bytes.as_slice()).unwrap(), b"{} ");
        assert!(read_frame(&mut bytes[..bytes.len() - 1].as_ref()).is_err());
    }
    #[test]
    fn validates_peer_and_rejects_link_permissions() {
        let (a, _) = UnixStream::pair().unwrap();
        assert!(peer_owned(&a).is_ok());
        let path =
            std::env::temp_dir().join(format!("control-security-test-{}", std::process::id()));
        let _ = fs::remove_file(&path);
        File::create(&path).unwrap();
        fs::set_permissions(&path, fs::Permissions::from_mode(0o644)).unwrap();
        assert!(verify_owned(&path, 0o600, false).is_err());
        fs::remove_file(&path).unwrap();
        std::os::unix::fs::symlink("/tmp", &path).unwrap();
        assert!(verify_owned(&path, 0o700, false).is_err());
        fs::remove_file(path).unwrap();
    }
}
