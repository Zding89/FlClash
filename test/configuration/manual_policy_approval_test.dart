import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/configuration/manual_policy_approval.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ConfigurationProposal proposal({
    String path = 'policies.nodeSets',
    Map<String, Object?> validation = const {},
  }) => ConfigurationProposal(
    id: 'manual-form',
    summary: 'Local rules',
    highRisk: true,
    expiresAt: 0,
    differences: [
      ConfigurationDifference(path: path, before: [], after: [1]),
    ],
    validation: validation,
  );
  test(
    'explicit local policy edits do not need a second configuration dialog',
    () {
      for (final path in [
        'policies',
        'policies.nodeSets',
        'policies.nodeAttributes.node',
        'policies.policies',
        'policies.integrations',
      ]) {
        expect(isPlainManualPolicyChange(proposal(path: path)), isTrue);
      }
    },
  );
  test('script execution and additional runtime changes still need review', () {
    for (final validation in <Map<String, Object?>>[
      {'executionOnly': true},
      {'requiresScriptExecutionApproval': true},
      {
        'finalConfigDifferences': [
          {'path': 'dns'},
        ],
      },
      {'finalConfigDifferences': 'invalid'},
    ]) {
      expect(
        isPlainManualPolicyChange(proposal(validation: validation)),
        isFalse,
      );
    }
    expect(isPlainManualPolicyChange(proposal(path: 'config.proxy')), isFalse);
    expect(
      isPlainManualPolicyChange(proposal(path: 'resources.profile')),
      isFalse,
    );
  });
}
