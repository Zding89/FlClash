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
import 'package:fl_clash/views/ai/assistant.dart';
import 'package:fl_clash/views/ai/errors.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'editors.dart';
import 'rule_editor.dart';
import 'simulation.dart';
import 'widgets.dart';
import 'node_set_editor.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/core/controller.dart';

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
  String? _viewTarget;
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
    await showDialog<SubscriptionIntegration>(
      context: context,
      builder: (_) => PolicyIntegrationEditor(
        existing: existing,
        profiles: profiles,
        loadNodes: (ids) async {
          final sources = await _controller.profiles.loader.load(
            profiles.where((p) => ids.contains(p.id)).toList(),
          );
          return sources
              .expand(_controller.profiles.compiler.extractNodes)
              .toList();
        },
        onSave: (next) async {
          await _commitDocument(
            document,
            LocalPolicyDocument.fromJson(
              _patch(document, {
                'integrations': [
                  for (final i in document.integrations)
                    (i.id == next.id ? next : i).toJson(),
                  if (existing == null) next.toJson(),
                ],
                'activeIntegrationId': document.activeIntegrationId ?? next.id,
              }),
            ),
          );
        },
      ),
    );
  }

  Future<void> _rule(
    LocalPolicyDocument document,
    Map<String, String> targets,
    LocalPolicy? existing,
  ) async {
    if (existing == null && document.activeIntegration == null) {
      await _integration(document, ref.read(profilesProvider), null);
      return;
    }
    final preferredTarget =
        existing?.targetId ??
        _viewTarget ??
        document.activeIntegration?.targetId;
    final orderedTargets = <String, String>{
      if (preferredTarget != null && targets.containsKey(preferredTarget))
        preferredTarget: targets[preferredTarget]!,
      if (existing != null) ...targets,
    };
    await showDialog<LocalPolicy>(
      context: context,
      builder: (_) => LocalPolicyEditor(
        existing: existing,
        targets: orderedTargets,
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
    if (policyDigest((await _controller.readPolicies()).toJson()) !=
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
    final target =
        existing?.targetId ??
        _viewTarget ??
        document.activeIntegration?.targetId ??
        targets.keys.firstOrNull;
    if (target == null) return;
    try {
      final nodes = await _controller.loadNodes(target);
      if (!mounted) return;
      final sourceIds = target.startsWith('integration:')
          ? document.integrations
                .firstWhere((i) => i.targetId == target)
                .sourceProfileIds
                .map((id) => '$id')
                .toSet()
          : {target.split(':').last};
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
    return _list([
      Text(strings.policySharedSetImpact),
      for (final set in document.nodeSets)
        Card(
          child: ListTile(
            title: Text(set.label),
            subtitle: Text(
              '${targets[set.targetId] ?? set.targetId} · ${set.regions.join(' · ')} · ${set.maxMultiplier ?? '—'}×',
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
        onPressed: _busy || targets.isEmpty
            ? null
            : () => _nodeSet(document, targets, snapshot, null),
        icon: const Icon(Icons.add),
        label: Text(strings.policyNodeSet),
      ),
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

  Widget _integrations(LocalPolicyDocument document, List<Profile> profiles) {
    final strings = context.appLocalizations;
    return _list([
      Text(strings.policyIntegrationHint),
      for (final profile in profiles) _PolicySourceFacts(profile: profile),
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
                      if (document.integrationEnabled &&
                          document.activeIntegrationId == integration.id) {
                        setState(() => _message = strings.policyDeleteLinked);
                        return;
                      }
                      final remaining = document.integrations
                          .where((entry) => entry.id != integration.id)
                          .toList();
                      final active =
                          document.activeIntegrationId == integration.id
                          ? null
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
    final selected =
        _viewTarget ??
        document.activeIntegration?.targetId ??
        targets.keys.firstOrNull;
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
          ? strings.policyModuleOffHint
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
              leading: draggable && rule.scope.type != PolicyMatchType.global
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
                '${rule.scope.type == PolicyMatchType.global ? strings.policyRemainingTraffic : rule.scope.values.join(' · ')} · $runtime',
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
                selections
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
                        rule.fallback == PolicyFallback.reject
                            ? strings.policyFallbackReject
                            : strings.policyFallbackDirect,
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
      if (targets.isNotEmpty)
        DropdownButtonFormField<String>(
          key: ValueKey(selected),
          initialValue: selected,
          isExpanded: true,
          decoration: InputDecoration(labelText: strings.policyTarget),
          items: [
            for (final entry in targets.entries)
              DropdownMenuItem(
                value: entry.key,
                child: Text(entry.value, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _busy
              ? null
              : (value) => setState(() => _viewTarget = value),
        ),
      const SizedBox(height: 12),
      Text(strings.policyRuleOrderHint),
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
          if (_busy || rules[oldIndex].scope.type == PolicyMatchType.global) {
            return;
          }
          final next = [...rules];
          final value = next.removeAt(oldIndex);
          final globalIndex = next.indexWhere(
            (p) => p.scope.type == PolicyMatchType.global,
          );
          next.insert(
            globalIndex >= 0 && newIndex > globalIndex ? globalIndex : newIndex,
            value,
          );
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
      Wrap(
        spacing: 12,
        children: [
          FilledButton.tonalIcon(
            onPressed:
                _busy || targets.isEmpty || document.policies.length >= 100
                ? null
                : () => _rule(document, targets, null),
            icon: const Icon(Icons.add),
            label: Text(strings.policyAddRule),
          ),
          OutlinedButton.icon(
            onPressed: _busy || selected == null
                ? null
                : () => showExtend(
                    context,
                    builder: (_) => AiAssistantView(
                      initialPrompt: strings.policyAiGenerationRequest(
                        selected,
                      ),
                    ),
                  ),
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text(strings.aiAssistantTitle),
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
    ]);
  }

  String _runtimeLabel(Map<dynamic, dynamic> status) {
    final strings = context.appLocalizations;
    if (status['reason'] == 'schedule_inactive') {
      return strings.policyScheduleSkip;
    }
    if (status['reason'] == 'recovery_hold') return strings.policyRecovery;
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
    final snapshot =
        ref.watch(localPolicyStatusProvider).asData?.value ??
        const <String, Object?>{};
    final value = ref.watch(localPoliciesProvider);
    return DefaultTabController(
      length: 5,
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
              for (final rule in document.policies)
                if (!profiles.any((p) => 'profile:${p.id}' == rule.targetId) &&
                    !document.integrations.any(
                      (i) => i.targetId == rule.targetId,
                    ))
                  rule.targetId: rule.targetId,
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
                    SwitchListTile(
                      title: Text(strings.policyModule),
                      subtitle: Text(strings.policyModuleOffHint),
                      value: document.moduleEnabled,
                      onChanged: _busy
                          ? null
                          : (enabled) => _operation(
                              (_) => _controller.selectPolicyTarget(
                                moduleEnabled: enabled,
                                approve: _approve,
                              ),
                            ),
                    ),
                    TabBar(
                      isScrollable: true,
                      tabs: [
                        Tab(text: strings.policyRulesTab),
                        Tab(text: strings.policyNodeSets),
                        Tab(text: strings.policySourcesCollection),
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
                          _rules(document, targets, snapshot),
                          _nodeSets(document, targets, snapshot),
                          _integrations(document, profiles),
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

class _PolicySourceFacts extends ConsumerWidget {
  const _PolicySourceFacts({required this.profile});
  final Profile profile;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.appLocalizations;
    return StreamBuilder<Map<String, Object?>?>(
      stream: ref
          .watch(workbenchDatabaseProvider)
          .watchSection('sourceMetadata:${profile.id}'),
      builder: (context, snapshot) {
        final known = snapshot.data ?? const {};
        final info = profile.subscriptionInfo;
        final expiry = known['expiresAt'] is int
            ? known['expiresAt'] as int
            : info != null && info.expire > 0
            ? info.expire * 1000
            : null;
        final remaining = known['remainingBytes'] == 0
            ? 0
            : info != null &&
                  info.total > 0 &&
                  info.knownFields.containsAll({'total', 'upload', 'download'})
            ? (info.total - info.upload - info.download).clamp(
                0,
                9007199254740991,
              )
            : null;
        return ExpansionTile(
          title: Text(profile.realLabel),
          subtitle: Text(
            '${strings.policySourceQuota}: ${remaining == null ? strings.policyUnknownAttribute : '${policyGiB(remaining)} GiB'}',
          ),
          children: [
            ListTile(
              title: Text(strings.policySourceExpiry),
              subtitle: Text(
                expiry == null
                    ? strings.policyUnknownAttribute
                    : policyBeijingTime(expiry),
              ),
            ),
          ],
        );
      },
    );
  }
}
