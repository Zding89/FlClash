import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:fl_clash/control/operations.dart';
import 'package:fl_clash/control/service.dart';
import 'package:fl_clash/control/password.dart';
import 'package:fl_clash/control/transport.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:flutter_test/flutter_test.dart';

class _Password implements ControlPasswordStore {
  @override
  Future<String?> read() async => 'fixture-password-123456';
  @override
  Future<void> write(String value) async {}
}

class _Transport implements ControlTransport {
  String? instance;
  @override
  void start(String id) => instance = id;
  @override
  void stop() {}
  @override
  ControlPacket? poll() => null;
  @override
  void reply(int token, Map<String, Object?> response) {}
}

void main() {
  late WorkbenchDatabase store;
  late _Transport transport;
  late LocalControlService service;
  late Completer<Map<String, Object?>> work;
  var calls = 0;
  ControlRequestLedger ledger() => ControlRequestLedger(
    load: () => store.readSection('fixture.requests'),
    save: (value) => store.writeSection('fixture.requests', value),
  );
  String request({
    String command = 'runtime_read',
    Map<String, Object?> params = const {},
    String? key,
    String password = 'fixture-password-123456',
  }) => jsonEncode({
    'version': 1,
    'instanceId': transport.instance,
    'requestId': 'request',
    'command': command,
    'params': params,
    'auth': {'password': password},
    'idempotencyKey': ?key,
  });
  setUp(() async {
    store = WorkbenchDatabase(NativeDatabase.memory());
    transport = _Transport();
    work = Completer();
    calls = 0;
    service = LocalControlService(
      passwordStore: _Password(),
      transport: transport,
      supported: true,
      operations: ledger(),
      queryTimeout: const Duration(milliseconds: 15),
      executor: (_) {
        calls++;
        return work.future;
      },
    );
    await service.enable();
  });
  tearDown(() async {
    if (!work.isCompleted) work.complete({'status': 'completed'});
    await service.close();
    service.dispose();
    await store.close();
  });
  test(
    'R08 timeout remains authenticated, queryable, persisted and idempotent',
    () async {
      final pending = await service.handle(request(key: 'once'));
      final id = pending['operationId'] as String;
      expect(pending['errorCode'], 'query_timeout');
      expect(
        (await service.handle(
          request(
            command: 'operation_query',
            params: {'operationId': id},
            password: 'bad',
          ),
        ))['errorCode'],
        'authentication_failed',
      );
      expect(
        (await service.handle(
          request(command: 'operation_query', params: {'operationId': id}),
        ))['status'],
        'running',
      );
      expect((await service.handle(request(key: 'once')))['operationId'], id);
      expect(calls, 1);
      work.complete({
        'status': 'completed',
        'result': {'running': true},
      });
      await service.disable();
      await service.enable();
      final finalResult = await service.handle(
        request(command: 'operation_query', params: {'operationId': id}),
      );
      expect(finalResult['status'], 'completed');
      expect((finalResult['result'] as Map)['running'], true);
      expect(
        (await service.handle(request(key: 'once')))['status'],
        'completed',
      );
      expect(calls, 1);
      expect((await ledger().query(id, 'new-owner'))?['status'], 'completed');
    },
  );
  test(
    'R08 result storage failure never reports completion or repeats action',
    () async {
      await service.close();
      service.dispose();
      final persisted = ControlRequestLedger(
        load: () => store.readSection('storage-failure'),
        save: (value) async {
          final rows = value['records'] as List;
          if (rows.any(
            (row) =>
                (row as Map)['response'] is Map &&
                (row['response'] as Map)['status'] == 'completed',
          )) {
            throw StateError('fixture-save-failed');
          }
          await store.writeSection('storage-failure', value);
        },
      );
      service = LocalControlService(
        passwordStore: _Password(),
        transport: transport,
        supported: true,
        operations: persisted,
        executor: (_) async {
          calls++;
          return {'status': 'completed'};
        },
      );
      await service.enable();
      expect(
        (await service.handle(request(key: 'failed-save')))['errorCode'],
        'operation_result_save_failed',
      );
      expect(
        (await service.handle(request(key: 'failed-save')))['errorCode'],
        'operation_result_save_failed',
      );
      expect(calls, 1);
    },
  );
  test('R08 final executor failure survives timeout', () async {
    final response = await service.handle(request());
    work.completeError(StateError('sensitive failure body'));
    await service.disable();
    await service.enable();
    final finalResult = await service.handle(
      request(
        command: 'operation_query',
        params: {'operationId': response['operationId']},
      ),
    );
    expect(finalResult['status'], 'failed');
    expect(finalResult['errorCode'], 'capability_failed');
    expect(finalResult.toString(), isNot(contains('sensitive')));
  });
  test(
    'R08 simultaneous key retries never duplicate executor and conflict is rejected',
    () async {
      final responses = await Future.wait([
        service.handle(request(key: 'same')),
        service.handle(request(key: 'same')),
      ]);
      expect(responses[0]['operationId'], responses[1]['operationId']);
      expect(calls, 1);
      expect(
        (await service.handle(
          request(command: 'network_status', key: 'same'),
        ))['errorCode'],
        'idempotency_conflict',
      );
    },
  );
  test(
    'R08 restart interrupted requests are explicit and not replayed',
    () async {
      final previous = ledger();
      await previous.register(
        id: 'ctl_interrupted',
        owner: 'old',
        fingerprint: ControlRequestLedger.digest({
          'command': 'runtime_read',
          'params': {},
        }),
        key: ControlRequestLedger.digest('old-key'),
      );
      final result = await service.handle(
        request(
          command: 'operation_query',
          params: {'operationId': 'ctl_interrupted'},
        ),
      );
      expect(result['errorCode'], 'operation_interrupted');
      expect(
        (await service.handle(request(key: 'old-key')))['errorCode'],
        'operation_interrupted',
      );
      expect(calls, 0);
    },
  );
  test(
    'R08 limits and expiry bound persisted records and result privacy',
    () async {
      var now = DateTime(2026, 10, 14);
      final bounded = ControlRequestLedger(
        load: () => store.readSection('bounded'),
        save: (value) => store.writeSection('bounded', value),
        maxRecords: 1,
        maxResultBytes: 512,
        retention: const Duration(seconds: 1),
        now: () => now,
      );
      await bounded.register(
        id: 'ctl_one',
        owner: 'owner',
        fingerprint: 'hash',
        key: 'hashed-key',
      );
      await expectLater(
        bounded.register(id: 'ctl_two', owner: 'owner', fingerprint: 'hash2'),
        throwsStateError,
      );
      await bounded.complete('ctl_one', {
        'status': 'completed',
        'password': 'hidden-password',
        'params': {'privateInput': 'hidden-param'},
        'result': {'url': 'https://host.example/private-token'},
      });
      final stored = jsonEncode(await store.readSection('bounded'));
      expect(stored, isNot(contains('hidden-password')));
      expect(stored, isNot(contains('hidden-param')));
      expect(stored, isNot(contains('private-token')));
      await bounded.complete('ctl_one', {
        'status': 'completed',
        'result': 'x' * 600,
      });
      expect(
        (await bounded.query('ctl_one', 'owner'))?['errorCode'],
        'result_limit',
      );
      now = now.add(const Duration(seconds: 2));
      expect(await bounded.query('ctl_one', 'owner'), null);
      await bounded.register(
        id: 'ctl_two',
        owner: 'owner',
        fingerprint: 'hash2',
      );
      expect((await store.readSection('bounded'))?['records'], hasLength(1));
    },
  );
  test(
    'R08 capability confirmation authority survives request handle query',
    () async {
      final pending = await service.handle(request());
      work.complete({
        'status': 'pending_confirmation',
        'operationId': 'capability-id',
        'confirmation': {'digest': 'digest', 'version': 'version'},
      });
      await service.disable();
      await service.enable();
      final response = await service.handle(
        request(
          command: 'operation_query',
          params: {'operationId': pending['operationId']},
        ),
      );
      expect(response['operationId'], 'capability-id');
      expect(response['requestOperationId'], pending['operationId']);
      expect(response['confirmation'], {
        'digest': 'digest',
        'version': 'version',
      });
    },
  );
}
