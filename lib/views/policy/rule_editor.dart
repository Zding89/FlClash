import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:flutter/material.dart';

import 'widgets.dart';
import 'editor_section.dart';
import 'match_editor.dart';
import 'schedule_editor.dart';
import 'node_set_editor.dart';

class LocalPolicyEditor extends StatefulWidget {
  const LocalPolicyEditor({
    super.key,
    this.existing,
    this.targets = const {},
    this.sources = const {},
    required this.loadNodes,
    this.initialPriority = 100,
    this.nodeSets = const [],
    this.attributes = const {},
    this.referencedRules = const {},
    this.onSave,
    this.onPreview,
    this.onManageSources,
  });
  final LocalPolicy? existing;
  final Map<String, String> targets;
  final Map<String, String> sources;
  final Future<List<LocalNode>> Function(String) loadNodes;
  final int initialPriority;
  final List<PolicyNodeSet> nodeSets;
  final Map<String, NodeAttributes> attributes;
  final Map<String, List<String>> referencedRules;
  final Future<void> Function(
    LocalPolicy,
    List<PolicyNodeSet>,
    Map<String, NodeAttributes>,
  )?
  onSave;
  final Future<void> Function(
    LocalPolicy,
    List<PolicyNodeSet>,
    Map<String, NodeAttributes>,
  )?
  onPreview;
  final Future<Map<String, String>> Function()? onManageSources;
  @override
  State<LocalPolicyEditor> createState() => _LocalPolicyEditorState();
}

class _LocalPolicyEditorState extends State<LocalPolicyEditor> {
  final _form = GlobalKey<FormState>();
  final Map<String, TextEditingController> _fields = {};
  static const _target = localPolicyTargetId;
  late PolicyMatchType _scope;
  late List<PolicyChoice> _choices;
  late List<PolicyNodeSet> _nodeSets;
  late Map<String, NodeAttributes> _attributes;
  late Map<String, String> _sources;
  bool _saving = false;
  bool _managingSources = false;
  String _initial = '';
  late PolicyAction _action;
  late PolicySchedule _time;
  late bool _enabled;
  late bool _recover;
  late bool _unknown;
  late bool _terminate;
  List<LocalNode> _nodes = [];
  bool _loading = false;
  String? _error;
  int _nodeEpoch = 0;

  @override
  void initState() {
    super.initState();
    final policy = widget.existing;
    _scope = policy?.scope.type ?? PolicyMatchType.domainSuffix;
    _choices = policy?.choices.isNotEmpty == true
        ? [...policy!.choices]
        : [
            for (final id in policy?.candidateNodeIds ?? <String>[])
              PolicyChoice(type: PolicyChoiceType.node, id: id),
          ];
    _nodeSets = [...widget.nodeSets];
    _attributes = {...widget.attributes};
    _sources = {...widget.sources};
    _action = policy?.action ?? PolicyAction.proxy;
    _time = policy?.schedule ?? const PolicySchedule();
    _enabled = policy?.enabled ?? true;
    _recover = policy?.autoRecover ?? true;
    _unknown =
        policy != null &&
        policy.guard.unknownBehavior != PolicyUnknownBehavior.allow;
    _terminate = policy?.terminateConnectionsOnExclusion ?? false;
    final probe =
        policy?.probe ??
        const PolicyProbe(
          method: 'GET',
          intervalSeconds: 60,
          successThreshold: 3,
        );
    final guard = policy?.guard ?? const PolicyGuard();
    final window = policy?.schedule.windows.firstOrNull ?? const PolicyWindow();
    final initial = <String, String>{
      'name': policy?.label ?? '',
      'priority': '${policy?.priority ?? widget.initialPriority}',
      'scope': policy?.scope.values.join('\n') ?? '',
      'scopeJson': jsonEncode((policy?.scope ?? const PolicyMatch()).toJson()),
      'probeUrl': probe.url,
      'interval': '${probe.intervalSeconds}',
      'timeout': '${probe.timeoutSeconds}',
      'failures': '${probe.failureThreshold}',
      'successes': '${probe.successThreshold}',
      'status': probe.expectedStatus,
      'expiry': '${guard.expiryMarginSeconds / 3600}',
      'remaining': '${guard.minRemainingBytes / (1024 * 1024 * 1024)}',
      'metadata': '${guard.metadataMaxAgeSeconds / 3600}',
      'recovery': '${policy?.recoverySeconds ?? 300}',
      'cooldown': '${policy?.cooldownSeconds ?? 60}',
      'weekdays': window.weekdays.join(','),
      'start': '${window.startMinute}',
      'end': '${window.endMinute}',
      'scheduleJson': jsonEncode(
        (policy?.schedule ?? const PolicySchedule()).toJson(),
      ),
    };
    for (final entry in initial.entries) {
      _fields[entry.key] = TextEditingController(text: entry.value)
        ..addListener(_draftChanged);
    }
    _initial = _fingerprint;
    if (_target.isNotEmpty) _load();
  }

  void _draftChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final epoch = ++_nodeEpoch;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final nodes = await widget.loadNodes(_target);
      if (mounted && _nodeEpoch == epoch) setState(() => _nodes = nodes);
    } catch (_) {
      if (mounted && _nodeEpoch == epoch) {
        setState(() {
          _nodes = _nodes
              .where((node) => _sources.containsKey(node.sourceId))
              .toList();
          _error = context.appLocalizations.policyOperationFailed;
        });
      }
    } finally {
      if (mounted && _nodeEpoch == epoch) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nodeEpoch++;
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  String _text(String field) => _fields[field]!.text.trim();
  int _integer(String field) => int.parse(_text(field));
  int _seconds(String field) => (double.parse(_text(field)) * 3600).round();
  Widget _field(
    String field,
    String label, {
    bool numeric = false,
    int lines = 1,
  }) => PolicyField(
    key: ValueKey('policy-rule-$field'),
    controller: _fields[field]!,
    label: label,
    numeric: numeric,
    required: field != 'name',
    maxLines: lines,
  );

  LocalPolicy? _value() {
    if (!_form.currentState!.validate()) return null;
    try {
      final scope = PolicyMatch.fromJson(
        policyObject(jsonDecode(_text('scopeJson')), 'scope'),
      );
      final schedule = PolicySchedule.fromJson(_time.toJson());
      final description = policyMatchDescription(context, scope);
      final policy = LocalPolicy(
        id: widget.existing?.id ?? policyNewId(),
        label: _text('name').isEmpty
            ? description.substring(0, description.length.clamp(0, 200))
            : _text('name'),
        targetId: _target,
        action: _action,
        candidateNodeIds:
            _action == PolicyAction.proxy &&
                widget.existing?.choices.isEmpty == true &&
                _choices.every((choice) => choice.type == PolicyChoiceType.node)
            ? _choices.map((choice) => choice.id).toList()
            : const [],
        choices:
            _action == PolicyAction.proxy &&
                !(widget.existing?.choices.isEmpty == true &&
                    _choices.every(
                      (choice) => choice.type == PolicyChoiceType.node,
                    ))
            ? _choices
            : const [],
        origin: widget.existing?.origin ?? PolicyOrigin.manual,
        userModified: widget.existing != null,
        enabled: _enabled,
        priority: _integer('priority'),
        scope: scope,
        probe: PolicyProbe(
          url: _text('probeUrl'),
          intervalSeconds: _integer('interval'),
          timeoutSeconds: _integer('timeout'),
          failureThreshold: _integer('failures'),
          successThreshold: _integer('successes'),
          expectedStatus: _text('status'),
          method: widget.existing?.probe.method ?? 'GET',
          automatic: widget.existing?.probe.automatic ?? true,
          retrySeconds: widget.existing?.probe.retrySeconds ?? 180,
          validitySeconds: widget.existing?.probe.validitySeconds ?? 600,
        ),
        guard: PolicyGuard(
          expiryMarginSeconds: _seconds('expiry'),
          minRemainingBytes: policyBytes(_text('remaining')),
          metadataMaxAgeSeconds: _seconds('metadata'),
          unknownBehavior: _unknown
              ? PolicyUnknownBehavior.exclude
              : PolicyUnknownBehavior.allow,
        ),
        schedule: schedule,
        recoverySeconds: _integer('recovery'),
        cooldownSeconds: _integer('cooldown'),
        autoRecover: _recover,
        terminateConnectionsOnExclusion: _terminate,
      );
      return LocalPolicy.fromJson(policy.toJson());
    } catch (_) {
      setState(() => _error = context.appLocalizations.policyInvalidData);
      return null;
    }
  }

  String _scopeLabel(PolicyMatchType type) {
    final strings = context.appLocalizations;
    return switch (type) {
      PolicyMatchType.global => strings.policyGlobalScope,
      PolicyMatchType.group => strings.policyGroupScope,
      PolicyMatchType.domain => strings.policyDomainScope,
      PolicyMatchType.domainSuffix => strings.policyDomainSuffix,
      PolicyMatchType.domainKeyword => strings.policyDomainKeyword,
      PolicyMatchType.processName => strings.policyProcessName,
      PolicyMatchType.processPath => strings.policyProcessPath,
      PolicyMatchType.processPathRegex => strings.policyInstalledApps,
      PolicyMatchType.destinationRegion => strings.policyDestinationRegion,
      PolicyMatchType.ipCidr ||
      PolicyMatchType.ipCidr6 => strings.policyIpNetworks,
      PolicyMatchType.all => strings.policyMatchAll,
      PolicyMatchType.any => strings.policyMatchAny,
      PolicyMatchType.not => strings.policyMatchNot,
    };
  }

  PolicyMatch _matchForEditor() {
    try {
      final raw = policyObject(jsonDecode(_text('scopeJson')), 'scope');
      PolicyMatch parse(Map<String, Object?> entry) => PolicyMatch(
        type: PolicyMatchType.values.byName(entry['type'] as String),
        values: (entry['values'] as List? ?? []).cast<String>(),
        children: [
          for (final child in entry['children'] as List? ?? [])
            parse(policyObject(child, 'condition')),
        ],
      );
      final match = parse(raw);
      return match.type == _scope ? match : PolicyMatchEditor.empty(_scope);
    } catch (_) {
      return PolicyMatchEditor.empty(_scope);
    }
  }

  String get _fingerprint => policyDigest({
    'target': _target,
    'scope': _scope.name,
    'fields': _fields.map((k, v) => MapEntry(k, v.text)),
    'choices': _choices.map((c) => c.toJson()).toList(),
    'sets': _nodeSets.map((s) => s.toJson()).toList(),
    'attributes': _attributes.map((k, v) => MapEntry(k, v.toJson())),
    'action': _action.name,
    'scheduleValue': _time.toJson(),
    'enabled': _enabled,
    'recover': _recover,
    'unknown': _unknown,
    'terminate': _terminate,
  });

  Future<void> _leave() async {
    if (_saving || _managingSources) return;
    if (_initial != _fingerprint) {
      final strings = context.appLocalizations;
      final discard = await showDialog<bool>(
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
      );
      if (discard != true) return;
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _save() async {
    if (_saving || _managingSources) return;
    final value = _value();
    if (value == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.onSave != null) {
        await widget.onSave!(value, _nodeSets, _attributes);
      }
      if (mounted) Navigator.pop(context, value);
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.appLocalizations.policyOperationFailed);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _preview() async {
    final value = _value();
    if (value == null || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.onPreview?.call(value, _nodeSets, _attributes);
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.appLocalizations.policyOperationFailed);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _newSet() async {
    final next = await showDialog<PolicyNodeSetEdit>(
      context: context,
      builder: (_) => PolicyNodeSetEditor(
        targetId: _target,
        sources: {
          ..._sources,
          for (final n in _nodes) n.sourceId: n.sourceLabel,
        },
        nodes: _nodes,
        attributes: _attributes,
        referencedRules: const [],
        onManageSources: widget.onManageSources == null ? null : _manageSources,
        loadNodes: () => widget.loadNodes(_target),
      ),
    );
    if (next == null || !mounted) return;
    setState(() {
      _nodeSets.add(next.nodeSet);
      _attributes.addAll(next.attributes);
      _choices = [
        PolicyChoice(type: PolicyChoiceType.nodeSet, id: next.nodeSet.id),
      ];
    });
  }

  Future<void> _editSet(PolicyNodeSet set) async {
    final next = await showDialog<PolicyNodeSetEdit>(
      context: context,
      builder: (_) => PolicyNodeSetEditor(
        existing: set,
        targetId: _target,
        sources: {
          ..._sources,
          for (final n in _nodes) n.sourceId: n.sourceLabel,
        },
        nodes: _nodes,
        attributes: _attributes,
        referencedRules: widget.referencedRules[set.id] ?? const [],
        onManageSources: widget.onManageSources == null ? null : _manageSources,
        loadNodes: () => widget.loadNodes(_target),
      ),
    );
    if (next == null || !mounted) return;
    setState(() {
      final index = _nodeSets.indexWhere((value) => value.id == set.id);
      if (index == -1) {
        _nodeSets.add(next.nodeSet);
      } else {
        _nodeSets[index] = next.nodeSet;
      }
      _attributes.addAll(next.attributes);
    });
  }

  Future<Map<String, String>> _manageSources() async {
    if (_saving || _managingSources || widget.onManageSources == null) {
      return _sources;
    }
    setState(() => _managingSources = true);
    try {
      final sources = await widget.onManageSources!();
      if (!mounted) return sources;
      setState(() => _sources = {...sources});
      await _load();
      return sources;
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.appLocalizations.policyOperationFailed);
      }
      return _sources;
    } finally {
      if (mounted) setState(() => _managingSources = false);
    }
  }

  Widget _choiceEditor() {
    final strings = context.appLocalizations;
    final choices = <String, String>{
      for (final set in _nodeSets.where((s) => s.targetId == _target))
        'nodeSet:${set.id}': '${strings.policyNodeSet} · ${set.label}',
      for (final node in _nodes)
        'node:${node.id}':
            '${strings.policyFixedNode} · ${node.sourceLabel} · ${node.label}',
    };
    final selected = _choices.firstOrNull;
    final selectedKey = selected == null
        ? null
        : '${selected.type.name}:${selected.id}';
    final selectedId = selected?.id;
    final selectedSet = selected?.type == PolicyChoiceType.nodeSet
        ? _nodeSets.where((set) => set.id == selectedId).firstOrNull
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<PolicyAction>(
          segments: [
            ButtonSegment(
              value: PolicyAction.proxy,
              label: Text(strings.policyActionProxy),
            ),
            ButtonSegment(
              value: PolicyAction.direct,
              label: Text(strings.policyActionDirect),
            ),
            ButtonSegment(
              value: PolicyAction.reject,
              label: Text(strings.policyActionReject),
            ),
          ],
          selected: {_action},
          onSelectionChanged: (value) => setState(() => _action = value.single),
        ),
        if (_action == PolicyAction.proxy) ...[
          const SizedBox(height: 12),
          if (widget.onManageSources != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('policy-manage-subscription-sources'),
                onPressed: _saving || _managingSources ? null : _manageSources,
                icon: const Icon(Icons.source_outlined),
                label: Text(strings.policySubscriptionSources),
              ),
            ),
          if (_choices.length > 1) Text(strings.policyLegacySelections),
          if (_choices.length > 1)
            Text(
              _choices
                  .map(
                    (choice) =>
                        choices['${choice.type.name}:${choice.id}'] ??
                        strings.policySourceMissing,
                  )
                  .join(' · '),
            ),
          DropdownButtonFormField<String>(
            key: ValueKey('policy-processing-$selectedKey'),
            initialValue: selectedKey,
            isExpanded: true,
            decoration: InputDecoration(labelText: strings.policyNodeSet),
            items: [
              for (final entry in {
                ...choices,
                if (selectedKey != null && !choices.containsKey(selectedKey))
                  selectedKey: strings.policySourceMissing,
              }.entries)
                DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;
              final colon = value.indexOf(':');
              setState(
                () => _choices = [
                  PolicyChoice(
                    type: PolicyChoiceType.values.byName(
                      value.substring(0, colon),
                    ),
                    id: value.substring(colon + 1),
                  ),
                ],
              );
            },
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  key: const ValueKey('policy-add-node-set'),
                  onPressed: _saving || _managingSources ? null : _newSet,
                  icon: const Icon(Icons.add),
                  label: Text(strings.policyNodeSet),
                ),
                if (selectedSet != null)
                  TextButton.icon(
                    key: const ValueKey('policy-edit-node-set'),
                    onPressed: _saving || _managingSources
                        ? null
                        : () => _editSet(selectedSet),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(strings.edit),
                  ),
              ],
            ),
          ),
          Text(
            strings.policyNoNodeContinue,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Widget _effect() {
    final strings = context.appLocalizations;
    final nodeNames = {for (final node in _nodes) node.id: node.label};
    final setNames = {for (final set in _nodeSets) set.id: set.label};
    return PolicyEditorSection(
      key: const ValueKey('policy-current-effect'),
      title: strings.policyCurrentEffect,
      icon: Icons.visibility_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _scopeLabel(_scope),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(
            policyMatchDescription(context, _matchForEditor()).isEmpty
                ? strings.policyScopeValues
                : policyMatchDescription(context, _matchForEditor()),
            key: const ValueKey('policy-effect-match'),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Icon(Icons.arrow_downward, size: 20),
          ),
          Text(switch (_action) {
            PolicyAction.direct => strings.policyActionDirect,
            PolicyAction.reject => strings.policyActionReject,
            PolicyAction.proxy => strings.policyActionProxy,
          }, style: Theme.of(context).textTheme.titleSmall),
          if (_action == PolicyAction.proxy) ...[
            for (final choice in _choices)
              Text(
                choice.type == PolicyChoiceType.nodeSet
                    ? setNames[choice.id] ?? strings.policySourceMissing
                    : nodeNames[choice.id] ?? strings.policySourceMissing,
                key: ValueKey(
                  'policy-effect-choice-${_choices.indexOf(choice)}',
                ),
              ),
            Text(strings.policyNoNodeContinue),
          ],
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: _saving || widget.onPreview == null ? null : _preview,
            icon: const Icon(Icons.play_arrow_outlined),
            label: Text(strings.policySimulation),
          ),
          const SizedBox(height: 8),
          Text(
            strings.policyPreviewHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
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
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Text(
          widget.existing == null
              ? strings.policyAddRule
              : strings.policyEditRule,
        ),
        content: SizedBox(
          width: 1200,
          child: SingleChildScrollView(
            child: AbsorbPointer(
              absorbing: _saving || _managingSources,
              child: Form(
                key: _form,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final form = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_loading || _saving)
                          const LinearProgressIndicator(),
                        PolicyEditorSection(
                          key: const ValueKey('policy-traffic-section'),
                          step: 1,
                          title: strings.policyTrafficSection,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _field('name', strings.name),
                              const SizedBox(height: 4),

                              PolicyMatchEditor(
                                value: _matchForEditor(),
                                onChanged: (value) => setState(() {
                                  _scope = value.type;
                                  _fields['scopeJson']!.text = jsonEncode(
                                    value.toJson(),
                                  );
                                  _fields['scope']!.text = value.values.join(
                                    '\n',
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                        PolicyEditorSection(
                          key: const ValueKey('policy-choice-section'),
                          step: 2,
                          title: strings.policyChoiceSection,
                          child: _choiceEditor(),
                        ),
                        PolicyEditorSection(
                          key: const ValueKey('policy-schedule-section'),
                          step: 3,
                          title: strings.policySchedule,
                          child: PolicyScheduleEditor(
                            value: _time,
                            onChanged: (value) => setState(() => _time = value),
                          ),
                        ),
                        Card.filled(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ExpansionTile(
                            key: const ValueKey('policy-more-settings'),
                            maintainState: true,
                            title: Text(strings.policyMoreSettings),
                            childrenPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            children: [
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(strings.policyEnableRules),
                                value: _enabled,
                                onChanged: (value) =>
                                    setState(() => _enabled = value),
                              ),

                              ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: Text(strings.policyProbe),
                                children: [
                                  _field('probeUrl', strings.policyProbeUrl),
                                  _field(
                                    'interval',
                                    strings.policyProbeInterval,
                                    numeric: true,
                                  ),
                                  _field(
                                    'timeout',
                                    strings.policyProbeTimeout,
                                    numeric: true,
                                  ),
                                  _field(
                                    'failures',
                                    strings.policyFailures,
                                    numeric: true,
                                  ),
                                  _field(
                                    'successes',
                                    strings.policySuccesses,
                                    numeric: true,
                                  ),
                                  _field(
                                    'status',
                                    strings.policyExpectedStatus,
                                  ),
                                ],
                              ),
                              ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: Text(strings.policyAdmission),
                                children: [
                                  _field(
                                    'expiry',
                                    strings.policyExpiryMargin,
                                    numeric: true,
                                  ),
                                  _field(
                                    'remaining',
                                    strings.policyRemainingGiB,
                                    numeric: true,
                                  ),
                                  _field(
                                    'metadata',
                                    strings.policyMetadataAge,
                                    numeric: true,
                                  ),
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(strings.policyUnknownMetadata),
                                    value: _unknown,
                                    onChanged: (value) =>
                                        setState(() => _unknown = value),
                                  ),
                                ],
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(strings.policyTerminate),
                                subtitle: Text(strings.policyTerminateHint),
                                value: _terminate,
                                onChanged: (value) =>
                                    setState(() => _terminate = value),
                              ),
                            ],
                          ),
                        ),
                        if (_error != null)
                          Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                    );
                    if (constraints.maxWidth >= 800) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: form),
                          const SizedBox(width: 16),
                          Expanded(child: _effect()),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [form, _effect()],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving || _managingSources ? null : _leave,
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: _loading || _saving || _managingSources ? null : _save,
            child: Text(strings.save),
          ),
        ],
      ),
    );
  }
}
