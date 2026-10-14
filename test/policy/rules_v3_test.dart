import 'package:fl_clash/models/profile.dart';
import 'package:fl_clash/policy/compiler.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/policy/profile_service.dart';
import 'package:fl_clash/policy/sources.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const compiler = LocalPolicyCompiler();
  PolicySource source(String id, String label) => PolicySource(
    id: id,
    label: id,
    raw: {
      'proxies': [
        {'name': label, 'type': 'ss', 'server': '$id.example', 'port': 443},
      ],
    },
  );
  final a = source('1', '日本 1x');
  final b = source('2', '香港');
  const set = PolicyNodeSet(
    id: 'all',
    label: '跨机场',
    targetId: 'profile:1',
    sourceIds: ['2'],
    preferences: [
      NodePreference(
        type: NodePreferenceType.expiry,
        direction: SortDirection.ascending,
      ),
      NodePreference(
        type: NodePreferenceType.remaining,
        direction: SortDirection.descending,
      ),
    ],
    selectionMode: NodeSelectionMode.loadBalance,
  );
  LocalPolicy proxy(
    String id,
    int priority, {
    PolicyMatch scope = const PolicyMatch(),
  }) => LocalPolicy(
    id: id,
    label: id,
    targetId: 'profile:1',
    priority: priority,
    scope: scope,
    choices: const [PolicyChoice(type: PolicyChoiceType.nodeSet, id: 'all')],
  );
  LocalPolicyDocument document(List<LocalPolicy> rules) => LocalPolicyDocument(
    moduleEnabled: true,
    policiesEnabled: true,
    policies: rules,
    nodeSets: const [set],
  );
  Map<String, Object?> base() => {
    ...a.raw,
    'mode': 'rule',
    'rules': ['DOMAIN-SUFFIX,original.example,DIRECT', 'MATCH,DIRECT'],
    'proxy-groups': [
      {
        'name': 'Original',
        'type': 'select',
        'proxies': ['日本 1x'],
      },
    ],
  };

  test('ordinary profile can use another airport without integration', () {
    final config = compiler
        .compile(
          document: document([proxy('p', 1)]),
          profileId: 1,
          baseConfig: base(),
          sources: [a, b],
        )
        .config;
    final wire = config['flclash-local-policy'] as Map;
    expect(wire['schemaVersion'], 3);
    expect((wire['sources'] as List).map((s) => s['id']), ['1', '2']);
    expect((wire['nodes'] as List).last['label'], '香港');
    expect((wire['policies'] as List).single['skipUnavailable'], isTrue);
    expect((wire['policies'] as List).single.containsKey('fallback'), isFalse);
    expect((config['proxies'] as List).length, 2);
    expect((config['proxy-groups'] as List).first['name'], 'Original');
    expect((config['rules'] as List).last, 'MATCH,DIRECT');
  });

  test('all traffic rules can be multiple and retain chosen positions', () {
    final first = proxy('first', 1);
    final middle = proxy(
      'domain',
      2,
      scope: const PolicyMatch(
        type: PolicyMatchType.domain,
        values: ['example.com'],
      ),
    );
    final last = proxy('last', 3);
    final result = compiler.compile(
      document: document([first, middle, last]),
      profileId: 1,
      baseConfig: base(),
      sources: [a, b],
    );
    expect((result.config['rules'] as List).take(3), [
      'MATCH,${first.groupName}',
      'DOMAIN,example.com,${middle.groupName}',
      'MATCH,${last.groupName}',
    ]);
    final updated = insertPolicy([
      first,
      middle,
      last,
    ], LocalPolicy.fromJson({...first.toJson(), 'label': 'changed'}));
    expect(orderedPolicies(updated).map((r) => r.id), [
      'first',
      'domain',
      'last',
    ]);
  });

  test('region app domain and IP clauses compose into native expressions', () {
    const app = r'^/Applications/Example\x28test\x29\x2c\+\.app/Contents/.*$';
    final match = PolicyMatch.fromJson(
      const PolicyMatch(
        type: PolicyMatchType.all,
        children: [
          PolicyMatch(type: PolicyMatchType.destinationRegion, values: ['!CN']),
          PolicyMatch(type: PolicyMatchType.processPathRegex, values: [app]),
          PolicyMatch(
            type: PolicyMatchType.any,
            children: [
              PolicyMatch(type: PolicyMatchType.ipCidr, values: ['192.0.2.1']),
              PolicyMatch(
                type: PolicyMatchType.ipCidr6,
                values: ['2001:db8::/32'],
              ),
            ],
          ),
        ],
      ).toJson(),
    );
    final result = compiler.compile(
      document: document([proxy('p', 1, scope: match)]),
      profileId: 1,
      baseConfig: base(),
      sources: [a, b],
    );
    expect(result.config['find-process-mode'], 'strict');
    final expression = (result.config['rules'] as List).first as String;
    expect(expression, contains('NOT,((GEOIP,CN))'));
    expect(expression, contains('PROCESS-PATH-REGEX,$app'));
    expect(expression, contains('IP-CIDR,192.0.2.1/32'));
    expect(expression, contains('IP-CIDR6,2001:db8::/32'));
    for (final value in [
      r'^/Applications/A(app)\.app/Contents/.*$',
      r'^/Applications/.*\.app/Contents/.*$',
      r'^/Applications/A\.app/Contents/.*$,DIRECT',
    ]) {
      expect(
        () => PolicyMatch.fromJson({
          'type': 'processPathRegex',
          'values': [value],
        }),
        throwsFormatException,
      );
    }
  });

  test(
    'explicit actions need no nodes and groups may have no current members',
    () {
      for (final action in [PolicyAction.direct, PolicyAction.reject]) {
        final rule = LocalPolicy.fromJson(
          LocalPolicy(
            id: 'action',
            label: 'action',
            targetId: 'profile:1',
            action: action,
          ).toJson(),
        );
        final result = compiler.compile(
          document: document([rule]),
          profileId: 1,
          baseConfig: base(),
          sources: [a],
        );
        expect(
          ((result.config['flclash-local-policy'] as Map)['policies'] as List)
              .single['action'],
          action.name,
        );
      }
      const empty = PolicySource(
        id: '2',
        label: 'Empty',
        raw: {'proxies': []},
      );
      final result = compiler.compile(
        document: document([proxy('p', 1)]),
        profileId: 1,
        baseConfig: base(),
        sources: [a, empty],
      );
      expect(
        ((result.config['flclash-local-policy'] as Map)['sources'] as List)
            .last['id'],
        '2',
      );
    },
  );

  test(
    'cross source references survive migration and protect source deletion',
    () async {
      final store = WorkbenchDatabase(NativeDatabase.memory());
      addTearDown(store.close);
      final service = PolicyProfileService(
        loader: PolicySourceLoader(store: store),
      );
      final value = LocalPolicyDocument.fromJson({
        ...document([proxy('p', 1)]).toJson(),
        'schemaVersion': 2,
      });
      expect(value.schemaVersion, 3);
      expect(value.referencesProfile(2), isTrue);
      final profiles = [
        for (final id in [1, 2, 3])
          Profile(id: id, autoUpdateDuration: const Duration(hours: 1)),
      ];
      expect(
        service
            .requiredProfiles(document: value, profiles: profiles, profileId: 1)
            .map((p) => p.id),
        [1, 2],
      );
    },
  );

  test('node preferences filters and overnight schedule preserve intent', () {
    final parsed = PolicyNodeSet.fromJson({
      ...set.toJson(),
      'nameIncludes': ['香港'],
      'nameExcludes': ['维护'],
      'excludedRegions': ['JP'],
      'schedule': {
        'windows': [
          {
            'weekdays': [1],
            'startMinute': 1320,
            'endMinute': 0,
          },
        ],
      },
    });
    expect(parsed.exclusion(compiler.extractNodes(b).single), isNull);
    expect(
      parsed.effectiveMultiplier(compiler.extractNodes(b).single.attributes),
      1,
    );
    expect(parsed.preferences.last.direction, SortDirection.descending);
    expect(parsed.schedule.windows.single.endMinute, 0);
    expect(
      () => PolicyWindow.fromJson({'startMinute': 0, 'endMinute': 0}),
      throwsFormatException,
    );
    expect(
      () => PolicyNodeSet.fromJson({
        ...set.toJson(),
        'preferences': [
          set.preferences.first.toJson(),
          set.preferences.first.toJson(),
        ],
      }),
      throwsFormatException,
    );
  });

  test(
    'a broken unselected profile and more than twenty saved profiles do not block referenced sources',
    () async {
      final store = WorkbenchDatabase(NativeDatabase.memory());
      addTearDown(store.close);
      final loader = PolicySourceLoader(
        store: store,
        profilePath: (id) async => '/profile/$id',
        readFile: (path) async => path == '/profile/22'
            ? 'proxies: [invalid'
            : 'proxies: [{name: Node, type: ss, server: "$path.example", port: 443}]',
      );
      final service = PolicyProfileService(loader: loader);
      final profiles = [
        for (var id = 1; id <= 22; id++)
          Profile(id: id, autoUpdateDuration: const Duration(hours: 1)),
      ];
      final value = document([proxy('p', 1)]);
      expect(
        (await service.nodesForTarget(
          document: value,
          profiles: profiles,
          targetId: 'profile:1',
        )).map((n) => n.sourceId),
        ['1', '2'],
      );
      expect(
        (await service.nodesForTarget(
          document: value,
          profiles: profiles,
          targetId: 'profile:1',
          includeAllSources: true,
        )).length,
        21,
      );
      final broken = LocalPolicyDocument.fromJson({
        ...value.toJson(),
        'nodeSets': [
          {
            ...set.toJson(),
            'sourceIds': ['22'],
          },
        ],
      });
      await expectLater(
        service.nodesForTarget(
          document: broken,
          profiles: profiles,
          targetId: 'profile:1',
        ),
        throwsA(isA<FormatException>()),
      );
    },
  );
}
