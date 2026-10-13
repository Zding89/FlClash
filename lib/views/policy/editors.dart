import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/profile.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:flutter/material.dart';

import 'widgets.dart';

Future<bool> _discardPolicyEdits(BuildContext context) async {
  final strings = context.appLocalizations;
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(strings.policyUnsavedTitle),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(strings.policyContinueEditing),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(strings.policyDiscardChanges),
            ),
          ],
        ),
      ) ==
      true;
}

class PolicyIntegrationEditor extends StatefulWidget {
  const PolicyIntegrationEditor({
    super.key,
    this.existing,
    required this.profiles,
    required this.loadNodes,
    this.onSave,
  });
  final SubscriptionIntegration? existing;
  final Future<void> Function(SubscriptionIntegration)? onSave;
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
  bool _saving = false;
  bool _leaving = false;
  late final String _initial;
  bool get _busy => _saving || _loading;
  String get _fingerprint => policyDigest({
    'name': _name.text,
    'filter': _filter.text,
    'sources': _sources.toList()..sort(),
    'excluded': _excluded,
    'fallback': _fallback.name,
  });
  String? _error;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.label ?? '');
    _filter = TextEditingController(text: widget.existing?.nameFilter ?? '');
    _sources = {...?widget.existing?.sourceProfileIds};
    _excluded = [...?widget.existing?.excludedNodeIds];
    _fallback = widget.existing?.fallback ?? PolicyFallback.reject;
    _initial = _fingerprint;
  }

  @override
  void dispose() {
    _name.dispose();
    _filter.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_busy || _leaving || _sources.isEmpty) return;
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

  Future<void> _leave() async {
    if (_busy || _leaving) return;
    _leaving = true;
    try {
      if (_initial != _fingerprint && !await _discardPolicyEdits(context)) {
        return;
      }
      if (mounted) Navigator.pop(context);
    } finally {
      _leaving = false;
    }
  }

  Future<void> _save() async {
    if (_busy || _leaving || !_form.currentState!.validate()) return;
    final SubscriptionIntegration integration;
    try {
      integration = SubscriptionIntegration.fromJson({
        'id': widget.existing?.id ?? policyNewId(),
        'label': _name.text.trim(),
        'sourceProfileIds': _sources.toList(),
        'nameFilter': _filter.text.trim().isEmpty ? null : _filter.text.trim(),
        'excludedNodeIds': _excluded,
        'fallback': _fallback.name,
      });
    } catch (_) {
      setState(() => _error = context.appLocalizations.policyInvalidData);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.onSave != null) await widget.onSave!(integration);
      if (mounted) Navigator.of(context).pop(integration);
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.appLocalizations.policyOperationFailed);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.appLocalizations;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: AlertDialog(
        title: Text(
          widget.existing == null
              ? strings.policyAddIntegration
              : strings.policyEditIntegration,
        ),
        content: AbsorbPointer(
          absorbing: _busy,
          child: ExcludeFocus(
            excluding: _busy,
            child: SizedBox(
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
                              onChanged: _busy
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
                        onChanged: (value) {
                          if (!_busy) setState(() => _fallback = value);
                        },
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _busy || _sources.isEmpty ? null : _load,
                        icon: const Icon(Icons.refresh),
                        label: Text(strings.policyLoadNodes),
                      ),
                      if (_busy) const LinearProgressIndicator(),
                      if (_nodes.isNotEmpty || _excluded.isNotEmpty)
                        OrderedPolicyNodes(
                          nodes: _nodes,
                          value: _excluded,
                          exclusion: true,
                          onChanged: (value) {
                            if (!_busy) setState(() => _excluded = value);
                          },
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
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : _leave,
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(strings.save),
          ),
        ],
      ),
    );
  }
}

class PolicyBudgetEditor extends StatefulWidget {
  const PolicyBudgetEditor({
    super.key,
    this.existing,
    required this.sources,
    this.onSave,
  });
  final SourceBudget? existing;
  final Future<void> Function(SourceBudget)? onSave;
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
  bool _saving = false;
  bool _leaving = false;
  late final String _initial;
  String get _fingerprint => policyDigest({
    'source': _source,
    'limit': _limit.text,
    'reset': _reset.text,
  });
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
    _initial = _fingerprint;
  }

  @override
  void dispose() {
    _limit.dispose();
    _reset.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_saving || _leaving) return;
    _leaving = true;
    try {
      if (_initial != _fingerprint && !await _discardPolicyEdits(context)) {
        return;
      }
      if (mounted) Navigator.pop(context);
    } finally {
      _leaving = false;
    }
  }

  Future<void> _save() async {
    if (_saving || _leaving || !_form.currentState!.validate()) return;
    final SourceBudget value;
    try {
      value = SourceBudget.fromJson({
        'sourceId': _source,
        'limitBytes': policyBytes(_limit.text),
        'resetDay': int.parse(_reset.text),
        'timeZone': widget.existing?.timeZone ?? 'Asia/Shanghai',
      });
    } catch (_) {
      setState(() => _error = context.appLocalizations.policyInvalidData);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.onSave != null) await widget.onSave!(value);
      if (mounted) Navigator.of(context).pop(value);
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.appLocalizations.policyOperationFailed);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.appLocalizations;
    final sources = {
      ...widget.sources,
      if (_source != null && !widget.sources.containsKey(_source))
        _source!: _source!,
    };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: AlertDialog(
        title: Text(strings.policyAddBudget),
        content: AbsorbPointer(
          absorbing: _saving,
          child: ExcludeFocus(
            excluding: _saving,
            child: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Form(
                  key: _form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_saving) const LinearProgressIndicator(),
                      DropdownButtonFormField<String>(
                        initialValue: _source,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: strings.policySources,
                        ),
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
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _source = value),
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
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _leave,
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(strings.save),
          ),
        ],
      ),
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
