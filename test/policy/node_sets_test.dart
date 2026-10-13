import 'package:fl_clash/policy/compiler.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const compiler = LocalPolicyCompiler();
  const source = PolicySource(
    id: '1',
    label: 'source',
    raw: {
      'proxies': [
        {'name': '日本 0.5x', 'type': 'ss', 'server': 'a', 'port': 443},
        {'name': '日本 unknown', 'type': 'ss', 'server': 'b', 'port': 443},
        {'name': '香港 0.2x', 'type': 'ss', 'server': 'c', 'port': 443},
      ],
    },
  );
  test(
    'unknown one is local to the set, retains basis and region exclusion',
    () {
      final nodes = compiler.extractNodes(source);
      const set = PolicyNodeSet(
        id: 'jp',
        label: 'jp',
        targetId: 'integration:pool',
        sourceIds: ['1'],
        regions: ['JP'],
        maxMultiplier: 1,
        unknownMultiplier: UnknownMultiplier.assumeOne,
      );
      expect(nodes.where((n) => set.exclusion(n) == null).length, 2);
      expect(nodes[1].attributes.multiplier, isNull);
      expect(nodes[1].attributes.multiplierBasis, NodeAttributeBasis.unknown);
      expect(set.effectiveMultiplier(nodes[1].attributes), 1);
      final strict = PolicyNodeSet.fromJson({
        ...set.toJson(),
        'unknownMultiplier': 'exclude',
      });
      expect(nodes.where((n) => strict.exclusion(n) == null).length, 1);
    },
  );
  test('attribute declaration and rename preserve endpoint identity', () {
    final before = compiler.extractNodes(source).first;
    final changed = PolicySource(
      id: '1',
      label: 'source',
      raw: {
        'proxies': [
          {
            ...before.raw,
            'name': 'renamed',
            'flclash-region': 'US',
            'flclash-multiplier': 2,
          },
        ],
      },
    );
    final node = compiler.extractNodes(changed).single;
    expect(node.id, before.id);
    expect(node.attributes.regionBasis, NodeAttributeBasis.subscription);
    expect(node.attributes.multiplier, 2);
  });
  test('schema one migration preserves switches and unknown rule origin', () {
    final document = LocalPolicyDocument.fromJson({
      'schemaVersion': 1,
      'policiesEnabled': true,
      'policies': [
        {
          'id': 'p',
          'label': 'p',
          'targetId': 'profile:1',
          'candidateNodeIds': ['a'],
        },
      ],
    });
    expect(document.schemaVersion, 2);
    expect(document.moduleEnabled, isTrue);
    expect(document.integrationEnabled, isFalse);
    expect(document.policies.single.origin, PolicyOrigin.unknown);
  });
  test(
    'mixed choices persist filtering intent and scope restricted to target',
    () {
      const set = PolicyNodeSet(
        id: 'jp',
        label: 'jp',
        targetId: 'integration:pool',
        sourceIds: ['1'],
        regions: ['JP'],
      );
      final document = LocalPolicyDocument(
        integrationEnabled: true,
        policiesEnabled: true,
        activeIntegrationId: 'pool',
        integrations: const [
          SubscriptionIntegration(
            id: 'pool',
            label: 'pool',
            sourceProfileIds: [1],
          ),
        ],
        nodeSets: const [set],
        policies: [
          LocalPolicy(
            id: 'p',
            label: 'p',
            targetId: 'integration:pool',
            choices: [
              const PolicyChoice(type: PolicyChoiceType.nodeSet, id: 'jp'),
              PolicyChoice(
                type: PolicyChoiceType.node,
                id: compiler.extractNodes(source).last.id,
              ),
            ],
          ),
        ],
      );
      final compiled = compiler.compile(
        document: document,
        profileId: null,
        baseConfig: {'mode': 'rule'},
        sources: [source],
      );
      final core = compiled.config['flclash-local-policy'] as Map;
      expect(core['schemaVersion'], 2);
      expect(
        (core['policies'] as List).single['choices'],
        document.policies.single.toJson()['choices'],
      );
      expect((core['nodeSets'] as List).single['regions'], ['JP']);
      final outside = LocalPolicyDocument.fromJson({
        ...document.toJson(),
        'nodeSets': [
          {
            ...set.toJson(),
            'sourceIds': ['2'],
          },
        ],
      });
      expect(
        () => compiler.compile(
          document: outside,
          profileId: null,
          baseConfig: {'mode': 'rule'},
          sources: [source],
        ),
        throwsFormatException,
      );
    },
  );
  test('manual insertion respects edited order and last remaining traffic', () {
    LocalPolicy rule(
      String id,
      int priority, {
      PolicyOrigin origin = PolicyOrigin.manual,
      PolicyMatchType type = PolicyMatchType.domain,
    }) => LocalPolicy(
      id: id,
      label: id,
      targetId: 'profile:1',
      priority: priority,
      candidateNodeIds: const ['a'],
      origin: origin,
      scope: PolicyMatch(
        type: type,
        values: type == PolicyMatchType.global ? const [] : [id],
      ),
    );
    final result = insertPolicy([
      rule('old', 1),
      rule('ai', 2, origin: PolicyOrigin.ai),
      rule('rest', 3, type: PolicyMatchType.global),
    ], rule('new', 100));
    expect(result.map((r) => r.id), ['old', 'new', 'ai', 'rest']);
    expect(result.map((r) => r.priority), [1, 2, 3, 4]);
  });
  test('probe presets reject credentials and stale validity bounds', () {
    expect(
      () => PolicyProbe.fromJson({
        ...const PolicyProbe().toJson(),
        'url': 'https://user:secret@example.com',
      }),
      throwsFormatException,
    );
    expect(
      () => PolicyProbe.fromJson({
        ...const PolicyProbe().toJson(),
        'method': 'POST',
      }),
      throwsFormatException,
    );
    expect(
      () => PolicyProbe.fromJson({
        ...const PolicyProbe().toJson(),
        'validitySeconds': 5,
      }),
      throwsFormatException,
    );
  });
}
