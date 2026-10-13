import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/profile.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:flutter/material.dart';

import 'widgets.dart';

class PolicyIntegrationEditor extends StatefulWidget {
  const PolicyIntegrationEditor({
    super.key,
    this.existing,
    required this.profiles,
    required this.loadNodes,
  });
  final SubscriptionIntegration? existing;
  final List<Profile> profiles;
  final Future<List<LocalNode>> Function(List<int>) loadNodes;
  @override
  State<PolicyIntegrationEditor> createState() =>
      _PolicyIntegrationEditorState();
}

class _PolicyIntegrationEditorState extends State<PolicyIntegrationEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _filter;
  late final Set<int> _sources;
  late List<String> _excluded;
  late PolicyFallback _fallback;
  List<LocalNode> _nodes = [];
  bool _loading = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.label ?? '');
    _filter = TextEditingController(text: widget.existing?.nameFilter ?? '');
    _sources = {...?widget.existing?.sourceProfileIds};
    _excluded = [...?widget.existing?.excludedNodeIds];
    _fallback = widget.existing?.fallback ?? PolicyFallback.reject;
  }

  @override
  void dispose() {
    _name.dispose();
    _filter.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading || _sources.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final nodes = await widget.loadNodes(_sources.toList());
      if (mounted) setState(() => _nodes = nodes);
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.appLocalizations.policyOperationFailed);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    try {
      final integration = SubscriptionIntegration.fromJson({
        'id': widget.existing?.id ?? policyNewId(),
        'label': _name.text.trim(),
        'sourceProfileIds': _sources.toList(),
        'nameFilter': _filter.text.trim().isEmpty ? null : _filter.text.trim(),
        'excludedNodeIds': _excluded,
        'fallback': _fallback.name,
      });
      Navigator.of(context).pop(integration);
    } catch (_) {
      setState(() => _error = context.appLocalizations.policyInvalidData);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.appLocalizations;
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? strings.policyAddIntegration
            : strings.policyEditIntegration,
      ),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PolicyField(
                  key: const ValueKey('policy-integration-name'),
                  controller: _name,
                  label: strings.name,
                  required: true,
                ),
                Text(strings.policyIntegrationHint),
                const SizedBox(height: 12),
                Text(
                  strings.policySources,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                SizedBox(
                  height: 180,
                  child: ListView.builder(
                    itemCount: widget.profiles.length,
                    itemBuilder: (context, index) {
                      final profile = widget.profiles[index];
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: _sources.contains(profile.id),
                        title: Text(profile.label),
                        onChanged: _loading
                            ? null
                            : (value) => setState(() {
                                if (value == true) {
                                  _sources.add(profile.id);
                                } else {
                                  _sources.remove(profile.id);
                                }
                                _nodes = [];
                              }),
                      );
                    },
                  ),
                ),
                PolicyField(
                  controller: _filter,
                  label: strings.policyNameFilter,
                ),
                PolicyFallbackField(
                  value: _fallback,
                  onChanged: (value) => setState(() => _fallback = value),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _loading || _sources.isEmpty ? null : _load,
                  icon: const Icon(Icons.refresh),
                  label: Text(strings.policyLoadNodes),
                ),
                if (_loading) const LinearProgressIndicator(),
                if (_nodes.isNotEmpty || _excluded.isNotEmpty)
                  OrderedPolicyNodes(
                    nodes: _nodes,
                    value: _excluded,
                    exclusion: true,
                    onChanged: (value) => setState(() => _excluded = value),
                  ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: _loading ? null : _save,
          child: Text(strings.save),
        ),
      ],
    );
  }
}

class PolicyBudgetEditor extends StatefulWidget {
  const PolicyBudgetEditor({super.key, this.existing, required this.sources});
  final SourceBudget? existing;
  final Map<String, String> sources;
  @override
  State<PolicyBudgetEditor> createState() => _PolicyBudgetEditorState();
}

class _PolicyBudgetEditorState extends State<PolicyBudgetEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _limit;
  late final TextEditingController _reset;
  late String? _source;
  String? _error;
  @override
  void initState() {
    super.initState();
    _source = widget.existing?.sourceId ?? widget.sources.keys.firstOrNull;
    _limit = TextEditingController(
      text: widget.existing == null
          ? ''
          : (widget.existing!.limitBytes / (1024 * 1024 * 1024)).toString(),
    );
    _reset = TextEditingController(text: '${widget.existing?.resetDay ?? 1}');
  }

  @override
  void dispose() {
    _limit.dispose();
    _reset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.appLocalizations;
    final sources = {
      ...widget.sources,
      if (_source != null && !widget.sources.containsKey(_source))
        _source!: _source!,
    };
    return AlertDialog(
      title: Text(strings.policyAddBudget),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _source,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: strings.policySources),
                  items: [
                    for (final entry in sources.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _source = value),
                ),
                const SizedBox(height: 16),
                PolicyField(
                  key: const ValueKey('policy-budget-limit'),
                  controller: _limit,
                  label: strings.policyBudgetGiB,
                  required: true,
                  numeric: true,
                ),
                PolicyField(
                  controller: _reset,
                  label: strings.policyResetDay,
                  required: true,
                  numeric: true,
                ),
                Text(strings.policyBudgetHint),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            try {
              final value = SourceBudget.fromJson({
                'sourceId': _source,
                'limitBytes': policyBytes(_limit.text),
                'resetDay': int.parse(_reset.text),
                'timeZone': widget.existing?.timeZone ?? 'Asia/Shanghai',
              });
              Navigator.of(context).pop(value);
            } catch (_) {
              setState(() => _error = strings.policyInvalidData);
            }
          },
          child: Text(strings.save),
        ),
      ],
    );
  }
}

class PolicyOverrideEditor extends StatefulWidget {
  const PolicyOverrideEditor({
    super.key,
    required this.policy,
    required this.nodes,
  });
  final LocalPolicy policy;
  final List<LocalNode> nodes;
  @override
  State<PolicyOverrideEditor> createState() => _PolicyOverrideEditorState();
}

class _PolicyOverrideEditorState extends State<PolicyOverrideEditor> {
  final _minutes = TextEditingController(text: '30');
  late String _node;
  String? _error;
  @override
  void initState() {
    super.initState();
    _node = widget.policy.candidateNodeIds.first;
  }

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.appLocalizations;
    final labels = {
      for (final node in widget.nodes)
        node.id: '${node.sourceLabel} · ${node.label}',
    };
    return AlertDialog(
      title: Text(strings.policyTemporaryOverride),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _node,
              isExpanded: true,
              items: [
                for (final id in widget.policy.candidateNodeIds)
                  DropdownMenuItem(
                    value: id,
                    child: Text(
                      labels[id] ?? strings.policyMissingNode,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _node = value);
              },
            ),
            const SizedBox(height: 16),
            PolicyField(
              controller: _minutes,
              label: strings.policyOverrideMinutes,
              numeric: true,
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: () {
            final minutes = int.tryParse(_minutes.text);
            if (minutes == null || minutes < 1 || minutes > 1440) {
              setState(() => _error = strings.policyInvalidData);
              return;
            }
            Navigator.of(context).pop(
              PolicyOverride(
                policyId: widget.policy.id,
                nodeId: _node,
                expiresAt: DateTime.now()
                    .add(Duration(minutes: minutes))
                    .millisecondsSinceEpoch,
              ),
            );
          },
          child: Text(strings.save),
        ),
      ],
    );
  }
}
