import 'dart:io';
import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/models/profile.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/views/ai/approval.dart';
import 'package:fl_clash/views/ai/composer_context.dart';
import 'package:fl_clash/views/ai/errors.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'editors.dart';
import 'rule_editor.dart';
import 'simulation.dart';
import 'widgets.dart';
import 'selection_fields.dart';
import 'node_set_editor.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/core/controller.dart';

class LocalPolicyWorkbenchView extends ConsumerStatefulWidget {
  const LocalPolicyWorkbenchView({super.key, this.initialTab = 0});
  final int initialTab;
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
              ? ref.read(coreStatusProvider) == CoreStatus.connected
                    ? context.appLocalizations.policySaved
                    : context.appLocalizations.policySavedInactive
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
        final current = (await _controller.readPolicies()).asStandalone();
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

  Future<void> _rule(
    LocalPolicyDocument document,
    Map<String, String> targets,
    LocalPolicy? existing,
  ) async {
    await showDialog<LocalPolicy>(
      context: context,
      builder: (_) => LocalPolicyEditor(
        existing: existing,
        loadNodes: (target) => _controller.loadNodes(target),
        initialPriority: existing?.priority ?? 100,
        nodeSets: document.nodeSets,
        attributes: document.nodeAttributes,
        onSave: (rule, sets, attributes) async {
          final next = LocalPolicyDocument.fromJson(
            _patch(document, {
              'policiesEnabled': document.policies.isEmpty
                  ? true
                  : document.policiesEnabled,
              'policies': insertPolicy(
                document.policies,
                rule,
              ).map((p) => p.toJson()).toList(),
              'nodeSets': sets.map((s) => s.toJson()).toList(),
              'nodeAttributes': attributes.map(
                (k, v) => MapEntry(k, v.toJson()),
              ),
              'overrides': document.overrides
                  .where(
                    (o) =>
                        o.policyId != rule.id ||
                        (existing?.targetId == rule.targetId &&
                            o.references(rule)),
                  )
                  .map((o) => o.toJson())
                  .toList(),
            }),
          );
          await _commitDocument(document, next);
        },
        onPreview: (rule, sets, attributes) async {
          final next = LocalPolicyDocument.fromJson(
            _patch(document, {
              'policies': insertPolicy(
                document.policies,
                rule,
              ).map((p) => p.toJson()).toList(),
              'nodeSets': sets.map((s) => s.toJson()).toList(),
              'nodeAttributes': attributes.map(
                (k, v) => MapEntry(k, v.toJson()),
              ),
              'overrides': document.overrides
                  .where(
                    (o) =>
                        o.policyId != rule.id ||
                        (existing?.targetId == rule.targetId &&
                            o.references(rule)),
                  )
                  .map((o) => o.toJson())
                  .toList(),
            }),
          );
          await showDialog<void>(
            context: context,
            builder: (_) => PolicySimulationDialog(
              document: next,
              targets: {rule.targetId: targets[rule.targetId] ?? rule.targetId},
              snapshot: ref.read(localPolicyStatusProvider).value ?? const {},
              controller: _controller,
            ),
          );
        },
      ),
    );
  }

  Future<Map<String, Object?>> _commitDocument(
    LocalPolicyDocument before,
    LocalPolicyDocument next,
  ) async {
    if (policyDigest(
          (await _controller.readPolicies()).asStandalone().toJson(),
        ) !=
        policyDigest(before.toJson())) {
      throw const ConfigurationChangeException(
        'configuration_version_conflict',
      );
    }
    final proposal = await _controller.proposePolicies(next);
    final result = await _controller.commit(proposal, approve: _approve);
    if (result['status'] != 'applied') {
      throw const ConfigurationChangeException('configuration_cancelled');
    }
    if (mounted) {
      setState(
        () => _message = ref.read(coreStatusProvider) == CoreStatus.connected
            ? context.appLocalizations.policySaved
            : context.appLocalizations.policySavedInactive,
      );
    }
    return result;
  }

  Future<void> _nodeSet(
    LocalPolicyDocument document,
    Map<String, String> targets,
    Map<String, Object?> snapshot,
    PolicyNodeSet? existing,
  ) async {
    const target = localPolicyTargetId;
    try {
      final nodes = await _controller.loadNodes(target);
      if (!mounted) return;
      final sourceIds = target.startsWith('integration:')
          ? document.integrations
                .firstWhere((i) => i.targetId == target)
                .sourceProfileIds
                .map((id) => '$id')
                .toSet()
          : ref
                .read(profilesProvider)
                .map((profile) => '${profile.id}')
                .toSet();
      final sourceNames = {
        for (final profile in ref.read(profilesProvider))
          if (sourceIds.contains('${profile.id}'))
            '${profile.id}': profile.realLabel,
      };
      await showDialog<PolicyNodeSetEdit>(
        context: context,
        builder: (_) => PolicyNodeSetEditor(
          existing: existing,
          targetId: target,
          sources: sourceNames,
          nodes: nodes,
          attributes: document.nodeAttributes,
          snapshot: snapshot,
          loadStatus: coreController.getLocalPolicyDetails,
          referencedRules: document.policies
              .where(
                (p) => p.choices.any(
                  (c) =>
                      c.type == PolicyChoiceType.nodeSet &&
                      c.id == existing?.id,
                ),
              )
              .map((p) => p.label)
              .toList(),
          onCheck: (id) async {
            await coreController.checkLocalPolicyNodes({
              'revision': snapshot['revision'],
              'nodeSetId': id,
            });
          },
          onSave: (edit) async {
            await _commitDocument(
              document,
              LocalPolicyDocument.fromJson(
                _patch(document, {
                  'nodeSets': [
                    for (final s in document.nodeSets)
                      (s.id == edit.nodeSet.id ? edit.nodeSet : s).toJson(),
                    if (existing == null) edit.nodeSet.toJson(),
                  ],
                  'nodeAttributes': edit.attributes.map(
                    (k, v) => MapEntry(k, v.toJson()),
                  ),
                }),
              ),
            );
          },
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = context.appLocalizations.policyOperationFailed,
        );
      }
    }
  }

  Widget _nodeSets(
    LocalPolicyDocument document,
    Map<String, String> targets,
    Map<String, Object?> snapshot,
  ) {
    final strings = context.appLocalizations;
    final selected = _selectedTarget(document, targets);
    return _list([
      const SizedBox(height: 12),
      Text(strings.policyNodeSetHint),
      const SizedBox(height: 8),
      Text(strings.policySharedSetImpact),
      for (final set in document.nodeSets.where((s) => s.targetId == selected))
        Card(
          child: ListTile(
            title: Text(set.label),
            subtitle: Text(
              '${set.regions.isEmpty ? strings.policyAnyRegion : set.regions.map((region) => policyRegionOptions(context, set.regions)[region] ?? region).join(' · ')} · ${set.maxMultiplier == null ? strings.policyAnyMultiplier : '${set.maxMultiplier}×'}',
            ),
            onTap: _busy
                ? null
                : () => _nodeSet(document, targets, snapshot, set),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _busy
                      ? null
                      : () => _nodeSet(document, targets, snapshot, set),
                  tooltip: strings.edit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  onPressed: _busy
                      ? null
                      : () {
                          if (document.policies.any(
                            (p) => p.choices.any(
                              (c) =>
                                  c.type == PolicyChoiceType.nodeSet &&
                                  c.id == set.id,
                            ),
                          )) {
                            setState(
                              () => _message = strings.policyDeleteLinked,
                            );
                            return;
                          }
                          _apply(
                            document,
                            _patch(document, {
                              'nodeSets': document.nodeSets
                                  .where((s) => s.id != set.id)
                                  .map((s) => s.toJson())
                                  .toList(),
                            }),
                          );
                        },
                  tooltip: strings.delete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ),
      FilledButton.tonalIcon(
        onPressed: _busy
            ? null
            : () => _nodeSet(document, targets, snapshot, null),
        icon: const Icon(Icons.add),
        label: Text(strings.policyNodeSet),
      ),
      if (document.localProfile.sourceProfileIds.isEmpty)
        Text(strings.policyLocalSourcesEmpty),
    ]);
  }

  Future<void> _budget(
    LocalPolicyDocument document,
    Map<String, String> sources,
    SourceBudget? existing,
  ) async {
    await showDialog<SourceBudget>(
      context: context,
      builder: (_) => PolicyBudgetEditor(
        existing: existing,
        sources: sources,
        onSave: (next) async {
          if (document.budgets.any(
            (b) =>
                b.sourceId == next.sourceId && b.sourceId != existing?.sourceId,
          )) {
            throw const FormatException('duplicate budget');
          }
          await _commitDocument(
            document,
            LocalPolicyDocument.fromJson(
              _patch(document, {
                'budgets': [
                  ...document.budgets
                      .where((b) => b.sourceId != existing?.sourceId)
                      .map((b) => b.toJson()),
                  next.toJson(),
                ],
              }),
            ),
          );
        },
      ),
    );
  }

  Future<void> _override(LocalPolicyDocument document, LocalPolicy rule) async {
    try {
      final nodes = await _controller.loadNodes(
        rule.targetId,
        document: document,
      );
      final eligible = await _controller.eligibleOverrideChoices(
        document,
        rule,
      );
      if (!mounted) return;
      final next = await showDialog<PolicyOverride>(
        context: context,
        builder: (_) => PolicyOverrideEditor(
          policy: rule,
          nodes: nodes,
          nodeSets: document.nodeSets,
          eligibleChoices: eligible,
        ),
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

  String _selectedTarget(
    LocalPolicyDocument document,
    Map<String, String> targets,
  ) => localPolicyTargetId;

  Widget _section(List<Widget> children) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );

  Widget _sources(LocalPolicyDocument document, List<Profile> profiles) {
    final strings = context.appLocalizations;
    final local = document.localProfile;
    final selected = local.sourceProfileIds.map((id) => '$id').toList();
    return _section([
      Text(strings.policyLocalSourcesHint),
      const SizedBox(height: 12),
      PolicyMultiSelect(
        label: strings.policySubscriptionSources,
        options: {
          for (final profile in profiles) '${profile.id}': profile.realLabel,
        },
        value: selected,
        enabled: !_busy,
        onChanged: (ids) {
          if (!mounted || _busy) return;
          if (ids.length > 20) {
            setState(() {
              _failed = true;
              _message = strings.policyLocalSourceLimit;
            });
            return;
          }
          _apply(
            document,
            _patch(document, {
              'integrations': [
                for (final integration in document.integrations)
                  integration.id == localPolicyProfileId
                      ? {
                          ...integration.toJson(),
                          'sourceProfileIds': ids.map(int.parse).toList(),
                        }
                      : integration.toJson(),
              ],
            }),
          );
        },
      ),
      if (selected.isEmpty) Text(strings.policyLocalSourcesEmpty),
      for (final profile in profiles.where(
        (profile) => selected.contains('${profile.id}'),
      ))
        Card(child: _PolicySourceFacts(profile: profile)),
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
    ]);
  }

  Widget _rules(
    LocalPolicyDocument document,
    Map<String, String> targets,
    Map<String, Object?> snapshot,
  ) {
    final strings = context.appLocalizations;
    final selected = _selectedTarget(document, targets);
    final rules = orderedPolicies(
      document.policies.where(
        (p) => p.targetId == selected && p.scope.type != PolicyMatchType.group,
      ),
    );
    final groups = document.policies
        .where(
          (p) =>
              p.targetId == selected && p.scope.type == PolicyMatchType.group,
        )
        .toList();
    final statuses = snapshot['policies'] is List
        ? (snapshot['policies'] as List).whereType<Map>().toList()
        : <Map>[];
    final active = document.moduleEnabled && document.integrationEnabled
        ? document.activeIntegration?.targetId
        : 'profile:${ref.watch(currentProfileIdProvider)}';
    Widget row(LocalPolicy rule, int index, {bool draggable = true}) {
      final status = statuses
          .where((s) => s['policyId'] == rule.id)
          .firstOrNull;
      final runtime = !document.moduleEnabled
          ? strings.policySavedInactive
          : !document.policiesEnabled || !rule.enabled
          ? strings.policySavedInactive
          : rule.targetId != active
          ? strings.policySavedInactive
          : snapshot['state'] == 'core_disconnected'
          ? strings.policyCoreStopped
          : status == null
          ? strings.policyCheckPending
          : _runtimeLabel(status);
      final selections = rule.choices.isEmpty
          ? [
              for (final id in rule.candidateNodeIds)
                PolicyChoice(type: PolicyChoiceType.node, id: id),
            ]
          : rule.choices;
      return Card(
        key: ValueKey(rule.id),
        child: Column(
          children: [
            ListTile(
              leading: draggable
                  ? ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_indicator),
                    )
                  : const Icon(Icons.lock_outline),
              title: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(rule.label),
                  if (rule.origin == PolicyOrigin.ai)
                    Chip(label: Text(strings.policyAiOrigin)),
                  if (rule.origin == PolicyOrigin.manual)
                    Chip(label: Text(strings.policyManualOrigin)),
                ],
              ),
              subtitle: Text(
                '${policyMatchDescription(context, rule.scope)} · ${rule.action == PolicyAction.direct
                    ? strings.policyActionDirect
                    : rule.action == PolicyAction.reject
                    ? strings.policyActionReject
                    : strings.policyActionProxy} · $runtime',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: rule.enabled,
                    onChanged: _busy
                        ? null
                        : (value) => _apply(
                            document,
                            _patch(document, {
                              'policies': [
                                for (final p in document.policies)
                                  {
                                    ...p.toJson(),
                                    if (p.id == rule.id) 'enabled': value,
                                  },
                              ],
                            }),
                          ),
                  ),
                  IconButton(
                    onPressed: _busy
                        ? null
                        : () => _rule(document, targets, rule),
                    tooltip: strings.edit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  PopupMenuButton<String>(
                    enabled: !_busy,
                    onSelected: (action) {
                      if (action == 'override') {
                        _override(document, rule);
                      } else if (action == 'removeOverride') {
                        _apply(
                          document,
                          _patch(document, {
                            'overrides': document.overrides
                                .where((o) => o.policyId != rule.id)
                                .map((o) => o.toJson())
                                .toList(),
                          }),
                        );
                      } else if (action == 'delete') {
                        _apply(
                          document,
                          _patch(document, {
                            'policies': document.policies
                                .where((p) => p.id != rule.id)
                                .map((p) => p.toJson())
                                .toList(),
                            'overrides': document.overrides
                                .where((o) => o.policyId != rule.id)
                                .map((o) => o.toJson())
                                .toList(),
                          }),
                        );
                      }
                    },
                    itemBuilder: (_) => [
                      if (rule.action == PolicyAction.proxy)
                        PopupMenuItem(
                          value: 'override',
                          child: Text(strings.policyTemporaryOverride),
                        ),
                      if (document.overrides.any((o) => o.policyId == rule.id))
                        PopupMenuItem(
                          value: 'removeOverride',
                          child: Text(strings.policyRemoveOverride),
                        ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(strings.delete),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ExpansionTile(
              title: Text(
                rule.action != PolicyAction.proxy
                    ? (rule.action == PolicyAction.direct
                          ? strings.policyActionDirect
                          : strings.policyActionReject)
                    : selections
                          .map(
                            (c) => c.type == PolicyChoiceType.nodeSet
                                ? document.nodeSets
                                          .where((s) => s.id == c.id)
                                          .firstOrNull
                                          ?.label ??
                                      strings.policySourceMissing
                                : strings.policyFixedNode,
                          )
                          .join(' → '),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rule.action == PolicyAction.direct
                            ? strings.policyActionDirect
                            : rule.action == PolicyAction.reject
                            ? strings.policyActionReject
                            : strings.policyNoNodeContinue,
                      ),
                      if (status != null)
                        for (final node
                            in (status['nodes'] as List? ?? [])
                                .whereType<Map>())
                          Text(
                            '${node['nodeId']} · ${node['reason'] == '' ? strings.policyEligible : policyReasonLabel(context, '${node['reason']}')}',
                          ),
                      for (final o in document.overrides.where(
                        (o) =>
                            o.policyId == rule.id &&
                            o.expiresAt > DateTime.now().millisecondsSinceEpoch,
                      ))
                        Text(
                          '${strings.policyTemporaryOverride} · ${policyBeijingTime(o.expiresAt)}',
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return _list([
      const SizedBox(height: 12),
      if (document.localProfile.sourceProfileIds.isEmpty)
        Text(strings.policyLocalSourcesEmpty),
      Text(strings.policyRuleOrderHint),
      const SizedBox(height: 8),
      Text(strings.policyLocalDefaultReject),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        children: [
          FilledButton.tonalIcon(
            onPressed: _busy || document.policies.length >= 100
                ? null
                : () => _rule(document, targets, null),
            icon: const Icon(Icons.add),
            label: Text(strings.policyAddRule),
          ),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () {
                    final navigator = Navigator.of(context);
                    ref
                        .read(aiComposerContextProvider.notifier)
                        .offer(strings.policyAiOptimizationRequest(selected));
                    ref
                        .read(currentPageLabelProvider.notifier)
                        .toPage(PageLabel.aiAssistant);
                    if (navigator.canPop()) navigator.pop();
                  },
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text(strings.policyAiOptimizeRule),
          ),
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
        ],
      ),
      const SizedBox(height: 12),
      if (!document.policiesEnabled)
        SwitchListTile(
          title: Text(strings.policyEnableRules),
          value: false,
          onChanged: _busy
              ? null
              : (v) =>
                    _apply(document, _patch(document, {'policiesEnabled': v})),
        ),
      if (rules.isEmpty) Text(strings.policyEmptyRules),
      ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: rules.length,
        itemBuilder: (_, index) => row(rules[index], index),
        onReorderItem: (oldIndex, newIndex) {
          if (_busy) {
            return;
          }
          final next = [...rules];
          final value = next.removeAt(oldIndex);
          next.insert(newIndex, value);
          _apply(
            document,
            _patch(document, {
              'policies': [
                ...document.policies
                    .where(
                      (p) =>
                          p.targetId != selected ||
                          p.scope.type == PolicyMatchType.group,
                    )
                    .map((p) => p.toJson()),
                for (var i = 0; i < next.length; i++)
                  {...next[i].toJson(), 'priority': i + 1},
              ],
            }),
          );
        },
      ),
      if (groups.isNotEmpty)
        ExpansionTile(
          title: Text(strings.policyGroupScope),
          children: [
            for (var i = 0; i < groups.length; i++)
              row(groups[i], i, draggable: false),
          ],
        ),
    ]);
  }

  String _runtimeLabel(Map<dynamic, dynamic> status) {
    final strings = context.appLocalizations;
    if (status['reason'] == 'schedule_inactive') {
      return strings.policyScheduleSkip;
    }
    if (status['reason'] == 'recovery_hold') return strings.policyRecovery;
    final state = status['state'];
    if (state == 'skipped') return strings.policyNoNodeContinue;
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
    final history =
        ref.watch(localBudgetHistoryProvider).asData?.value ??
        const <String, Object?>{};
    final ledgers = snapshot['budgets'] is List
        ? (snapshot['budgets'] as List).whereType<Map>().toList()
        : <Map>[];
    final integration = document.integrationEnabled
        ? document.activeIntegration
        : null;
    final profileId = ref.watch(currentProfileIdProvider);
    final targetId = document.integrationEnabled
        ? integration?.targetId
        : profileId == null
        ? null
        : 'profile:$profileId';
    final activeSources = document.integrationEnabled
        ? {for (final id in integration?.sourceProfileIds ?? <int>[]) '$id'}
        : {if (profileId != null) '$profileId'};
    final running =
        document.moduleEnabled &&
        document.integrationEnabled &&
        integration?.id == localPolicyProfileId &&
        document.budgetsEnabled &&
        ref.watch(coreStatusProvider) == CoreStatus.connected &&
        snapshot['enabled'] == true &&
        snapshot['documentRevision'] == document.revision &&
        snapshot['revision'] is int &&
        (snapshot['revision'] as int) >= 0 &&
        targetId != null &&
        snapshot['targetId'] == targetId;
    Widget budgetCard(SourceBudget budget) {
      final current = ledgers
          .where((entry) => entry['sourceId'] == budget.sourceId)
          .firstOrNull;
      final active =
          running &&
          activeSources.contains(budget.sourceId) &&
          current != null &&
          current['limitBytes'] == budget.limitBytes;
      final used = current?['usedBytes'];
      final reached =
          active &&
          current['trusted'] == true &&
          used is int &&
          used >= budget.limitBytes;
      return Card(
        child: ListTile(
          title: Text(sources[budget.sourceId] ?? budget.sourceId),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${strings.policyBudgetGiB}: ${policyGiB(budget.limitBytes)}\n${_ledgerText(budget.sourceId, ledgers, history, active: active)}',
              ),
              if (reached) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        strings.policyBudgetReached,
                        key: ValueKey(
                          'policy-budget-reached-${budget.sourceId}',
                        ),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(strings.policyBudgetReachedHint),
              ],
            ],
          ),
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
      );
    }

    return _section([
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
      for (final budget in document.budgets) budgetCard(budget),
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

  String _ledgerText(
    String id,
    List<Map> ledgers,
    Map<String, Object?> history, {
    required bool active,
  }) {
    final current = ledgers
        .where((entry) => entry['sourceId'] == id)
        .firstOrNull;
    final cached = history[id] is Map ? history[id] as Map : null;
    final row = active ? current ?? cached : cached ?? current;
    final live = active && current != null;
    final strings = context.appLocalizations;
    if (row == null || row['usedBytes'] is! int) {
      return strings.policyNotCollected;
    }
    return [
      if (!live) strings.policySavedInactive,
      row['trusted'] != true
          ? live
                ? strings.policyLedgerUntrusted
                : strings.policyUsageUnknown
          : '${strings.policyUsage}: ${policyGiB(row['usedBytes'] as int)} GiB',
      if (row['periodStart'] is int)
        strings.policyBudgetPeriod(
          policyBeijingTime(row['periodStart'] as int),
        ),
      if (!live && row['sampleAt'] is int)
        strings.policyBudgetLastSample(
          policyBeijingTime(row['sampleAt'] as int),
        ),
    ].join('\n');
  }

  Future<void> _recover(WorkbenchChange row) async {
    var keepCurrent = false;
    int? recoveryProfile;
    var working = false;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(context.appLocalizations.policyRecoveryCheck),
          content: SizedBox(
            width: 600,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.summary),
                Text(
                  row.error ?? context.appLocalizations.policyRecoveryStatus,
                ),
                if (working) const LinearProgressIndicator(),
                SwitchListTile(
                  title: Text(context.appLocalizations.policyRecoveryKeep),
                  value: keepCurrent,
                  onChanged: working
                      ? null
                      : (value) => update(() => keepCurrent = value),
                ),
                if (!row.category.startsWith('resource:'))
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: context.appLocalizations.policyTarget,
                    ),
                    items: [
                      for (final profile in ref.read(profilesProvider))
                        DropdownMenuItem(
                          value: profile.id,
                          child: Text(
                            profile.realLabel,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: working
                        ? null
                        : (value) => update(() => recoveryProfile = value),
                  ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: working
                  ? null
                  : () async {
                      final document = await _controller.readPolicies();
                      final known = ref
                          .read(profilesProvider)
                          .map((p) => p.id)
                          .toSet();
                      final missing = <int>{
                        for (final integration in document.integrations)
                          ...integration.sourceProfileIds,
                        for (final p in document.policies)
                          if (p.targetId.startsWith('profile:'))
                            int.parse(p.targetId.split(':').last),
                      }.where((id) => !known.contains(id)).toList();
                      if (missing.isEmpty) {
                        if (context.mounted) {
                          update(
                            () => error =
                                context.appLocalizations.policySourceMissing,
                          );
                        }
                        return;
                      }
                      if (!context.mounted) return;
                      final selected = await showDialog<int>(
                        context: context,
                        builder: (context) => SimpleDialog(
                          title: Text(context.appLocalizations.policySources),
                          children: [
                            for (final id in missing)
                              SimpleDialogOption(
                                onPressed: () => Navigator.pop(context, id),
                                child: Text('$id'),
                              ),
                          ],
                        ),
                      );
                      if (selected == null || !context.mounted) return;
                      final file = await picker.pickerFile();
                      if (file?.path == null || !context.mounted) return;
                      update(() => working = true);
                      try {
                        final source = File(file!.path!);
                        if (await source.length() > 8 * 1024 * 1024) {
                          throw const FormatException('source size');
                        }
                        final proposal = await _controller.resources
                            .proposeRepairSource(
                              row.id,
                              selected,
                              content: await source.readAsString(),
                            );
                        await _controller.resources.commit(
                          proposal.id,
                          approve: _approve,
                        );
                        if (context.mounted) {
                          update(
                            () => error =
                                context.appLocalizations.policyRecoveryStatus,
                          );
                        }
                      } catch (_) {
                        if (context.mounted) {
                          update(
                            () => error =
                                context.appLocalizations.policyOperationFailed,
                          );
                        }
                      } finally {
                        if (context.mounted) update(() => working = false);
                      }
                    },
              child: Text(context.appLocalizations.policySources),
            ),
            TextButton(
              onPressed: working ? null : () => Navigator.pop(context),
              child: Text(context.appLocalizations.cancel),
            ),
            FilledButton(
              onPressed: working
                  ? null
                  : () async {
                      update(() => working = true);
                      try {
                        final resource = row.category.startsWith('resource:');
                        final proposal = resource
                            ? await _controller.resources.proposeRecovery(
                                row.id,
                                keepCurrent: keepCurrent,
                              )
                            : recoveryProfile != null
                            ? await _controller.proposeRecoveryToProfile(
                                row.id,
                                recoveryProfile!,
                              )
                            : await _controller.changes.proposeRecovery(
                                row.id,
                                keepCurrent: keepCurrent,
                              );
                        final result = resource
                            ? await _controller.resources.commit(
                                proposal.id,
                                approve: _approve,
                              )
                            : await _controller.changes.commitRecovery(
                                proposal,
                                approve: _approve,
                              );
                        if (result['status'] == 'applied' && context.mounted) {
                          Navigator.pop(context);
                        } else if (context.mounted) {
                          update(
                            () => error =
                                context.appLocalizations.policyRejectedStatus,
                          );
                        }
                      } catch (_) {
                        if (context.mounted) {
                          update(
                            () => error =
                                context.appLocalizations.policyOperationFailed,
                          );
                        }
                      } finally {
                        if (context.mounted) update(() => working = false);
                      }
                    },
              child: Text(context.appLocalizations.policyRecoveryCheck),
            ),
          ],
        ),
      ),
    );
  }

  String _historyStatus(String status) {
    final strings = context.appLocalizations;
    return switch (status) {
      'applied' => strings.policyAppliedStatus,
      'draft' => strings.policyDraftStatus,
      'rejected' => strings.policyRejectedStatus,
      'recovery_required' => strings.policyRecoveryStatus,
      'restored' || 'resolved' => strings.policyRestoredStatus,
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
                trailing: row.status == 'recovery_required'
                    ? IconButton(
                        onPressed: _busy ? null : () => _recover(row),
                        tooltip: context.appLocalizations.policyRecoveryCheck,
                        icon: const Icon(Icons.build_circle_outlined),
                      )
                    : IconButton(
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
    ref.watch(currentProfileIdProvider);
    final snapshot =
        ref.watch(localPolicyStatusProvider).asData?.value ??
        const <String, Object?>{};
    final value = ref.watch(localPoliciesProvider);
    return DefaultTabController(
      length: 4,
      initialIndex: switch (widget.initialTab) {
        4 => 3,
        final index => index.clamp(0, 3),
      },
      child: CommonScaffold(
        title: strings.policyWorkbenchTitle,
        actions: [
          IconButton(
            onPressed: _busy || value.asData == null
                ? null
                : () => _json(value.asData!.value.asStandalone()),
            tooltip: strings.policyAdvancedJson,
            icon: const Icon(Icons.data_object),
          ),
        ],
        body: value.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(child: Text(strings.policyOperationFailed)),
          data: (stored) {
            final document = stored.asStandalone();
            final targets = {
              localPolicyTargetId: strings.policyLocalCollection,
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
                    if (document.migrationReviewRequired)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(strings.policyLocalMigrationReview),
                      ),
                    TabBar(
                      isScrollable: true,
                      tabs: [
                        Tab(text: strings.policyRulesTab),
                        Tab(text: strings.policyNodeSets),
                        Tab(text: strings.policyAdvancedTab),
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
                          _rules(document, targets, snapshot),
                          _nodeSets(document, targets, snapshot),
                          _list([
                            ExpansionTile(
                              key: const PageStorageKey('policy-sources'),
                              initiallyExpanded: true,
                              title: Text(strings.policySubscriptionSources),
                              children: [_sources(document, profiles)],
                            ),
                            ExpansionTile(
                              key: const PageStorageKey('policy-budgets'),
                              title: Text(strings.policyBudgetTab),
                              children: [_budgets(document, sources, snapshot)],
                            ),
                          ]),
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

class _PolicySourceFacts extends ConsumerWidget {
  const _PolicySourceFacts({required this.profile});
  final Profile profile;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.appLocalizations;
    final metadata = profile.subscriptionInfo?.metadata;
    final remaining = metadata?.remainingBytes;
    return ExpansionTile(
      title: Text(profile.realLabel),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SubscriptionInfoView(
          subscriptionInfo: profile.subscriptionInfo,
          showUnknown: true,
          updatedAt: profile.lastUpdateDate,
        ),
      ),
      children: [
        ListTile(
          title: Text(strings.policySourceQuota),
          subtitle: Text(
            remaining == null
                ? strings.policyTrafficUnknown
                : '${policyGiB(remaining)} GiB',
          ),
        ),
      ],
    );
  }
}
