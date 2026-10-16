import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/ai/history.dart';
import 'package:fl_clash/capabilities/service.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/views/policy/policy.dart';
import 'package:fl_clash/views/policy/widgets.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'change_record.dart';
import 'approval.dart';

class AiConversationHistoryView extends StatefulWidget {
  const AiConversationHistoryView({super.key, required this.store});
  final AiHistoryStore store;

  @override
  State<AiConversationHistoryView> createState() =>
      _AiConversationHistoryViewState();
}

class _AiConversationHistoryViewState extends State<AiConversationHistoryView> {
  late Future<List<AiConversation>> _entries;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _entries = widget.store.list();
  }

  Future<void> _delete(AiConversation entry) async {
    setState(() => _busy = true);
    try {
      await widget.store.delete(entry.id);
      if (mounted) setState(() => _entries = widget.store.list());
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.appLocalizations.policyOperationFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.appLocalizations;
    return CommonScaffold(
      title: strings.aiConversationHistory,
      body: FutureBuilder<List<AiConversation>>(
        future: _entries,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(strings.policyOperationFailed));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(strings.aiConversationHistoryHint),
              if (_error != null) Text(_error!),
              const SizedBox(height: 12),
              if (snapshot.data!.isEmpty) Text(strings.aiEmptyHistory),
              for (final entry in snapshot.data!)
                Card(
                  child: ListTile(
                    title: Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      [
                        policyBeijingTime(entry.updatedAt),
                        if (entry.targetLabel != null)
                          '${strings.aiStartedWithProfile}: ${entry.targetLabel}',
                      ].join('\n'),
                    ),
                    onTap: _busy
                        ? null
                        : () => Navigator.of(context).pop(entry),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (entry.changeIds.isNotEmpty)
                          IconButton(
                            tooltip: strings.aiLinkedChanges,
                            onPressed: _busy
                                ? null
                                : () => Navigator.of(context).push<void>(
                                    MaterialPageRoute(
                                      builder: (_) => AiLinkedChangesView(
                                        store: widget.store.database,
                                        ids: entry.changeIds,
                                      ),
                                    ),
                                  ),
                            icon: const Icon(Icons.receipt_long_outlined),
                          ),
                        IconButton(
                          tooltip: strings.delete,
                          onPressed: _busy ? null : () => _delete(entry),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class AiLinkedChangesView extends ConsumerStatefulWidget {
  const AiLinkedChangesView({
    super.key,
    required this.store,
    required this.ids,
  });
  final WorkbenchDatabase store;
  final List<String> ids;

  @override
  ConsumerState<AiLinkedChangesView> createState() =>
      _AiLinkedChangesViewState();
}

class _AiLinkedChangesViewState extends ConsumerState<AiLinkedChangesView> {
  late final Stream<List<WorkbenchChange>> _rows;
  final _statuses = <String, Future<String>>{};

  @override
  void initState() {
    super.initState();
    _rows = (widget.store.select(
      widget.store.workbenchChanges,
    )..where((table) => table.id.isIn(widget.ids))).watch();
  }

  Future<String> _readStatus(WorkbenchChange row) async {
    if (!row.category.startsWith('capability:')) {
      return aiStoredChangeStatus(row);
    }
    try {
      final result = await ref
          .read(applicationCapabilityServiceProvider)
          .execute('operation_query', {'operationId': row.id}, origin: 'agent')
          .timeout(const Duration(seconds: 5));
      return result['operationId'] == row.id && result['status'] is String
          ? result['status'] as String
          : 'unverified';
    } catch (_) {
      return 'unverified';
    }
  }

  String _status(String status) {
    final strings = context.appLocalizations;
    return switch (status) {
      'applied' => strings.policyAppliedStatus,
      'saved' => strings.policySaved,
      'draft' ||
      'pending_confirmation' ||
      'proposal_ready' => strings.policyDraftStatus,
      'rejected' => strings.policyRejectedStatus,
      'requires_recovery' ||
      'recovery_required' => strings.policyRecoveryStatus,
      'restored' || 'resolved' => strings.policyRestoredStatus,
      'superseded' => strings.policySupersededStatus,
      'completed' => strings.aiChangeCompleted,
      'failed' || 'interrupted' || 'conflict' => strings.aiChangeFailed,
      'cancelled' => strings.aiCancelled,
      'expired' => strings.aiChangeExpired,
      'unverified' => strings.aiChangesUnavailable,
      _ => strings.policyPreparingStatus,
    };
  }

  Future<void> _view(WorkbenchChange row) async {
    ConfigurationProposal proposal;
    try {
      proposal = await ref
          .read(applicationCapabilityServiceProvider)
          .reviewChange(row.id);
    } catch (_) {
      if (row.category.startsWith('capability:')) return;
      proposal = aiStoredProposal(row);
    }
    if (!mounted) return;
    await showAiConfigurationApproval(context, proposal, readOnly: true);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.appLocalizations;
    return CommonScaffold(
      title: strings.aiLinkedChanges,
      body: StreamBuilder<List<WorkbenchChange>>(
        stream: _rows,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(strings.policyOperationFailed));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data!.toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(strings.aiLinkedChangesHint),
              if (rows.length < widget.ids.toSet().length)
                Text(strings.aiChangesUnavailable),
              for (final row in rows)
                Card(
                  child: ListTile(
                    title: Text(row.summary),
                    subtitle: FutureBuilder<String>(
                      future: _statuses.putIfAbsent(
                        '${row.id}:${row.status}',
                        () => _readStatus(row),
                      ),
                      builder: (context, snapshot) => Text(
                        '${policyBeijingTime(row.createdAt)} · ${_status(snapshot.data ?? row.status)}',
                      ),
                    ),
                    onTap: () => _view(row),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) =>
                        const LocalPolicyWorkbenchView(initialTab: 4),
                  ),
                ),
                icon: const Icon(Icons.history),
                label: Text(strings.aiManageChanges),
              ),
            ],
          );
        },
      ),
    );
  }
}
