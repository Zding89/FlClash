import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:fl_clash/ai/runtime.dart';
import 'package:fl_clash/ai/tools.dart';
import 'package:fl_clash/ai/policy_contract.dart';
import 'package:fl_clash/common/javascript.dart';
import 'package:fl_clash/common/snowflake.dart';
import 'package:fl_clash/configuration/resources.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/policy/compiler.dart';
import 'package:fl_clash/policy/profile_service.dart';
import 'package:fl_clash/policy/simulation.dart';
import 'package:fl_clash/policy/sources.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

const _profile = Profile(
  id: 7,
  label: 'fixture',
  url: 'https://example.invalid/subscription?token=never-expose',
  autoUpdateDuration: Duration(hours: 1),
);

class _Controller extends Mock implements WorkbenchController {
  _Controller(this.store) {
    profiles = PolicyProfileService(
      loader: PolicySourceLoader(
        store: store,
        profilePath: (id) async => '$id.yaml',
        readFile: (_) async => 'proxies: [{name: fixture, type: direct}]',
      ),
    );
  }
  @override
  final WorkbenchDatabase store;
  @override
  late final PolicyProfileService profiles;
  int simulations = 0;
  List<Map<String, Object?>>? simulationSteps;
  Map<String, Object?>? settingsPatch;
  LocalPolicyDocument? proposedDocument;
  ConfigurationChangeService? policyChanges;
  Object? readError;
  LocalPolicyDocument currentDocument = const LocalPolicyDocument()
      .asStandalone();
  ConfigurationProposal get proposal => const ConfigurationProposal(
    id: 'fixture-proposal',
    summary: 'fixture',
    highRisk: true,
    expiresAt: 2000000000000,
    differences: [],
    validation: {},
  );
  @override
  Future<ConfigurationProposal> proposeSettingsPatch(
    Map<String, Object?> patch,
  ) async {
    settingsPatch = patch;
    return proposal;
  }

  @override
  Future<ConfigurationProposal> proposePolicies(
    LocalPolicyDocument document, {
    String? draftId,
    String? expectedPolicyDigest,
  }) async {
    proposedDocument = document;
    final changes = policyChanges;
    if (changes == null) return proposal;
    final state = await changes.backend.readState();
    return changes.propose(
      category: 'policies',
      summary: 'Local rules',
      candidate: {...state, 'policies': document.toJson()},
      baseDraftId: draftId,
      expectedPolicyDigest: expectedPolicyDigest,
    );
  }

  @override
  Future<LocalPolicyDocument> readPolicyDraft(String id) =>
      policyChanges!.readPolicyDraft(id);
  @override
  Future<LocalPolicyDocument> readPolicies() async {
    if (readError != null) throw readError!;
    return currentDocument;
  }

  @override
  Future<PolicySimulationResult> simulatePolicies({
    required LocalPolicyDocument document,
    required String targetId,
    required List<PolicySource> sources,
    required Map<String, bool?> health,
    required DateTime now,
    Map<String, int> localUsage = const {},
    List<Map<String, Object?>> steps = const [],
    List<Map<String, Object?>> flows = const [],
  }) async {
    simulations++;
    simulationSteps = steps;
    return PolicySimulationResult(
      snapshot: const {},
      timeline: [
        {'at': now.millisecondsSinceEpoch},
      ],
      results: const [
        {'policyId': 'p', 'reason': 'fixture'},
      ],
    );
  }
}

class _PolicyBackend implements ConfigurationBackend {
  final Map<String, Object?> state;
  int writes = 0;
  bool failValidation = false;
  void Function()? onValidate;

  _PolicyBackend(LocalPolicyDocument document)
    : state = {
        'policies': document.toJson(),
        'config': {'password': 'never-expose-config'},
      };

  @override
  Future<Map<String, Object?>> readState() async =>
      policyObject(jsonDecode(jsonEncode(state)), 'state');
  @override
  Future<Map<String, Object?>> validate(Map<String, Object?> candidate) async {
    onValidate?.call();
    if (failValidation) throw const FormatException('private source content');
    LocalPolicyDocument.fromJson(
      policyObject(candidate['policies'], 'policies'),
    );
    return {};
  }

  @override
  bool isHighRisk(Map<String, Object?> before, Map<String, Object?> after) =>
      true;
  @override
  Future<void> persist(Map<String, Object?> candidate) async {
    writes++;
  }

  @override
  Future<void> activate(Map<String, Object?> candidate) async {}
}

class _SupersedeFailureDatabase extends WorkbenchDatabase {
  _SupersedeFailureDatabase() : super(NativeDatabase.memory());

  @override
  Future<void> changeStatus(String id, String status, {String? error}) async {
    if (status == 'superseded') throw StateError('journal unavailable');
    return super.changeStatus(id, status, error: error);
  }
}

class _Environment implements ResourceEnvironment {
  final Map<String, Map<String, Object?>> snapshots = {};
  int writes = 0;
  Map<String, Object?>? validated;
  @override
  Future<Map<String, Object?>> read(ResourceScope scope) async => policyObject(
    jsonDecode(
      jsonEncode(
        snapshots.putIfAbsent(
          scope.category,
          () => {
            'scope': scope.toJson(),
            'profile': _profile.toJson(),
            'protectedContent': 'private source credential',
            'protectedScriptContent': null,
            'selectedProfileId': 7,
            'addedRules': <Object?>[],
            'customRules': <Object?>[],
            'disabledRules': <Object?>[],
            'groups': <Object?>[],
          },
        ),
      ),
    ),
    'state',
  );
  @override
  Future<ResourceValidation> validate(
    ResourceScope scope,
    Map<String, Object?> candidate, {
    required bool approvedScript,
  }) async {
    validated = candidate;
    return const ResourceValidation({
      'validated': true,
    }, generatedYaml: 'fixture yaml');
  }

  @override
  Future<void> persist(
    ResourceScope scope,
    Map<String, Object?> candidate,
  ) async {
    writes++;
    snapshots[scope.category] = Map.of(candidate);
  }

  @override
  Future<void> activate(
    ResourceScope scope,
    Map<String, Object?> candidate, {
    String? generatedYaml,
    Map<String, Object?>? previousSnapshot,
  }) async {}
}

class _Gateway implements AgentResourceGateway {
  int clears = 0;
  int updates = 0;
  int enabledWrites = 0;
  List<Profile> profiles = [_profile];
  @override
  Future<List<Profile>> readProfiles() async => profiles;
  @override
  Future<List<Script>> readScripts() async => [
    Script(id: 8, label: 'fixture script', lastUpdateTime: DateTime(2026)),
  ];
  @override
  Future<Map<String, Object?>> downloadProfile(String url) async => {
    'protectedContent': 'secret downloaded source',
    'subscriptionInfo': const SubscriptionInfo().toJson(),
  };
  @override
  Future<Map<String, Object?>> usageSummary() async => {
    'enabled': true,
    'upload': 10,
    'download': 20,
  };
  @override
  Future<void> setUsageEnabled(bool enabled) async {
    enabledWrites++;
  }

  @override
  Future<void> clearUsage() async {
    clears++;
  }

  @override
  Future<Map<String, Object?>> updateResource(
    String kind,
    String? providerName, {
    bool Function()? isCurrent,
  }) async {
    updates++;
    return {'status': 'accepted', 'completionRequiresCoreEvent': true};
  }

  @override
  Future<Map<String, Object?>> openPanel(String panel) async => {
    'status': 'requires_user_action',
    'panel': panel,
    'modelMayProvidePath': false,
  };
}

void main() {
  late WorkbenchDatabase database;
  late _Controller controller;
  late _Environment environment;
  late _Gateway gateway;
  late AgentTools tools;
  var current = true;
  var allow = true;
  var approvals = 0;
  var sequence = 0;
  setUp(() async {
    await AppLocalizations.load(const Locale('en'));
    database = WorkbenchDatabase(NativeDatabase.memory());
    controller = _Controller(database);
    environment = _Environment();
    gateway = _Gateway();
    current = true;
    allow = true;
    approvals = 0;
    tools = AgentTools(
      controller: controller,
      resources: ResourceChangeService(
        store: database,
        environment: environment,
      ),
      gateway: gateway,
      approve: (_) async {
        approvals++;
        return allow;
      },
    );
  });
  tearDown(() async => database.close());
  AgentToolRequest request(
    String name, [
    Map<String, Object?> args = const {},
  ]) => AgentToolRequest(
    requestId: 'fixture',
    toolCallId: 'call${sequence++}',
    name: name,
    arguments: args,
    isCurrent: () => current,
  );
  Future<AgentToolResult> execute(
    String name, [
    Map<String, Object?> args = const {},
  ]) => tools.execute(request(name, args));

  test(
    'AI proposals retain origins, dynamic references and user rule positions',
    () async {
      controller.currentDocument = LocalPolicyDocument.fromJson({
        ...const LocalPolicyDocument().asStandalone().toJson(),
        'policies': [
          {
            'id': 'terminal',
            'label': 'Remaining',
            'targetId': localPolicyTargetId,
            'origin': 'manual',
            'candidateNodeIds': ['fixed'],
          },
        ],
      });
      final result = await execute('policies_propose', {
        'patch': {
          'moduleEnabled': true,
          'nodeSets': [
            {
              'id': 'japan',
              'label': 'Japan set',
              'targetId': localPolicyTargetId,
              'sourceIds': ['7'],
              'regions': ['JP'],
              'unknownMultiplier': 'assumeOne',
            },
          ],
          'policies': [
            {'id': 'terminal', 'label': 'Keep remaining', 'origin': 'ai'},
            {
              'id': 'new-ai',
              'label': 'Example traffic',
              'targetId': localPolicyTargetId,
              'scope': {
                'type': 'domainSuffix',
                'values': ['example.test'],
              },
              'choices': [
                {'type': 'nodeSet', 'id': 'japan'},
              ],
            },
          ],
        },
      });
      expect(result.isError, false, reason: '${result.value}');
      final proposed = controller.proposedDocument!;
      expect(proposed.schemaVersion, 4);
      expect(
        proposed.nodeSets.single.unknownMultiplier,
        UnknownMultiplier.assumeOne,
      );
      expect(orderedPolicies(proposed.policies).map((rule) => rule.id), [
        'terminal',
        'new-ai',
      ]);
      expect(proposed.policies.first.origin, PolicyOrigin.manual);
      expect(proposed.policies.last.origin, PolicyOrigin.ai);
      expect(proposed.policies.last.choices.single.id, 'japan');
      expect(approvals, 0);
    },
  );

  LocalPolicyDocument nodeSetDocument() => LocalPolicyDocument.fromJson({
    ...const LocalPolicyDocument().asStandalone().toJson(),
    'nodeSets': [
      for (final pair in [('hk', 'HK'), ('us', 'US'), ('low', 'HK')])
        {
          'id': pair.$1,
          'label': pair.$1,
          'targetId': localPolicyTargetId,
          'sourceIds': ['7'],
          'regions': [pair.$2],
          if (pair.$1 == 'low') 'maxMultiplier': 0.5,
        },
    ],
  });

  Map<String, Object?> policyPatch(String id, String set) => {
    'policies': [
      {
        'id': id,
        'label': id,
        'targetId': localPolicyTargetId,
        'scope': {
          'type': 'domainSuffix',
          'values': ['$id.example'],
        },
        'choices': [
          {'type': 'nodeSet', 'id': set},
        ],
      },
    ],
  };

  test(
    'policy discovery explains empty independent configuration and examples',
    () async {
      final empty = await execute('policies_read');
      expect((empty.value['document'] as Map)['policies'], isEmpty);
      final contract = empty.value['contract'] as Map;
      expect(contract['targetId'], localPolicyTargetId);
      final semantics = contract['semantics'] as Map;
      expect(semantics['subscriptionProfileSelectionRequired'], false);
      expect(semantics['nodeSetsAreSubscriptionProxyGroups'], false);
      final example = (contract['examples'] as List).single as Map;
      final result = await execute(
        'policies_propose',
        policyObject(example['arguments'], 'arguments'),
      );
      expect(result.isError, false, reason: '${result.value}');
      expect(
        controller.proposedDocument!.policies.single.action,
        PolicyAction.direct,
      );
      controller.currentDocument = nodeSetDocument();
      final populated = await execute('policies_catalog');
      final available =
          (populated.value['contract'] as Map)['availableNodeSets'] as List;
      expect(available.map((entry) => (entry as Map)['id']), [
        'hk',
        'us',
        'low',
      ]);
      expect(populated.value['patchSchema'], AgentPolicyContract.patchSchema);
      expect(approvals, 0);
    },
  );

  test(
    'policy schema discovers all model fields and enforces nested inputs',
    () async {
      final schema = AgentPolicyContract.patchSchema['properties'] as Map;
      final policySchema = (schema['policies'] as Map)['items'] as Map;
      final setSchema = (schema['nodeSets'] as Map)['items'] as Map;
      expect(
        (policySchema['properties'] as Map).keys.toSet(),
        const LocalPolicy(
          id: 'p',
          label: 'P',
          targetId: localPolicyTargetId,
          action: PolicyAction.direct,
        ).toJson().keys.toSet(),
      );
      expect(
        (setSchema['properties'] as Map).keys.toSet(),
        nodeSetDocument().nodeSets.first.toJson().keys.toSet(),
      );
      final probe =
          ((policySchema['properties'] as Map)['probe'] as Map)['properties']
              as Map;
      expect(probe.keys.toSet(), const PolicyProbe().toJson().keys.toSet());
      for (final patch in [
        {
          'policies': [
            {
              'id': 'p',
              'scope': {'type': 'unsupported'},
            },
          ],
        },
        {
          'nodeSets': [
            {
              'id': 'hk',
              'preferences': [
                {'type': 'latency', 'direction': 'up'},
              ],
            },
          ],
        },
        {
          'policies': [
            {
              'id': 'p',
              'guard': {'password': 'never-expose'},
            },
          ],
        },
        {
          'nodeAttributes': {
            'node': {'multiplier': -1},
          },
        },
      ]) {
        final result = await execute('policies_propose', {'patch': patch});
        expect(result.value['code'], 'tool_invalid_arguments');
      }
      expect(controller.proposedDocument, isNull);
    },
  );

  test(
    'local nodeSet rules can be edited continuously without profile selection or loss',
    () async {
      controller.currentDocument = nodeSetDocument();
      final backend = _PolicyBackend(controller.currentDocument);
      controller.policyChanges = ConfigurationChangeService(
        backend: backend,
        store: database,
      );
      final first = await execute('policies_propose', {
        'patch': policyPatch('streaming', 'hk'),
      });
      expect(first.isError, false, reason: '${first.value}');
      final firstId = (first.value['proposal'] as Map)['id'] as String;
      final read = await execute('policies_draft_read', {'id': firstId});
      expect(read.isError, false);
      expect(jsonEncode(read.value), isNot(contains('never-expose-config')));
      expect(read.value.keys, isNot(contains('config')));
      final second = await execute('policies_propose', {
        'draftId': firstId,
        'patch': {
          'policies': [
            {
              'id': 'streaming',
              'label': 'Updated',
              'choices': [
                {'type': 'nodeSet', 'id': 'us'},
              ],
              'probe': {'intervalSeconds': 120},
            },
            ...(policyPatch('downloads', 'low')['policies'] as List),
          ],
        },
      });
      expect(second.isError, false, reason: '${second.value}');
      final secondId = (second.value['proposal'] as Map)['id'] as String;
      final revised = await controller.readPolicyDraft(secondId);
      expect(revised.policies.map((rule) => rule.id), [
        'streaming',
        'downloads',
      ]);
      expect(revised.policies.first.scope.values, ['streaming.example']);
      expect(revised.policies.first.probe.intervalSeconds, 120);
      expect(revised.policies.first.probe.timeoutSeconds, 5);
      expect(revised.policies.first.choices.single.id, 'us');
      expect(revised.nodeSets.length, 3);
      final third = await execute('policies_propose', {
        'draftId': secondId,
        'patch': {
          'policies': [
            {'id': 'streaming', 'label': 'Final'},
          ],
        },
      });
      expect(third.isError, false, reason: '${third.value}');
      final thirdId = (third.value['proposal'] as Map)['id'] as String;
      expect((await controller.readPolicyDraft(thirdId)).policies.length, 2);
      expect((await database.readChange(firstId))!.status, 'superseded');
      expect((await database.readChange(secondId))!.status, 'superseded');
      expect((await database.readChange(thirdId))!.status, 'draft');
      expect(backend.writes, 0);
      expect(approvals, 0);
      expect(controller.currentDocument.policies, isEmpty);
    },
  );

  test(
    'draft failures retain the prior draft and conflicts remain explicit',
    () async {
      controller.currentDocument = nodeSetDocument();
      final backend = _PolicyBackend(controller.currentDocument);
      controller.policyChanges = ConfigurationChangeService(
        backend: backend,
        store: database,
      );
      final first = await execute('policies_propose', {
        'patch': policyPatch('streaming', 'hk'),
      });
      final id = (first.value['proposal'] as Map)['id'] as String;
      backend.failValidation = true;
      final failed = await execute('policies_propose', {
        'draftId': id,
        'patch': {
          'policies': [
            {'id': 'streaming', 'label': 'Invalid'},
          ],
        },
      });
      expect(failed.value['code'], 'tool_invalid_arguments');
      expect((await database.readChange(id))!.status, 'draft');
      backend.failValidation = false;
      backend.onValidate = () => backend.state['other'] = true;
      final conflict = await execute('policies_propose', {
        'draftId': id,
        'patch': {
          'policies': [
            {'id': 'streaming', 'label': 'Stale'},
          ],
        },
      });
      expect(conflict.value['code'], 'configuration_version_conflict');
      expect((await database.readChange(id))!.status, 'draft');
      expect(
        (await execute('policies_draft_read', {'id': id})).value['code'],
        'configuration_version_conflict',
      );
      expect(
        (await execute('policies_draft_read', {'id': 'missing'})).value['code'],
        'configuration_proposal_missing',
      );
      backend.state.remove('other');
      await database.changeStatus(id, 'rejected');
      expect(
        (await execute('policies_draft_read', {'id': id})).value['code'],
        'configuration_proposal_not_pending',
      );
      expect(backend.writes, 0);
    },
  );

  test('only pending unexpired policy drafts can be continued', () async {
    final backend = _PolicyBackend(controller.currentDocument);
    var now = DateTime(2026, 10, 15);
    final changes = ConfigurationChangeService(
      backend: backend,
      store: database,
      clock: () => now,
    );
    controller.policyChanges = changes;
    final settings = await changes.propose(
      category: 'settings',
      summary: 'Settings',
      candidate: {...backend.state, 'other': 1},
    );
    expect(
      (await execute('policies_draft_read', {'id': settings.id})).value['code'],
      'configuration_proposal_not_pending',
    );
    final draft = await execute('policies_propose', {
      'patch': {
        'policies': [
          {
            'id': 'p',
            'label': 'P',
            'targetId': localPolicyTargetId,
            'action': 'direct',
          },
        ],
      },
    });
    final id = (draft.value['proposal'] as Map)['id'] as String;
    now = now.add(const Duration(minutes: 10));
    expect(
      (await execute('policies_draft_read', {'id': id})).value['code'],
      'configuration_proposal_expired',
    );
    expect((await database.readChange(id))!.status, 'draft');
  });

  test(
    'tool errors always return a safe machine code without raw source details',
    () async {
      const secret = 'password=never-expose-raw-source';
      for (final error in [
        const FormatException(secret),
        const ConfigurationChangeException(secret),
        const ScriptExecutionException(secret),
        const PolicySourceException(secret),
        StateError(secret),
      ]) {
        controller.readError = error;
        final result = await execute('policies_read');
        expect(result.isError, true);
        expect(result.value['code'], matches(RegExp(r'^[a-z][a-z0-9_]+$')));
        expect(jsonEncode(result.value), isNot(contains(secret)));
      }
    },
  );

  test(
    'nested partial nodeSet patches preserve fields and legacy opaque inputs remain accepted',
    () async {
      controller.currentDocument = nodeSetDocument();
      final result = await execute('policies_propose', {
        'patch': {
          'nodeSets': [
            {
              'id': 'hk',
              'preferences': [
                {'type': 'latency', 'direction': 'ascending'},
              ],
            },
          ],
        },
      });
      expect(result.isError, false, reason: '${result.value}');
      final set = controller.proposedDocument!.nodeSets.first;
      expect(set.sourceIds, ['7']);
      expect(set.regions, ['HK']);
      expect(set.preferences.single.type, NodePreferenceType.latency);
      final opaque = await execute('settings_propose', {
        'patch': {
          'legacy': {
            'nested': [
              true,
              'value',
              {'number': 2},
            ],
          },
        },
      });
      expect(opaque.isError, false);
      expect(controller.settingsPatch!['legacy'], isA<Map>());
    },
  );

  test('concurrent revisions of one draft produce one successor', () async {
    controller.currentDocument = nodeSetDocument();
    final backend = _PolicyBackend(controller.currentDocument);
    controller.policyChanges = ConfigurationChangeService(
      backend: backend,
      store: database,
    );
    final first = await execute('policies_propose', {
      'patch': policyPatch('streaming', 'hk'),
    });
    final id = (first.value['proposal'] as Map)['id'] as String;
    final results = await Future.wait([
      for (final label in ['A', 'B'])
        execute('policies_propose', {
          'draftId': id,
          'patch': {
            'policies': [
              {'id': 'streaming', 'label': label},
            ],
          },
        }),
    ]);
    expect(results.where((result) => !result.isError).length, 1);
    expect(
      results.where((result) => result.isError).single.value['code'],
      'configuration_proposal_not_pending',
    );
    final rows = await database.watchChanges().first;
    expect(rows.where((row) => row.status == 'draft').length, 1);
    expect(rows.where((row) => row.status == 'superseded').length, 1);
    expect(backend.writes, 0);
  });

  test(
    'a successor journal failure rolls back without destroying the original draft',
    () async {
      final failingStore = _SupersedeFailureDatabase();
      try {
        final backend = _PolicyBackend(controller.currentDocument);
        final changes = ConfigurationChangeService(
          backend: backend,
          store: failingStore,
        );
        final candidate = {
          ...backend.state,
          'policies': LocalPolicyDocument.fromJson({
            ...controller.currentDocument.toJson(),
            'policies': [
              {
                'id': 'p',
                'label': 'P',
                'targetId': localPolicyTargetId,
                'action': 'direct',
              },
            ],
          }).toJson(),
        };
        final original = await changes.propose(
          category: 'policies',
          summary: 'Original',
          candidate: candidate,
        );
        await expectLater(
          changes.propose(
            category: 'policies',
            summary: 'Revised',
            candidate: candidate,
            baseDraftId: original.id,
          ),
          throwsStateError,
        );
        final rows = await failingStore.watchChanges().first;
        expect(rows.length, 1);
        expect(rows.single.id, original.id);
        expect(rows.single.status, 'draft');
        expect(
          (await changes.readPolicyDraft(original.id)).policies.single.id,
          'p',
        );
      } finally {
        await failingStore.close();
      }
    },
  );

  test('tool surface has safe names and no arbitrary execution or paths', () {
    expect(
      tools.definitions.map((tool) => tool.name).toSet().length,
      tools.definitions.length,
    );
    for (final tool in tools.definitions) {
      expect(tool.name, matches(RegExp(r'^[a-z][a-z0-9_]*$')));
      expect(tool.parameters['additionalProperties'], false);
      expect(
        (tool.parameters['properties'] as Map).keys,
        isNot(contains('path')),
      );
    }
    expect(
      tools.definitions.map((tool) => tool.name),
      containsAll([
        'settings_catalog',
        'policies_propose',
        'profile_propose',
        'rule_propose',
        'group_propose',
        'script_propose',
        'usage_clear',
        'backup_panel',
      ]),
    );
  });

  test('strict argument whitelist and types reject approval bypass', () async {
    for (final args in [
      {'enabled': true, 'approve': true},
      {'enabled': 'true'},
      {'enabled': null},
      {'enabled': true, 'highRisk': false},
    ]) {
      expect((await execute('usage_set_enabled', args)).isError, true);
    }
    expect(approvals, 0);
    expect(gateway.enabledWrites, 0);
    expect(
      (await execute('shell', {'command': 'fixture'})).value['code'],
      'tool_unknown',
    );
  });

  test(
    'profile and script metadata withhold source and subscription secrets',
    () async {
      final profiles = jsonEncode((await execute('profiles_list')).value);
      expect(profiles, contains('https://example.invalid'));
      expect(profiles, isNot(contains('never-expose')));
      expect(profiles, isNot(contains('subscription?')));
      final scripts = jsonEncode((await execute('scripts_list')).value);
      expect(scripts, contains('fixture script'));
      expect(scripts, isNot(contains('protectedContent')));
    },
  );

  test(
    'profile URL proposal diff is redacted and commit is locally approved',
    () async {
      final result = await execute('profile_propose', {
        'operation': 'edit',
        'profileId': 7,
        'patch': {'url': 'https://new.invalid/path?token=second-secret'},
      });
      expect(result.isError, false, reason: '${result.value}');
      final encoded = jsonEncode(result.value);
      expect(encoded, isNot(contains('second-secret')));
      expect(encoded, isNot(contains('never-expose')));
      expect(environment.writes, 0);
      final id = (result.value['proposal'] as Map)['id'];
      final commit = await execute('changes_commit', {'id': id});
      expect(commit.isError, false, reason: '${commit.value}');
      expect(approvals, 1);
      expect(environment.writes, 1);
    },
  );

  test(
    'rule CRUD operates on a scoped mutable copy and journals the draft',
    () async {
      final result = await execute('rule_propose', {
        'profileId': 7,
        'scene': 'added',
        'operation': 'add',
        'rule': {
          'ruleAction': 'DOMAIN',
          'content': 'example.invalid',
          'ruleTarget': 'REJECT',
        },
      });
      expect(result.isError, false, reason: '${result.value}');
      expect((environment.validated!['addedRules'] as List).length, 1);
      expect(environment.writes, 0);
      final id = (result.value['proposal'] as Map)['id'] as String;
      expect(
        (await database.readChange(id))!.category,
        'resource:rules:7:added',
      );
      expect(
        (await execute('rule_propose', {
          'profileId': 7,
          'scene': 'added',
          'operation': 'add',
          'rule': {'path': '/private/secret'},
        })).isError,
        true,
      );
    },
  );

  test(
    'group rename updates scoped group and rule references in the draft',
    () async {
      const scope = ResourceScope(ResourceKind.groups, 7);
      final state = await environment.read(scope);
      state['groups'] = [
        const ProxyGroup(
          id: 21,
          name: 'A',
          type: GroupType.Selector,
          proxies: ['REJECT'],
        ).toJson(),
        const ProxyGroup(
          id: 22,
          name: 'B',
          type: GroupType.Selector,
          proxies: ['A'],
        ).toJson(),
      ];
      state['customRules'] = [
        const Rule(
          id: 23,
          content: 'example.invalid',
          ruleTarget: 'A',
        ).toJson(),
      ];
      environment.snapshots[scope.category] = state;
      final result = await execute('group_propose', {
        'profileId': 7,
        'operation': 'edit',
        'groupId': 21,
        'group': {'name': 'Renamed'},
      });
      expect(result.isError, false, reason: '${result.value}');
      final groups = environment.validated!['groups'] as List;
      expect((groups[1] as Map)['proxies'], ['Renamed']);
      expect(
        ((environment.validated!['customRules'] as List).first
            as Map)['ruleTarget'],
        'Renamed',
      );
      expect(environment.writes, 0);
      expect(
        (await execute('group_propose', {
          'profileId': 7,
          'operation': 'delete',
          'groupId': 21,
        })).value['code'],
        'resource_group_referenced',
      );
    },
  );

  test('disabling an existing rule preserves its shared content', () async {
    const scope = ResourceScope(
      ResourceKind.rules,
      7,
      scene: RuleScene.disabled,
    );
    final state = await environment.read(scope);
    state['addedRules'] = [
      const Rule(
        id: 31,
        content: 'example.invalid',
        ruleTarget: 'REJECT',
      ).toJson(),
    ];
    environment.snapshots[scope.category] = state;
    final result = await execute('rule_set_disabled', {
      'profileId': 7,
      'ruleId': 31,
      'disabled': true,
    });
    expect(result.isError, false, reason: '${result.value}');
    expect(environment.validated!['disabledRules'], state['addedRules']);
    expect(
      (await execute('rule_set_disabled', {
        'profileId': 7,
        'ruleId': 99,
        'disabled': true,
      })).value['code'],
      'resource_rule_missing',
    );
  });

  test(
    'script disabling accepts explicit null selection without execution',
    () async {
      const scope = ResourceScope(ResourceKind.profile, 7);
      final state = await environment.read(scope);
      state['profile'] = _profile
          .copyWith(scriptId: 8, overwriteType: OverwriteType.script)
          .toJson();
      state['protectedScriptContent'] = 'private existing script';
      environment.snapshots[scope.category] = state;
      final result = await execute('script_select', {
        'profileId': 7,
        'scriptId': null,
        'enabled': false,
      });
      expect(result.isError, false, reason: '${result.value}');
      expect((environment.validated!['profile'] as Map)['scriptId'], null);
      expect(environment.writes, 0);
    },
  );

  test(
    'simulation uses shared controller decision RPC and validates event steps',
    () async {
      final steps = [
        {
          'at': 1700000001000,
          'probes': [
            {'nodeId': 'fixture', 'success': false},
          ],
          'usage': {'7': 5},
        },
      ];
      final result = await execute('policies_simulate', {
        'targetId': localPolicyTargetId,
        'now': 1700000000000,
        'steps': steps,
      });
      expect(result.isError, false, reason: '${result.value}');
      expect(controller.simulations, 1);
      expect(controller.simulationSteps, steps);
      expect(result.value['mode'], 'cold_start');
      expect(result.value['predictsCurrentRuntime'], false);
      expect(result.value['timeline'], [
        {'at': 1700000000000},
      ]);
      for (final step in [
        {'at': 1, 'probes': null},
        {
          'at': 1,
          'probes': [
            {'nodeId': 'fixture', 'success': 'false'},
          ],
        },
        {
          'at': 1,
          'sources': [
            {'id': '7', 'path': '/tmp/secret'},
          ],
        },
        {
          'at': 1,
          'usage': {'7': -1},
        },
      ]) {
        final invalid = await execute('policies_simulate', {
          'targetId': localPolicyTargetId,
          'steps': [step],
        });
        expect(invalid.value['code'], 'tool_invalid_arguments');
      }
      expect(controller.simulations, 1);
      expect(environment.writes, 0);
      expect(approvals, 0);
    },
  );

  test(
    'real Snowflake identifiers read, edit, bind scripts, commit and undo exactly',
    () async {
      final id = snowflake.id;
      final scriptId = snowflake.id;
      expect(id, greaterThan(9007199254740991));
      final profile = _profile.copyWith(id: id);
      gateway.profiles = [profile];
      final scope = ResourceScope(ResourceKind.profile, id);
      final state = await environment.read(scope);
      state['profile'] = profile.toJson();
      state['selectedProfileId'] = id;
      environment.snapshots[scope.category] = state;
      final listed = await execute('profiles_list');
      final dto = (listed.value['profiles'] as List).first as Map;
      expect(dto['id'], id.toString());
      final proposal = await execute('profile_propose', {
        'operation': 'edit',
        'profileId': '$id',
        'patch': {'label': 'edited'},
      });
      expect(proposal.isError, false, reason: '${proposal.value}');
      expect((environment.validated!['profile'] as Map)['id'], id);
      final changeId = (proposal.value['proposal'] as Map)['id'] as String;
      expect(
        (await execute('changes_commit', {'id': changeId})).isError,
        false,
      );
      final undo = await execute('changes_undo', {'id': changeId});
      expect(undo.isError, false, reason: '${undo.value}');
      final undoId = (undo.value['proposal'] as Map)['id'] as String;
      expect((await execute('changes_commit', {'id': undoId})).isError, false);
      expect(
        (environment.snapshots[scope.category]!['profile'] as Map)['id'],
        id,
      );
      expect(
        (environment.snapshots[scope.category]!['profile'] as Map)['label'],
        'fixture',
      );
      final scriptScope = ResourceScope(ResourceKind.script, scriptId);
      environment.snapshots[scriptScope.category] = {
        'scope': scriptScope.toJson(),
        'script': Script(
          id: scriptId,
          label: 'fixture',
          lastUpdateTime: DateTime(2026),
        ).toJson(),
        'protectedContent': 'private script',
      };
      final bound = await execute('script_select', {
        'profileId': '$id',
        'scriptId': '$scriptId',
        'enabled': true,
      });
      expect(bound.isError, false, reason: '${bound.value}');
      expect((environment.validated!['profile'] as Map)['scriptId'], scriptId);
      expect(
        (await execute('profile_propose', {
          'operation': 'edit',
          'profileId': id,
          'patch': {'label': 'must reject'},
        })).value['code'],
        'tool_invalid_arguments',
      );
    },
  );

  test(
    'Node JSON roundtrip preserves decimal Snowflake tool identifiers',
    () async {
      final id = snowflake.id;
      gateway.profiles = [_profile.copyWith(id: id, scriptId: snowflake.id)];
      final dto = (await execute('profiles_list')).value;
      final roundtrip = await handleEvaluate(
        'function main(config) { return config; }',
        Map<String, dynamic>.from(dto),
        launcher: () => launchScriptProcess(
          executablePath:
              Platform.environment['FLCLASH_TEST_NODE'] ??
              '/private/tmp/flclash-ai-host-node22-arm64/Resources/ai/node',
          runnerPath: '${Directory.current.path}/scripts/script_runner.mjs',
        ),
      );
      expect(
        ((roundtrip['profiles'] as List).first as Map)['id'],
        id.toString(),
      );
      expect(jsonEncode(roundtrip), contains('"id":"$id"'));
    },
    skip: !Platform.isMacOS,
  );

  test(
    'settings and integration tools normalize exact decimal resource identifiers',
    () async {
      final id = snowflake.id;
      final settings = await execute('settings_propose', {
        'patch': {'currentProfileId': '$id'},
      });
      expect(settings.isError, false, reason: '${settings.value}');
      expect(controller.settingsPatch!['currentProfileId'], id);
      final policies = await execute('policies_propose', {
        'patch': {
          'sourceUpdateRoute': 'direct',
          'integrations': [
            {
              'id': localPolicyProfileId,
              'label': 'fixture',
              'sourceProfileIds': ['$id'],
            },
          ],
        },
      });
      expect(policies.isError, false, reason: '${policies.value}');
      expect(controller.proposedDocument!.localProfile.sourceProfileIds, [id]);
      expect(
        controller.proposedDocument!.sourceUpdateRoute,
        SourceUpdateRoute.direct,
      );
      final archive = await execute('policies_propose', {
        'patch': {
          'integrations': [
            {
              'id': 'other',
              'label': 'Other',
              'sourceProfileIds': ['$id'],
            },
          ],
        },
      });
      expect(archive.value['code'], 'tool_invalid_arguments');
      final unsafe = await execute('policies_propose', {
        'patch': {
          'integrations': [
            {
              'id': 'fixture',
              'label': 'fixture',
              'sourceProfileIds': [id],
            },
          ],
        },
      });
      expect(unsafe.value['code'], 'tool_invalid_arguments');
      expect(approvals, 0);
    },
  );

  test('usage clear denial and replay cannot bypass local approval', () async {
    allow = false;
    final denied = request('usage_clear');
    expect((await tools.execute(denied)).value['status'], 'rejected');
    allow = true;
    expect((await tools.execute(denied)).value['replayed'], true);
    expect(gateway.clears, 0);
    final approved = request('usage_clear');
    expect((await tools.execute(approved)).isError, false);
    expect((await tools.execute(approved)).value['replayed'], true);
    expect(gateway.clears, 1);
    expect(approvals, 2);
  });

  test('session cancellation during approval blocks mutation', () async {
    tools = AgentTools(
      controller: controller,
      resources: tools.resources,
      gateway: gateway,
      approve: (_) async {
        current = false;
        return true;
      },
    );
    final result = await execute('usage_clear');
    expect(result.value['code'], 'configuration_cancelled');
    expect(gateway.clears, 0);
  });

  test(
    'invalid resource and panel input is rejected before approval or gateway',
    () async {
      expect(
        (await execute('resource_update', {
          'kind': 'mmdb',
          'providerName': 'unexpected',
        })).isError,
        true,
      );
      expect(
        (await execute('resource_update', {'kind': 'provider'})).isError,
        true,
      );
      expect(
        (await execute('backup_panel', {
          'action': 'backup',
          'path': '/tmp/not-user-selected',
        })).isError,
        true,
      );
      expect(
        (await execute('profile_import_panel', {
          'path': '/tmp/not-user-selected',
        })).isError,
        true,
      );
      expect(gateway.updates, 0);
      expect(approvals, 0);
    },
  );
  test(
    'draft reply uses actual final order and duplicate global cannot replace valid draft',
    () async {
      controller.currentDocument = nodeSetDocument();
      final backend = _PolicyBackend(controller.currentDocument);
      controller.policyChanges = ConfigurationChangeService(
        backend: backend,
        store: database,
      );
      final first = await execute('policies_propose', {
        'patch': {
          'policies': [
            ...(policyPatch('ai', 'us')['policies'] as List),
            {
              'id': 'old_global',
              'label': 'Old all traffic',
              'targetId': localPolicyTargetId,
              'scope': {'type': 'global'},
              'choices': [
                {'type': 'nodeSet', 'id': 'hk'},
              ],
            },
          ],
        },
      });
      final firstId = (first.value['proposal'] as Map)['id'] as String;
      final duplicate = await execute('policies_propose', {
        'draftId': firstId,
        'patch': {
          'policies': [
            {
              'id': 'new_global',
              'label': 'New all traffic',
              'targetId': localPolicyTargetId,
              'scope': {'type': 'global'},
              'choices': [
                {'type': 'nodeSet', 'id': 'hk'},
              ],
            },
          ],
        },
      });
      expect(duplicate.value['status'], 'failed');
      expect((await database.readChange(firstId))!.status, 'draft');
      final revised = await execute('policies_propose', {
        'draftId': firstId,
        'removePolicyIds': ['old_global'],
        'patch': {
          'policies': [
            {
              'id': 'domestic',
              'label': 'Domestic direct',
              'targetId': localPolicyTargetId,
              'scope': {
                'type': 'destinationRegion',
                'values': ['CN'],
              },
              'action': 'direct',
            },
            {
              'id': 'new_global',
              'label': 'Other to HK',
              'targetId': localPolicyTargetId,
              'scope': {'type': 'global'},
              'choices': [
                {'type': 'nodeSet', 'id': 'hk'},
              ],
            },
          ],
        },
      });
      expect(revised.isError, false, reason: '${revised.value}');
      final id = (revised.value['proposal'] as Map)['id'] as String;
      expect(revised.value['supersedesId'], firstId);
      final read = await execute('policies_draft_read', {'id': id});
      expect((read.value['validation'] as Map)['valid'], true);
      final summary = read.value['businessSummary'] as Map;
      expect(summary['ruleCount'], 3);
      expect((summary['rules'] as List).map((row) => (row as Map)['id']), [
        'ai',
        'domestic',
        'new_global',
      ]);
      expect((summary['rules'] as List)[1]['match'], contains('GeoIP'));
      expect(
        summary['reply'],
        (revised.value['businessSummary'] as Map)['reply'],
      );
      expect(backend.writes, 0);
      expect(approvals, 0);
    },
  );
}
