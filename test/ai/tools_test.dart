import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:fl_clash/ai/runtime.dart';
import 'package:fl_clash/ai/tools.dart';
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
    LocalPolicyDocument document,
  ) async {
    proposedDocument = document;
    return proposal;
  }

  @override
  Future<LocalPolicyDocument> readPolicies() async =>
      const LocalPolicyDocument();
  @override
  Future<PolicySimulationResult> simulatePolicies({
    required LocalPolicyDocument document,
    required String targetId,
    required List<PolicySource> sources,
    required Map<String, bool?> health,
    required DateTime now,
    Map<String, int> localUsage = const {},
    List<Map<String, Object?>> steps = const [],
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
        'targetId': 'profile:7',
        'now': 1700000000000,
        'steps': steps,
      });
      expect(result.isError, false, reason: '${result.value}');
      expect(controller.simulations, 1);
      expect(controller.simulationSteps, steps);
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
          'targetId': 'profile:7',
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
              'id': 'fixture',
              'label': 'fixture',
              'sourceProfileIds': ['$id'],
            },
          ],
        },
      });
      expect(policies.isError, false, reason: '${policies.value}');
      expect(
        controller.proposedDocument!.integrations.single.sourceProfileIds,
        [id],
      );
      expect(
        controller.proposedDocument!.sourceUpdateRoute,
        SourceUpdateRoute.direct,
      );
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
    'resource async acceptance and user panels are reported honestly',
    () async {
      final result = await execute('resource_update', {'kind': 'mmdb'});
      expect(result.value['status'], 'accepted');
      expect(result.value['completionRequiresCoreEvent'], true);
      expect(gateway.updates, 1);
      expect(
        (await execute('backup_panel', {'action': 'restore'})).value['status'],
        'requires_user_action',
      );
      expect(
        (await execute('backup_panel', {
          'action': 'backup',
          'path': '/tmp/not-user-selected',
        })).isError,
        true,
      );
    },
  );
}
