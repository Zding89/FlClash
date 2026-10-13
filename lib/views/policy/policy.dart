import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/models/profile.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:fl_clash/views/ai/approval.dart';
import 'package:fl_clash/views/ai/errors.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'editors.dart';
import 'rule_editor.dart';
import 'simulation.dart';
import 'widgets.dart';

class LocalPolicyWorkbenchView extends ConsumerStatefulWidget {
  const LocalPolicyWorkbenchView({super.key});
  @override
  ConsumerState<LocalPolicyWorkbenchView> createState() =>
      _LocalPolicyWorkbenchViewState();
}

class _LocalPolicyWorkbenchViewState
    extends ConsumerState<LocalPolicyWorkbenchView> {
  late final WorkbenchController _controller;
  bool _busy = false;
  String? _message;
  bool _failed = false;
  int _epoch = 0;
  @override
  void initState() {
    super.initState();
    _controller = ref.read(workbenchControllerProvider);
  }

  @override
  void dispose() {
    _epoch++;
    super.dispose();
  }

  Future<void> _operation(
    Future<Map<String, Object?>> Function(bool Function()) action,
  ) async {
    if (_busy) return;
    final epoch = ++_epoch;
    setState(() {
      _busy = true;
      _message = null;
      _failed = false;
    });
    try {
      final result = await action(() => mounted && _epoch == epoch);
      if (mounted && _epoch == epoch) {
        setState(
          () => _message = result['status'] == 'applied'
              ? context.appLocalizations.policySaved
              : context.appLocalizations.policyRejectedStatus,
        );
      }
    } catch (error) {
      if (mounted && _epoch == epoch) {
        setState(() {
          _failed = true;
          _message =
              error is PolicySourceException ||
                  error is ConfigurationChangeException &&
                      error.code == 'source_update_proxy_unavailable'
              ? aiErrorText(context, error)
              : context.appLocalizations.policyOperationFailed;
        });
      }
    } finally {
      if (mounted && _epoch == epoch) setState(() => _busy = false);
    }
  }

  Future<bool> _approve(ConfigurationProposal proposal) => mounted
      ? showAiConfigurationApproval(context, proposal)
      : Future.value(false);

  Future<void> _apply(LocalPolicyDocument before, Object candidate) =>
      _operation((isCurrent) async {
        final current = await _controller.readPolicies();
        if (policyDigest(current.toJson()) != policyDigest(before.toJson())) {
          throw const ConfigurationChangeException(
            'configuration_version_conflict',
          );
        }
        final parsed = candidate is LocalPolicyDocument
            ? LocalPolicyDocument.fromJson(candidate.toJson())
            : LocalPolicyDocument.fromJson(candidate as Map<String, Object?>);
        final proposal = await _controller.proposePolicies(parsed);
        return _controller.commit(
          proposal,
          approve: _approve,
          isCurrent: isCurrent,
        );
      });

  Map<String, Object?> _patch(
    LocalPolicyDocument before,
    Map<String, Object?> patch,
  ) => {...before.toJson(), ...patch};

  Future<void> _json(LocalPolicyDocument document) async {
    if (_busy) return;
    final next = await showDialog<LocalPolicyDocument>(
      context: context,
      builder: (_) => PolicyJsonDialog(
        initial: document.toJson(),
        parse: LocalPolicyDocument.fromJson,
      ),
    );
    if (next != null && mounted) await _apply(document, next);
  }

  Future<void> _integration(
    LocalPolicyDocument document,
    List<Profile> profiles,
    SubscriptionIntegration? existing,
  ) async {
    final next = await showDialog<SubscriptionIntegration>(
      context: context,
      builder: (_) => PolicyIntegrationEditor(
        existing: existing,
        profiles: profiles,
        loadNodes: (ids) async {
          final sources = await _controller.profiles.loader.load(
            profiles.where((profile) => ids.contains(profile.id)).toList(),
          );
          return sources
              .expand(_controller.profiles.compiler.extractNodes)
              .toList();
        },
      ),
    );
    if (next == null || !mounted) return;
    await _apply(
      document,
      _patch(document, {
        'integrations': [
          for (final entry in document.integrations)
            (entry.id == next.id ? next : entry).toJson(),
          if (existing == null) next.toJson(),
        ],
        'activeIntegrationId': document.activeIntegrationId ?? next.id,
      }),
    );
  }

  Future<void> _rule(
    LocalPolicyDocument document,
    Map<String, String> targets,
    LocalPolicy? existing,
  ) async {
    var priority = 100;
    final priorities = document.policies.map((rule) => rule.priority).toSet();
    while (priorities.contains(priority)) {
      priority += 100;
    }
    final next = await showDialog<LocalPolicy>(
      context: context,
      builder: (_) => LocalPolicyEditor(
        existing: existing,
        targets: targets,
        loadNodes: (target) => _controller.loadNodes(target),
        initialPriority: priority,
      ),
    );
    if (next == null || !mounted) return;
    await _apply(
      document,
      _patch(document, {
        'policies': [
          for (final rule in document.policies)
            (rule.id == existing?.id ? next : rule).toJson(),
          if (existing == null) next.toJson(),
        ],
      }),
    );
  }

  Future<void> _budget(
    LocalPolicyDocument document,
    Map<String, String> sources,
    SourceBudget? existing,
  ) async {
    final next = await showDialog<SourceBudget>(
      context: context,
      builder: (_) => PolicyBudgetEditor(existing: existing, sources: sources),
    );
    if (next == null || !mounted) return;
    if (document.budgets.any(
      (entry) =>
          entry.sourceId == next.sourceId &&
          entry.sourceId != existing?.sourceId,
    )) {
      setState(() {
        _failed = true;
        _message = context.appLocalizations.policyInvalidData;
      });
      return;
    }
    final entries = document.budgets
        .where((entry) => entry.sourceId != existing?.sourceId)
        .toList();
    await _apply(
      document,
      _patch(document, {
        'budgets': [...entries.map((entry) => entry.toJson()), next.toJson()],
      }),
    );
  }

  Future<void> _override(LocalPolicyDocument document, LocalPolicy rule) async {
    try {
      final nodes = await _controller.loadNodes(rule.targetId);
      if (!mounted) return;
      final next = await showDialog<PolicyOverride>(
        context: context,
        builder: (_) => PolicyOverrideEditor(policy: rule, nodes: nodes),
      );
      if (next == null || !mounted) return;
      await _apply(
        document,
        _patch(document, {
          'overrides': [
            for (final entry in document.overrides)
              if (entry.policyId != rule.id) entry.toJson(),
            next.toJson(),
          ],
        }),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _message = context.appLocalizations.policyOperationFailed;
        });
      }
    }
  }

  Widget _list(List<Widget> children) =>
      ListView(padding: const EdgeInsets.all(16), children: children);

  Widget _integrations(LocalPolicyDocument document, List<Profile> profiles) {
    final strings = context.appLocalizations;
    return _list([
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(strings.policyEnableIntegrations),
        subtitle: Text(strings.policyIntegrationHint),
        value: document.integrationEnabled,
        onChanged: _busy || document.activeIntegration == null
            ? null
            : (value) => _apply(
                document,
                _patch(document, {'integrationEnabled': value}),
              ),
      ),
      if (document.integrations.isNotEmpty)
        DropdownButtonFormField<String>(
          key: ValueKey(document.activeIntegrationId),
          initialValue: document.activeIntegrationId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: strings.policyActiveIntegration,
          ),
          items: [
            for (final integration in document.integrations)
              DropdownMenuItem(
                value: integration.id,
                child: Text(integration.label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _busy
              ? null
              : (id) {
                  if (id != null && id != document.activeIntegrationId) {
                    _apply(
                      document,
                      _patch(document, {'activeIntegrationId': id}),
                    );
                  }
                },
        ),
      const SizedBox(height: 16),
      DropdownButtonFormField<SourceUpdateRoute>(
        key: ValueKey(document.sourceUpdateRoute),
        initialValue: document.sourceUpdateRoute,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: strings.policyUpdateRoute,
          helperText: strings.policyUpdateRouteHint,
          helperMaxLines: 3,
        ),
        items: [
          DropdownMenuItem(
            value: SourceUpdateRoute.proxy,
            child: Text(strings.policyUpdateRouteProxy),
          ),
          DropdownMenuItem(
            value: SourceUpdateRoute.direct,
            child: Text(strings.policyUpdateRouteDirect),
          ),
        ],
        onChanged: _busy
            ? null
            : (value) {
                if (value != null && value != document.sourceUpdateRoute) {
                  _apply(
                    document,
                    _patch(document, {'sourceUpdateRoute': value.name}),
                  );
                }
              },
      ),
      const SizedBox(height: 16),
      if (document.integrations.isEmpty) Text(strings.policyEmptyIntegrations),
      for (final integration in document.integrations)
        Card(
          child: ListTile(
            leading: const Icon(Icons.merge_outlined),
            title: Text(integration.label),
            subtitle: Text(
              integration.sourceProfileIds
                  .map(
                    (id) =>
                        profiles
                            .where((profile) => profile.id == id)
                            .firstOrNull
                            ?.label ??
                        '$id',
                  )
                  .join(' · '),
            ),
            onTap: _busy
                ? null
                : () => _integration(document, profiles, integration),
            trailing: IconButton(
              onPressed: _busy
                  ? null
                  : () {
                      if (document.policies.any(
                        (rule) => rule.targetId == integration.targetId,
                      )) {
                        setState(() {
                          _failed = true;
                          _message = strings.policyDeleteLinked;
                        });
                        return;
                      }
                      final remaining = document.integrations
                          .where((entry) => entry.id != integration.id)
                          .toList();
                      final active =
                          document.activeIntegrationId == integration.id
                          ? remaining.firstOrNull?.id
                          : document.activeIntegrationId;
                      _apply(
                        document,
                        _patch(document, {
                          'integrations': remaining
                              .map((entry) => entry.toJson())
                              .toList(),
                          'activeIntegrationId': active,
                          'integrationEnabled':
                              document.integrationEnabled && active != null,
                        }),
                      );
                    },
              tooltip: strings.delete,
              icon: const Icon(Icons.delete_outline),
            ),
          ),
        ),
      const SizedBox(height: 16),
      FilledButton.tonalIcon(
        onPressed:
            _busy || profiles.isEmpty || document.integrations.length >= 20
            ? null
            : () => _integration(document, profiles, null),
        icon: const Icon(Icons.add),
        label: Text(strings.policyAddIntegration),
      ),
    ]);
  }

  Widget _rules(
    LocalPolicyDocument document,
    Map<String, String> targets,
    Map<String, Object?> snapshot,
  ) {
    final strings = context.appLocalizations;
    final statuses = snapshot['policies'] is List
        ? snapshot['policies'] as List
        : const [];
    final sorted = [...document.policies]
      ..sort((a, b) => a.priority.compareTo(b.priority));
    return _list([
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(strings.policyEnableRules),
        subtitle: Text(strings.policyRulesHint),
        value: document.policiesEnabled,
        onChanged: _busy
            ? null
            : (value) => _apply(
                document,
                _patch(document, {'policiesEnabled': value}),
              ),
      ),
      if (snapshot['state'] == 'core_disconnected')
        Text(strings.policyCoreStopped),
      if (document.policies.isEmpty) Text(strings.policyEmptyRules),
      for (final rule in sorted) ...[
        Card(
          child: ListTile(
            leading: Switch(
              value: rule.enabled,
              onChanged: _busy
                  ? null
                  : (value) => _apply(
                      document,
                      _patch(document, {
                        'policies': [
                          for (final entry in document.policies)
                            {
                              ...entry.toJson(),
                              if (entry.id == rule.id) 'enabled': value,
                            },
                        ],
                      }),
                    ),
            ),
            title: Text(rule.label),
            subtitle: Text(
              '${targets[rule.targetId] ?? rule.targetId}\n${strings.policyPriority}: ${rule.priority}',
            ),
            isThreeLine: true,
            onTap: _busy ? null : () => _rule(document, targets, rule),
            trailing: PopupMenuButton<String>(
              enabled: !_busy,
              onSelected: (action) {
                switch (action) {
                  case 'edit':
                    _rule(document, targets, rule);
                  case 'override':
                    _override(document, rule);
                  case 'removeOverride':
                    _apply(
                      document,
                      _patch(document, {
                        'overrides': document.overrides
                            .where((entry) => entry.policyId != rule.id)
                            .map((entry) => entry.toJson())
                            .toList(),
                      }),
                    );
                  case 'delete':
                    _apply(
                      document,
                      _patch(document, {
                        'policies': document.policies
                            .where((entry) => entry.id != rule.id)
                            .map((entry) => entry.toJson())
                            .toList(),
                        'overrides': document.overrides
                            .where((entry) => entry.policyId != rule.id)
                            .map((entry) => entry.toJson())
                            .toList(),
                      }),
                    );
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(strings.edit)),
                PopupMenuItem(
                  value: 'override',
                  child: Text(strings.policyTemporaryOverride),
                ),
                if (document.overrides.any(
                  (entry) => entry.policyId == rule.id,
                ))
                  PopupMenuItem(
                    value: 'removeOverride',
                    child: Text(strings.policyRemoveOverride),
                  ),
                PopupMenuItem(value: 'delete', child: Text(strings.delete)),
              ],
            ),
          ),
        ),
        if (statuses.whereType<Map>().any(
          (status) => status['policyId'] == rule.id,
        ))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _runtimeLabel(
                statuses.whereType<Map>().firstWhere(
                  (status) => status['policyId'] == rule.id,
                ),
              ),
            ),
          ),
        for (final override in document.overrides.where(
          (entry) => entry.policyId == rule.id,
        ))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '${strings.policyTemporaryOverride} · ${policyBeijingTime(override.expiresAt)}',
            ),
          ),
      ],
      const SizedBox(height: 16),
      FilledButton.tonalIcon(
        onPressed: _busy || targets.isEmpty || document.policies.length >= 100
            ? null
            : () => _rule(document, targets, null),
        icon: const Icon(Icons.add),
        label: Text(strings.policyAddRule),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: targets.isEmpty
            ? null
            : () => showDialog<void>(
                context: context,
                builder: (_) => PolicySimulationDialog(
                  document: document,
                  targets: targets,
                  snapshot: snapshot,
                  controller: _controller,
                ),
              ),
        icon: const Icon(Icons.science_outlined),
        label: Text(strings.policySimulation),
      ),
    ]);
  }

  String _runtimeLabel(Map<dynamic, dynamic> status) {
    final strings = context.appLocalizations;
    final state = status['state'];
    return '${strings.policyRuntimeState}: ${state == 'reject'
        ? strings.policyFallbackReject
        : state == 'direct'
        ? strings.policyFallbackDirect
        : strings.policyEligible}';
  }

  Widget _budgets(
    LocalPolicyDocument document,
    Map<String, String> sources,
    Map<String, Object?> snapshot,
  ) {
    final strings = context.appLocalizations;
    final ledgers = snapshot['budgets'] is List
        ? (snapshot['budgets'] as List).whereType<Map>().toList()
        : <Map>[];
    return _list([
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(strings.policyEnableBudgets),
        subtitle: Text(strings.policyBudgetHint),
        value: document.budgetsEnabled,
        onChanged: _busy
            ? null
            : (value) =>
                  _apply(document, _patch(document, {'budgetsEnabled': value})),
      ),
      if (document.budgets.isEmpty) Text(strings.policyEmptyBudgets),
      for (final budget in document.budgets)
        Card(
          child: ListTile(
            title: Text(sources[budget.sourceId] ?? budget.sourceId),
            subtitle: Text(
              '${strings.policyBudgetGiB}: ${policyGiB(budget.limitBytes)}\n${_ledgerText(budget.sourceId, ledgers)}',
            ),
            isThreeLine: true,
            onTap: _busy ? null : () => _budget(document, sources, budget),
            trailing: IconButton(
              onPressed: _busy
                  ? null
                  : () => _apply(
                      document,
                      _patch(document, {
                        'budgets': document.budgets
                            .where((entry) => entry.sourceId != budget.sourceId)
                            .map((entry) => entry.toJson())
                            .toList(),
                      }),
                    ),
              tooltip: strings.delete,
              icon: const Icon(Icons.delete_outline),
            ),
          ),
        ),
      const SizedBox(height: 16),
      FilledButton.tonalIcon(
        onPressed: _busy || sources.isEmpty || document.budgets.length >= 20
            ? null
            : () => _budget(document, sources, null),
        icon: const Icon(Icons.add),
        label: Text(strings.policyAddBudget),
      ),
    ]);
  }

  String _ledgerText(String id, List<Map> ledgers) {
    final row = ledgers.where((entry) => entry['sourceId'] == id).firstOrNull;
    final strings = context.appLocalizations;
    if (row == null || row['usedBytes'] is! int) {
      return strings.policyNotCollected;
    }
    return row['trusted'] != true
        ? strings.policyLedgerUntrusted
        : '${strings.policyUsage}: ${policyGiB(row['usedBytes'] as int)} GiB';
  }

  String _historyStatus(String status) {
    final strings = context.appLocalizations;
    return switch (status) {
      'applied' => strings.policyAppliedStatus,
      'draft' => strings.policyDraftStatus,
      'rejected' => strings.policyRejectedStatus,
      'recovery_required' => strings.policyRecoveryStatus,
      'restored' => strings.policyRestoredStatus,
      'superseded' => strings.policySupersededStatus,
      _ => strings.policyPreparingStatus,
    };
  }

  Widget _history() => ref
      .watch(workbenchChangesProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            Center(child: Text(context.appLocalizations.policyOperationFailed)),
        data: (rows) => _list([
          if (rows.isEmpty) Text(context.appLocalizations.policyEmptyHistory),
          for (final row in rows)
            Card(
              child: ListTile(
                title: Text(row.summary),
                subtitle: Text(
                  '${policyBeijingTime(row.createdAt)} · ${_historyStatus(row.status)}',
                ),
                onTap: () => _viewChange(row),
                trailing: IconButton(
                  onPressed: _busy || row.status != 'applied'
                      ? null
                      : () => _operation(
                          (current) => _controller.undo(
                            row.id,
                            approve: _approve,
                            isCurrent: current,
                          ),
                        ),
                  tooltip: context.appLocalizations.policyUndo,
                  icon: const Icon(Icons.undo),
                ),
              ),
            ),
        ]),
      );

  Future<void> _viewChange(WorkbenchChange row) async {
    try {
      final differences = configurationDifferences(
        jsonDecode(row.beforePayload),
        jsonDecode(row.afterPayload),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.appLocalizations.policyViewChanges),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final difference in differences) ...[
                    Text(
                      difference.path,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(context.appLocalizations.aiBefore),
                    SelectableText(aiDisplayValue(difference.before)),
                    Text(context.appLocalizations.aiAfter),
                    SelectableText(aiDisplayValue(difference.after)),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.appLocalizations.confirm),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _message = context.appLocalizations.policyOperationFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.appLocalizations;
    final profiles = ref.watch(profilesProvider);
    final snapshot =
        ref.watch(localPolicyStatusProvider).asData?.value ??
        const <String, Object?>{};
    final value = ref.watch(localPoliciesProvider);
    return DefaultTabController(
      length: 4,
      child: CommonScaffold(
        title: strings.policyWorkbenchTitle,
        actions: [
          IconButton(
            onPressed: _busy || value.asData == null
                ? null
                : () => _json(value.asData!.value),
            tooltip: strings.policyAdvancedJson,
            icon: const Icon(Icons.data_object),
          ),
        ],
        body: value.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(child: Text(strings.policyOperationFailed)),
          data: (document) {
            final targets = <String, String>{
              for (final profile in profiles)
                'profile:${profile.id}': profile.label,
              for (final integration in document.integrations)
                integration.targetId: integration.label,
            };
            final sources = {
              for (final profile in profiles) '${profile.id}': profile.label,
            };
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Column(
                  children: [
                    TabBar(
                      tabs: [
                        Tab(text: strings.policyIntegrationTab),
                        Tab(text: strings.policyRulesTab),
                        Tab(text: strings.policyBudgetTab),
                        Tab(text: strings.policyHistoryTab),
                      ],
                    ),
                    if (_busy) const LinearProgressIndicator(),
                    if (_message != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          _message!,
                          style: _failed
                              ? TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                )
                              : null,
                        ),
                      ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _integrations(document, profiles),
                          _rules(document, targets, snapshot),
                          _budgets(document, sources, snapshot),
                          _history(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
