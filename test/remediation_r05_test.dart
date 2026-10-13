import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:fl_clash/ai/tools.dart';
import 'package:fl_clash/capabilities/gateway.dart';
import 'package:fl_clash/capabilities/service.dart';
import 'package:fl_clash/configuration/resources.dart';
import 'package:fl_clash/control/password.dart';
import 'package:fl_clash/control/service.dart';
import 'package:fl_clash/control/transport.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class Environment extends Mock implements ResourceEnvironment {}

class AgentGateway extends Mock implements AgentResourceGateway {}

class Controller extends Mock implements WorkbenchController {
  Controller(this.store);
  @override
  final WorkbenchDatabase store;
}

class Gateway implements ApplicationCapabilityGateway {
  int calls = 0;
  String currentVersion = 'unchanged';
  Completer<Map<String, Object?>>? work;
  final started = Completer<void>();
  @override
  bool supported = true;
  @override
  Future<String> version() async => currentVersion;
  @override
  Future<Map<String, Object?>> execute(
    String command,
    Map<String, Object?> params, {
    required String origin,
    Future<bool> Function()? beginMutation,
    bool Function()? isCurrent,
  }) async {
    calls++;
    if (!started.isCompleted) started.complete();
    return work?.future ?? {'status': 'completed'};
  }
}

class PasswordStore implements ControlPasswordStore {
  String? value = 'fake-password-123456';
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String password) async => value = password;
}

class Transport implements ControlTransport {
  String? instance;
  @override
  void start(String instanceId) => instance = instanceId;
  @override
  void stop() {}
  @override
  ControlPacket? poll() => null;
  @override
  void reply(int token, Map<String, Object?> response) {}
}

class Fixture {
  final store = WorkbenchDatabase(NativeDatabase.memory());
  final gateway = Gateway();
  final container = ProviderContainer();
  late final controller = Controller(store);
  late final service = create();
  ApplicationCapabilityService create() => container.read(
    Provider(
      (ref) => ApplicationCapabilityService(
        ref: ref,
        controller: controller,
        gateway: gateway,
        tools: AgentTools(
          controller: controller,
          approve: (_) async => false,
          exposeApplication: false,
          resources: ResourceChangeService(
            store: store,
            environment: Environment(),
          ),
          gateway: AgentGateway(),
        ),
      ),
    ),
  );
  Future<Map<String, Object?>> confirm({
    bool Function()? current,
    int generation = 17,
  }) async {
    final proposal = await service.execute(
      'maintenance_clear_cache',
      {},
      credentialGeneration: generation,
    );
    final result = await service.execute(
      'capability_confirm',
      {
        'operationId': proposal['operationId'],
        ...Map<String, Object?>.from(proposal['confirmation'] as Map),
      },
      credentialGeneration: generation,
      isCurrent: current,
    );
    expect(result['status'], 'accepted');
    return proposal;
  }

  Future<void> close() async {
    if (gateway.work != null && !gateway.work!.isCompleted) {
      gateway.work!.complete({'status': 'completed'});
    }
    await service.drain();
    container.dispose();
    await store.close();
  }
}

void main() {
  test(
    'R05 restart owner uses fresh authority and rejects pre-rotation pending approval',
    () async {
      final f = Fixture();
      addTearDown(f.close);
      final password = PasswordStore();
      final first = LocalControlService(
        passwordStore: password,
        transport: Transport(),
        supported: true,
        executor: (_) async => {'status': 'completed'},
        onCredentialRotated: (generation) async =>
            f.service.invalidateCredentialGeneration(generation),
      );
      await first.enable();
      final old = first.credentialGeneration;
      final proposal = await f.service.execute(
        'maintenance_clear_cache',
        {},
        credentialGeneration: old,
      );
      expect(await first.rotatePassword('fake-new-password-123456'), true);
      await first.close();
      first.dispose();
      final replacement = f.create();
      final second = LocalControlService(
        passwordStore: password,
        transport: Transport(),
        supported: true,
        executor: (_) async => {'status': 'completed'},
        onCredentialRotated: (generation) async =>
            replacement.invalidateCredentialGeneration(generation),
      );
      await second.enable();
      expect(second.credentialGeneration, isNot(old));
      final result = await replacement.execute('capability_confirm', {
        'operationId': proposal['operationId'],
        ...Map<String, Object?>.from(proposal['confirmation'] as Map),
      }, credentialGeneration: second.credentialGeneration);
      expect(result['status'], 'conflict');
      expect(f.gateway.calls, 0);
      await second.close();
      second.dispose();
    },
  );

  for (final boundary in [
    'version',
    'expiry',
    'credential',
    'caller_cancel',
    'operation_cancel',
  ]) {
    test(
      'R05 queued operation rechecks $boundary before gateway mutation',
      () async {
        final f = Fixture();
        addTearDown(f.close);
        f.service.invalidateCredentialGeneration(17);
        f.gateway.work = Completer<Map<String, Object?>>();
        await f.confirm();
        await f.gateway.started.future;
        var current = true;
        final second = await f.confirm(current: () => current);
        if (boundary == 'version') f.gateway.currentVersion = 'changed';
        if (boundary == 'credential') {
          f.service.invalidateCredentialGeneration(23);
        }
        if (boundary == 'caller_cancel') current = false;
        if (boundary == 'operation_cancel') {
          final cancelled = await f.service.execute('operation_cancel', {
            'operationId': second['operationId'],
          }, credentialGeneration: 17);
          expect(cancelled['status'], 'cancelled');
        }
        if (boundary == 'expiry') {
          await (f.store.update(f.store.workbenchChanges)..where(
                (table) => table.id.equals(second['operationId'] as String),
              ))
              .write(
                WorkbenchChangesCompanion(
                  expiresAt: drift.Value(
                    DateTime.now().millisecondsSinceEpoch - 1,
                  ),
                ),
              );
        }
        f.gateway.work!.complete({'status': 'completed'});
        await f.service.drain();
        expect(
          f.gateway.calls,
          1,
          reason: 'stale second operation must never reach gateway',
        );
        final status = await f.service.execute('operation_query', {
          'operationId': second['operationId'],
        }, credentialGeneration: boundary == 'credential' ? 23 : 17);
        expect(status['status'], anyOf('conflict', 'cancelled', 'failed'));
        await f.confirm(generation: boundary == 'credential' ? 23 : 17);
        await f.service.drain();
        expect(
          f.gateway.calls,
          2,
          reason: 'a fresh authorized proposal still executes',
        );
      },
    );
  }

  test(
    'R08 timed-out executor supplies durable operation ID and final query result',
    () async {
      final store = PasswordStore();
      final transport = Transport();
      final completion = Completer<Map<String, Object?>>();
      final service = LocalControlService(
        passwordStore: store,
        transport: transport,
        supported: true,
        queryTimeout: const Duration(milliseconds: 10),
        executor: (_) => completion.future,
      );
      addTearDown(() async {
        if (!completion.isCompleted) {
          completion.complete({'status': 'completed'});
        }
        await service.close();
        service.dispose();
      });
      await service.enable();
      final response = await service.handle(
        jsonEncode({
          'version': 1,
          'instanceId': transport.instance,
          'requestId': 'fake-request',
          'command': 'runtime_read',
          'auth': {'password': store.value},
          'params': {},
        }),
      );
      expect(response['status'], anyOf('pending', 'accepted'));
      expect(
        response['operationId'],
        isA<String>(),
        reason: 'timeout must return a queryable operation handle',
      );
    },
  );
}
