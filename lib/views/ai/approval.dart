import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/policy/source_change.dart';
import 'package:flutter/material.dart';

import 'review.dart';

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

ConfigurationApproval aiAfterReviewApproval(
  ConfigurationProposal reviewed, {
  required ConfigurationApproval onReview,
  bool Function()? isCurrent,
}) {
  var consumed = false;
  Map<String, Object?> snapshot(ConfigurationProposal proposal) {
    final validation = Map<String, Object?>.from(proposal.validation)
      ..remove('reviewStatus')
      ..remove('reviewCategory');
    return {...proposal.toJson(), 'validation': validation};
  }

  final original = snapshot(reviewed);
  return (proposal) async {
    if (isCurrent?.call() == false) return false;
    final same =
        !consumed &&
        const DeepCollectionEquality().equals(original, snapshot(proposal));
    consumed = true;
    final approved = same || await onReview(proposal);
    return approved && isCurrent?.call() != false;
  };
}

Future<bool> showAiConfigurationApproval(
  BuildContext context,
  ConfigurationProposal proposal, {
  bool readOnly = false,
  Future<void>? cancelled,
}) async {
  final route = DialogRoute<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) =>
        AiConfigurationApprovalDialog(proposal: proposal, readOnly: readOnly),
  );
  unawaited(
    cancelled?.then((_) {
      if (route.isActive) route.navigator?.removeRoute(route, false);
    }),
  );
  return await Navigator.of(context).push(route) ?? false;
}

class AiConfigurationApprovalDialog extends StatelessWidget {
  const AiConfigurationApprovalDialog({
    super.key,
    required this.proposal,
    this.readOnly = false,
  });

  final ConfigurationProposal proposal;
  final bool readOnly;

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
    final sourceOnly =
        !executionOnly &&
        finalDifferences.isEmpty &&
        proposal.differences.every(
          (change) =>
              change.path == 'policies.revision' ||
              change.path == 'policies.integrations' ||
              change.path.startsWith('policies.integrations.'),
        );
    final sourceChange = sourceOnly
        ? LocalSourceChangeSummary.tryParse(
            proposal.validation[localSourceChangeValidationKey],
          )
        : null;
    final metadata = proposal.validation['agentReview'];
    final command = metadata is Map ? metadata['command'] : null;
    final fetching = const {
      'profile_propose',
      'profiles_refresh_all',
    }.contains(command);
    final warn =
        proposal.highRisk &&
        (metadata is! Map ||
            const {
              'backup_create',
              'backup_restore',
              'webdav_upload',
              'webdav_restore',
              'maintenance_clear_data',
              'usage_clear',
              'connection_close',
              'developer_test',
            }.contains(command) ||
            command is String && command.endsWith('_export'));
    return AlertDialog(
      title: Text(
        sourceChange != null
            ? strings.policySourceChangeTitle
            : aiReviewTitle(strings, proposal),
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (executionOnly) ...[
                Text(
                  strings.aiScriptExecutionOnly,
                  style: TextStyle(color: colors.error),
                ),
                const SizedBox(height: 12),
              ],
              AiProposalReviewBody(proposal: proposal),
              if (warn && sourceChange == null) ...[
                const SizedBox(height: 12),
                Text(strings.aiHighRisk, style: TextStyle(color: colors.error)),
              ],
              if (finalDifferences.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  strings.aiFinalConfigDifferences,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                AiReviewRowsView(
                  rows: aiReviewRows(
                    strings,
                    ConfigurationProposal(
                      id: proposal.id,
                      summary: proposal.summary,
                      highRisk: proposal.highRisk,
                      expiresAt: proposal.expiresAt,
                      differences: finalDifferences,
                      validation: const {},
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(readOnly ? strings.aiReviewClose : strings.cancel),
        ),
        if (!readOnly)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              executionOnly
                  ? strings.aiApproveScriptExecution
                  : fetching
                  ? '${strings.confirm} · ${strings.download}'
                  : strings.aiApprove,
            ),
          ),
      ],
    );
  }
}
