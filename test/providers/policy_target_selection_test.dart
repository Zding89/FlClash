import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/profile.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/policy/profile_service.dart';
import 'package:fl_clash/policy/sources.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _collection = SubscriptionIntegration(
  id: localPolicyProfileId,
  label: 'Collection',
  sourceProfileIds: [1],
);
Map<String, Object?> _standaloneFixture(LocalPolicyDocument value) => {
  ...value.toJson(),
  'schemaVersion': 4,
  'activeIntegrationId': localPolicyProfileId,
};
Map<String, Object?> _copy(Map<String, Object?> value) =>
    Map<String, Object?>.from(jsonDecode(jsonEncode(value)) as Map);

class _Backend extends FlutterConfigurationBackend {
  _Backend({required super.ref, required super.store})
    : super(
        profiles: PolicyProfileService(
          loader: PolicySourceLoader(
            store: store,
            fetchFile: (_) async => throw StateError('unexpected network'),
          ),
        ),
      );
  Map<String, Object?> state = {};
  int writes = 0;
  bool script = false;
  bool scriptPrepared = false;
  final activations = <Map<String, Object?>>[];
  Completer<void>? readGate;
  final readStarted = Completer<void>();
  bool _blocked = false;
  @override
  Future<Map<String, Object?>> readState() async {
    if (readGate != null && !_blocked) {
      _blocked = true;
      readStarted.complete();
      await readGate!.future;
    }
    return _copy(state);
  }

  @override
  Future<Map<String, Object?>> validate(Map<String, Object?> candidate) async {
    LocalPolicyDocument.fromJson(
      policyObject(candidate['policies'], 'policies'),
    );
    return {
      'checked': true,
      if (script && !scriptPrepared) 'requiresScriptExecutionApproval': true,
      if (scriptPrepared) 'finalConfigDifferences': <Object?>[],
    };
  }

  @override
  Future<Map<String, Object?>> validateApproved(
    Map<String, Object?> candidate,
  ) async {
    scriptPrepared = true;
    return {
      'finalConfigValidated': true,
      'finalConfigDigest': 'fixture',
      'finalConfigDifferences': <Object?>[],
    };
  }

  @override
  bool isHighRisk(Map<String, Object?> before, Map<String, Object?> after) =>
      true;
  @override
  Future<void> persist(Map<String, Object?> candidate) async {
    writes++;
    state = _copy(candidate);
  }

  @override
  Future<void> activate(Map<String, Object?> candidate) async =>
      activations.add(_copy(candidate));
  @override
  Future<void> beginCommit(
    String id,
    Map<String, Object?> before,
    Map<String, Object?> after,
    Map<String, Object?> validation,
  ) async {}
  @override
  Future<void> activateCommit(
    String id,
    Map<String, Object?> after,
    Map<String, Object?> validation,
  ) => activate(after);
  @override
  Future<void> restoreCommit(
    String id,
    Map<String, Object?> before,
    Map<String, Object?> after,
  ) async => state = _copy(before);
  @override
  Future<void> endCommit(String id) async {}
}

class _Controller extends WorkbenchController {
  _Controller(
    super.ref, {
    required super.store,
    required this.testBackend,
    required this.testChanges,
  });
  final _Backend testBackend;
  final ConfigurationChangeService testChanges;
  @override
  FlutterConfigurationBackend get backend => testBackend;
  @override
  ConfigurationChangeService get changes => testChanges;
}

void main() {
  late WorkbenchDatabase store;
  late ProviderContainer container;
  late _Backend backend;
  late WorkbenchController controller;
  setUpAll(() async {
    await AppLocalizations.load(const Locale('en'));
  });
  setUp(() {
    store = WorkbenchDatabase(NativeDatabase.memory());
    final provider = Provider<WorkbenchController>((ref) {
      backend = _Backend(ref: ref, store: store);
      backend.state = {
        'config': {'currentProfileId': 1},
        'policies': _standaloneFixture(
          const LocalPolicyDocument(
            moduleEnabled: true,
            integrations: [_collection],
          ),
        ),
      };
      return _Controller(
        ref,
        store: store,
        testBackend: backend,
        testChanges: ConfigurationChangeService(backend: backend, store: store),
      );
    });
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWithBuild(
          (_, _) => const [
            Profile(id: 1, autoUpdateDuration: Duration(days: 1)),
            Profile(id: 2, autoUpdateDuration: Duration(days: 1)),
          ],
        ),
      ],
    );
    controller = container.read(provider);
  });
  tearDown(() async {
    if (backend.readGate != null && !backend.readGate!.isCompleted) {
      backend.readGate!.complete();
    }
    container.dispose();
    await store.close();
  });
  LocalPolicyDocument document() => LocalPolicyDocument.fromJson(
    policyObject(backend.state['policies'], 'policies'),
  );
  Future<bool> approve(ConfigurationProposal _) async => true;
  void setDocument(LocalPolicyDocument value, {int? profileId = 1}) =>
      backend.state = {
        'config': {'currentProfileId': profileId},
        'policies': _standaloneFixture(value),
      };

  test(
    'selecting local configuration opens its module and acknowledges migration without enabling old rules',
    () async {
      backend.state['policies'] = {
        ..._standaloneFixture(
          const LocalPolicyDocument(
            moduleEnabled: false,
            policiesEnabled: false,
            integrations: [_collection],
            policies: [
              LocalPolicy(
                id: 'migrated',
                label: 'Migrated',
                targetId: localPolicyTargetId,
                enabled: false,
                action: PolicyAction.direct,
              ),
            ],
          ),
        ),
        'migrationReviewRequired': true,
      };
      var approvals = 0;
      final result = await controller.selectPolicyTarget(
        integrationId: localPolicyProfileId,
        approve: (_) async {
          approvals++;
          return true;
        },
      );
      expect(result['status'], 'applied');
      expect(approvals, 1);
      expect(document().moduleEnabled, true);
      expect(document().integrationEnabled, true);
      expect(document().migrationReviewRequired, false);
      expect(document().policiesEnabled, false);
      expect(document().policies.single.enabled, false);
      expect((backend.state['config'] as Map)['currentProfileId'], 1);
    },
  );

  test(
    'legacy integration cannot be activated through the target API',
    () async {
      backend.state['policies'] = {
        ..._standaloneFixture(
          const LocalPolicyDocument(
            integrations: [
              _collection,
              SubscriptionIntegration(
                id: 'archived',
                label: 'Archived',
                sourceProfileIds: [2],
              ),
            ],
          ),
        ),
      };
      await expectLater(
        controller.selectPolicyTarget(
          integrationId: 'archived',
          approve: approve,
        ),
        throwsA(isA<ConfigurationChangeException>()),
      );
      expect(backend.writes, 0);
      expect(backend.activations, isEmpty);
    },
  );

  test(
    'legacy proposals are normalized to paused local rules before persistence',
    () async {
      final proposal = await controller.proposePolicies(
        const LocalPolicyDocument(
          moduleEnabled: true,
          policiesEnabled: true,
          policies: [
            LocalPolicy(
              id: 'old',
              label: 'Old',
              targetId: 'profile:1',
              action: PolicyAction.direct,
            ),
          ],
        ),
      );
      final stored = (await store.readChange(proposal.id))!;
      final after = jsonDecode(stored.afterPayload) as Map;
      final policies = LocalPolicyDocument.fromJson(
        policyObject(after['policies'], 'policies'),
      );
      expect(policies.schemaVersion, 4);
      expect(policies.integrationEnabled, false);
      expect(policies.migrationReviewRequired, true);
      expect(policies.policies.single.targetId, localPolicyTargetId);
      expect(policies.policies.single.enabled, false);
    },
  );

  test(
    'latest queued target intent supersedes older selections before any write',
    () async {
      backend.readGate = Completer<void>();
      final first = controller.selectPolicyTarget(
        profileId: 2,
        approve: approve,
      );
      await backend.readStarted.future;
      final second = controller.selectPolicyTarget(
        integrationId: localPolicyProfileId,
        approve: approve,
      );
      final latest = controller.selectPolicyTarget(
        profileId: 1,
        approve: approve,
      );
      backend.readGate!.complete();
      expect((await first)['status'], 'superseded');
      expect((await second)['status'], 'superseded');
      expect((await latest)['status'], 'applied');
      expect(backend.writes, 1);
      expect(backend.activations, hasLength(1));
      expect((backend.state['config'] as Map)['currentProfileId'], 1);
      expect(document().integrationEnabled, false);
    },
  );

  test(
    'opening the module retains data and does not select a collection',
    () async {
      setDocument(
        const LocalPolicyDocument(
          moduleEnabled: false,
          integrations: [_collection],
          activeIntegrationId: localPolicyProfileId,
        ),
      );
      var approvals = 0;
      final result = await controller.selectPolicyTarget(
        moduleEnabled: true,
        approve: (_) async {
          approvals++;
          return true;
        },
      );
      expect(result['status'], 'applied');
      expect(document().moduleEnabled, true);
      expect(document().integrationEnabled, false);
      expect(document().activeIntegrationId, localPolicyProfileId);
      expect(document().integrations.single.sourceProfileIds, [1]);
      expect((backend.state['config'] as Map)['currentProfileId'], 1);
      expect(approvals, 0);
    },
  );

  test(
    'closing an active collection returns safely to the existing ordinary profile',
    () async {
      setDocument(
        const LocalPolicyDocument(
          moduleEnabled: true,
          integrationEnabled: true,
          integrations: [_collection],
          activeIntegrationId: localPolicyProfileId,
        ),
        profileId: 2,
      );
      final result = await controller.selectPolicyTarget(
        moduleEnabled: false,
        approve: approve,
      );
      expect(result['status'], 'applied');
      expect(document().moduleEnabled, false);
      expect(document().integrationEnabled, false);
      expect(document().activeIntegrationId, localPolicyProfileId);
      expect(document().integrations, hasLength(1));
      expect(
        (backend.activations.single['config'] as Map)['currentProfileId'],
        2,
      );
    },
  );

  test(
    'closing an active collection fails before writing without a return profile',
    () async {
      for (final missing in <int?>[null, 999]) {
        setDocument(
          const LocalPolicyDocument(
            moduleEnabled: true,
            integrationEnabled: true,
            integrations: [_collection],
            activeIntegrationId: localPolicyProfileId,
          ),
          profileId: missing,
        );
        final original = policyDigest(backend.state);
        await expectLater(
          controller.selectPolicyTarget(moduleEnabled: false, approve: approve),
          throwsA(
            isA<ConfigurationChangeException>().having(
              (error) => error.code,
              'code',
              'configuration_return_profile_required',
            ),
          ),
        );
        expect(policyDigest(backend.state), original);
      }
      expect(backend.writes, 0);
      expect(await store.select(store.workbenchChanges).get(), isEmpty);
    },
  );

  test(
    'ordinary profile selection clears integration use while retaining its definition',
    () async {
      setDocument(
        const LocalPolicyDocument(
          moduleEnabled: true,
          integrationEnabled: true,
          integrations: [_collection],
          activeIntegrationId: localPolicyProfileId,
        ),
      );
      expect(
        (await controller.selectPolicyTarget(
          profileId: 2,
          approve: approve,
        ))['status'],
        'applied',
      );
      expect(document().integrationEnabled, false);
      expect(document().moduleEnabled, true);
      expect(document().activeIntegrationId, localPolicyProfileId);
      expect(document().integrations, hasLength(1));
      expect((backend.state['config'] as Map)['currentProfileId'], 2);
    },
  );

  test('missing ordinary profile fails without writes or a proposal', () async {
    final original = policyDigest(backend.state);
    await expectLater(
      controller.selectPolicyTarget(profileId: 999, approve: approve),
      throwsA(
        isA<ConfigurationChangeException>().having(
          (error) => error.code,
          'code',
          'configuration_profile_missing',
        ),
      ),
    );
    expect(policyDigest(backend.state), original);
    expect(backend.writes, 0);
    expect(await store.select(store.workbenchChanges).get(), isEmpty);
  });

  test(
    'rejected collection activation leaves current target and configuration untouched',
    () async {
      final original = policyDigest(backend.state);
      var approvals = 0;
      final result = await controller.selectPolicyTarget(
        integrationId: localPolicyProfileId,
        approve: (_) async {
          approvals++;
          return false;
        },
      );
      expect(result['status'], 'rejected');
      expect(approvals, 1);
      expect(backend.writes, 0);
      expect(backend.activations, isEmpty);
      expect(policyDigest(backend.state), original);
      expect(
        (await store.readChange(result['id'] as String))!.status,
        'rejected',
      );
    },
  );

  test(
    'later selection invalidates an older approval before persistence',
    () async {
      final gate = Completer<bool>();
      final entered = Completer<void>();
      final first = controller.selectPolicyTarget(
        integrationId: localPolicyProfileId,
        approve: (_) {
          entered.complete();
          return gate.future;
        },
      );
      final rejected = expectLater(
        first,
        throwsA(
          isA<ConfigurationChangeException>().having(
            (error) => error.code,
            'code',
            'configuration_cancelled',
          ),
        ),
      );
      await entered.future;
      final latest = controller.selectPolicyTarget(
        profileId: 2,
        approve: approve,
      );
      gate.complete(true);
      await rejected;
      expect((await latest)['status'], 'applied');
      expect(backend.writes, 1);
      expect(document().integrationEnabled, false);
      expect((backend.state['config'] as Map)['currentProfileId'], 2);
    },
  );
  test(
    'script target selection requires approval of generated configuration after execution approval',
    () async {
      backend.script = true;
      var approvals = 0;
      final result = await controller.selectPolicyTarget(
        profileId: 2,
        approve: (proposal) async {
          approvals++;
          return proposal.validation['executionOnly'] == true;
        },
      );
      expect(backend.scriptPrepared, true);
      expect(approvals, 2);
      expect(result['status'], 'rejected');
      expect(backend.writes, 0);
      expect((backend.state['config'] as Map)['currentProfileId'], 1);
    },
  );
}
