import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:flutter/material.dart';

import 'widgets.dart';

class LocalPolicyEditor extends StatefulWidget {
  const LocalPolicyEditor({
    super.key,
    this.existing,
    required this.targets,
    required this.loadNodes,
    this.initialPriority = 100,
  });
  final LocalPolicy? existing;
  final Map<String, String> targets;
  final Future<List<LocalNode>> Function(String) loadNodes;
  final int initialPriority;
  @override
  State<LocalPolicyEditor> createState() => _LocalPolicyEditorState();
}

class _LocalPolicyEditorState extends State<LocalPolicyEditor> {
  final _form = GlobalKey<FormState>();
  final Map<String, TextEditingController> _fields = {};
  late String _target;
  late PolicyMatchType _scope;
  late List<String> _candidates;
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
    _scope = policy?.scope.type ?? PolicyMatchType.global;
    _candidates = [...?policy?.candidateNodeIds];
    _fallback = policy?.fallback ?? PolicyFallback.reject;
    _enabled = policy?.enabled ?? true;
    _recover = policy?.autoRecover ?? true;
    _unknown = policy?.guard.unknownBehavior != PolicyUnknownBehavior.allow;
    _terminate = policy?.terminateConnectionsOnExclusion ?? false;
    _schedule = policy?.schedule.windows.isNotEmpty ?? false;
    _scheduleAdvanced =
        (policy?.schedule.windows.length ?? 0) > 1 ||
        policy?.schedule.timeZone == 'UTC';
    final probe = policy?.probe ?? const PolicyProbe();
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
    required: true,
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
      final schedule = !_schedule
          ? const PolicySchedule()
          : _scheduleAdvanced
          ? PolicySchedule.fromJson(
              policyObject(jsonDecode(_text('scheduleJson')), 'schedule'),
            )
          : PolicySchedule(
              windows: [
                PolicyWindow(
                  weekdays: _text(
                    'weekdays',
                  ).split(',').map((value) => int.parse(value.trim())).toList(),
                  startMinute: _minute(_text('start')),
                  endMinute: _minute(_text('end')),
                ),
              ],
            );
      final policy = LocalPolicy(
        id: widget.existing?.id ?? policyNewId(),
        label: _text('name'),
        targetId: _target,
        candidateNodeIds: _candidates,
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

  Future<void> _advanced() async {
    final current = _value();
    if (current == null) return;
    final next = await showDialog<LocalPolicy>(
      context: context,
      builder: (_) => PolicyJsonDialog(
        initial: current.toJson(),
        parse: (json) {
          final value = LocalPolicy.fromJson(json);
          if (value.id != current.id) throw const FormatException('identity');
          return value;
        },
      ),
    );
    if (next != null && mounted) Navigator.of(context).pop(next);
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
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? strings.policyAddRule
            : strings.policyEditRule,
      ),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
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
                  decoration: InputDecoration(labelText: strings.policyTarget),
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
                  onChanged: (value) {
                    if (value == null || value == _target) return;
                    setState(() {
                      _target = value;
                      _candidates = [];
                      _nodes = [];
                    });
                    _load();
                  },
                ),
                const SizedBox(height: 16),
                _field('priority', strings.policyPriority, numeric: true),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(strings.policyEnableRules),
                  value: _enabled,
                  onChanged: (value) => setState(() => _enabled = value),
                ),
                DropdownButtonFormField<PolicyMatchType>(
                  initialValue: _scope,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: strings.policyScope),
                  items: [
                    for (final type in PolicyMatchType.values)
                      DropdownMenuItem(
                        value: type,
                        child: Text(
                          _scopeLabel(type),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _scope = value);
                  },
                ),
                const SizedBox(height: 16),
                if (_scope != PolicyMatchType.global)
                  _field(
                    logical ? 'scopeJson' : 'scope',
                    logical
                        ? strings.policyAdvancedJson
                        : strings.policyScopeValues,
                    lines: 3,
                  ),
                if (_loading) const LinearProgressIndicator(),
                OrderedPolicyNodes(
                  nodes: _nodes,
                  value: _candidates,
                  onChanged: (value) => setState(() => _candidates = value),
                ),
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
                    _field('failures', strings.policyFailures, numeric: true),
                    _field('successes', strings.policySuccesses, numeric: true),
                    _field('status', strings.policyExpectedStatus),
                  ],
                ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(strings.policyAdmission),
                  children: [
                    _field('expiry', strings.policyExpiryMargin, numeric: true),
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
                      onChanged: (value) => setState(() => _unknown = value),
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
                      onChanged: (value) => setState(() => _recover = value),
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
                      onChanged: (value) => setState(() => _schedule = value),
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
      actions: [
        TextButton(
          onPressed: _advanced,
          child: Text(strings.policyAdvancedJson),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: _loading
              ? null
              : () {
                  final value = _value();
                  if (value != null) Navigator.of(context).pop(value);
                },
          child: Text(strings.save),
        ),
      ],
    );
  }
}
