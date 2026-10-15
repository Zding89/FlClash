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
    : row.status;
