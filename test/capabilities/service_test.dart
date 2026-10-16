import 'dart:async';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:fl_clash/ai/tools.dart';
import 'package:fl_clash/capabilities/gateway.dart';
import 'package:fl_clash/capabilities/service.dart';
import 'package:fl_clash/configuration/resources.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/policy/models.dart';
import 'dart:convert';
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

class _CompletionGateway extends _Gateway
    implements ApplicationCompletionGateway {
  bool running = false;
  bool matches = true;
  bool capturedBeforeMutation = false;
  int reads = 0;

  @override
  Future<ConfigurationActivationBasis?> captureActivationBasis() async {
    capturedBeforeMutation = calls == 0;
    return ConfigurationActivationBasis(
      stateFingerprint: List.filled(64, 'a').join(),
      targetId: localPolicyTargetId,
      documentRevision: 7,
    );
  }

  @override
  Future<ConfigurationCompletionReceipt> readActivationBasis(
    ConfigurationActivationBasis basis,
  ) async {
    reads++;
    return ConfigurationCompletionReceipt(
      persisted: true,
      currentStateMatches: matches,
      scope: ConfigurationCompletionScope.localPolicy,
      activation: ConfigurationActivationReceipt(
        required: true,
        targetId: basis.targetId,
        documentRevision: basis.documentRevision,
        loadedTargetId: localPolicyTargetId,
        loadedDocumentRevision: 7,
        loaded: true,
        running: running,
        reason: running ? 'active' : 'network_stopped',
      ),
    );
  }

  @override
  Future<Map<String, Object?>> execute(
    String command,
    Map<String, Object?> params, {
    required String origin,
    Future<bool> Function()? beginMutation,
    bool Function()? isCurrent,
  }) async {
    final result = await super.execute(
      command,
      params,
      origin: origin,
      beginMutation: beginMutation,
      isCurrent: isCurrent,
    );
    running = params['running'] == true;
    return result;
  }
}

class _ReviewGateway extends _Gateway implements ApplicationReviewGateway {
  String selection = 'original-node';

  @override
  Future<Map<String, Object?>> reviewState(
    String command,
    Map<String, Object?> params,
  ) async => {
    'command': command,
    'before': {'node': selection},
    'after': params,
    'labels': {'node': 'Requested node'},
  };
}

class _CompletionBackend extends _ConfigurationBackend
    implements ConfigurationCompletionBackend {
  bool running = true;

  @override
  Future<ConfigurationCompletionReceipt> readCompletion(
    Map<String, Object?> before,
    Map<String, Object?> after, {
    required bool currentStateMatches,
  }) async => ConfigurationCompletionReceipt(
    persisted: true,
    currentStateMatches: currentStateMatches,
    scope: ConfigurationCompletionScope.localPolicy,
    activation: ConfigurationActivationReceipt(
      required: true,
      targetId: localPolicyTargetId,
      documentRevision: 7,
      loadedTargetId: localPolicyTargetId,
      loadedDocumentRevision: 7,
      loaded: true,
      running: running,
      reason: running ? 'active' : 'network_stopped',
    ),
  );
}

class _ConfigurationBackend implements ConfigurationBackend {
  Map<String, Object?> state = {'value': 1};
  bool script = false;
  bool highRisk = true;
  int writes = 0;
  @override
  Future<Map<String, Object?>> readState() async => Map.of(state);
  @override
  Future<Map<String, Object?>> validate(Map<String, Object?> candidate) async =>
      {
        'validated': true,
        'finalConfigValidated': true,
        if (script) 'requiresScriptExecutionApproval': true,
      };
  @override
  bool isHighRisk(Map<String, Object?> before, Map<String, Object?> after) =>
      highRisk;
  @override
  Future<void> persist(Map<String, Object?> candidate) async {
    writes++;
    state = Map.of(candidate);
  }

  @override
  Future<void> activate(Map<String, Object?> candidate) async {}
}

void main() {
  late WorkbenchDatabase store;
  late _Controller controller;
  late _Gateway gateway;
  late ProviderContainer container;
  late ApplicationCapabilityService service;
  late Ref serviceRef;
  setUpAll(() {
    registerFallbackValue(
      const ConfigurationProposal(
        id: 'fixture',
        summary: 'fixture',
        highRisk: true,
        expiresAt: 1,
        differences: [],
        validation: {},
      ),
    );
    registerFallbackValue(() => true);
  });
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

  ApplicationCapabilityService replacement(_Gateway replacementGateway) =>
      ApplicationCapabilityService(
        ref: serviceRef,
        controller: controller,
        gateway: replacementGateway,
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

  void useConfigurationService(ConfigurationChangeService changes) {
    when(() => controller.changes).thenReturn(changes);
    when(
      () => controller.commit(
        any(),
        approve: any(named: 'approve'),
        isCurrent: any(named: 'isCurrent'),
        requireApproval: any(named: 'requireApproval'),
      ),
    ).thenAnswer(
      (invocation) => changes.commit(
        id: (invocation.positionalArguments.first as ConfigurationProposal).id,
        approve: invocation.namedArguments[#approve] as ConfigurationApproval,
        isCurrent: invocation.namedArguments[#isCurrent] as bool Function()?,
        requireApproval: invocation.namedArguments[#requireApproval] as bool,
      ),
    );
  }

  test(
    'local capability review confirms once using the stored operation',
    () async {
      final live = _ReviewGateway();
      gateway = live;
      service = replacement(live);
      final pending = await service.execute('proxy_select', {
        'group': 'group',
        'node': 'next-node',
      }, origin: 'agent');
      final id = pending['operationId'] as String;
      expect(pending['status'], 'pending_confirmation');
      expect(gateway.calls, 0);
      final reviewed = await service.reviewChange(id);
      expect(reviewed.id, id);
      expect(reviewed.validation['reviewStatus'], 'pending_confirmation');
      expect((reviewed.validation['agentReview'] as Map)['before'], {
        'node': 'original-node',
      });
      var approvals = 0;
      final applied = await service.confirmReviewedChange(
        id,
        approve: (shown) async {
          approvals++;
          expect(shown.id, reviewed.id);
          expect(
            shown.differences.map((row) => row.toJson()).toList(),
            reviewed.differences.map((row) => row.toJson()).toList(),
          );
          return true;
        },
      );
      expect(applied['status'], 'completed');
      expect(applied['operationId'], id);
      expect(gateway.calls, 1);
      final replay = await service.confirmReviewedChange(
        id,
        approve: (_) async {
          approvals++;
          return true;
        },
      );
      expect(replay['status'], 'completed');
      expect(approvals, 1);
      expect((await service.cancelReviewedChange(id))['status'], 'completed');
      expect(gateway.calls, 1);
    },
  );

  test(
    'local cancellation of a capability card never executes its action',
    () async {
      final pending = await service.execute('connection_set', {
        'running': true,
      }, origin: 'agent');
      final id = pending['operationId'] as String;
      expect((await service.cancelReviewedChange(id))['status'], 'cancelled');
      expect(
        (await service.confirmReviewedChange(
          id,
          approve: (_) async => throw StateError('unexpected approval'),
        ))['status'],
        'cancelled',
      );
      expect(gateway.calls, 0);
    },
  );

  test(
    'AI review names survive selection-only diffs without exposing credentials',
    () async {
      final backend = _ConfigurationBackend()..highRisk = false;
      backend.state = {
        'ai': {
          'selectedConnectionId': 'primary',
          'connections': [
            {'id': 'primary', 'label': '旧连接', 'password': 'local-secret'},
            {
              'id': 'alternate',
              'label': '新连接',
              'password': 'other-local-secret',
            },
          ],
        },
      };
      final changes = ConfigurationChangeService(
        backend: backend,
        store: store,
      );
      useConfigurationService(changes);
      final candidate =
          jsonDecode(jsonEncode(backend.state)) as Map<String, Object?>;
      (candidate['ai'] as Map)['selectedConnectionId'] = 'alternate';
      final proposal = await changes.propose(
        category: 'ai',
        summary: 'Switch AI connection',
        candidate: candidate,
      );
      final reviewed = await service.reviewChange(proposal.id);
      expect(reviewed.differences.single.path, 'ai.selectedConnectionId');
      final labels = reviewed.validation['aiReviewConnections'];
      expect(labels, {
        'before': {'primary': '旧连接', 'alternate': '新连接'},
        'after': {'primary': '旧连接', 'alternate': '新连接'},
      });
      expect(jsonEncode(reviewed.toJson()), isNot(contains('local-secret')));
      var approvals = 0;
      final result = await service.confirmReviewedChange(
        proposal.id,
        approve: (actual) async {
          approvals++;
          expect(actual.validation['aiReviewConnections'], labels);
          return true;
        },
      );
      expect(result['status'], 'applied');
      expect(approvals, 1);
      expect(backend.writes, 1);
    },
  );

  for (final accepted in [false, true]) {
    test(
      'agent configuration card forces low risk approval accepted=$accepted',
      () async {
        final backend = _ConfigurationBackend()..highRisk = false;
        final changes = ConfigurationChangeService(
          backend: backend,
          store: store,
        );
        useConfigurationService(changes);
        final proposal = await changes.propose(
          category: 'settings',
          summary: 'low risk setting',
          candidate: {'value': 2},
        );
        final reviewed = await service.reviewChange(proposal.id);
        expect(reviewed.highRisk, isFalse);
        expect(reviewed.validation['reviewStatus'], 'draft');
        expect(backend.writes, 0);
        var approvals = 0;
        final result = await service.confirmReviewedChange(
          reviewed.id,
          approve: (_) async {
            approvals++;
            expect(backend.writes, 0);
            return accepted;
          },
        );
        expect(approvals, 1);
        expect(result['status'], accepted ? 'applied' : 'rejected');
        expect(backend.writes, accepted ? 1 : 0);
        expect(backend.state['value'], accepted ? 2 : 1);
        expect(gateway.calls, 0);
      },
    );
  }

  test(
    'local rejection of a configuration draft needs no action execution',
    () async {
      final backend = _ConfigurationBackend()..highRisk = false;
      final changes = ConfigurationChangeService(
        backend: backend,
        store: store,
      );
      useConfigurationService(changes);
      final proposal = await changes.propose(
        category: 'settings',
        summary: 'low risk setting',
        candidate: {'value': 2},
      );
      expect(
        (await service.cancelReviewedChange(proposal.id))['status'],
        'rejected',
      );
      expect(
        (await service.reviewChange(proposal.id)).validation['reviewStatus'],
        'rejected',
      );
      expect(backend.writes, 0);
      expect(backend.state['value'], 1);
      expect(gateway.calls, 0);
    },
  );

  test(
    'runtime changes during approval invalidate an unchanged configuration version',
    () async {
      final live = _ReviewGateway();
      gateway = live;
      service = replacement(live);
      final result = await service.execute(
        'proxy_select',
        {'group': 'group', 'node': 'next-node'},
        origin: 'agent',
        approve: (_) async {
          live.selection = 'changed-node';
          return true;
        },
      );
      expect(result['status'], 'conflict');
      expect(result['errorCode'], 'confirmation_stale');
      expect(live.currentVersion, 'version-one');
      expect(live.calls, 0);
    },
  );

  test(
    'queued reviewed actions recheck runtime state before execution',
    () async {
      final live = _ReviewGateway()..work = Completer<Map<String, Object?>>();
      gateway = live;
      service = replacement(live);
      final first = await service.execute(
        'maintenance_clear_cache',
        {},
        origin: 'agent',
        approve: (_) async => true,
      );
      expect(first['status'], 'accepted');
      await live.firstStarted.future;
      final second = await service.execute(
        'proxy_select',
        {'group': 'group', 'node': 'next-node'},
        origin: 'agent',
        approve: (_) async => true,
      );
      expect(second['status'], 'accepted');
      live.selection = 'changed-while-queued';
      live.work!.complete({'status': 'completed'});
      await service.drain();
      final queried = await service.execute('operation_query', {
        'operationId': second['operationId'],
      }, origin: 'agent');
      expect(queried['status'], 'conflict');
      expect(queried['errorCode'], 'configuration_version_conflict');
      expect(live.currentVersion, 'version-one');
      expect(live.calls, 1);
    },
  );

  test(
    'connection completion binds before execution and refreshes after stop and target change',
    () async {
      final live = _CompletionGateway();
      final connected = replacement(live);
      final operation = await connected.execute(
        'connection_set',
        {'running': true},
        origin: 'agent',
        approve: (_) async => true,
      );
      await connected.drain();
      final id = operation['operationId'] as String;
      expect(live.capturedBeforeMutation, isTrue);
      final stored = await store.readSection('capability.activation.$id');
      expect(stored!.keys.toSet(), {
        'version',
        'stateFingerprint',
        'targetId',
        'documentRevision',
      });
      Future<Map> completion() async {
        final query = await connected.execute('operation_query', {
          'operationId': id,
        });
        expect(query['operationId'], id);
        expect(query['status'], 'completed');
        expect(jsonEncode(query), isNot(contains('stateFingerprint')));
        return (query['result'] as Map)['completion'] as Map;
      }

      expect((await completion())['outcome'], 'effective');
      live.running = false;
      expect((await completion())['outcome'], 'saved');
      live.running = true;
      live.matches = false;
      expect((await completion())['currentStateMatches'], isFalse);
      expect(live.reads, 3);
    },
  );

  test(
    'profile selection query refreshes its bound configuration row instead of stored proof',
    () async {
      final backend = _CompletionBackend();
      final changes = ConfigurationChangeService(
        backend: backend,
        store: store,
      );
      when(() => controller.changes).thenReturn(changes);
      final draft = await changes.propose(
        category: 'target',
        summary: 'local target',
        candidate: {'value': 2},
      );
      final committed = await changes.commit(
        id: draft.id,
        approve: (_) async => true,
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      await store.saveChange(
        id: 'selection-operation',
        category: 'capability:profile_select',
        summary: 'select local',
        highRisk: true,
        fingerprint: 'fixture',
        before: {},
        after: {
          'command': 'profile_select',
          'params': {'integrationId': localPolicyProfileId},
        },
        createdAt: now,
        expiresAt: now + 60000,
      );
      await store.changeStatus('selection-operation', 'applied');
      await store.writeSection(
        'capability.result.selection-operation',
        committed,
      );
      Future<Map> completion() async {
        final query = await service.execute('operation_query', {
          'operationId': 'selection-operation',
        });
        expect(query['operationId'], 'selection-operation');
        return (query['result'] as Map)['completion'] as Map;
      }

      expect((await completion())['outcome'], 'effective');
      backend.running = false;
      expect((await completion())['outcome'], 'saved');
      backend.state['value'] = 3;
      expect((await completion())['currentStateMatches'], isFalse);
      await store.writeSection('capability.result.selection-operation', {
        ...committed,
        'id': 'missing-target-change',
      });
      final missing = await service.execute('operation_query', {
        'operationId': 'selection-operation',
      });
      expect((missing['result'] as Map)['currentStateMatches'], isFalse);
      expect((missing['result'] as Map).containsKey('completion'), isFalse);
    },
  );

  test(
    'restarted agent must locally approve a pending operation again',
    () async {
      final waiting = Completer<bool>();
      var originalApprovals = 0;
      final originalApproving = Completer<void>();
      final original = service.execute(
        'connection_set',
        {'running': false},
        origin: 'agent',
        approve: (_) {
          originalApprovals++;
          originalApproving.complete();
          return waiting.future;
        },
      );
      final rows = await store.watchChanges().firstWhere(
        (rows) => rows.any((row) => row.status == 'pending_confirmation'),
      );
      final id = rows.single.id;
      final restartedGateway = _Gateway();
      final restarted = replacement(restartedGateway);
      var resumedApprovals = 0;
      try {
        await originalApproving.future;
        expect(originalApprovals, 1);
        final preview = await restarted.execute('operation_query', {
          'operationId': id,
        }, origin: 'agent');
        final rejected = await restarted.execute(
          'capability_confirm',
          {
            'operationId': id,
            ...Map<String, Object?>.from(preview['confirmation'] as Map),
          },
          origin: 'agent',
          approve: (_) async {
            resumedApprovals++;
            return false;
          },
        );
        expect(rejected['status'], 'cancelled');
        await restarted.drain();
        expect(resumedApprovals, 1);
        expect(restartedGateway.calls, 0);
        expect((await store.readChange(id))!.status, 'cancelled');
      } finally {
        waiting.complete(false);
        await original;
        await restarted.drain();
      }
    },
  );

  test(
    'normal agent approval executes once and repeated confirmation is inert',
    () async {
      var approvals = 0;
      final accepted = await service.execute(
        'connection_set',
        {'running': true},
        origin: 'agent',
        approve: (_) async {
          approvals++;
          return true;
        },
      );
      expect(accepted['status'], 'accepted');
      await service.drain();
      final id = accepted['operationId'] as String;
      final before = policyObject(
        jsonDecode((await store.readChange(id))!.beforePayload),
        'before',
      );
      final replay = await service.execute(
        'capability_confirm',
        {
          'operationId': id,
          'digest': before['digest'],
          'version': before['version'],
        },
        origin: 'agent',
        approve: (_) async {
          approvals++;
          return true;
        },
      );
      expect(replay['status'], 'completed');
      expect(approvals, 1);
      expect(gateway.calls, 1);
    },
  );

  test(
    'concurrent confirmations can claim a pending operation only once',
    () async {
      final draft = await service.execute('connection_set', {
        'running': true,
      }, origin: 'agent');
      final otherGateway = _Gateway();
      final other = replacement(otherGateway);
      final bothApproving = Completer<void>();
      final release = Completer<bool>();
      var approvals = 0;
      Future<bool> approve(ConfigurationProposal proposal) {
        approvals++;
        if (approvals == 2) bothApproving.complete();
        return release.future;
      }

      final params = {
        'operationId': draft['operationId'],
        ...Map<String, Object?>.from(draft['confirmation'] as Map),
      };
      final confirmations = [
        service.execute(
          'capability_confirm',
          params,
          origin: 'agent',
          approve: approve,
        ),
        other.execute(
          'capability_confirm',
          params,
          origin: 'agent',
          approve: approve,
        ),
      ];
      await bothApproving.future;
      release.complete(true);
      await Future.wait(confirmations);
      await Future.wait([service.drain(), other.drain()]);
      expect(gateway.calls + otherGateway.calls, 1);
      expect(
        (await store.readChange(draft['operationId'] as String))!.status,
        'completed',
      );
    },
  );

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

  test(
    'agent manual commands remain inert until their review is approved',
    () async {
      for (final request in <(String, Map<String, Object?>)>[
        ('credentials_panel', {'kind': 'ai'}),
        ('profile_qr_import', {}),
      ]) {
        final pending = await service.execute(
          request.$1,
          request.$2,
          origin: 'agent',
        );
        expect(pending['status'], 'pending_confirmation');
        expect(gateway.calls, 0);
        expect(
          (await service.cancelReviewedChange(
            pending['operationId'] as String,
          ))['status'],
          'cancelled',
        );
        var approvals = 0;
        final declined = await service.execute(
          request.$1,
          request.$2,
          origin: 'agent',
          approve: (_) async {
            approvals++;
            return false;
          },
        );
        expect(declined['status'], 'cancelled');
        expect(approvals, 1);
        expect(gateway.calls, 0);
      }
    },
  );

  test(
    'agent cancellation requests review before changing another operation',
    () async {
      final target = await service.execute('connection_set', {
        'running': true,
      }, origin: 'agent');
      final id = target['operationId'] as String;
      final requested = await service.execute('operation_cancel', {
        'operationId': id,
      }, origin: 'agent');
      final cancellationId = requested['operationId'] as String;
      expect(requested['status'], 'pending_confirmation');
      expect(cancellationId, isNot(id));
      expect((await store.readChange(id))!.status, 'pending_confirmation');
      expect(gateway.calls, 0);
      expect(
        (await service.cancelReviewedChange(cancellationId))['status'],
        'cancelled',
      );
      expect((await store.readChange(id))!.status, 'pending_confirmation');
      final approved = await service.execute(
        'operation_cancel',
        {'operationId': id},
        origin: 'agent',
        approve: (_) async => true,
      );
      expect(approved['status'], 'accepted');
      await service.drain();
      expect((await store.readChange(id))!.status, 'cancelled');
      expect(gateway.calls, 0);
    },
  );

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
  for (final script in [false, true]) {
    test(
      'CLI bound confirmation handles native preflight with script=$script',
      () async {
        final backend = _ConfigurationBackend()..script = script;
        final changes = ConfigurationChangeService(
          store: store,
          backend: backend,
        );
        when(() => controller.changes).thenReturn(changes);
        when(
          () => controller.commit(
            any(),
            approve: any(named: 'approve'),
            isCurrent: any(named: 'isCurrent'),
            requireApproval: any(named: 'requireApproval'),
          ),
        ).thenAnswer(
          (invocation) => changes.commit(
            id: (invocation.positionalArguments.first as ConfigurationProposal)
                .id,
            approve:
                invocation.namedArguments[#approve] as ConfigurationApproval,
            isCurrent:
                invocation.namedArguments[#isCurrent] as bool Function()?,
            requireApproval:
                invocation.namedArguments[#requireApproval] as bool,
          ),
        );
        final proposal = await changes.propose(
          category: 'settings',
          summary: 'fixture',
          candidate: {'value': 2},
        );
        await store.writeSection('capability.authority.${proposal.id}', {
          'origin': 'cli',
          'credentialGeneration': 10,
        });
        final row = (await store.readChange(proposal.id))!;
        final response = await service.execute('changes_commit', {
          'id': proposal.id,
          'confirmation': {
            'digest': policyDigest({
              'id': row.id,
              'fingerprint': row.fingerprint,
              'afterDigest': policyDigest(jsonDecode(row.afterPayload)),
              'expiresAt': row.expiresAt,
            }),
            'version': row.fingerprint,
          },
        }, credentialGeneration: 10);
        expect(response['status'], 'accepted');
        await service.drain();
        expect(backend.writes, script ? 0 : 1);
        expect(
          (await store.readChange(proposal.id))!.status,
          script ? 'draft' : 'applied',
        );
      },
    );
  }
}
