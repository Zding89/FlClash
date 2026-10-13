import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/control/password.dart';
import 'package:fl_clash/control/service.dart';
import 'package:fl_clash/control/transport.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryStore implements ControlPasswordStore {
  String? value;
  bool readFails = false;
  bool writeFails = false;
  int writes = 0;
  @override
  Future<String?> read() async {
    if (readFails) throw StateError('locked');
    return value;
  }

  @override
  Future<void> write(String password) async {
    if (writeFails) throw StateError('locked');
    value = password;
    writes++;
  }
}

class FakeTransport implements ControlTransport {
  String? instance;
  @override
  ControlPacket? poll() => null;
  @override
  void reply(int token, Map<String, Object?> response) {}
  @override
  void start(String instanceId) {
    instance = instanceId;
  }

  @override
  void stop() {}
}

void main() {
  late MemoryStore store;
  late FakeTransport transport;
  late LocalControlService service;
  var calls = 0;
  String request({
    String? password,
    String command = 'capabilities.list',
    Map<String, Object?> extra = const {},
  }) => jsonEncode({
    'version': 1,
    'instanceId': transport.instance,
    'requestId': 'request',
    'command': command,
    'auth': {'password': password ?? store.value},
    'params': <String, Object?>{},
    ...extra,
  });
  setUp(() {
    store = MemoryStore();
    transport = FakeTransport();
    calls = 0;
    service = LocalControlService(
      passwordStore: store,
      transport: transport,
      supported: true,
      executor: (_) async {
        calls++;
        return {'status': 'completed'};
      },
    );
  });
  tearDown(() async {
    await service.close();
    service.dispose();
  });
  test(
    'disabled and unsupported native transport never opens a dynamic library',
    () async {
      service.dispose();
      final native = NativeControlTransport();
      expect(native.poll(), null);
      native.stop();
      service = LocalControlService(
        passwordStore: store,
        transport: native,
        supported: false,
        executor: (_) async => {'status': 'completed'},
      );
      await service.enable();
      expect(service.errorCode, 'unsupported_platform');
      expect(store.writes, 0);
      await service.close();
    },
  );
  test(
    'default off and password only generated for missing record, restart retains it',
    () async {
      expect(service.enabled, false);
      await service.enable();
      final password = store.value;
      expect(base64Url.decode('$password=').length, 32);
      expect(store.writes, 1);
      await service.disable();
      await service.enable();
      expect(store.value, password);
      expect(store.writes, 1);
    },
  );
  test('read and write failures never enable or overwrite', () async {
    store.readFails = true;
    await service.enable();
    expect(service.enabled, false);
    expect(store.writes, 0);
    store.readFails = false;
    store.writeFails = true;
    await service.enable();
    expect(service.enabled, false);
    expect(store.value, null);
  });
  test(
    'all commands authenticate; unknown fields and auth never reach executor',
    () async {
      await service.enable();
      for (final command in [
        'capabilities.list',
        'connection.status',
        'operations.get',
      ]) {
        final result = await service.handle(
          request(password: 'wrong-password', command: command),
        );
        expect(result['errorCode'], 'authentication_failed');
        expect(jsonEncode(result).contains('wrong-password'), false);
      }
      expect(
        (await service.handle(request(extra: {'unknown': true})))['errorCode'],
        'invalid_envelope',
      );
      expect(calls, 0);
      expect((await service.handle(request()))['status'], 'completed');
      expect(calls, 1);
    },
  );
  test(
    'password unicode validation preserves spaces and rejects C1 controls',
    () {
      expect(isValidControlPassword('  这是测试安全密码１２３  '), true);
      expect(isValidControlPassword('abcdefghijkl\u0085'), false);
      expect(matchesControlPassword('  abcdefghijkl  ', 'abcdefghijkl'), false);
      expect(isValidControlPassword('\uD800abcdefghijkl'), false);
      expect(
        matchesControlPassword('\uD800abcdefghijkl', '\uFFFDabcdefghijkl'),
        false,
      );
    },
  );
  test(
    'restart and re-enable use a fresh exact JSON credential generation before accepting',
    () async {
      final synchronized = <int>[];
      service.dispose();
      service = LocalControlService(
        passwordStore: store,
        transport: transport,
        supported: true,
        onCredentialRotated: (generation) async {
          expect(service.enabled, false);
          synchronized.add(generation);
        },
        executor: (_) async => {'status': 'completed'},
      );
      await service.enable();
      final first = service.credentialGeneration;
      expect(first, greaterThan(0));
      expect(first, lessThan(1 << 53));
      expect(
        jsonDecode(jsonEncode({'generation': first}))['generation'],
        first,
      );
      await service.disable();
      await service.enable();
      expect(service.credentialGeneration, isNot(first));
      expect(synchronized, hasLength(2));
      await service.close();
      service.dispose();
      service = LocalControlService(
        passwordStore: store,
        transport: transport,
        supported: true,
        executor: (_) async => {'status': 'completed'},
      );
      await service.enable();
      expect(service.credentialGeneration, isNot(first));
      expect(store.writes, 1);
    },
  );
  test('generation synchronization failure never starts accepting', () async {
    service.dispose();
    service = LocalControlService(
      passwordStore: store,
      transport: transport,
      supported: true,
      onCredentialRotated: (_) async => throw StateError('fixture_sync_failed'),
      executor: (_) async => {'status': 'completed'},
    );
    await service.enable();
    expect(service.enabled, false);
    expect(transport.instance, null);
    expect(calls, 0);
  });
  test(
    'malformed JSON unicode cannot authenticate as a replacement-character password',
    () async {
      store.value = '\uFFFDabcdefghijkl';
      await service.enable();
      final malformed = request().replaceFirst('\uFFFD', r'\ud800');
      expect(
        (await service.handle(malformed))['errorCode'],
        'authentication_failed',
      );
      expect(calls, 0);
      expect((await service.handle(request()))['status'], 'completed');
    },
  );
  test(
    'rotation rejects queued old generation and waits for writing even after client timeout',
    () async {
      final writing = Completer<Map<String, Object?>>();
      service.dispose();
      service = LocalControlService(
        passwordStore: store,
        transport: transport,
        supported: true,
        queryTimeout: const Duration(milliseconds: 5),
        executor: (_) {
          calls++;
          return writing.future;
        },
      );
      await service.enable();
      final old = store.value;
      final active = service.handle(request());
      await Future<void>.delayed(Duration.zero);
      final queued = service.handle(request());
      expect((await active)['status'], 'pending');
      var rotated = false;
      final rotation = service
          .rotatePassword('new-password-123456')
          .then((value) => rotated = value);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(rotated, false);
      expect(store.value, old);
      writing.complete({'status': 'completed'});
      await rotation;
      expect(rotated, true);
      expect((await queued)['errorCode'], 'queue_timeout');
      expect(calls, 1);
      expect(
        (await service.handle(request(password: old)))['errorCode'],
        'authentication_failed',
      );
    },
  );
  test(
    'failed save preserves old password and request authentication',
    () async {
      await service.enable();
      final old = store.value;
      store.writeFails = true;
      expect(await service.rotatePassword('new-password-123456'), false);
      expect(store.value, old);
      expect(
        (await service.handle(request(password: old)))['status'],
        'completed',
      );
    },
  );
  test('failure rate and queue are bounded', () async {
    await service.enable();
    for (var index = 0; index < 8; index++) {
      await service.handle(request(password: 'bad-password'));
    }
    expect(
      (await service.handle(request()))['errorCode'],
      'authentication_rate_limited',
    );
  });
  test('queue overflow and rotation reject old waiting work', () async {
    final writing = Completer<Map<String, Object?>>();
    service.dispose();
    service = LocalControlService(
      passwordStore: store,
      transport: transport,
      supported: true,
      executor: (_) {
        calls++;
        return writing.future;
      },
    );
    await service.enable();
    final requests = List.generate(16, (_) => service.handle(request()));
    await Future<void>.delayed(Duration.zero);
    expect((await service.handle(request()))['errorCode'], 'server_busy');
    final rotation = service.rotatePassword('another-password-1234');
    writing.complete({'status': 'completed'});
    expect(await rotation, true);
    final results = await Future.wait(requests);
    expect(results.first['status'], 'completed');
    expect(
      results
          .skip(1)
          .every((result) => result['errorCode'] == 'credential_superseded'),
      true,
    );
    expect(calls, 1);
  });
  test(
    'background accepted writes remain owned through rotation drain',
    () async {
      final writing = Completer<void>();
      service.dispose();
      service = LocalControlService(
        passwordStore: store,
        transport: transport,
        supported: true,
        drainCapabilities: () => writing.future,
        executor: (_) async => {
          'status': 'accepted',
          'operationId': 'operation',
        },
      );
      await service.enable();
      final old = store.value;
      expect((await service.handle(request()))['operationId'], 'operation');
      final rotation = service.rotatePassword('new-background-password');
      await Future<void>.delayed(Duration.zero);
      expect(store.value, old);
      writing.complete();
      expect(await rotation, true);
      expect(store.value, 'new-background-password');
    },
  );
  test(
    'drain timeout preserves old credential without interrupting writes',
    () async {
      final writing = Completer<void>();
      service.dispose();
      service = LocalControlService(
        passwordStore: store,
        transport: transport,
        supported: true,
        drainTimeout: const Duration(milliseconds: 5),
        drainCapabilities: () => writing.future,
        executor: (_) async => {
          'status': 'accepted',
          'operationId': 'operation',
        },
      );
      await service.enable();
      final old = store.value;
      expect(await service.rotatePassword('cannot-yet-save-password'), false);
      expect(store.value, old);
      expect(writing.isCompleted, false);
      writing.complete();
      expect(
        (await service.handle(request(password: old)))['status'],
        'accepted',
      );
    },
  );
}
