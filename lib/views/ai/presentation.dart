import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:flutter/material.dart';

import 'approval.dart';
import 'change_record.dart';
import 'errors.dart';
import 'policy_plan.dart';

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
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                strings.more,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              children: [
                for (final capability in entry.value)
                  ListTile(
                    dense: true,
                    title: Text('${capability['command']}'),
                    subtitle: Text('${capability['description']}'),
                  ),
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
  });
  final Map<String, Object?>? result;
  final String? summary;
  final ConfigurationProposal? proposal;
  final bool failed;
  final bool expanded;
  final bool awaitingApproval;
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

  String _field(BuildContext context, String key) {
    final strings = context.appLocalizations;
    return switch (key) {
      'running' || 'connected' => strings.coreStatus,
      'mode' => strings.mode,
      'model' => strings.aiModel,
      'provider' => strings.aiProvider,
      'connections' => strings.connections,
      'profiles' => strings.profiles,
      'nodes' || 'node' => strings.proxies,
      'latency' => strings.delay,
      'rules' => strings.rule,
      'settings' => strings.settings,
      'logs' => strings.logs,
      'errorCode' || 'code' => strings.aiRequestFailed,
      _ => key,
    };
  }

  String _differenceValue(String key, Object? value) {
    final display = aiDisplayValue({key: value});
    if (display.endsWith('…')) return display;
    final safe = (jsonDecode(display) as Map)[key];
    if (safe == null) return '—';
    if (safe is Map || safe is List) return jsonEncode(safe);
    return '$safe';
  }

  String _value(BuildContext context, String key, Object? value) {
    if ((key == 'running' || key == 'connected') && value is bool) {
      return value
          ? context.appLocalizations.start
          : context.appLocalizations.stop;
    }
    if (value is Map || value is List) {
      return '${value is Map ? value.length : (value as List).length}';
    }
    final display = aiDisplayValue({key: value});
    if (display.endsWith('…')) return display;
    final safe = (jsonDecode(display) as Map)[key];
    if (safe is Map) return '${safe.length}';
    if (safe is List) return '${safe.length}';
    return '$safe';
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.appLocalizations;
    final colors = Theme.of(context).colorScheme;
    final plan = proposal == null ? null : aiPolicyPlan(context, proposal!);
    final localPolicyChanges =
        proposal != null &&
        proposal!.differences.isNotEmpty &&
        proposal!.differences.every(
          (difference) => difference.path.startsWith('policies.'),
        );
    final nested = result?['result'];
    final fields = <String, Object?>{
      if (nested is Map)
        for (final entry in nested.entries) '${entry.key}': entry.value,
      if (result != null)
        for (final entry in result!.entries)
          if (!{'status', 'result', 'proposal'}.contains(entry.key))
            entry.key: entry.value,
    };
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
                  proposal == null
                      ? Icons.fact_check_outlined
                      : Icons.rule_outlined,
                  color: failed ? colors.error : colors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    plan != null
                        ? strings.aiPolicyPlanTitle
                        : proposal?.summary ?? summary ?? strings.aiCheckResult,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (proposal != null) ...[
              if (plan != null)
                AiPolicyPlanView(plan: plan, compact: !expanded),
              if (plan == null && localPolicyChanges)
                AiPolicyChangeOverview(proposal: proposal!),
              if (plan == null && !localPolicyChanges)
                for (final difference
                    in expanded
                        ? proposal!.differences
                        : proposal!.differences.take(8))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          difference.path,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                '${strings.aiBefore}: ${_differenceValue(difference.path, difference.before)}',
                                maxLines: expanded ? null : 3,
                                overflow: expanded
                                    ? TextOverflow.visible
                                    : TextOverflow.ellipsis,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(Icons.arrow_forward, size: 16),
                            ),
                            Expanded(
                              child: Text(
                                '${strings.aiAfter}: ${_differenceValue(difference.path, difference.after)}',
                                maxLines: expanded ? null : 3,
                                overflow: expanded
                                    ? TextOverflow.visible
                                    : TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              if (awaitingApproval ||
                  result?['status'] == null ||
                  result!['status'] == 'pending_confirmation')
                Text(
                  awaitingApproval
                      ? strings.aiAwaitingApproval
                      : strings.aiPolicyPlanReady,
                )
              else
                Text(_status(context)),
            ] else if (result != null) ...[
              Text(
                _status(context),
                style: TextStyle(
                  color: failed || result!['status'] == 'failed'
                      ? colors.error
                      : colors.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              for (final entry
                  in fields.entries
                      .where(
                        (entry) => !{
                          'taskEffect',
                          'recovery',
                          'completion',
                        }.contains(entry.key),
                      )
                      .where(
                        (entry) =>
                            !{'code', 'errorCode'}.contains(entry.key) ||
                            (!failed && entry.value != null),
                      )
                      .take(8))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          _field(context, entry.key),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _value(context, entry.key, entry.value),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(strings.view),
                children: [SelectableText(aiDisplayValue(result))],
              ),
            ],
            if (onReview != null || onApprove != null || onCancel != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onReview != null)
                    OutlinedButton(
                      onPressed: onReview,
                      child: Text(strings.aiReviewPlan),
                    ),
                  if (onApprove != null)
                    FilledButton(
                      onPressed: onApprove,
                      child: Text(
                        proposal!.validation['executionOnly'] == true ||
                                (proposal!.validation['requiresScriptExecutionApproval'] ==
                                        true &&
                                    proposal!
                                            .validation['finalConfigValidated'] !=
                                        true)
                            ? strings.aiApproveScriptExecution
                            : strings.aiApprove,
                      ),
                    ),
                  if (onCancel != null)
                    TextButton(
                      onPressed: onCancel,
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
