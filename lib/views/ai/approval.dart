import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/policy/source_change.dart';
import 'package:fl_clash/views/policy/source_change_summary.dart';
import 'package:flutter/material.dart';

Object? _redact(Object? value) {
  if (value is Map) {
    return value.map(
      (key, entry) => MapEntry(
        '$key',
        RegExp(
              r'(password|secret|token|credential|api.?key|authorization)',
              caseSensitive: false,
            ).hasMatch('$key')
            ? '••••'
            : _redact(entry),
      ),
    );
  }
  if (value is List) return value.map(_redact).toList();
  if (value is String) {
    final uri = Uri.tryParse(value);
    if (uri != null && ['https', 'http'].contains(uri.scheme)) {
      return uri
          .replace(
            userInfo: '',
            queryParameters: uri.hasQuery
                ? {
                    for (final entry in uri.queryParameters.entries)
                      entry.key:
                          RegExp(
                            r'(key|token|secret|password|auth)',
                            caseSensitive: false,
                          ).hasMatch(entry.key)
                          ? '••••'
                          : entry.value,
                  }
                : null,
          )
          .toString();
    }
  }
  return value;
}

String aiDisplayValue(Object? value) {
  final encoded = const JsonEncoder.withIndent('  ').convert(_redact(value));
  return encoded.length > 8192 ? '${encoded.substring(0, 8192)}…' : encoded;
}

Future<bool> showAiConfigurationApproval(
  BuildContext context,
  ConfigurationProposal proposal,
) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AiConfigurationApprovalDialog(proposal: proposal),
    ) ??
    false;

class AiConfigurationApprovalDialog extends StatelessWidget {
  const AiConfigurationApprovalDialog({super.key, required this.proposal});

  final ConfigurationProposal proposal;

  @override
  Widget build(BuildContext context) {
    final strings = context.appLocalizations;
    final colors = Theme.of(context).colorScheme;
    final executionOnly =
        proposal.validation['executionOnly'] == true ||
        (proposal.validation['requiresScriptExecutionApproval'] == true &&
            proposal.validation['finalConfigValidated'] != true);
    final rawFinal = proposal.validation['finalConfigDifferences'];
    final finalDifferences = <ConfigurationDifference>[
      if (rawFinal is List)
        for (final entry in rawFinal)
          if (entry is Map && entry['path'] is String)
            ConfigurationDifference(
              path: entry['path'] as String,
              before: entry['before'],
              after: entry['after'],
            ),
    ];
    final sourceChange =
        !executionOnly &&
            finalDifferences.isEmpty &&
            proposal.differences.every(
              (difference) =>
                  difference.path == 'policies.revision' ||
                  difference.path == 'policies.integrations' ||
                  difference.path.startsWith('policies.integrations.'),
            )
        ? LocalSourceChangeSummary.tryParse(
            proposal.validation[localSourceChangeValidationKey],
          )
        : null;
    return AlertDialog(
      title: Text(
        sourceChange != null
            ? strings.policySourceChangeTitle
            : executionOnly
            ? strings.confirm
            : strings.aiApprovalTitle,
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sourceChange == null) SelectableText(proposal.summary),
              if (executionOnly) ...[
                const SizedBox(height: 12),
                Text(
                  strings.aiScriptExecutionOnly,
                  style: TextStyle(color: colors.error),
                ),
              ],
              if (proposal.highRisk && sourceChange == null) ...[
                const SizedBox(height: 12),
                Text(strings.aiHighRisk, style: TextStyle(color: colors.error)),
              ],
              if (sourceChange == null) const SizedBox(height: 16),
              if (sourceChange != null)
                LocalSourceChangeSummaryView(summary: sourceChange),
              if (sourceChange == null && proposal.differences.isEmpty)
                Text(strings.aiNoDifferences),
              if (sourceChange == null)
                for (final difference in proposal.differences) ...[
                  Text(
                    difference.path,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    strings.aiBefore,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  SelectableText(aiDisplayValue(difference.before)),
                  const SizedBox(height: 6),
                  Text(
                    strings.aiAfter,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  SelectableText(aiDisplayValue(difference.after)),
                  const SizedBox(height: 16),
                ],
              if (finalDifferences.isNotEmpty) ...[
                Text(
                  strings.aiFinalConfigDifferences,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                for (final difference in finalDifferences) ...[
                  Text(
                    difference.path,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(strings.aiBefore),
                  SelectableText(aiDisplayValue(difference.before)),
                  const SizedBox(height: 6),
                  Text(strings.aiAfter),
                  SelectableText(aiDisplayValue(difference.after)),
                  const SizedBox(height: 16),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(strings.aiReject),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            executionOnly
                ? strings.aiApproveScriptExecution
                : strings.aiApprove,
          ),
        ),
      ],
    );
  }
}
