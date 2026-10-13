import 'dart:async';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:fl_clash/ai/tools.dart';
import 'package:fl_clash/capabilities/gateway.dart';
import 'package:fl_clash/capabilities/service.dart';
import 'package:fl_clash/configuration/resources.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Environment extends Mock implements ResourceEnvironment {}

class _AgentGateway extends Mock implements AgentResourceGateway {}

class _Controller extends Mock implements WorkbenchController {
  _Controller(this.store);
  @override
  final WorkbenchDatabase store;
}

class _Gateway implements ApplicationCapabilityGateway {
  @override
  bool supported = true;
  String currentVersion = 'version-one';
  int calls = 0;
  final firstStarted = Completer<void>();
  final secondStarted = Completer<void>();
  Completer<Map<String, Object?>>? work;
  Future<bool> Function()? begin;
  bool Function()? current;
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
    if (calls == 1) firstStarted.complete();
    if (calls == 2) secondStarted.complete();
    begin = beginMutation;
    current = isCurrent;
    return work?.future ??
        {'status': 'completed', 'running': params['running']};
  }
}

void main() {
  late WorkbenchDatabase store;
  late _Controller controller;
  late _Gateway gateway;
  late ProviderContainer container;
  late ApplicationCapabilityService service;
  late Ref serviceRef;
  setUp(() {
    store = WorkbenchDatabase(NativeDatabase.memory());
    controller = _Controller(store);
    gateway = _Gateway();
    final provider = Provider((ref) {
      serviceRef = ref;
      return ApplicationCapabilityService(
        ref: ref,
        controller: controller,
        gateway: gateway,
        tools: AgentTools(
          controller: controller,
          approve: (_) async => false,
          exposeApplication: false,
          resources: ResourceChangeService(
            store: store,
            environment: _Environment(),
          ),
          gateway: _AgentGateway(),
        ),
      );
    });
    container = ProviderContainer();
    service = container.read(provider);
  });
  tearDown(() async {
    if (gateway.work != null && !gateway.work!.isCompleted) {
      gateway.work!.complete({'status': 'cancelled'});
    }
    await service.drain();
    container.dispose();
    await store.close();
  });

  test(
    'manifest alias works and malformed inputs never reach actions',
    () async {
      final manifest = await service.execute('capabilities_list', {});
      expect(manifest['status'], 'completed');
      expect((manifest['result'] as Map)['capabilities'], isNotEmpty);
      expect(
        (await service.execute('connection_set', {
          'running': 'true',
        }))['errorCode'],
        'invalid_arguments',
      );
      expect(
        (await service.execute('connection_set', {
          'running': true,
          'shell': 'unsafe',
        }))['errorCode'],
        'invalid_arguments',
      );
      expect(gateway.calls, 0);
    },
  );

  test(
    'local policy detail reads require one target and bounded pagination',
    () async {
      for (final params in <Map<String, Object?>>[
        {'revision': 1},
        {'revision': 1, 'policyId': 'fixture', 'nodeSetId': 'fixture'},
        {'revision': 1, 'policyId': 'fixture', 'limit': 201},
        {'revision': 1, 'nodeSetId': 'fixture', 'offset': 5001},
      ]) {
        expect(
          (await service.execute('local_policy_details', params))['errorCode'],
          'invalid_arguments',
        );
      }
      expect(gateway.calls, 0);
      expect(
        (await service.execute('local_policy_details', {
          'revision': 1,
          'nodeSetId': 'fixture',
          'offset': 0,
          'limit': 200,
        }))['status'],
        'completed',
      );
      expect(gateway.calls, 1);
    },
  );

  test('confirmation binds parameters and version before any action', () async {
    final proposal = await service.execute('connection_set', {'running': true});
    expect(proposal['status'], 'pending_confirmation');
    expect(gateway.calls, 0);
    final id = proposal['operationId'] as String;
    final confirmation = Map<String, Object?>.from(
      proposal['confirmation'] as Map,
    );
    final mismatch = await service.execute('capability_confirm', {
      'operationId': id,
      ...confirmation,
      'digest': 'wrong',
    });
    expect(mismatch['status'], 'conflict');
    gateway.currentVersion = 'version-two';
    final stale = await service.execute('capability_confirm', {
      'operationId': id,
      ...confirmation,
    });
    expect(stale['status'], 'conflict');
    expect(gateway.calls, 0);
  });

  test(
    'accepted action remains in drain until persistence actually finishes',
    () async {
      gateway.work = Completer();
      final proposal = await service.execute('connection_set', {
        'running': true,
      }, idempotencyKey: 'stable-key');
      final id = proposal['operationId'] as String;
      final confirmation = Map<String, Object?>.from(
        proposal['confirmation'] as Map,
      );
      final accepted = await service.execute('capability_confirm', {
        'operationId': id,
        ...confirmation,
      });
      expect(accepted['status'], 'accepted');
      expect(
        (await service.execute('operation_query', {
          'operationId': id,
        }))['status'],
        anyOf('running', 'queued'),
      );
      await gateway.firstStarted.future;
      var drained = false;
      final drain = service.drain().then((_) => drained = true);
      await Future<void>.delayed(Duration.zero);
      expect(drained, false);
      expect(
        (await service.execute('operation_cancel', {
          'operationId': id,
        }))['errorCode'],
        'transaction_in_progress',
      );
      gateway.work!.complete({'status': 'completed', 'running': true});
      await drain;
      final result = await service.execute('operation_query', {
        'operationId': id,
      });
      expect(result['status'], 'completed');
      expect((result['result'] as Map)['running'], true);
      expect(
        (await service.execute('connection_set', {
          'running': true,
        }, idempotencyKey: 'stable-key'))['status'],
        'completed',
      );
      expect(
        (await service.execute('connection_set', {
          'running': false,
        }, idempotencyKey: 'stable-key'))['status'],
        'conflict',
      );
      expect(gateway.calls, 1);
    },
  );

  test(
    'rotated credentials invalidate pending confirmations and caller',
    () async {
      service.invalidateCredentialGeneration(1);
      final proposal = await service.execute('connection_set', {
        'running': true,
      }, credentialGeneration: 1);
      service.invalidateCredentialGeneration(2);
      final old = await service.execute('capability_confirm', {
        'operationId': proposal['operationId'],
        ...Map<String, Object?>.from(proposal['confirmation'] as Map),
      }, credentialGeneration: 1);
      expect(old['status'], 'cancelled');
      final current = await service.execute('capability_confirm', {
        'operationId': proposal['operationId'],
        ...Map<String, Object?>.from(proposal['confirmation'] as Map),
      }, credentialGeneration: 2);
      expect(current['status'], 'conflict');
      expect(gateway.calls, 0);
    },
  );

  test(
    'a new owner rejects old pending approvals but retains completed queries',
    () async {
      service.invalidateCredentialGeneration(17);
      final pending = await service.execute('connection_set', {
        'running': true,
      }, credentialGeneration: 17);
      final done = await service.execute('connection_set', {
        'running': false,
      }, credentialGeneration: 17);
      await service.execute('capability_confirm', {
        'operationId': done['operationId'],
        ...Map<String, Object?>.from(done['confirmation'] as Map),
      }, credentialGeneration: 17);
      await service.drain();
      final replacement = ApplicationCapabilityService(
        ref: serviceRef,
        controller: controller,
        gateway: gateway,
        tools: AgentTools(
          controller: controller,
          approve: (_) async => false,
          exposeApplication: false,
          resources: ResourceChangeService(
            store: store,
            environment: _Environment(),
          ),
          gateway: _AgentGateway(),
        ),
      );
      replacement.invalidateCredentialGeneration(23);
      final stale = await replacement.execute('capability_confirm', {
        'operationId': pending['operationId'],
        ...Map<String, Object?>.from(pending['confirmation'] as Map),
      }, credentialGeneration: 23);
      expect(stale['errorCode'], 'confirmation_stale');
      expect(
        (await replacement.execute('operation_query', {
          'operationId': done['operationId'],
        }, credentialGeneration: 23))['status'],
        'completed',
      );
      expect(gateway.calls, 1);
    },
  );

  test(
    'legacy resource proposals retain their credential authority and safe preview',
    () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await store.saveChange(
        id: 'resource-fixture',
        category: 'profile:refresh',
        summary: 'fixture',
        highRisk: true,
        fingerprint: 'version',
        before: {'protectedContent': 'private-before', 'label': 'before'},
        after: {'protectedContent': 'private-after', 'label': 'after'},
        createdAt: now,
        expiresAt: now + 600000,
      );
      await store.writeSection('capability.authority.resource-fixture', {
        'origin': 'cli',
        'credentialGeneration': 17,
      });
      service.invalidateCredentialGeneration(23);
      final preview = await service.execute('operation_query', {
        'operationId': 'resource-fixture',
      }, credentialGeneration: 23);
      expect(preview.toString(), isNot(contains('private-before')));
      expect(preview.toString(), contains('after'));
      final stale = await service.execute('changes_commit', {
        'id': 'resource-fixture',
        'confirmation': preview['confirmation'],
      }, credentialGeneration: 23);
      expect(stale['errorCode'], 'confirmation_stale');
      expect(gateway.calls, 0);
    },
  );

  test(
    'manual requests stay pending, cancellation prevents any later mutation',
    () async {
      gateway.work = Completer();
      final request = await service.execute('credentials_panel', {
        'kind': 'cli',
      });
      final id = request['operationId'] as String;
      expect(request['status'], 'requires_user_action');
      await service.drain();
      expect(
        (await service.execute('operation_cancel', {
          'operationId': id,
        }))['status'],
        'cancelled',
      );
      expect(await gateway.begin!(), false);
      gateway.work!.complete({'status': 'cancelled'});
      await Future<void>.delayed(Duration.zero);
      expect(
        (await service.execute('operation_query', {
          'operationId': id,
        }))['status'],
        'cancelled',
      );
    },
  );

  test('started manual writes are included in rotation drain', () async {
    gateway.work = Completer();
    final request = await service.execute('credentials_panel', {'kind': 'cli'});
    expect(await gateway.begin!(), true);
    var drained = false;
    final drain = service.drain().then((_) => drained = true);
    await Future<void>.delayed(Duration.zero);
    expect(drained, false);
    gateway.work!.complete({'status': 'completed'});
    await drain;
    expect(
      (await service.execute('operation_query', {
        'operationId': request['operationId'],
      }))['status'],
      'completed',
    );
  });

  test(
    'proxy-test cancellation cancels its own waiter without aborting writes',
    () async {
      gateway.work = Completer();
      final proposal = await service.execute('proxy_test', {'node': 'fixture'});
      final id = proposal['operationId'] as String;
      await service.execute('capability_confirm', {
        'operationId': id,
        ...Map<String, Object?>.from(proposal['confirmation'] as Map),
      });
      await gateway.firstStarted.future;
      expect(gateway.current!(), true);
      final cancelled = await service.execute('operation_cancel', {
        'operationId': id,
      });
      expect(cancelled['cancellationRequested'], true);
      expect(gateway.current!(), false);
      gateway.work!.complete({'status': 'cancelled', 'results': <Object?>[]});
      await service.drain();
      expect(
        (await service.execute('operation_query', {
          'operationId': id,
        }))['status'],
        'cancelled',
      );
    },
  );

  test(
    'later lifecycle intent reaches the existing owner without waiting for prior work',
    () async {
      gateway.work = Completer();
      for (final running in [true, false]) {
        final proposal = await service.execute('connection_set', {
          'running': running,
        });
        await service.execute('capability_confirm', {
          'operationId': proposal['operationId'],
          ...Map<String, Object?>.from(proposal['confirmation'] as Map),
        });
      }
      await gateway.secondStarted.future.timeout(const Duration(seconds: 5));
      expect(gateway.calls, 2);
      gateway.work!.complete({'status': 'completed'});
      await service.drain();
    },
  );

  test('queued work rechecks configuration before its action starts', () async {
    gateway.work = Completer();
    final operations = <String>[];
    for (var index = 0; index < 2; index++) {
      final proposal = await service.execute('maintenance_clear_cache', {});
      operations.add(proposal['operationId'] as String);
      await service.execute('capability_confirm', {
        'operationId': proposal['operationId'],
        ...Map<String, Object?>.from(proposal['confirmation'] as Map),
      });
    }
    await gateway.firstStarted.future;
    gateway.currentVersion = 'changed-before-second-action';
    gateway.work!.complete({'status': 'completed'});
    await service.drain();
    final result = await service.execute('operation_query', {
      'operationId': operations.last,
    });
    expect(result['errorCode'], 'configuration_version_conflict');
    expect(gateway.calls, 1);
  });

  test('pending approval can be cancelled and cannot later execute', () async {
    final proposal = await service.execute('connection_set', {'running': true});
    final id = proposal['operationId'] as String;
    expect(
      (await service.execute('operation_cancel', {
        'operationId': id,
      }))['status'],
      'cancelled',
    );
    expect(
      (await service.execute('capability_confirm', {
        'operationId': id,
        ...Map<String, Object?>.from(proposal['confirmation'] as Map),
      }))['status'],
      'cancelled',
    );
    expect(gateway.calls, 0);
  });
  for (final invalidation in [
    'request_cancelled',
    'operation_cancelled',
    'expired',
    'generation_changed',
  ]) {
    test(
      'queued authority rechecks $invalidation before starting a side effect',
      () async {
        gateway.work = Completer();
        service.invalidateCredentialGeneration(10);
        var current = true;
        final ids = <String>[];
        for (var index = 0; index < 2; index++) {
          final proposal = await service.execute(
            'maintenance_clear_cache',
            {},
            credentialGeneration: 10,
          );
          ids.add(proposal['operationId'] as String);
          await service.execute(
            'capability_confirm',
            {
              'operationId': proposal['operationId'],
              ...Map<String, Object?>.from(proposal['confirmation'] as Map),
            },
            credentialGeneration: 10,
            isCurrent: index == 1 ? () => current : null,
          );
        }
        await gateway.firstStarted.future;
        switch (invalidation) {
          case 'request_cancelled':
            current = false;
          case 'operation_cancelled':
            expect(
              (await service.execute('operation_cancel', {
                'operationId': ids.last,
              }, credentialGeneration: 10))['status'],
              'cancelled',
            );
          case 'expired':
            await (store.update(store.workbenchChanges)
                  ..where((t) => t.id.equals(ids.last)))
                .write(const WorkbenchChangesCompanion(expiresAt: Value(1)));
          case 'generation_changed':
            service.invalidateCredentialGeneration(11);
        }
        gateway.work!.complete({'status': 'completed'});
        await service.drain();
        final result = await service.execute(
          'operation_query',
          {'operationId': ids.last},
          credentialGeneration: invalidation == 'generation_changed' ? 11 : 10,
        );
        expect(
          result['status'],
          invalidation == 'request_cancelled' ||
                  invalidation == 'operation_cancelled'
              ? 'cancelled'
              : 'conflict',
        );
        expect(gateway.calls, 1);
        expect(
          (await service.execute(
            'operation_query',
            {'operationId': ids.first},
            credentialGeneration: invalidation == 'generation_changed'
                ? 11
                : 10,
          ))['status'],
          'completed',
        );
      },
    );
  }
}
