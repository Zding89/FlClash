import 'dart:convert';

import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/database/workbench_database.dart';

ConfigurationProposal aiStoredProposal(WorkbenchChange row) {
  final before = jsonDecode(row.beforePayload);
  final after = jsonDecode(row.afterPayload);
  return ConfigurationProposal(
    id: row.id,
    summary: row.summary,
    highRisk: row.highRisk,
    expiresAt: row.expiresAt,
    differences: configurationDifferences(before, after),
    validation: {
      'reviewStatus': aiStoredChangeStatus(row),
      'reviewCategory': row.category,
      if (row.category == 'policies' && before is Map && after is Map)
        'localPolicyDocuments': {
          'before': before['policies'],
          'after': after['policies'],
        },
    },
  );
}

String aiStoredChangeStatus(WorkbenchChange row) =>
    row.status == 'draft' &&
        row.expiresAt <= DateTime.now().millisecondsSinceEpoch
    ? 'expired'
    : row.status == 'applied' && row.category == 'policies'
    ? 'saved'
    : row.status;

String? aiCompletionStatus(Map<String, Object?>? result) {
  if (result == null) return null;
  final nested = result['result'];
  final receipt =
      result['completion'] ?? (nested is Map ? nested['completion'] : null);
  if (receipt is! Map ||
      receipt['version'] != 1 ||
      receipt['scope'] != 'local_policy' ||
      receipt['persisted'] != true) {
    return null;
  }
  if (receipt['currentStateMatches'] != true) return 'saved_unverified';
  final activation = receipt['activation'];
  if (activation is! Map) return 'saved_unverified';
  if (activation['effective'] == true &&
      activation['required'] == true &&
      activation['loaded'] == true &&
      activation['running'] == true &&
      activation['targetId'] != null &&
      activation['targetId'] == activation['loadedTargetId'] &&
      activation['documentRevision'] is int &&
      activation['documentRevision'] == activation['loadedDocumentRevision']) {
    return 'effective';
  }
  return const {
        'integration_disabled',
        'network_stopped',
      }.contains(activation['reason'])
      ? 'saved_inactive'
      : 'saved_unverified';
}
