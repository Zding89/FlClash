import 'dart:convert';

import 'package:drift/native.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/models/profile.dart';
import 'package:fl_clash/policy/compiler.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/policy/profile_service.dart';
import 'package:fl_clash/policy/simulation.dart';
import 'package:fl_clash/policy/sources.dart';
import 'package:flutter_test/flutter_test.dart';

const _compiler = LocalPolicyCompiler();
const _set = PolicyNodeSet(
  id: 'pool',
  label: 'Pool',
  targetId: localPolicyTargetId,
  sourceIds: ['1', '2'],
);
const _rule = LocalPolicy(
  id: 'route',
  label: 'Route',
  targetId: localPolicyTargetId,
  choices: [PolicyChoice(type: PolicyChoiceType.nodeSet, id: 'pool')],
);

LocalPolicyDocument _document({
  bool selected = true,
  List<int> sourceIds = const [1, 2],
  List<LocalPolicy> rules = const [_rule],
  List<PolicyNodeSet> sets = const [_set],
}) => LocalPolicyDocument.fromJson({
  ...const LocalPolicyDocument().asStandalone().toJson(),
  'moduleEnabled': true,
  'integrationEnabled': selected,
  'policiesEnabled': true,
  'integrations': [
    SubscriptionIntegration(
      id: localPolicyProfileId,
      label: 'Local',
      sourceProfileIds: sourceIds,
    ).toJson(),
  ],
  'nodeSets': sets.map((set) => set.toJson()).toList(),
  'policies': rules.map((rule) => rule.toJson()).toList(),
});

PolicySource _source(String id) => PolicySource(
  id: id,
  label: 'Airport $id',
  raw: {
    'proxies': [
      {'name': 'Japan $id', 'type': 'ss', 'server': '$id.example', 'port': 443},
    ],
    'proxy-groups': [
      {
        'name': 'Airport group $id',
        'type': 'select',
        'proxies': ['Japan $id'],
      },
    ],
    'rules': ['MATCH,Airport group $id'],
    'dns': {
      'nameserver': ['https://airport.invalid/dns-query'],
    },
    'script': 'airport-script',
  },
);

void main() {
  test(
    'empty local configuration is independent and normalization is stable',
    () {
      final local = const LocalPolicyDocument().asStandalone();
      expect(local.schemaVersion, 4);
      expect(local.activeIntegrationId, localPolicyProfileId);
      expect(local.localProfile.sourceProfileIds, isEmpty);
      expect(local.integrationEnabled, isFalse);
      expect(local.asStandalone(), same(local));
      expect(
        LocalPolicyDocument.fromJson(
          jsonDecode(jsonEncode(local.toJson())) as Map<String, dynamic>,
        ).toJson(),
        local.toJson(),
      );
    },
  );

  test('migration retains old data without broadening active rules', () {
    final legacy = LocalPolicyDocument(
      revision: 7,
      moduleEnabled: true,
      policiesEnabled: true,
      integrationEnabled: true,
      activeIntegrationId: 'old',
      integrations: const [
        SubscriptionIntegration(id: 'old', label: 'Old', sourceProfileIds: [2]),
      ],
      nodeSets: [
        PolicyNodeSet.fromJson({..._set.toJson(), 'targetId': 'profile:1'}),
      ],
      policies: [
        LocalPolicy.fromJson({
          ..._rule.toJson(),
          'targetId': 'profile:1',
          'choices': <Object?>[],
          'candidateNodeIds': ['opaque-old-node', '0:old-node', '-1:old-node'],
        }),
        const LocalPolicy(
          id: 'other',
          label: 'Other',
          targetId: 'integration:old',
          action: PolicyAction.direct,
        ),
      ],
      budgets: const [SourceBudget(sourceId: '2', limitBytes: 1000)],
    );
    final migrated = legacy.asStandalone();
    expect(migrated.revision, 7);
    expect(migrated.migrationReviewRequired, isTrue);
    expect(migrated.integrationEnabled, isFalse);
    expect(migrated.policiesEnabled, isFalse);
    expect(
      migrated.policies.map((rule) => rule.enabled),
      everyElement(isFalse),
    );
    expect(migrated.policies.map((rule) => rule.priority), [1, 2]);
    expect(migrated.policies.first.candidateNodeIds, [
      'opaque-old-node',
      '0:old-node',
      '-1:old-node',
    ]);
    expect(migrated.nodeSets.single.targetId, localPolicyTargetId);
    expect(migrated.localProfile.sourceProfileIds.toSet(), {1, 2});
    expect(
      migrated.integrations.last.toJson(),
      legacy.integrations.single.toJson(),
    );
    expect(migrated.budgets.single.toJson(), legacy.budgets.single.toJson());
  });

  test(
    'migration archives conflicting reserved identifiers without losing data',
    () {
      const conflict = SubscriptionIntegration(
        id: localPolicyProfileId,
        label: 'Previous local',
        sourceProfileIds: [2],
        nameFilter: 'Japan',
        excludedNodeIds: ['2:excluded'],
        fallback: PolicyFallback.direct,
      );
      const legacy = LocalPolicyDocument(
        integrations: [
          conflict,
          SubscriptionIntegration(
            id: '${localPolicyProfileId}_legacy',
            label: 'Previous archive',
            sourceProfileIds: [1],
          ),
        ],
      );
      final migrated = legacy.asStandalone();
      final roundtrip = LocalPolicyDocument.fromJson(
        jsonDecode(jsonEncode(migrated.toJson())) as Map<String, dynamic>,
      ).asStandalone();
      final archived = roundtrip.integrations.firstWhere(
        (entry) => entry.id == '${localPolicyProfileId}_legacy_1',
      );
      expect(archived.toJson(), {
        ...conflict.toJson(),
        'id': '${localPolicyProfileId}_legacy_1',
      });
      expect(roundtrip.localProfile.sourceProfileIds.toSet(), {1, 2});
      expect(roundtrip.localProfile.fallback, PolicyFallback.reject);
      expect(roundtrip.toJson(), migrated.toJson());
    },
  );

  test(
    'migration does not silently truncate more than twenty source profiles',
    () {
      final legacy = LocalPolicyDocument(
        integrations: [
          SubscriptionIntegration(
            id: 'a',
            label: 'A',
            sourceProfileIds: List.generate(20, (index) => index + 1),
          ),
          const SubscriptionIntegration(
            id: 'b',
            label: 'B',
            sourceProfileIds: [21],
          ),
        ],
      );
      final migrated = legacy.asStandalone();
      expect(migrated.localProfile.sourceProfileIds, isEmpty);
      expect(migrated.integrations.skip(1).map((entry) => entry.id), [
        'a',
        'b',
      ]);
      expect(migrated.migrationReviewRequired, isTrue);
    },
  );

  test(
    'canonical documents reject per-airport targets and hidden direct end action',
    () {
      final json = _document().toJson();
      expect(
        () => LocalPolicyDocument.fromJson({
          ...json,
          'policies': [
            {..._rule.toJson(), 'targetId': 'profile:1'},
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => LocalPolicyDocument.fromJson({
          ...json,
          'integrations': [
            {..._document().localProfile.toJson(), 'fallback': 'direct'},
          ],
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'local selection merges nodes and imports no airport routing or DNS',
    () {
      final result = _compiler.compile(
        document: _document(),
        profileId: 999,
        baseConfig: const {
          'mode': 'rule',
          'dns': {
            'nameserver': ['127.0.0.1'],
          },
          'rules': ['MATCH,Airport base'],
          'proxy-groups': [
            {'name': 'Airport base', 'type': 'select'},
          ],
        },
        sources: [_source('1'), _source('2')],
      );
      expect(result.nodes.length, 2);
      expect(result.targetId, localPolicyTargetId);
      expect(result.config['rules'], [
        'MATCH,${_rule.groupName}',
        'MATCH,REJECT',
      ]);
      expect(result.config['dns'], {
        'nameserver': ['127.0.0.1'],
      });
      expect(jsonEncode(result.config), isNot(contains('airport.invalid')));
      expect(jsonEncode(result.config), isNot(contains('Airport group')));
      expect(jsonEncode(result.config), isNot(contains('Airport base')));
      final wire = result.config['flclash-local-policy'] as Map;
      expect(wire['schemaVersion'], 3);
      expect(wire['targetId'], localPolicyTargetId);
      expect((wire['policies'] as List).single['skipUnavailable'], isTrue);
      expect(
        (wire['policies'] as List).single.containsKey('fallback'),
        isFalse,
      );
    },
  );

  test(
    'ordinary subscription receives neither local routing nor budget extension',
    () {
      final base = <String, Object?>{
        'rules': ['MATCH,Airport'],
        'proxy-groups': [
          {
            'name': 'Airport',
            'type': 'select',
            'proxies': ['node'],
          },
        ],
        'dns': {
          'nameserver': ['airport.example'],
        },
      };
      final result = _compiler.compile(
        document: LocalPolicyDocument.fromJson({
          ..._document(selected: false).toJson(),
          'budgetsEnabled': true,
          'budgets': [
            const SourceBudget(sourceId: '1', limitBytes: 1).toJson(),
          ],
        }),
        profileId: 999,
        baseConfig: base,
        sources: const [],
      );
      expect(result.config, base);
      expect(result.nodes, isEmpty);
      expect(result.config.containsKey('flclash-local-policy'), isFalse);
    },
  );

  test('removing an airport leaves its saved filter empty and skippable', () {
    final result = _compiler.compile(
      document: _document(sourceIds: [1]),
      profileId: null,
      baseConfig: const {'mode': 'rule'},
      sources: [_source('1')],
    );
    expect(result.nodes.length, 1);
    expect(result.config['rules'], [
      'MATCH,${_rule.groupName}',
      'MATCH,REJECT',
    ]);
    final document = _document(
      sourceIds: [1],
      sets: [
        PolicyNodeSet.fromJson({
          ..._set.toJson(),
          'sourceIds': ['2'],
        }),
      ],
    );
    final empty = _compiler.compile(
      document: document,
      profileId: null,
      baseConfig: const {'mode': 'rule'},
      sources: [_source('1')],
    );
    expect((empty.config['proxy-groups'] as List).single['proxies'], [
      'REJECT',
    ]);
  });

  test('direct local routing does not require any source profile', () {
    final result = _compiler.compile(
      document: _document(
        sourceIds: [],
        sets: [],
        rules: const [
          LocalPolicy(
            id: 'direct',
            label: 'Direct',
            targetId: localPolicyTargetId,
            action: PolicyAction.direct,
          ),
        ],
      ),
      profileId: null,
      baseConfig: const {'mode': 'rule'},
      sources: const [],
    );
    expect(result.nodes, isEmpty);
    expect(
      (result.config['flclash-local-policy'] as Map)['policies'],
      isNotEmpty,
    );
  });

  test(
    'database exposes a canonical local document without rewriting old records',
    () async {
      final database = WorkbenchDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final old = const LocalPolicyDocument(revision: 5).toJson();
      await database.writeSection('policies', old);
      expect((await database.readPolicies()).isStandalone, isTrue);
      expect(
        (await database.watchPolicies().first).localProfile.id,
        localPolicyProfileId,
      );
      expect(await database.readSection('policies'), old);
    },
  );

  test('ordinary compilation does not read other source files', () async {
    final database = WorkbenchDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final service = PolicyProfileService(
      loader: PolicySourceLoader(
        store: database,
        readFile: (_) async => throw StateError('Must not read local sources'),
      ),
    );
    final result = await service.compile(
      document: _document(selected: false),
      profiles: [Profile.normal()],
      profileId: 999,
      baseConfig: const {
        'rules': ['MATCH,DIRECT'],
      },
    );
    expect(result.config['rules'], ['MATCH,DIRECT']);
  });

  test('canonical simulation cannot target another subscription', () async {
    final simulation = LocalPolicySimulation(
      invoke: (_) async => throw StateError('Must not invoke'),
    );
    await expectLater(
      simulation.run(
        document: _document(),
        targetId: 'profile:1',
        sources: const [],
        health: const {},
        now: DateTime(2026),
      ),
      throwsFormatException,
    );
  });
}
