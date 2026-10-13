import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'password.dart';
import 'transport.dart';

class ControlCommand {
  const ControlCommand({
    required this.command,
    required this.params,
    required this.requestId,
    required this.credentialGeneration,
    this.idempotencyKey,
  });
  final String command;
  final Map<String, Object?> params;
  final String requestId;
  final int credentialGeneration;
  final String? idempotencyKey;
}

typedef CapabilityExecutor =
    Future<Map<String, Object?>> Function(ControlCommand command);

class LocalControlService extends ChangeNotifier {
  LocalControlService({
    required this.passwordStore,
    required this.transport,
    required this.executor,
    required this.supported,
    this.onCredentialRotated,
    this.onEnabledChanged,
    this.drainCapabilities,
    this.drainTimeout = const Duration(seconds: 30),
    this.queryTimeout = const Duration(seconds: 10),
  });

  final ControlPasswordStore passwordStore;
  final ControlTransport transport;
  final CapabilityExecutor executor;
  final bool supported;
  final Future<void> Function(int generation)? onCredentialRotated;
  final Future<void> Function(bool enabled)? onEnabledChanged;
  final Future<void> Function()? drainCapabilities;
  final Duration drainTimeout;
  final Duration queryTimeout;
  bool enabled = false;
  bool busy = false;
  String? errorCode;
  String? _password;
  String? _instanceId;
  int _generation = 0;
  bool _accepting = false;
  bool _closed = false;
  Timer? _timer;
  Future<void> _tail = Future.value();
  int _pending = 0;
  final _failureWindow = Stopwatch()..start();
  int _failures = 0;

  bool get passwordConfigured => _password != null;
  int get credentialGeneration => _generation;
  String? revealPassword() => _password;

  Future<void> enable() async {
    if (_closed || busy || enabled) return;
    if (!supported) {
      errorCode = 'unsupported_platform';
      notifyListeners();
      return;
    }
    busy = true;
    errorCode = null;
    notifyListeners();
    try {
      var password = await passwordStore.read();
      if (password == null) {
        password = generateControlPassword();
        await passwordStore.write(password);
      }
      if (!isValidControlPassword(password)) {
        throw StateError('invalid_stored_password');
      }
      _password = password;
      _generation = generateControlCredentialGeneration();
      await onCredentialRotated?.call(_generation);
      _instanceId = generateControlPassword();
      transport.start(_instanceId!);
      _accepting = true;
      enabled = true;
      _timer = Timer.periodic(const Duration(milliseconds: 20), (_) => _poll());
      await onEnabledChanged?.call(true);
    } catch (_) {
      _timer?.cancel();
      transport.stop();
      _accepting = false;
      enabled = false;
      errorCode = 'control_unavailable';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> disable() async {
    if (busy || !enabled) return;
    busy = true;
    _accepting = false;
    notifyListeners();
    try {
      await _drain().timeout(drainTimeout);
      _timer?.cancel();
      transport.stop();
      enabled = false;
      await onEnabledChanged?.call(false);
      errorCode = null;
    } catch (_) {
      errorCode = 'control_drain_timeout';
      _accepting = true;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _drain() async {
    await _tail;
    await drainCapabilities?.call();
  }

  Future<bool> rotatePassword(String password) async {
    if (_closed || busy || !isValidControlPassword(password)) return false;
    if (_password != null && matchesControlPassword(password, _password!)) {
      errorCode = 'control_password_unchanged';
      notifyListeners();
      return false;
    }
    busy = true;
    _accepting = false;
    notifyListeners();
    final previous = _password;
    try {
      await _drain().timeout(drainTimeout);
      await passwordStore.write(password);
      _password = password;
      _generation = _generation < (1 << 53) - 1
          ? _generation + 1
          : generateControlCredentialGeneration();
      await onCredentialRotated?.call(_generation);
      errorCode = null;
      return true;
    } catch (_) {
      if (_password == previous) {
        errorCode = 'control_password_save_failed';
      } else {
        errorCode = 'control_rotation_callback_failed';
        enabled = false;
        transport.stop();
        _timer?.cancel();
        return true;
      }
      return false;
    } finally {
      _accepting = enabled && !_closed;
      busy = false;
      notifyListeners();
    }
  }

  void _poll() {
    for (var count = 0; count < 16; count++) {
      final packet = transport.poll();
      if (packet == null) return;
      unawaited(
        handle(
          packet.body,
        ).then((response) => transport.reply(packet.token, response)),
      );
    }
  }

  Future<Map<String, Object?>> handle(String body) async {
    String? requestId;
    Map<String, Object?> reject(String code) => {
      'requestId': requestId,
      'status': 'rejected',
      'errorCode': code,
    };
    try {
      if (utf8.encode(body).length > 1024 * 1024) {
        return reject('invalid_frame');
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return reject('invalid_envelope');
      const allowed = {
        'version',
        'instanceId',
        'requestId',
        'command',
        'auth',
        'params',
        'idempotencyKey',
      };
      if (decoded.keys.any((key) => !allowed.contains(key))) {
        return reject('invalid_envelope');
      }
      final id = decoded['requestId'];
      if (id is! String ||
          id.isEmpty ||
          id.length > 128 ||
          id.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
        return reject('invalid_envelope');
      }
      requestId = id;
      if (decoded['version'] != 1) return reject('protocol_mismatch');
      final auth = decoded['auth'];
      if (_failureWindow.elapsed >= const Duration(seconds: 5)) {
        _failures = 0;
        _failureWindow.reset();
      }
      if (_failures >= 8) return reject('authentication_rate_limited');
      if (auth is! Map<String, dynamic> ||
          auth.length != 1 ||
          auth['password'] is! String ||
          (auth['password'] as String).length > 512 ||
          _password == null ||
          !matchesControlPassword(auth['password'] as String, _password!)) {
        _failures++;
        return reject('authentication_failed');
      }
      if (decoded['instanceId'] != _instanceId) {
        return reject('instance_mismatch');
      }
      if (!_accepting || !enabled || _closed) {
        return reject(_closed ? 'shutting_down' : 'control_paused');
      }
      final command = decoded['command'];
      final params = decoded['params'];
      final key = decoded['idempotencyKey'];
      if (command is! String ||
          !RegExp(r'^[a-z][a-zA-Z0-9_.]{0,127}$').hasMatch(command) ||
          params is! Map<String, dynamic> ||
          (key != null &&
              (key is! String || key.isEmpty || key.length > 128))) {
        return reject('invalid_envelope');
      }
      if (_pending >= 16) return reject('server_busy');
      final generation = _generation;
      final result = Completer<Map<String, Object?>>();
      var expired = false;
      final queueTimeout = Timer(queryTimeout, () {
        expired = true;
        if (!result.isCompleted) result.complete(reject('queue_timeout'));
      });
      _pending++;
      _tail = _tail.then((_) async {
        try {
          queueTimeout.cancel();
          if (expired) return;
          if (generation != _generation || !_accepting || _closed) {
            result.complete(reject('credential_superseded'));
            return;
          }
          final execution = executor(
            ControlCommand(
              command: command,
              params: Map<String, Object?>.from(params),
              requestId: id,
              credentialGeneration: generation,
              idempotencyKey: key as String?,
            ),
          );
          final timeout = Timer(queryTimeout, () {
            if (!result.isCompleted) {
              result.complete({
                'requestId': id,
                'status': 'pending',
                'errorCode': 'query_timeout',
              });
            }
          });
          try {
            final response = await execution;
            if (!result.isCompleted) {
              result.complete({...response, 'requestId': id});
            }
          } finally {
            timeout.cancel();
          }
        } catch (_) {
          if (!result.isCompleted) {
            result.complete({
              'requestId': id,
              'status': 'failed',
              'errorCode': 'capability_failed',
            });
          }
        } finally {
          _pending--;
        }
      });
      return result.future;
    } catch (_) {
      return reject('invalid_envelope');
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _accepting = false;
    _timer?.cancel();
    try {
      await _drain().timeout(drainTimeout);
    } catch (_) {
      errorCode = 'control_drain_timeout';
    }
    transport.stop();
    enabled = false;
    _password = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    transport.stop();
    super.dispose();
  }
}
