import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/configuration/changes.dart';

import 'widgets.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PolicySimulationDialog extends ConsumerStatefulWidget {
  const PolicySimulationDialog({
    super.key,
    required this.document,
    required this.targets,
    required this.snapshot,
    required this.controller,
  });
  final LocalPolicyDocument document;
  final Map<String, String> targets;
  final Map<String, Object?> snapshot;
  final WorkbenchController controller;
  @override
  ConsumerState<PolicySimulationDialog> createState() =>
      _PolicySimulationDialogState();
}

class _PolicySimulationDialogState
    extends ConsumerState<PolicySimulationDialog> {
  late String _target;
  bool _assume = false;
  bool _busy = false;
  List<Map<String, Object?>>? _results;
  String? _error;
  final _steps = TextEditingController(text: '[]');
  List<Map<String, Object?>> _timeline = [];
  Map<String, String> _labels = {};

  @override
  void dispose() {
    _steps.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _target = widget.targets.keys.first;
  }

  Future<void> _simulate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final stepsJson = jsonDecode(_steps.text);
      if (stepsJson is! List || stepsJson.length > 32) {
        throw const FormatException('steps');
      }
      final steps = stepsJson
          .map((step) => policyObject(step, 'step'))
          .toList();
      final nodes = await widget.controller.loadNodes(_target);
      final sourceIds = nodes.map((node) => node.sourceId).toSet();
      final profiles = ref
          .read(profilesProvider)
          .where((profile) => sourceIds.contains('${profile.id}'))
          .toList();
      final sources = await widget.controller.profiles.loader.load(profiles);
      final health = <String, bool?>{
        for (final node in nodes) node.id: _assume ? true : null,
      };
      final policies = widget.snapshot['policies'];
      if (!_assume && policies is List) {
        for (final policy in policies.whereType<Map>()) {
          final statuses = policy['nodes'];
          if (statuses is List) {
            for (final status in statuses.whereType<Map>()) {
              final id = status['nodeId'];
              if (id is String &&
                  status['lastProbeAt'] is int &&
                  status['healthy'] is bool) {
                health[id] = status['healthy'] as bool;
              }
            }
          }
        }
      }
      final usage = <String, int>{};
      final budgets = widget.snapshot['budgets'];
      if (budgets is List) {
        for (final budget in budgets.whereType<Map>()) {
          if (budget['sourceId'] is String &&
              budget['usedBytes'] is int &&
              budget['trusted'] == true) {
            usage[budget['sourceId'] as String] = budget['usedBytes'] as int;
          }
        }
      }
      if (widget.document.budgetsEnabled &&
          widget.document.budgets.any(
            (budget) =>
                sourceIds.contains(budget.sourceId) &&
                !usage.containsKey(budget.sourceId),
          )) {
        throw const FormatException('Budget unknown');
      }
      final result = await widget.controller.simulatePolicies(
        document: widget.document.budgetsEnabled
            ? widget.document
            : LocalPolicyDocument.fromJson({
                ...widget.document.toJson(),
                'budgets': <Object?>[],
              }),
        targetId: _target,
        sources: sources,
        health: health,
        localUsage: usage,
        now: DateTime.now(),
        steps: steps,
      );
      if (mounted) {
        setState(() {
          _results = result.results;
          _timeline = result.timeline;
          _labels = {
            for (final node in nodes)
              node.id: '${node.sourceLabel} · ${node.label}',
          };
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              error is ConfigurationChangeException &&
                  error.code == 'configuration_core_required_for_simulation'
              ? context.appLocalizations.policySimulationCoreRequired
              : context.appLocalizations.policyOperationFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _timelineStep(Map<String, Object?> step) {
    final at = step['at'];
    final decisions = step['decisions'];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(at is int ? policyBeijingTime(at) : ''),
      subtitle: Text(
        decisions is List
            ? decisions
                  .whereType<Map>()
                  .map((decision) {
                    final id = decision['selectedNodeId'];
                    return '${decision['policyId']}: ${_labels[id] ?? (decision['state'] == 'direct' ? context.appLocalizations.policyFallbackDirect : context.appLocalizations.policyFallbackReject)}';
                  })
                  .join('\n')
            : '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.appLocalizations;
    return AlertDialog(
      title: Text(strings.policySimulation),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.policySimulationHint),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _target,
                isExpanded: true,
                items: [
                  for (final target in widget.targets.entries)
                    DropdownMenuItem(
                      value: target.key,
                      child: Text(
                        target.value,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() {
                            _target = value;
                            _results = null;
                            _timeline = [];
                          });
                        }
                      },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(strings.policyAssumeHealthy),
                value: _assume,
                onChanged: _busy
                    ? null
                    : (value) => setState(() {
                        _assume = value;
                        _results = null;
                        _timeline = [];
                      }),
              ),
              if (_busy) const LinearProgressIndicator(),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(strings.policySimulationSteps),
                children: [
                  Text(strings.policySimulationStepsHint),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _steps,
                    enabled: !_busy,
                    minLines: 3,
                    maxLines: 8,
                    maxLength: 65536,
                    style: const TextStyle(fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              if (_timeline.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  strings.policySimulationTimeline,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                for (final step in _timeline) _timelineStep(step),
              ],
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              for (final result in _results ?? <Map<String, Object?>>[]) ...[
                const SizedBox(height: 16),
                Text(
                  widget.document.policies
                          .where((rule) => rule.id == result['policyId'])
                          .firstOrNull
                          ?.label ??
                      '${result['policyId']}',
                ),
                for (final candidate
                    in (result['candidates'] as List).whereType<Map>())
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      candidate['eligible'] == true
                          ? Icons.check_circle_outline
                          : Icons.remove_circle_outline,
                    ),
                    title: Text(
                      _labels[candidate['nodeId']] ?? '${candidate['nodeId']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      candidate['reason'] == 'health_unknown'
                          ? strings.policyUnknownHealth
                          : candidate['eligible'] == true
                          ? strings.policyEligible
                          : strings.policyExcluded,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _simulate,
          child: Text(strings.policySimulation),
        ),
      ],
    );
  }
}
