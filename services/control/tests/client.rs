use std::process::Command;

#[test]
fn help_and_version_are_local_and_never_require_credentials() {
    for argument in ["--help", "--version"] {
        let result = Command::new(env!("CARGO_BIN_EXE_flclashctl"))
            .arg(argument)
            .output()
            .unwrap();
        assert!(result.status.success());
        assert!(!result.stdout.is_empty());
        assert!(result.stderr.is_empty());
    }
}

#[test]
fn forbidden_password_arguments_are_rejected_without_reflection() {
    let secret = "test-only-secret-do-not-reflect";
    for option in ["--password", "--password-env"] {
        let result = Command::new(env!("CARGO_BIN_EXE_flclashctl"))
            .args([option, secret, "status"])
            .output()
            .unwrap();
        assert!(!result.status.success());
        assert!(result.stdout.is_empty());
        assert_eq!(
            String::from_utf8(result.stderr).unwrap(),
            "invalid_arguments\n"
        );
    }
}

#[test]
fn ambiguous_password_sources_are_rejected_before_reading() {
    let result = Command::new(env!("CARGO_BIN_EXE_flclashctl"))
        .args(["--password-stdin", "--password-fd", "3", "status"])
        .output()
        .unwrap();
    assert!(!result.status.success());
    assert_eq!(
        String::from_utf8(result.stderr).unwrap(),
        "invalid_arguments\n"
    );
}
