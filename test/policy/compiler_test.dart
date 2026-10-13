import 'package:fl_clash/policy/compiler.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const compiler = LocalPolicyCompiler();
  PolicySource source(String id, String server, {String name = 'same'}) =>
      PolicySource(
        id: id,
        label: 'source $id',
        raw: {
          'proxies': [
            {
              'name': name,
              'type': 'ss',
              'server': server,
              'port': 443,
              'cipher': 'aes-128-gcm',
              'password': 'test-password',
            },
          ],
        },
      );
  final a = source('1', 'a.example');
  final b = source('2', 'b.example');
  final c = source('3', 'c.example');
  final a1 = compiler.extractNodes(a).single;
  final b2 = compiler.extractNodes(b).single;
  const integration = SubscriptionIntegration(
    id: 'pool',
    label: 'pool',
    sourceProfileIds: [1, 2, 3],
  );
  final policy = LocalPolicy(
    id: 'strict',
    label: 'strict',
    targetId: 'integration:pool',
    candidateNodeIds: [a1.id, b2.id],
    scope: const PolicyMatch(
      type: PolicyMatchType.domainSuffix,
      values: ['example.com'],
    ),
  );
  LocalPolicyDocument document({bool budgets = false}) => LocalPolicyDocument(
    integrationEnabled: true,
    activeIntegrationId: 'pool',
    integrations: [integration],
    policiesEnabled: true,
    policies: [policy],
    budgetsEnabled: budgets,
    budgets: const [SourceBudget(sourceId: '1', limitBytes: 100)],
  );
  Map<String, Object?> base() => {
    'mode': 'rule',
    'dns': {
      'nameserver': ['local'],
    },
    'rules': ['MATCH,DIRECT'],
    'proxies': [],
    'proxy-groups': [],
  };
  test(
    'identity survives rename and separates identical names in different sources',
    () {
      expect(
        compiler
            .extractNodes(source('1', 'a.example', name: 'renamed'))
            .single
            .id,
        a1.id,
      );
      expect(a1.id, isNot(b2.id));
      expect(
        compiler.extractNodes(source('1', 'new.example')).single.id,
        isNot(a1.id),
      );
    },
  );
  test(
    'strict ordered core candidates never include a faster unrelated node',
    () {
      final result = compiler.compile(
        document: document(),
        profileId: 1,
        baseConfig: base(),
        sources: [a, b, c],
      );
      final extension = result.config['flclash-local-policy'] as Map;
      final definitions = extension['policies'] as List;
      expect((definitions.single as Map)['candidateNodeIds'], [a1.id, b2.id]);
      expect(
        (result.config['rules'] as List).first,
        contains('DOMAIN-SUFFIX,example.com'),
      );
      expect((result.config['proxies'] as List).length, 3);
    },
  );
  test(
    'integration retains local DNS and imports no upstream DNS or scripts',
    () {
      final malicious = PolicySource(
        id: '1',
        label: 'A',
        raw: {
          ...a.raw,
          'dns': {
            'nameserver': ['untrusted'],
          },
          'script': {'code': 'side effect'},
          'rules': ['MATCH,DIRECT'],
        },
      );
      final result = compiler.compile(
        document: document(),
        profileId: 1,
        baseConfig: base(),
        sources: [malicious, b, c],
      );
      expect(result.config['dns'], {
        'nameserver': ['local'],
      });
      expect(result.config.containsKey('script'), false);
    },
  );
  test(
    'missing nodes fail drafts and become explicit invalid runtime references',
    () {
      expect(
        () => compiler.compile(
          document: document(),
          profileId: 1,
          baseConfig: base(),
          sources: [source('1', 'new.example'), b, c],
        ),
        throwsFormatException,
      );
      final result = compiler.compile(
        document: document(),
        profileId: 1,
        baseConfig: base(),
        sources: [source('1', 'new.example'), b, c],
        enforceCandidateReferences: false,
      );
      expect(result.warnings.any((value) => value.contains('missing')), true);
      expect(
        ((result.config['flclash-local-policy'] as Map)['policies'] as List)
            .single['candidateNodeIds'],
        [a1.id, b2.id],
      );
    },
  );
  test(
    'nested dialers are rejected instead of silently selecting another source',
    () {
      expect(
        () => compiler.extractNodes(
          PolicySource(
            id: '1',
            label: 'A',
            raw: {
              'proxies': [
                {...a1.raw, 'dialer-proxy': 'B'},
              ],
            },
          ),
        ),
        throwsFormatException,
      );
    },
  );
  test('duplicate endpoint labels all resolve to the same guarded alias', () {
    final duplicate = PolicySource(
      id: '1',
      label: 'A',
      raw: {
        'proxies': [
          a1.raw,
          {...a1.raw, 'name': 'second'},
        ],
      },
    );
    final result = compiler.compile(
      document: const LocalPolicyDocument(
        budgetsEnabled: true,
        budgets: [SourceBudget(sourceId: '1', limitBytes: 100)],
      ),
      profileId: 1,
      baseConfig: {
        ...duplicate.raw,
        'mode': 'rule',
        'rules': ['MATCH,second'],
        'proxy-groups': [
          {
            'name': 'pool',
            'type': 'select',
            'proxies': ['same', 'second'],
          },
        ],
      },
      sources: [duplicate],
    );
    expect((result.config['proxies'] as List).length, 1);
    expect((result.config['proxy-groups'] as List).first['proxies'], [
      compiler.extractNodes(duplicate).single.proxyName,
    ]);
    expect(
      (result.config['rules'] as List).single,
      contains(compiler.extractNodes(duplicate).single.proxyName),
    );
  });
  test(
    'script changes to node endpoints fail instead of being silently overwritten',
    () {
      expect(
        () => compiler.compile(
          document: const LocalPolicyDocument(
            budgetsEnabled: true,
            budgets: [SourceBudget(sourceId: '1', limitBytes: 100)],
          ),
          profileId: 1,
          baseConfig: {
            'mode': 'rule',
            'rules': ['MATCH,same'],
            'proxies': [
              {...a1.raw, 'server': 'script.example'},
            ],
          },
          sources: [a],
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'generated aliases respect byte limits even with long Unicode labels',
    () {
      final node = LocalNode(
        id: a1.id,
        sourceId: '1',
        label: '节点' * 200,
        sourceLabel: '公司' * 200,
        protocol: 'ss',
        raw: a1.raw,
      );
      expect(node.proxyName.runes.length, lessThan(100));
    },
  );
  test('subscription IDs serialize without losing Snowflake precision', () {
    const id = 367048944821309440;
    const integration = SubscriptionIntegration(
      id: 'large',
      label: 'large',
      sourceProfileIds: [id],
    );
    expect(integration.toJson()['sourceProfileIds'], ['$id']);
    expect(
      SubscriptionIntegration.fromJson(integration.toJson()).sourceProfileIds,
      [id],
    );
  });
  test('budget only configurations support global mode and map every leaf', () {
    final result = compiler.compile(
      document: const LocalPolicyDocument(
        budgetsEnabled: true,
        budgets: [SourceBudget(sourceId: '1', limitBytes: 100)],
      ),
      profileId: 1,
      baseConfig: {
        ...a.raw,
        'mode': 'global',
        'rules': ['MATCH,same'],
        'proxy-groups': [
          {
            'name': 'pool',
            'type': 'select',
            'proxies': ['same'],
          },
        ],
      },
      sources: [a],
    );
    final nodes =
        (result.config['flclash-local-policy'] as Map)['nodes'] as List;
    expect(nodes.length, 1);
    expect((nodes.single as Map)['sourceId'], '1');
    expect((result.config['proxy-groups'] as List).first['proxies'], [
      a1.proxyName,
    ]);
  });

  test('include-all expands only original leaves and provider members', () {
    final definition = {
      'remote': {
        'type': 'inline',
        'payload': [b2.raw],
      },
    };
    final source = PolicySource(
      id: '1',
      label: 'A',
      raw: {
        'proxies': [a1.raw, b2.raw],
        'proxy-providers': definition,
        'flclash-inline-node-ids': [a1.id],
        'flclash-provider-members': {
          'remote': ['same-provider'],
        },
      },
    );
    final renamed = PolicySource(
      id: '1',
      label: 'A',
      raw: {
        ...source.raw,
        'proxies': [
          a1.raw,
          {...b2.raw, 'name': 'same-provider'},
        ],
        'proxy-providers': {
          'remote': {
            'type': 'inline',
            'payload': [
              {...b2.raw, 'name': 'same-provider'},
            ],
          },
        },
      },
    );
    final result = compiler.compile(
      document: const LocalPolicyDocument(
        budgetsEnabled: true,
        budgets: [SourceBudget(sourceId: '1', limitBytes: 100)],
      ),
      profileId: 1,
      baseConfig: {
        'proxies': [a1.raw],
        'proxy-providers': renamed.raw['proxy-providers'],
        'proxy-groups': [
          {'name': 'all', 'type': 'select', 'include-all': true},
        ],
        'rules': ['MATCH,all'],
      },
      sources: [renamed],
    );
    final group = (result.config['proxy-groups'] as List).single as Map;
    expect(
      group['proxies'],
      compiler.extractNodes(renamed).map((node) => node.proxyName).toList(),
    );
    expect(group.containsKey('include-all'), false);
    expect(group.containsKey('include-all-providers'), false);
    expect(result.config.containsKey('proxy-providers'), false);
    expect(
      (result.config['flclash-selection-aliases'] as Map)['same'],
      compiler.extractNodes(renamed).first.proxyName,
    );
  });

  test(
    'anchored group filters are rejected before aliasing can change meaning',
    () {
      expect(
        () => compiler.compile(
          document: const LocalPolicyDocument(
            budgetsEnabled: true,
            budgets: [SourceBudget(sourceId: '1', limitBytes: 100)],
          ),
          profileId: 1,
          baseConfig: {
            ...a.raw,
            'proxy-groups': [
              {
                'name': 'pool',
                'type': 'select',
                'include-all': true,
                'filter': '^same',
              },
            ],
          },
          sources: [a],
        ),
        throwsA(isA<PolicySourceException>()),
      );
    },
  );
}
