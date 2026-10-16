import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:flutter/material.dart';

import 'change_record.dart';
import 'errors.dart';
import 'review.dart';

ConfigurationProposal? aiResultProposal(Map<String, Object?> result) {
  final nested = result['result'];
  final raw = result['proposal'] ?? (nested is Map ? nested['proposal'] : null);
  if (raw is! Map ||
      raw['id'] is! String ||
      raw['summary'] is! String ||
      raw['expiresAt'] is! int) {
    return null;
  }
  final differences = raw['differences'];
  final validation = raw['validation'];
  return ConfigurationProposal(
    id: raw['id'] as String,
    summary: raw['summary'] as String,
    highRisk: raw['highRisk'] == true,
    expiresAt: raw['expiresAt'] as int,
    differences: [
      if (differences is List)
        for (final difference in differences)
          if (difference is Map && difference['path'] is String)
            ConfigurationDifference(
              path: difference['path'] as String,
              before: difference['before'],
              after: difference['after'],
            ),
    ],
    validation: validation is Map
        ? validation.map((key, value) => MapEntry('$key', value))
        : const {},
  );
}

List<ConfigurationProposal> aiResultProposals(Map<String, Object?> result) {
  final proposals = <String, ConfigurationProposal>{};
  void collect(Object? raw) {
    if (raw is! Map) return;
    final value = Map<String, Object?>.from(raw);
    final proposal =
        aiResultProposal(value) ?? aiResultProposal({'proposal': value});
    if (proposal != null) proposals[proposal.id] = proposal;
    collect(value['result']);
    final batch = value['proposals'];
    if (batch is List) {
      for (final item in batch) {
        collect(item);
      }
    }
  }

  collect(result);
  return proposals.values.toList();
}

class AiCapabilityPanel extends StatelessWidget {
  const AiCapabilityPanel({super.key, required this.catalog});
  final List<Map<String, Object?>> catalog;

  String _label(BuildContext context, String domain) {
    final strings = context.appLocalizations;
    return switch (domain) {
      'profiles' => strings.profiles,
      'policies' || 'rules' => strings.localPolicies,
      'lifecycle' || 'connections' || 'proxies' => strings.connections,
      'logs' => strings.logs,
      'backup' => strings.backupAndRestore,
      'scripts' => strings.script,
      'usage' => strings.usage,
      'network' => strings.network,
      _ => strings.settings,
    };
  }

  IconData _icon(String domain) => switch (domain) {
    'profiles' => Icons.description_outlined,
    'policies' || 'rules' => Icons.shield_outlined,
    'lifecycle' || 'connections' => Icons.hub_outlined,
    'logs' => Icons.receipt_long_outlined,
    'backup' => Icons.cloud_outlined,
    'usage' => Icons.bar_chart,
    _ => Icons.settings_outlined,
  };

  String? _action(BuildContext context, String command) {
    final strings = context.appLocalizations;
    return switch (command) {
      'proxy_select' => '${strings.proxies} · ${strings.edit}',
      'proxy_test' || 'policy_nodes_check' => strings.delayTest,
      'runtime_read' || 'network_status' => strings.coreStatus,
      'connection_set' =>
        '${strings.connections} · ${strings.start}/${strings.stop}',
      'core_restart' => strings.restart,
      'proxies_read' => '${strings.view} · ${strings.proxies}',
      'connections_read' => '${strings.view} · ${strings.connections}',
      'logs_read' => '${strings.view} · ${strings.logs}',
      'profile_select' => '${strings.profiles} · ${strings.edit}',
      'profiles_refresh_all' => '${strings.profiles} · ${strings.update}',
      'profile_file_propose' ||
      'profile_qr_import' => '${strings.import} · ${strings.profiles}',
      'profile_propose' =>
        '${strings.profiles} · ${strings.add}/${strings.edit}/${strings.delete}',
      'rule_propose' =>
        '${strings.rule} · ${strings.add}/${strings.edit}/${strings.delete}',
      'policies_propose' => '${strings.edit} · ${strings.localPolicies}',
      'policies_simulate' => strings.aiCheckResult,
      'settings_propose' => '${strings.edit} · ${strings.settings}',
      'usage_history' || 'usage_read' => '${strings.view} · ${strings.usage}',
      'backup_create' || 'backup_restore' => strings.backupAndRestore,
      'webdav_upload' => 'WebDAV · ${strings.upload}',
      'webdav_restore' => 'WebDAV · ${strings.download}',
      'script_patch' ||
      'script_propose' => '${strings.edit} · ${strings.script}',
      'update_check' => strings.checkUpdate,
      'agent_settings_read' => strings.aiSettingsTitle,
      _ => null,
    };
  }

  Set<String> _additionalActions(
    BuildContext context,
    List<Map<String, Object?>> capabilities,
  ) {
    final strings = context.appLocalizations;
    return capabilities
        .where(
          (entry) =>
              _action(context, '${entry['command']}') == null &&
              !const {
                'capabilities',
                'capabilities_list',
                'operation_query',
                'capability_confirm',
              }.contains(entry['command']),
        )
        .map((entry) => aiReviewCommandTitle(strings, '${entry['command']}'))
        .where((title) => title != strings.aiReviewUnknownAction)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.appLocalizations;
    final grouped = <String, List<Map<String, Object?>>>{};
    for (final capability in catalog) {
      final domain = capability['domain'] as String? ?? 'application';
      final group = switch (domain) {
        'appearance_network' ||
        'window' ||
        'application' ||
        'operations' ||
        'resources' => 'settings',
        'rules' => 'policies',
        'diagnostics' => 'logs',
        'proxies' || 'lifecycle' => 'connections',
        'dashboard' => 'network',
        'maintenance' ||
        'appearance' ||
        'files' ||
        'agent' ||
        'recovery' => 'settings',
        'profiles' ||
        'policies' ||
        'network' ||
        'logs' ||
        'backup' ||
        'scripts' ||
        'usage' ||
        'connections' => domain,
        _ => 'settings',
      };
      grouped.putIfAbsent(group, () => []).add(capability);
    }
    final order = [
      'connections',
      'profiles',
      'policies',
      'network',
      'logs',
      'backup',
      'settings',
      'scripts',
      'usage',
    ];
    final groups = grouped.entries.toList()
      ..sort((a, b) => order.indexOf(a.key).compareTo(order.indexOf(b.key)));
    return Card(
      key: const ValueKey('ai-capability-panel'),
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            strings.aiCanHelp,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            strings.aiCapabilityHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          for (final entry in groups) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_icon(entry.key)),
              title: Text(_label(context, entry.key)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${entry.value.length}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
            for (final action
                in entry.value
                    .map(
                      (capability) => _action(
                        context,
                        capability['command'] as String? ?? '',
                      ),
                    )
                    .whereType<String>()
                    .toSet())
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        action,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            if (_additionalActions(context, entry.value).isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  strings.more,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                children: [
                  for (final action in _additionalActions(context, entry.value))
                    ListTile(dense: true, title: Text(action)),
                ],
              ),
            const Divider(),
          ],
        ],
      ),
    );
  }
}

class AiToolResultCard extends StatelessWidget {
  const AiToolResultCard({
    super.key,
    this.result,
    this.summary,
    this.proposal,
    this.failed = false,
    this.expanded = false,
    this.awaitingApproval = false,
    this.onReview,
    this.onApprove,
    this.onCancel,
    this.reviewing = false,
  });
  final Map<String, Object?>? result;
  final String? summary;
  final ConfigurationProposal? proposal;
  final bool failed;
  final bool expanded;
  final bool awaitingApproval;
  final bool reviewing;
  final VoidCallback? onReview;
  final VoidCallback? onApprove;
  final VoidCallback? onCancel;

  String _status(BuildContext context) {
    final strings = context.appLocalizations;
    if (failed) {
      return aiErrorText(context, result?['code'] ?? result?['errorCode']);
    }
    final completion = aiCompletionStatus(result);
    return switch (completion ?? result?['status']) {
      'approved' => strings.aiApproved,
      'effective' => strings.aiPolicyEffectiveVerified,
      'saved_inactive' => strings.aiPolicySavedOnly,
      'saved_unverified' => strings.aiPolicySavedUnverified,
      'saved' => strings.policySaved,
      'applied' => strings.policyAppliedStatus,
      'draft' || 'proposal_ready' => strings.aiPolicyPlanReady,
      'superseded' => strings.policySupersededStatus,
      'expired' => strings.aiChangeExpired,
      'conflict' => strings.aiDraftInvalid,
      'unverified' => strings.aiChangesUnavailable,
      'requires_recovery' ||
      'recovery_required' => strings.policyRecoveryStatus,
      'persisted' => strings.aiChangeSavedPending,
      'committing' => strings.aiResourceUpdateAccepted,
      'completed' => strings.aiResultCompleted,
      'accepted' || 'running' || 'queued' => strings.aiResourceUpdateAccepted,
      'cancelled' => strings.aiCancelled,
      'rejected' => strings.policyRejectedStatus,
      'failed' || 'interrupted' || 'unsupported' => strings.aiRequestFailed,
      'pending_confirmation' ||
      'pending_user_input' => strings.aiAwaitingApproval,
      _ => strings.aiCheckResult,
    };
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.appLocalizations;
    final colors = Theme.of(context).colorScheme;
    final review = onReview;
    final rows = result == null
        ? const <AiReviewRow>[]
        : aiReadableResultRows(strings, result!);
    return Card(
      key: ValueKey('ai-result-${proposal?.id ?? 'check'}'),
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  proposal == null ? Icons.fact_check_outlined : Icons.tune,
                  color: failed ? colors.error : colors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    proposal == null
                        ? strings.aiCheckResult
                        : aiReviewTitle(strings, proposal!),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (proposal != null)
              AiProposalReviewBody(proposal: proposal!, compact: !expanded)
            else if (rows.isNotEmpty)
              AiReviewRowsView(rows: rows, compact: !expanded),
            Text(
              awaitingApproval
                  ? strings.aiAwaitingApproval
                  : proposal != null && result?['status'] == null
                  ? strings.aiPolicyPlanReady
                  : _status(context),
              style: TextStyle(
                color: failed ? colors.error : colors.onSurfaceVariant,
              ),
            ),
            if (review != null || onCancel != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (review != null)
                    OutlinedButton(
                      key: ValueKey('ai-review-${proposal?.id ?? 'check'}'),
                      onPressed: reviewing ? null : review,
                      child: Text(
                        awaitingApproval
                            ? strings.aiReviewAndConfirm
                            : strings.aiReviewPlan,
                      ),
                    ),
                  if (onCancel != null)
                    TextButton(
                      onPressed: reviewing ? null : onCancel,
                      child: Text(strings.cancel),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
