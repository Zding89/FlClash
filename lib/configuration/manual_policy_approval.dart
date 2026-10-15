import 'changes.dart';

bool isPlainManualPolicyChange(ConfigurationProposal proposal) {
  final validation = proposal.validation;
  final finalDifferences = validation['finalConfigDifferences'];
  return proposal.differences.isNotEmpty &&
      proposal.differences.every(
        (difference) =>
            difference.path == 'policies' ||
            difference.path.startsWith('policies.'),
      ) &&
      validation['executionOnly'] != true &&
      validation['requiresScriptExecutionApproval'] != true &&
      (finalDifferences == null ||
          finalDifferences is List && finalDifferences.isEmpty);
}
