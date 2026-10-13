import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:flutter/material.dart';

import 'widgets.dart';
import 'match_editor.dart';
import 'node_set_editor.dart';

class LocalPolicyEditor extends StatefulWidget {
  const LocalPolicyEditor({
    super.key,
    this.existing,
    required this.targets,
    required this.loadNodes,
    this.initialPriority = 100,
    this.nodeSets = const [],
    this.attributes = const {},
    this.onSave,
    this.onPreview,
  });
  final LocalPolicy? existing;
  final Map<String, String> targets;
  final Future<List<LocalNode>> Function(String) loadNodes;
  final int initialPriority;
  final List<PolicyNodeSet> nodeSets;
  final Map<String, NodeAttributes> attributes;
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
  @override
  State<LocalPolicyEditor> createState() => _LocalPolicyEditorState();
}

class _LocalPolicyEditorState extends State<LocalPolicyEditor> {
  final _form = GlobalKey<FormState>();
  final Map<String, TextEditingController> _fields = {};
  late String _target;
  late PolicyMatchType _scope;
  late List<PolicyChoice> _choices;
  late List<PolicyNodeSet> _nodeSets;
  late Map<String, NodeAttributes> _attributes;
  bool _saving = false;
  String _initial = '';
  late PolicyFallback _fallback;
  late bool _enabled;
  late bool _recover;
  late bool _unknown;
  late bool _terminate;
  late bool _schedule;
  List<LocalNode> _nodes = [];
  bool _loading = false;
  bool _scheduleAdvanced = false;
  String? _error;
  int _nodeEpoch = 0;

  @override
  void initState() {
    super.initState();
    final policy = widget.existing;
    _target = policy?.targetId ?? widget.targets.keys.firstOrNull ?? '';
    _scope = policy?.scope.type ?? PolicyMatchType.domainSuffix;
    _choices = policy?.choices.isNotEmpty == true
        ? [...policy!.choices]
        : [
            for (final id in policy?.candidateNodeIds ?? <String>[])
              PolicyChoice(type: PolicyChoiceType.node, id: id),
          ];
    _nodeSets = [...widget.nodeSets];
    _attributes = {...widget.attributes};
    _fallback = policy?.fallback ?? PolicyFallback.reject;
    _enabled = policy?.enabled ?? true;
    _recover = policy?.autoRecover ?? true;
    _unknown =
        policy != null &&
        policy.guard.unknownBehavior != PolicyUnknownBehavior.allow;
    _terminate = policy?.terminateConnectionsOnExclusion ?? false;
    _schedule = policy?.schedule.windows.isNotEmpty ?? false;
    _scheduleAdvanced =
        (policy?.schedule.windows.length ?? 0) > 1 ||
        policy?.schedule.timeZone == 'UTC';
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
      'start': _clock(window.startMinute),
      'end': _clock(window.endMinute),
      'scheduleJson': jsonEncode(
        (policy?.schedule ?? const PolicySchedule()).toJson(),
      ),
    };
    for (final entry in initial.entries) {
      _fields[entry.key] = TextEditingController(text: entry.value);
    }
    _initial = _fingerprint;
    if (_target.isNotEmpty) _load();
  }

  String _clock(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
  int _minute(String value) {
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value);
    if (match == null) throw const FormatException();
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (minute > 59 || hour > 24 || hour == 24 && minute != 0) {
      throw const FormatException();
    }
    return hour * 60 + minute;
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
        setState(() => _error = context.appLocalizations.policyOperationFailed);
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
      final logical = [
        PolicyMatchType.all,
        PolicyMatchType.any,
        PolicyMatchType.not,
      ].contains(_scope);
      final scope = logical
          ? PolicyMatch.fromJson(
              policyObject(jsonDecode(_text('scopeJson')), 'scope'),
            )
          : PolicyMatch(
              type: _scope,
              values: _scope == PolicyMatchType.global
                  ? []
                  : _text('scope')
                        .split('\n')
                        .map((entry) => entry.trim())
                        .where((entry) => entry.isNotEmpty)
                        .toList(),
            );
      if (scope.type != _scope) throw const FormatException('scopeType');
      scope.validate();
      PolicySchedule schedule;
      if (!_schedule) {
        schedule = const PolicySchedule();
      } else if (_scheduleAdvanced) {
        schedule = PolicySchedule.fromJson(
          policyObject(jsonDecode(_text('scheduleJson')), 'schedule'),
        );
      } else {
        final days = _text(
          'weekdays',
        ).split(',').map((v) => int.parse(v.trim())).toList();
        final start = _minute(_text('start'));
        final end = _minute(_text('end'));
        if (start == end || start >= 1440) {
          throw const FormatException('invalid time window');
        }
        schedule = PolicySchedule(
          windows: start < end
              ? [
                  PolicyWindow(
                    weekdays: days,
                    startMinute: start,
                    endMinute: end,
                  ),
                ]
              : [
                  PolicyWindow(
                    weekdays: days,
                    startMinute: start,
                    endMinute: 1440,
                  ),
                  if (end > 0)
                    PolicyWindow(
                      weekdays: days.map((d) => d % 7 + 1).toList(),
                      startMinute: 0,
                      endMinute: end,
                    ),
                ],
        );
      }
      final policy = LocalPolicy(
        id: widget.existing?.id ?? policyNewId(),
        label: _text('name').isEmpty
            ? _scope == PolicyMatchType.global
                  ? context.appLocalizations.policyRemainingTraffic
                  : logical
                  ? _scopeLabel(_scope)
                  : _text('scope').split('\n').first
            : _text('name'),
        targetId: _target,
        candidateNodeIds:
            widget.existing?.choices.isEmpty == true &&
                _choices.every((c) => c.type == PolicyChoiceType.node)
            ? _choices.map((c) => c.id).toList()
            : const [],
        choices:
            widget.existing?.choices.isEmpty == true &&
                _choices.every((c) => c.type == PolicyChoiceType.node)
            ? const []
            : _choices,
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
        fallback: _fallback,
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
      PolicyMatchType.all => strings.policyMatchAll,
      PolicyMatchType.any => strings.policyMatchAny,
      PolicyMatchType.not => strings.policyMatchNot,
    };
  }

  PolicyMatchType _scopeCategory(PolicyMatchType type) => switch (type) {
    PolicyMatchType.domain ||
    PolicyMatchType.domainSuffix ||
    PolicyMatchType.domainKeyword => PolicyMatchType.domainSuffix,
    PolicyMatchType.processName ||
    PolicyMatchType.processPath => PolicyMatchType.processName,
    PolicyMatchType.all ||
    PolicyMatchType.any ||
    PolicyMatchType.not => PolicyMatchType.all,
    _ => type,
  };

  void _setScope(PolicyMatchType value) {
    if (_scope == value) return;
    setState(() {
      _scope = value;
      if ({
        PolicyMatchType.all,
        PolicyMatchType.any,
        PolicyMatchType.not,
      }.contains(value)) {
        _fields['scopeJson']!.text = jsonEncode(
          PolicyMatchEditor.empty(value).toJson(),
        );
      }
    });
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
    'fallback': _fallback.name,
    'enabled': _enabled,
    'recover': _recover,
    'unknown': _unknown,
    'terminate': _terminate,
    'schedule': _schedule,
  });

  Future<void> _leave() async {
    if (_saving) return;
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
    final value = _value();
    if (value == null || _saving) return;
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
        sources: {for (final n in _nodes) n.sourceId: n.sourceLabel},
        nodes: _nodes,
        attributes: _attributes,
      ),
    );
    if (next == null || !mounted) return;
    setState(() {
      _nodeSets.add(next.nodeSet);
      _attributes.addAll(next.attributes);
      _choices.add(
        PolicyChoice(type: PolicyChoiceType.nodeSet, id: next.nodeSet.id),
      );
    });
  }

  Widget _choiceEditor() {
    final strings = context.appLocalizations;
    final choices = <String, String>{
      for (final node in _nodes)
        'node:${node.id}':
            '${strings.policyFixedNode} · ${node.sourceLabel} · ${node.label}',
      for (final set in _nodeSets.where((s) => s.targetId == _target))
        'nodeSet:${set.id}': '${strings.policyNodeSet} · ${set.label}',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.policyPreferred,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (var index = 0; index < _choices.length; index++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Text(
                  index == 0
                      ? strings.policyPreferred
                      : '${strings.policyAddBackup} $index',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(
                      'choice-$index-${_choices[index].type.name}:${_choices[index].id}',
                    ),
                    initialValue:
                        '${_choices[index].type.name}:${_choices[index].id}',
                    isExpanded: true,
                    items: [
                      for (final entry in {
                        ...choices,
                        '${_choices[index].type.name}:${_choices[index].id}':
                            choices['${_choices[index].type.name}:${_choices[index].id}'] ??
                            '${strings.policySourceMissing} · ${_choices[index].id}',
                      }.entries)
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
                        : (value) {
                            if (value == null) return;
                            final colon = value.indexOf(':');
                            setState(
                              () => _choices[index] = PolicyChoice(
                                type: PolicyChoiceType.values.byName(
                                  value.substring(0, colon),
                                ),
                                id: value.substring(colon + 1),
                              ),
                            );
                          },
                  ),
                ),
                IconButton(
                  onPressed: _saving || index == 0
                      ? null
                      : () {
                          setState(() {
                            final choice = _choices.removeAt(index);
                            _choices.insert(index - 1, choice);
                          });
                        },
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() => _choices.removeAt(index)),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              ],
            ),
          ),
        Wrap(
          spacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: _saving || _choices.length >= 10 || choices.isEmpty
                  ? null
                  : () => setState(() {
                      final available = choices.keys
                          .where(
                            (key) => !_choices.any(
                              (c) => '${c.type.name}:${c.id}' == key,
                            ),
                          )
                          .firstOrNull;
                      if (available == null) return;
                      final colon = available.indexOf(':');
                      _choices.add(
                        PolicyChoice(
                          type: PolicyChoiceType.values.byName(
                            available.substring(0, colon),
                          ),
                          id: available.substring(colon + 1),
                        ),
                      );
                    }),
              icon: const Icon(Icons.add),
              label: Text(
                _choices.isEmpty
                    ? strings.policyPreferred
                    : strings.policyAddBackup,
              ),
            ),
            TextButton.icon(
              onPressed: _saving || _choices.length >= 10 || _nodes.isEmpty
                  ? null
                  : _newSet,
              icon: const Icon(Icons.filter_alt_outlined),
              label: Text(strings.policyNodeSet),
            ),
          ],
        ),
        Text(strings.policyPreviewHint),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.appLocalizations;
    final targets = {
      ...widget.targets,
      if (_target.isNotEmpty && !widget.targets.containsKey(_target))
        _target: _target,
    };
    final logical = [
      PolicyMatchType.all,
      PolicyMatchType.any,
      PolicyMatchType.not,
    ].contains(_scope);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: AlertDialog(
        title: Text(
          widget.existing == null
              ? strings.policyAddRule
              : strings.policyEditRule,
        ),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: AbsorbPointer(
              absorbing: _saving,
              child: Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _field('name', strings.name),
                    DropdownButtonFormField<String>(
                      initialValue: _target.isEmpty ? null : _target,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: strings.policyTarget,
                      ),
                      items: [
                        for (final target in targets.entries)
                          DropdownMenuItem(
                            value: target.key,
                            child: Text(
                              target.value,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) async {
                              if (value == null || value == _target) return;
                              if (_choices.isNotEmpty) {
                                final proceed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(strings.policySourceMissing),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: Text(strings.cancel),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: Text(strings.confirm),
                                      ),
                                    ],
                                  ),
                                );
                                if (proceed != true || !mounted) return;
                              }
                              setState(() {
                                _target = value;
                                _choices = [];
                                _nodes = [];
                              });
                              _load();
                            },
                    ),
                    const SizedBox(height: 16),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(strings.policyEnableRules),
                      value: _enabled,
                      onChanged: (value) => setState(() => _enabled = value),
                    ),
                    Text(
                      strings.policyRuleType,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in <PolicyMatchType, String>{
                          PolicyMatchType.domainSuffix: strings.policyWebsite,
                          PolicyMatchType.processName:
                              strings.policyApplication,
                          PolicyMatchType.global:
                              strings.policyRemainingTraffic,
                          PolicyMatchType.all: strings.policyCombinedConditions,
                        }.entries)
                          ChoiceChip(
                            label: Text(entry.value),
                            selected: _scopeCategory(_scope) == entry.key,
                            onSelected: (_) => _setScope(entry.key),
                          ),
                      ],
                    ),
                    if (_scope == PolicyMatchType.processName ||
                        _scope == PolicyMatchType.processPath)
                      Text(strings.policyProcessHint),
                    DropdownButtonFormField<PolicyMatchType>(
                      key: ValueKey('scope-${_scope.name}'),
                      initialValue: _scope,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: strings.policyScope,
                      ),
                      items: [
                        for (final type in PolicyMatchType.values.where(
                          (type) =>
                              type != PolicyMatchType.group ||
                              widget.existing?.scope.type ==
                                  PolicyMatchType.group,
                        ))
                          DropdownMenuItem(
                            value: type,
                            child: Text(
                              _scopeLabel(type),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) _setScope(value);
                      },
                    ),
                    const SizedBox(height: 16),
                    if (logical) ...[
                      PolicyMatchEditor(
                        value: _matchForEditor(),
                        onChanged: (value) => setState(
                          () => _fields['scopeJson']!.text = jsonEncode(
                            value.toJson(),
                          ),
                        ),
                      ),
                      ExpansionTile(
                        title: Text(strings.policyAdvancedJson),
                        children: [
                          _field(
                            'scopeJson',
                            strings.policyAdvancedJson,
                            lines: 3,
                          ),
                        ],
                      ),
                    ] else if (_scope != PolicyMatchType.global)
                      _field('scope', strings.policyScopeValues, lines: 3),
                    if (_loading || _saving) const LinearProgressIndicator(),
                    _choiceEditor(),
                    const SizedBox(height: 16),
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
                        _field('status', strings.policyExpectedStatus),
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
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(strings.policyRecovery),
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(strings.policyAutoRecover),
                          value: _recover,
                          onChanged: (value) =>
                              setState(() => _recover = value),
                        ),
                        _field(
                          'recovery',
                          strings.policyRecoverySeconds,
                          numeric: true,
                        ),
                        _field(
                          'cooldown',
                          strings.policyCooldownSeconds,
                          numeric: true,
                        ),
                      ],
                    ),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(strings.policySchedule),
                      children: [
                        Text(strings.policyScheduleHint),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(strings.policyScheduleEnabled),
                          value: _schedule,
                          onChanged: (value) =>
                              setState(() => _schedule = value),
                        ),
                        if (_schedule && _scheduleAdvanced)
                          _field(
                            'scheduleJson',
                            strings.policyAdvancedJson,
                            lines: 5,
                          ),
                        if (_schedule && !_scheduleAdvanced) ...[
                          _field('weekdays', strings.policyWeekdays),
                          _field('start', strings.policyStartTime),
                          _field('end', strings.policyEndTime),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    PolicyFallbackField(
                      value: _fallback,
                      onChanged: (value) => setState(() => _fallback = value),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(strings.policyTerminate),
                      subtitle: Text(strings.policyTerminateHint),
                      value: _terminate,
                      onChanged: (value) => setState(() => _terminate = value),
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
        actions: [
          TextButton(
            onPressed: _saving || widget.onPreview == null ? null : _preview,
            child: Text(strings.policySimulation),
          ),
          TextButton(
            onPressed: _saving ? null : _leave,
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: _loading || _saving ? null : _save,
            child: Text(strings.save),
          ),
        ],
      ),
    );
  }
}
