import json
import os
import pathlib
import plistlib
import re
import secrets
import shlex
import shutil
import signal
import socket
import sqlite3
import stat
import struct
import subprocess
import sys
import tempfile
import time


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def run(arguments, **kwargs):
    return subprocess.run(arguments, check=True, capture_output=True, **kwargs)


def main():
    require(sys.platform == 'darwin', 'macOS required')
    require(os.environ.get('GITHUB_ACTIONS') == 'true', 'dedicated GitHub runner required')
    require(os.environ.get('RUNNER_OS') == 'macOS', 'macOS runner required')
    require(os.environ.get('RUNNER_ENVIRONMENT') == 'github-hosted', 'hosted disposable runner required')
    workspace = pathlib.Path(os.environ['GITHUB_WORKSPACE']).resolve()
    require(pathlib.Path.cwd().resolve() == workspace, 'unexpected working directory')
    app = workspace / 'build/macos/Build/Products/Release/FlClash Usage.app'
    require(app.is_dir() and not app.is_symlink(), 'missing built app')
    with (app / 'Contents/Info.plist').open('rb') as stream:
        info = plistlib.load(stream)
    bundle = 'com.zding.flclash.usage'
    require(info['CFBundleIdentifier'] == bundle, 'unexpected app identity')
    executable = app / 'Contents/MacOS' / info['CFBundleExecutable']
    core = app / 'Contents/MacOS/FlClashCore'
    cli = app / 'Contents/Resources/control/flclashctl'
    run(['/usr/bin/codesign', '--verify', '--deep', '--strict', str(app)])
    data = pathlib.Path.home() / 'Library/Application Support' / bundle
    runtime = pathlib.Path(f'/private/tmp/flclashctl-{os.getuid()}')
    require(not data.exists() and not data.is_symlink(), 'existing app data refuses smoke')
    require(not runtime.exists() and not runtime.is_symlink(), 'existing control endpoint refuses smoke')
    defaults = subprocess.run(['/usr/bin/defaults', 'read', bundle], capture_output=True)
    require(defaults.returncode != 0, 'existing preferences refuse smoke')
    source = pathlib.Path(__file__).resolve().parent
    scratch = pathlib.Path(tempfile.mkdtemp(prefix='flclash-macos-smoke-', dir='/private/tmp'))
    report_dir = workspace / 'build/macos-runtime-smoke'
    report_dir.mkdir(parents=True, exist_ok=False)
    report = {'status': 'running', 'fixture': 'empty isolated hosted macOS runner', 'checks': []}
    password = secrets.token_urlsafe(32)
    keychain_password = secrets.token_urlsafe(32)
    keychain_path = scratch / 'fixture.keychain-db'
    keychain_search_list = shlex.split(run(['/usr/bin/security', 'list-keychains', '-d', 'user']).stdout.decode())
    process = None
    children = {}
    keychain_created = False
    preferences_created = False
    log = None
    helper = scratch / 'seed_keychain'

    def checkpoint(name):
        report['checks'].append(name)
        print(f'PASS {name}', flush=True)

    def remember_children():
        if process is None:
            return
        listing = run(['/bin/ps', '-axo', 'pid=,ppid=,command=']).stdout.decode()
        for line in listing.splitlines():
            fields = line.strip().split(None, 2)
            if len(fields) == 3 and int(fields[1]) == process.pid and fields[2].startswith(str(core) + ' '):
                children[int(fields[0])] = fields[2]

    def owned_alive(pid, command):
        result = subprocess.run(['/bin/ps', '-p', str(pid), '-o', 'state=,command='], capture_output=True)
        fields = result.stdout.decode().strip().split(None, 1)
        return len(fields) == 2 and not fields[0].startswith('Z') and fields[1] == command

    def command(name, params=None, secret=None, expected=0, key=None):
        arguments = [str(cli), '--password-stdin']
        if key is not None:
            arguments += ['--idempotency-key', key]
        arguments += ['invoke', name, json.dumps(params or {}, separators=(',', ':'))]
        response = subprocess.run(arguments, input=((password if secret is None else secret) + '\n').encode(), capture_output=True, timeout=40)
        require(response.returncode == expected, f'{name} returned unexpected exit code {response.returncode}')
        require(password.encode() not in response.stdout + response.stderr, 'credential present in CLI output')
        value = json.loads(response.stdout)
        require(isinstance(value, dict), 'CLI response must be an object')
        return value

    def wait_operation(operation_id):
        deadline = time.monotonic() + 25
        while time.monotonic() < deadline:
            result = command('operation_query', {'operationId': operation_id})
            if result['status'] not in {'queued', 'running', 'pending', 'accepted'}:
                return result
            time.sleep(0.2)
        raise RuntimeError('operation never reached a terminal result')

    def mutate(name, key, params=None):
        proposal = command(name, params, key=key)
        require(proposal['status'] == 'pending_confirmation', f'{name} skipped preview')
        accepted = command('capability_confirm', {'operationId': proposal['operationId'], **proposal['confirmation']})
        require(accepted['status'] == 'accepted', f'{name} confirmation not accepted')
        return proposal['operationId']

    def start_app():
        nonlocal process, log
        index = len(list(report_dir.glob('launch-*.log'))) + 1
        log = (report_dir / f'launch-{index}.log').open('wb')
        process = subprocess.Popen([str(executable)], cwd=workspace, stdout=log, stderr=subprocess.STDOUT)
        deadline = time.monotonic() + 45
        while time.monotonic() < deadline:
            require(process.poll() is None, 'app exited before CLI became available')
            remember_children()
            discovery = runtime / 'instance.json'
            if discovery.exists() and (runtime / 'control.sock').exists():
                for path, mode in [(runtime, 0o700), (discovery, 0o600), (runtime / 'control.sock', 0o600)]:
                    entry = path.lstat()
                    require(entry.st_uid == os.getuid() and stat.S_IMODE(entry.st_mode) == mode and not path.is_symlink(), 'unsafe control endpoint')
                status = command('runtime_read')
                require(status['status'] == 'completed', 'runtime query did not complete')
                require(status['result']['running'] is False, 'empty fixture unexpectedly activated traffic')
                if status['result']['coreStatus'] == 'connected':
                    remember_children()
                    require(any(owned_alive(pid, value) for pid, value in children.items()), 'owned Core PID was not observed')
                    return
            time.sleep(0.25)
        raise RuntimeError('app/Keychain/GUI initialization timeout')

    def exit_app(key):
        mutate('app_exit', key)
        process.wait(timeout=35)
        require(process.returncode == 0, 'application exit was not clean')
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline and any(owned_alive(pid, value) for pid, value in children.items()):
            time.sleep(0.1)
        require(not any(owned_alive(pid, value) for pid, value in children.items()), 'owned Core survived application exit')
        require(not (runtime / 'control.sock').exists() and not (runtime / 'instance.json').exists(), 'control endpoint survived exit')
        log.close()

    try:
        config = scratch / 'config.json'
        run(['flutter', 'test', '--no-pub', f'--dart-define=SMOKE_DATA_DIR={data}', f'--dart-define=SMOKE_CONFIG_PATH={config}', str(source / 'seed_test.dart'), '--reporter', 'expanded'], cwd=workspace)
        run(['/usr/bin/defaults', 'write', bundle, 'flutter.config', '-string', config.read_text()])
        preferences_created = True
        run(['/usr/bin/xcrun', 'swiftc', '-module-cache-path', str(scratch / 'module-cache'), str(source / 'seed_keychain.swift'), '-o', str(helper)])
        keychain_created = True
        run([str(helper), 'seed', str(executable), str(keychain_path)], input=json.dumps({
            'password': password,
            'keychainPassword': keychain_password,
        }).encode())
        signature = run(['/usr/bin/codesign', '-d', '--verbose=4', str(executable)]).stderr.decode()
        hashes = re.findall(r'^CDHash=([0-9a-f]{40})$', signature, re.MULTILINE)
        require(len(hashes) == 1, 'missing unique application code hash')
        partition = [
            'set-generic-password-partition-list', '-a', 'password',
            '-s', bundle + '.control.credentials', '-S', 'cdhash:' + hashes[0],
            '-k', keychain_password, str(keychain_path),
        ]
        require(all(re.fullmatch(r'[A-Za-z0-9_./:-]+', argument) for argument in partition), 'unsafe keychain fixture argument')
        run(['/usr/bin/security', '-i'], input=(' '.join(partition) + '\n').encode())
        run(['/usr/bin/security', 'set-keychain-settings', '-lut', '600', str(keychain_path)])
        run(['/usr/bin/security', 'list-keychains', '-d', 'user', '-s', *keychain_search_list, str(keychain_path)])
        report['keychainFixture'] = 'temporary dedicated keychain with exact application ACL and code-hash partition'
        start_app()
        checkpoint('signed packaged app starts with its owned Core and authenticated CLI')
        wrong = command('runtime_read', secret='wrong-fixture-password', expected=2)
        require(wrong['errorCode'] == 'authentication_failed', 'wrong password was not rejected')
        discovery = json.loads((runtime / 'instance.json').read_text())
        request = json.dumps({'version': 1, 'instanceId': discovery['instanceId'], 'requestId': 'missing-auth-fixture', 'command': 'runtime_read', 'params': {}}).encode()
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
            connection.settimeout(10)
            connection.connect(str(runtime / 'control.sock'))
            connection.sendall(struct.pack('<I', len(request)) + request)
            def receive(count):
                result = bytearray()
                while len(result) < count:
                    chunk = connection.recv(count - len(result))
                    require(bool(chunk), 'truncated control response')
                    result.extend(chunk)
                return bytes(result)
            length = struct.unpack('<I', receive(4))[0]
            require(0 < length <= 1024 * 1024, 'unbounded control frame')
            missing = json.loads(receive(length))
        require(missing['errorCode'] == 'authentication_failed', 'missing authentication was not rejected')
        checkpoint('wrong and missing password rejected on read commands')
        manifest = command('capabilities')['result']['capabilities']
        require({'app_hide', 'app_show', 'app_exit', 'policies_read', 'local_policy_details'} <= {entry['command'] for entry in manifest}, 'capability manifest incomplete')
        checkpoint('real capability discovery succeeds')
        read_commands = [
            'settings_catalog', 'settings_read', 'profiles_list', 'scripts_list',
            'policies_read', 'policies_runtime', 'proxies_read', 'providers_read',
            'network_status', 'connections_read', 'logs_read', 'requests_read',
            'usage_read', 'version_read', 'hotkeys_status', 'agent_settings_read',
        ]
        for name in read_commands:
            response = command(name)
            require(response['status'] == 'completed', f'{name} did not return a completed observation')
        range_end = int(time.time() * 1000)
        empty_history = command('usage_history', {'start': range_end - 86400000, 'end': range_end})
        require(empty_history['status'] == 'completed', 'usage history query failed')
        report['observedCommands'] = read_commands + ['usage_history']
        checkpoint('17 authenticated read commands execute through the real application gateway')
        wrong_write = command('app_hide', secret='wrong-fixture-password', expected=2)
        require(wrong_write['errorCode'] == 'authentication_failed', 'wrong password was not rejected on write commands')
        closed = wait_operation(mutate('connection_close', 'smoke-close-empty', {'all': True}))
        require(closed['status'] == 'completed', 'empty fixture connection close did not reach completion')
        require(command('connections_read')['result']['total'] == 0, 'empty fixture connections did not remain empty')
        checkpoint('authenticated write rejection and confirmed connection command reach the real Core')
        hidden_id = mutate('app_hide', 'smoke-hide')
        hidden = wait_operation(hidden_id)
        require(hidden['status'] == 'completed' and hidden['result']['visible'] is False, 'window hide result is not confirmed')
        require(command('runtime_read')['status'] == 'completed', 'hidden window stopped the control service')
        replay = command('app_hide', key='smoke-hide')
        require(replay['operationId'] == hidden_id, 'idempotent retry created a second operation')
        checkpoint('bound confirmation, hidden-window service, and idempotent result query')
        visible = wait_operation(mutate('app_show', 'smoke-show'))
        require(visible['status'] == 'completed' and visible['result']['visible'] is True, 'window show result is not confirmed')
        subprocess.run(['/usr/sbin/screencapture', '-x', str(report_dir / 'app-window.png')], capture_output=True, timeout=10)
        exit_app('smoke-exit-one')
        checkpoint('authenticated exit removes endpoint and owned Core')
        start_app()
        prior = command('operation_query', {'operationId': hidden_id})
        require(prior['status'] == 'completed', 'completed operation not queryable across restart')
        checkpoint('same fixed password and prior completed operation survive application restart')
        exit_app('smoke-exit-two')
        checkpoint('second graceful exit succeeds')
        report['status'] = 'passed'
    except Exception as error:
        report['status'] = 'failed'
        report['error'] = str(error).replace(password, '[REDACTED-FIXTURE]').replace(keychain_password, '[REDACTED-KEYCHAIN]')
        report['endpointFiles'] = [
            {'name': path.name, 'mode': oct(stat.S_IMODE(path.lstat().st_mode))}
            for path in runtime.iterdir()
        ] if runtime.is_dir() and not runtime.is_symlink() else []
        database = data / 'workbench.sqlite'
        if database.is_file():
            try:
                with sqlite3.connect(f'file:{database}?mode=ro', uri=True) as connection:
                    record = connection.execute(
                        "SELECT payload FROM workbench_records WHERE section = 'localControl'"
                    ).fetchone()
                    report['fixtureControlEnabled'] = bool(record and json.loads(record[0]).get('enabled') is True)
            except Exception as diagnostic_error:
                report['fixtureDiagnosticError'] = type(diagnostic_error).__name__
        if process is not None and process.poll() is None:
            for arguments in [
                ['/usr/sbin/screencapture', '-x', str(report_dir / 'failure-window.png')],
                ['/usr/bin/sample', str(process.pid), '1', '1', '-file', str(report_dir / 'failure-sample.txt')],
            ]:
                try:
                    subprocess.run(arguments, capture_output=True, timeout=15)
                except (OSError, subprocess.SubprocessError) as diagnostic_error:
                    report.setdefault('captureErrors', []).append(type(diagnostic_error).__name__)
        if isinstance(error, subprocess.CalledProcessError):
            diagnostic = (error.stdout or b'') + (error.stderr or b'')
            (report_dir / 'setup-error.log').write_bytes(diagnostic[-1024 * 1024:].replace(password.encode(), b'[REDACTED-FIXTURE]').replace(keychain_password.encode(), b'[REDACTED-KEYCHAIN]'))
        raise
    finally:
        remember_children()
        if process is not None and process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
        for pid, value in children.items():
            if owned_alive(pid, value):
                os.kill(pid, signal.SIGTERM)
        if log is not None and not log.closed:
            log.close()
        for logfile in report_dir.glob('launch-*.log'):
            payload = logfile.read_bytes()
            if password.encode() in payload:
                logfile.write_bytes(payload.replace(password.encode(), b'[REDACTED-FIXTURE]'))
                report['status'] = 'failed'
                report['error'] = 'fixture credential found in application output'
        if keychain_created:
            for name, arguments in [
                ('restore_keychain_search_list', ['/usr/bin/security', 'list-keychains', '-d', 'user', '-s', *keychain_search_list]),
                ('remove_fixture_keychain', [str(helper), 'remove', str(executable), str(keychain_path)]),
            ]:
                try:
                    result = subprocess.run(arguments, capture_output=True, timeout=10)
                    if result.returncode != 0:
                        report.setdefault('cleanupErrors', []).append(name)
                except (OSError, subprocess.SubprocessError):
                    report.setdefault('cleanupErrors', []).append(name)
            if report.get('cleanupErrors'):
                report['status'] = 'failed'
                report.setdefault('error', 'temporary keychain cleanup failed')
            else:
                checkpoint('temporary keychain removed and original search list restored')
        (report_dir / 'report.json').write_text(json.dumps(report, indent=2))
        if preferences_created:
            subprocess.run(['/usr/bin/defaults', 'delete', bundle], capture_output=True, timeout=10)
        if data.exists():
            shutil.rmtree(data)
        shutil.rmtree(scratch)
        if report['status'] != 'passed':
            print('macOS runtime smoke failed; see report.json', file=sys.stderr)
    require(report['status'] == 'passed', 'smoke did not pass')


if __name__ == '__main__':
    main()
