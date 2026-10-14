import 'dart:io';

import 'package:fl_clash/common/yaml.dart' as writer;
import 'package:fl_clash/policy/compiler.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/policy/sources.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('generated schema three config matches the strict Core fixture', () {
    const match = PolicyMatch(
      type: PolicyMatchType.domainSuffix,
      values: ['example.test'],
    );
    const document = LocalPolicyDocument(
      schemaVersion: 4,
      moduleEnabled: true,
      integrationEnabled: true,
      policiesEnabled: true,
      budgetsEnabled: true,
      activeIntegrationId: localPolicyProfileId,
      integrations: [
        SubscriptionIntegration(
          id: localPolicyProfileId,
          label: 'Local',
          sourceProfileIds: [1, 2],
        ),
      ],
      nodeSets: [
        PolicyNodeSet(
          id: 'pool',
          label: 'Pool',
          targetId: localPolicyTargetId,
          sourceIds: ['1', '2'],
          selectionMode: NodeSelectionMode.loadBalance,
          balanceStrategy: NodeBalanceStrategy.roundRobin,
          preferences: [
            NodePreference(
              type: NodePreferenceType.expiry,
              direction: SortDirection.ascending,
            ),
            NodePreference(
              type: NodePreferenceType.latency,
              direction: SortDirection.ascending,
            ),
          ],
          schedule: PolicySchedule(
            windows: [
              PolicyWindow(
                weekdays: [1, 2, 3, 4, 5],
                startMinute: 1320,
                endMinute: 60,
              ),
            ],
          ),
        ),
      ],
      policies: [
        LocalPolicy(
          id: 'second',
          label: 'Second',
          targetId: localPolicyTargetId,
          priority: 20,
          scope: match,
          action: PolicyAction.direct,
        ),
        LocalPolicy(
          id: 'first',
          label: 'First',
          targetId: localPolicyTargetId,
          priority: 10,
          scope: match,
          choices: [PolicyChoice(type: PolicyChoiceType.nodeSet, id: 'pool')],
        ),
        LocalPolicy(
          id: 'last',
          label: 'Last',
          targetId: localPolicyTargetId,
          priority: 30,
          action: PolicyAction.reject,
        ),
      ],
      budgets: [SourceBudget(sourceId: '1', limitBytes: 1073741824)],
    );
    final sources = [
      for (final id in ['1', '2'])
        PolicySource(
          id: id,
          label: 'Source $id',
          raw: {
            'proxies': [
              {
                'name': 'Japan $id 1x',
                'type': 'ss',
                'server': '127.0.0.1',
                'port': int.parse(id),
                'cipher': 'aes-128-gcm',
                'password': 'fixture-$id',
              },
            ],
          },
        ),
    ];
    final generated = const LocalPolicyCompiler().compile(
      document: document,
      profileId: null,
      baseConfig: {'mode': 'rule'},
      sources: sources,
    );
    final ordered = orderedPolicies(document.policies);
    expect(generated.config['rules'], [
      'DOMAIN-SUFFIX,example.test,${ordered[0].groupName}',
      'DOMAIN-SUFFIX,example.test,${ordered[1].groupName}',
      'MATCH,${ordered[2].groupName}',
      'MATCH,REJECT',
    ]);
    expect(document.policies.first.priority, 20);
    final file = File('core/testdata/local_policy_v3_compiled.yaml');
    if (const bool.fromEnvironment('UPDATE_POLICY_WIRE_FIXTURE')) {
      file.writeAsStringSync(writer.yaml.encode(generated.config));
    }
    expect(
      normalizePolicyYaml(loadYaml(file.readAsStringSync())),
      generated.config,
    );
  });
}
