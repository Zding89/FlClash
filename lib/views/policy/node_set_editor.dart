import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/policy/quota_overview.dart';
import 'package:flutter/material.dart';

import 'widgets.dart';
import 'editor_section.dart';
import 'selection_fields.dart';
import 'preference_editor.dart';
import 'schedule_editor.dart';
import 'node_set_members.dart';

final class PolicyNodeSetEdit {
  final PolicyNodeSet nodeSet;
  final Map<String, NodeAttributes> attributes;
  const PolicyNodeSetEdit(this.nodeSet, this.attributes);
}

class PolicyNodeSetEditor extends StatefulWidget {
  final PolicyNodeSet? existing;
  final String targetId;
  final Map<String, String> sources;
  final List<LocalNode> nodes;
  final Map<String, QuotaSourceSummary> sourceSummaries;
  final Map<String, QuotaSourceSummary> Function()? loadSourceSummaries;
  final Map<String, NodeAttributes> attributes;
  final Map<String, Object?> snapshot;
  final List<String> referencedRules;
  final Future<void> Function(PolicyNodeSetEdit)? onSave;
  final Future<void> Function(String)? onCheck;
  final Future<Map<String, Object?>> Function(Map<String, Object?>)? loadStatus;
  final Future<Map<String, String>> Function()? onManageSources;
  final Future<List<LocalNode>> Function()? loadNodes;
  const PolicyNodeSetEditor({
    super.key,
    this.existing,
    required this.targetId,
    required this.sources,
    required this.nodes,
    this.sourceSummaries = const {},
    this.loadSourceSummaries,
    this.attributes = const {},
    this.snapshot = const {},
    this.referencedRules = const [],
    this.onSave,
    this.onCheck,
    this.loadStatus,
    this.onManageSources,
    this.loadNodes,
  });
  @override
  State<PolicyNodeSetEditor> createState() => _PolicyNodeSetEditorState();
}

class _PolicyNodeSetEditorState extends State<PolicyNodeSetEditor> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  late Set<String> _sources;
  late Set<String> _regions;
  late UnknownMultiplier _unknown;
  late NodeSetStrategy _strategy;
  late List<NodePreference> _preferences;
  late NodeSelectionMode _selectionMode;
  late NodeBalanceStrategy _balanceStrategy;
  late PolicySchedule _scheduleValue;
  late Set<String> _excludedSources;
  late Set<String> _excludedRegions;
  late bool _hide;
  late bool _automatic;
  late bool _unknownRegion;
  late String _method;
  bool _advanced = false;
  bool _showMembers = false;
  final _settingsScroll = ScrollController();
  final _membersKey = GlobalKey();
  bool _busy = false;
  bool _managingSources = false;
  bool _validityEdited = false;
  bool _updatingValidity = false;
  String _validityText = '';
  String? _error;
  String _initial = '';
  String _lastFingerprint = '';
  final _attributes = <String, NodeAttributes>{};
  late Map<String, String> _sourceOptions;
  late List<LocalNode> _nodes;
  Timer? _statusTimer;
  Map<String, Object?>? _details;
  int _statusEpoch = 0;
  int _statusTicks = 0;
  bool _statusLoading = false;
  static const _pageSize = 200;
  @override
  void initState() {
    super.initState();
    final set = widget.existing;
    _sourceOptions = {...widget.sources};
    _nodes = [...widget.nodes];
    final probe =
        set?.probe ??
        const PolicyProbe(
          intervalSeconds: 60,
          method: 'GET',
          expectedStatus: '204',
        );
    _sources = set == null ? {..._sourceOptions.keys} : {...set.sourceIds};
    _regions = {...?set?.regions};
    _unknown = set?.unknownMultiplier ?? UnknownMultiplier.assumeOne;
    _strategy = set?.strategy ?? NodeSetStrategy.stable;
    _preferences =
        set != null &&
            set.preferences.isEmpty &&
            set.strategy != NodeSetStrategy.stable
        ? [
            NodePreference(
              type: set.strategy == NodeSetStrategy.latency
                  ? NodePreferenceType.latency
                  : NodePreferenceType.multiplier,
              direction: SortDirection.ascending,
            ),
          ]
        : [...?set?.preferences];
    _selectionMode = set?.selectionMode ?? NodeSelectionMode.priority;
    _balanceStrategy = set?.balanceStrategy ?? NodeBalanceStrategy.roundRobin;
    _scheduleValue = set?.schedule ?? const PolicySchedule();
    _excludedSources = {...?set?.excludedSourceIds};
    _excludedRegions = {...?set?.excludedRegions};
    _hide = set?.hideUnavailable ?? true;
    _automatic = probe.automatic;
    _unknownRegion = set?.allowUnknownRegion ?? false;
    _method = probe.method;
    _attributes.addAll(widget.attributes);
    for (final entry in {
      'label': set?.label ?? '',
      'nameIncludes': set?.nameIncludes.join('\n') ?? '',
      'nameExcludes': set?.nameExcludes.join('\n') ?? '',
      'cap': set?.maxMultiplier?.toString() ?? '',
      'url': probe.url,
      'interval': '${probe.intervalSeconds}',
      'timeout': '${probe.timeoutSeconds}',
      'failures': '${probe.failureThreshold}',
      'successes': '${probe.successThreshold}',
      'status': probe.expectedStatus,
      'retry': '${probe.retrySeconds}',
      'validity': '${probe.validitySeconds}',
      'recovery': '${set?.recoverySeconds ?? 300}',
      'cooldown': '${set?.cooldownSeconds ?? 60}',
      'improvement': '${set?.improvementPercent ?? 20}',
    }.entries) {
      _fields[entry.key] = TextEditingController(text: entry.value)
        ..addListener(entry.key == 'validity' ? _validityChanged : _changed);
    }
    _validityText = _fields['validity']!.text;
    _updateDefaultValidity();
    _initial = _fingerprint;
    _lastFingerprint = _initial;
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      final ticks = ((_nodes.length + _pageSize - 1) ~/ _pageSize).clamp(1, 10);
      if (!_statusLoading && ++_statusTicks >= ticks) {
        _statusTicks = 0;
        unawaited(_refreshStatus());
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refreshStatus());
    });
  }

  Future<void> _refreshStatus() async {
    final load = widget.loadStatus;
    final revision = widget.snapshot['revision'];
    if (load == null ||
        widget.existing == null ||
        revision is! int ||
        _fingerprint != _initial ||
        _statusLoading) {
      return;
    }
    final epoch = ++_statusEpoch;
    final fingerprint = _fingerprint;
    bool current() =>
        mounted && epoch == _statusEpoch && fingerprint == _fingerprint;
    _statusTicks = 0;
    setState(() => _statusLoading = true);
    try {
      Map<String, Object?>? first;
      final rows = <Map<String, Object?>>[];
      var total = 0;
      for (var offset = 0; offset < 5000; offset += _pageSize) {
        final result = await load({
          'revision': revision,
          'nodeSetId': widget.existing!.id,
          'offset': offset,
          'limit': _pageSize,
          'includeUnavailable': true,
        });
        if (!current()) return;
        final probe = result['probe'];
        final page = result['nodes'];
        final pageTotal = result['total'];
        if (result['revision'] != revision ||
            result['nodeSetId'] != widget.existing!.id ||
            result['offset'] != offset ||
            probe is! Map ||
            page is! List ||
            pageTotal is! int ||
            pageTotal < 0 ||
            pageTotal > 5000 ||
            first != null && pageTotal != total ||
            policyDigest(probe) !=
                policyDigest(widget.existing!.probe.toJson())) {
          setState(() => _details = null);
          return;
        }
        first ??= result;
        total = pageTotal;
        rows.addAll(
          page.whereType<Map>().map((row) => Map<String, Object?>.from(row)),
        );
        if (offset + _pageSize >= total) break;
      }
      if (!current()) return;
      if (rows.length != total ||
          rows.map((row) => row['nodeId']).toSet().length != total) {
        setState(() => _details = null);
        return;
      }
      setState(
        () => _details = {
          ...?first,
          'nodes': rows,
          'offset': 0,
          'hasMore': false,
        },
      );
    } catch (_) {
      if (current()) setState(() => _details = null);
    } finally {
      if (current()) setState(() => _statusLoading = false);
    }
  }

  Future<void> _checkNow() async {
    if (_busy ||
        widget.onCheck == null ||
        widget.existing == null ||
        _fingerprint != _initial) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onCheck!(widget.existing!.id);
      if (mounted) await _refreshStatus();
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.appLocalizations.policyOperationFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _changed() {
    _updateDefaultValidity();
    if (mounted) setState(() {});
  }

  void _validityChanged() {
    if (_updatingValidity) return;
    final text = _fields['validity']!.text;
    if (text == _validityText) return;
    _validityText = text;
    _validityEdited = true;
    _changed();
  }

  int get _recommendedValidity {
    final sameTarget = widget.snapshot['targetId'] == widget.targetId;
    int snapshotNumber(String key, int maximum) {
      final value = widget.snapshot[key];
      return sameTarget && value is int ? value.clamp(0, maximum) : 0;
    }

    int inputNumber(String key, int fallback, int maximum) {
      final value = int.tryParse(_fields[key]!.text);
      return value != null && value > 0 && value <= maximum ? value : fallback;
    }

    final existingTasks = snapshotNumber('checkTaskCount', 5000);
    final existingTimeout = snapshotNumber('maxCheckTimeoutSeconds', 60);
    final existingCycle = snapshotNumber(
      'recommendedCheckCycleSeconds',
      200000,
    );
    final existingWait =
        (existingCycle - ((existingTasks + 7) ~/ 8) * (existingTimeout + 1))
            .clamp(0, 200000);
    final tasks = (_nodes.length + existingTasks).clamp(0, 5000);
    final timeout = inputNumber('timeout', 5, 60);
    final maxTimeout = timeout > existingTimeout ? timeout : existingTimeout;
    final interval = inputNumber('interval', 60, 86400);
    final retry = inputNumber('retry', 180, 86400);
    final wait = [
      interval,
      retry,
      existingWait,
    ].reduce((a, b) => a > b ? a : b);
    final cycle =
        (((tasks + 7) ~/ 8) * (maxTimeout + 1) + wait + 59) ~/ 60 * 60;
    return cycle < 600 ? 600 : cycle;
  }

  void _updateDefaultValidity() {
    if (widget.existing != null || _validityEdited || _updatingValidity) return;
    final controller = _fields['validity'];
    if (controller == null) return;
    final value = _recommendedValidity.clamp(600, 86400).toString();
    if (controller.text == value) return;
    _updatingValidity = true;
    _validityText = value;
    controller.text = value;
    _updatingValidity = false;
  }

  Future<void> _manageSources() async {
    final callback = widget.onManageSources;
    if (_busy || _managingSources || callback == null) return;
    setState(() => _managingSources = true);
    try {
      final sources = await callback();
      if (!mounted) return;
      var nodes = _nodes;
      if (widget.loadNodes != null) {
        try {
          nodes = await widget.loadNodes!();
        } catch (_) {
          nodes = nodes
              .where((node) => sources.containsKey(node.sourceId))
              .toList();
          if (mounted) {
            setState(
              () => _error = context.appLocalizations.policyOperationFailed,
            );
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _sourceOptions = {...sources};
        _nodes = nodes;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.appLocalizations.policyInvalidData);
      }
    } finally {
      if (mounted) setState(() => _managingSources = false);
    }
  }

  @override
  void didUpdateWidget(covariant PolicyNodeSetEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateDefaultValidity();
  }

  String get _fingerprint => policyDigest({
    'fields': _fields.map((k, v) => MapEntry(k, v.text)),
    'sources': _sources.toList(),
    'excludedSources': _excludedSources.toList()..sort(),
    'excludedRegions': _excludedRegions.toList()..sort(),
    'preferences': _preferences.map((value) => value.toJson()).toList(),
    'selectionMode': _selectionMode.name,
    'balanceStrategy': _balanceStrategy.name,
    'schedule': _scheduleValue.toJson(),
    'regions': _regions.toList()..sort(),
    'unknown': _unknown.name,
    'strategy': _strategy.name,
    'hide': _hide,
    'automatic': _automatic,
    'unknownRegion': _unknownRegion,
    'method': _method,
    'attributes': _attributes.map((k, v) => MapEntry(k, v.toJson())),
  });
  @override
  void dispose() {
    _statusEpoch++;
    _statusTimer?.cancel();
    _settingsScroll.dispose();
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _leave() async {
    if (_busy || _managingSources) return;
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

  PolicyNodeSet _value() => PolicyNodeSet.fromJson({
    'id': widget.existing?.id ?? policyNewId(),
    'label': _fields['label']!.text.trim().isEmpty
        ? _regions.isEmpty
              ? context.appLocalizations.policyNodeSet
              : _regions
                    .map(
                      (region) =>
                          policyRegionOptions(context, _regions)[region] ??
                          region,
                    )
                    .join(' · ')
        : _fields['label']!.text.trim(),
    'targetId': widget.targetId,
    'sourceIds': _sources.toList(),
    'excludedSourceIds': _excludedSources.toList(),
    'excludedRegions': _excludedRegions.toList(),
    'nameIncludes': _fields['nameIncludes']!.text
        .split('\n')
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList(),
    'nameExcludes': _fields['nameExcludes']!.text
        .split('\n')
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList(),
    'preferences': _preferences.map((p) => p.toJson()).toList(),
    'selectionMode': _selectionMode.name,
    'balanceStrategy': _balanceStrategy.name,
    'schedule': _scheduleValue.toJson(),
    'regions': _regions.toList(),
    'maxMultiplier': _fields['cap']!.text.trim().isEmpty
        ? null
        : double.parse(_fields['cap']!.text),
    'unknownMultiplier': _unknown.name,
    'allowUnknownRegion': _unknownRegion,
    'strategy': _strategy.name,
    'hideUnavailable': _hide,
    'probe': {
      'url': _fields['url']!.text.trim(),
      'method': _method,
      'automatic': _automatic,
      'intervalSeconds': int.parse(_fields['interval']!.text),
      'timeoutSeconds': int.parse(_fields['timeout']!.text),
      'failureThreshold': int.parse(_fields['failures']!.text),
      'successThreshold': int.parse(_fields['successes']!.text),
      'expectedStatus': _fields['status']!.text.trim(),
      'retrySeconds': int.parse(_fields['retry']!.text),
      'validitySeconds': int.parse(_fields['validity']!.text),
    },
    'recoverySeconds': int.parse(_fields['recovery']!.text),
    'cooldownSeconds': int.parse(_fields['cooldown']!.text),
    'improvementPercent': int.parse(_fields['improvement']!.text),
  });
  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = PolicyNodeSetEdit(_value(), Map.unmodifiable(_attributes));
      if (widget.onSave != null) await widget.onSave!(result);
      if (mounted) Navigator.pop(context, result);
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.appLocalizations.policyInvalidData);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(String key, String label, {bool required = true}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: PolicyField(
      controller: _fields[key]!,
      label: label,
      required: required,
      numeric: !{
        'url',
        'label',
        'status',
        'nameIncludes',
        'nameExcludes',
      }.contains(key),
      maxLines: {'nameIncludes', 'nameExcludes'}.contains(key) ? 2 : 1,
    ),
  );
  String get _preset {
    if (_method != 'GET') return 'custom';
    if (_fields['url']!.text == 'https://www.gstatic.com/generate_204' &&
        _fields['status']!.text == '204') {
      return 'google';
    }
    if (_fields['url']!.text == 'https://cp.cloudflare.com/generate_204' &&
        _fields['status']!.text == '204') {
      return 'cloudflare';
    }
    if (_fields['url']!.text ==
            'http://www.msftconnecttest.com/connecttest.txt' &&
        _fields['status']!.text == '200') {
      return 'microsoft';
    }
    return 'custom';
  }

  Widget _checks() {
    final strings = context.appLocalizations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(_preset),
          initialValue: _preset,
          isExpanded: true,
          decoration: InputDecoration(labelText: strings.policyCheckPreset),
          items: [
            const DropdownMenuItem(
              value: 'google',
              child: Text('Google · GET / 204'),
            ),
            const DropdownMenuItem(
              value: 'cloudflare',
              child: Text('Cloudflare · GET / 204'),
            ),
            const DropdownMenuItem(
              value: 'microsoft',
              child: Text('Microsoft · HTTP · GET / 200'),
            ),
            DropdownMenuItem(
              value: 'custom',
              child: Text(strings.policyCustomCheck),
            ),
          ],
          onChanged: _busy
              ? null
              : (value) {
                  if (value == null || value == 'custom') return;
                  setState(() {
                    _method = 'GET';
                    _fields['url']!.text = switch (value) {
                      'google' => 'https://www.gstatic.com/generate_204',
                      'cloudflare' => 'https://cp.cloudflare.com/generate_204',
                      _ => 'http://www.msftconnecttest.com/connecttest.txt',
                    };
                    _fields['status']!.text = value == 'microsoft'
                        ? '200'
                        : '204';
                  });
                },
        ),
        const SizedBox(height: 12),
        _field('url', strings.policyProbeUrl),
        if (!_advanced) Text(strings.policyCheckMeasurementHint),
      ],
    );
  }

  Widget _checkStatus() {
    final strings = context.appLocalizations;
    final unchanged = _fingerprint == _initial;
    final live = unchanged ? _details : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!unchanged)
          Text(strings.policyDraftStatusHint)
        else ...[
          if (_statusLoading) const LinearProgressIndicator(),
          Text(
            '${strings.policyChecksWaiting}: ${live?['checksWaiting'] ?? widget.snapshot['checksWaiting'] ?? '—'} · ${strings.policyChecksInFlight}: ${live?['checksInFlight'] ?? widget.snapshot['checksInFlight'] ?? '—'}',
          ),
          if (live?['sampleAt'] is int)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '${strings.policyPageSampleAt}: ${policyBeijingTime(live!['sampleAt'] as int)}',
              ),
            ),
          if (widget.onCheck != null && widget.existing != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          await widget.onCheck!(widget.existing!.id);
                        } catch (_) {
                          if (mounted) {
                            setState(
                              () => _error = strings.policyOperationFailed,
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                icon: const Icon(Icons.network_check),
                label: Text(strings.policyCheckNow),
              ),
            ),
        ],
        const SizedBox(height: 12),
        Text(
          strings.policyCheckMeasurementHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _advancedContent() {
    final strings = context.appLocalizations;
    final method = PolicyEditorSection(
      key: const ValueKey('node-set-check-method'),
      title: strings.policyCheckMethodSection,
      icon: Icons.track_changes,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _checks(),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(_method),
            initialValue: _method,
            decoration: InputDecoration(labelText: strings.policyMethod),
            items: [
              for (final m in ['GET', 'HEAD'])
                DropdownMenuItem(value: m, child: Text(m)),
            ],
            onChanged: _busy
                ? null
                : (value) {
                    if (value != null) setState(() => _method = value);
                  },
          ),
          const SizedBox(height: 12),
          _field('status', strings.policyExpectedStatus),
          _field('timeout', strings.policyProbeTimeout),
        ],
      ),
    );
    final frequency = PolicyEditorSection(
      key: const ValueKey('node-set-check-frequency'),
      title: strings.policyCheckFrequencySection,
      icon: Icons.schedule,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(strings.policyAutoCheck),
            value: _automatic,
            onChanged: _busy ? null : (v) => setState(() => _automatic = v),
          ),
          _field('interval', strings.policyProbeInterval),
          _field('retry', strings.policyRetrySeconds),
          _field('failures', strings.policyFailures),
          _field('successes', strings.policySuccesses),
          _field('validity', strings.policyValiditySeconds),
          if ((int.tryParse(_fields['validity']!.text) ?? 0) <
              _recommendedValidity)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                strings.policyCheckCapacityHint(_recommendedValidity),
              ),
            ),
          Text(
            strings.policyCheckFrequencyHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
    final selection = PolicyEditorSection(
      key: const ValueKey('node-set-selection-recovery'),
      title: strings.policySelectionRecoverySection,
      icon: Icons.shuffle,
      child: Column(
        children: [
          _field('recovery', strings.policyRecoverySeconds),
          _field('cooldown', strings.policyCooldownSeconds),
          _field('improvement', strings.policyImprovementPercent),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(strings.policyUnknownMultiplierAllowed),
            value: _unknown == UnknownMultiplier.allow,
            onChanged: _busy
                ? null
                : (v) => setState(
                    () => _unknown = v
                        ? UnknownMultiplier.allow
                        : UnknownMultiplier.exclude,
                  ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(strings.policyUnknownMetadata),
            value: _unknownRegion,
            onChanged: _busy ? null : (v) => setState(() => _unknownRegion = v),
          ),
        ],
      ),
    );
    final status = PolicyEditorSection(
      key: const ValueKey('node-set-check-status'),
      title: strings.policyCheckStatusSection,
      icon: Icons.monitor_heart_outlined,
      child: _checkStatus(),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(children: [method, frequency, selection, status]);
        }
        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: method),
                const SizedBox(width: 16),
                Expanded(child: frequency),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: selection),
                const SizedBox(width: 16),
                Expanded(child: status),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _formContent() {
    final strings = context.appLocalizations;
    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 10),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                strings.policyNodeSetConditions,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (widget.onManageSources != null)
              TextButton(
                key: const ValueKey('policy-node-set-manage-sources'),
                onPressed: _busy || _managingSources ? null : _manageSources,
                child: Text(strings.policySubscriptionSources),
              ),
          ],
        ),
        const SizedBox(height: 12),
        PolicyMultiSelect(
          compact: true,
          label: strings.policyIncludeSources,
          options: _sourceOptions,
          value: _sources.toList(),
          enabled: !_busy,
          onChanged: (values) => setState(() => _sources = values.toSet()),
        ),
        PolicyMultiSelect(
          compact: true,
          label: strings.policyIncludeRegions,
          options: policyRegionOptions(context, [
            ..._regions,
            ..._excludedRegions,
          ]),
          value: _regions.toList(),
          enabled: !_busy,
          onChanged: (values) => setState(() => _regions = values.toSet()),
        ),
        _field('cap', strings.policyMultiplierLimit, required: false),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(strings.policyUnknownOne),
          value: _unknown == UnknownMultiplier.assumeOne,
          onChanged: _busy
              ? null
              : (value) => setState(
                  () => _unknown = value == true
                      ? UnknownMultiplier.assumeOne
                      : UnknownMultiplier.exclude,
                ),
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(strings.policyNodeSetExclusions),
          maintainState: true,
          children: [
            PolicyMultiSelect(
              compact: true,
              label: strings.policyExcludeSources,
              options: _sourceOptions,
              value: _excludedSources.toList(),
              enabled: !_busy,
              onChanged: (values) =>
                  setState(() => _excludedSources = values.toSet()),
            ),
            PolicyMultiSelect(
              compact: true,
              label: strings.policyExcludeRegions,
              options: policyRegionOptions(context, [
                ..._regions,
                ..._excludedRegions,
              ]),
              value: _excludedRegions.toList(),
              enabled: !_busy,
              onChanged: (values) =>
                  setState(() => _excludedRegions = values.toSet()),
            ),
            _field('nameIncludes', strings.policyNameIncludes, required: false),
            _field('nameExcludes', strings.policyNameExcludes, required: false),
          ],
        ),
        section(strings.policySelectionMode),
        SegmentedButton<NodeSelectionMode>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: NodeSelectionMode.priority,
              label: Text(strings.policyPriorityMode),
            ),
            ButtonSegment(
              value: NodeSelectionMode.loadBalance,
              label: Text(strings.policyBalanceMode),
            ),
          ],
          selected: {_selectionMode},
          onSelectionChanged: (values) =>
              setState(() => _selectionMode = values.single),
        ),
        if (_selectionMode == NodeSelectionMode.loadBalance) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<NodeBalanceStrategy>(
            initialValue: _balanceStrategy,
            isExpanded: true,
            items: [
              DropdownMenuItem(
                value: NodeBalanceStrategy.roundRobin,
                child: Text(strings.policyRoundRobin),
              ),
              DropdownMenuItem(
                value: NodeBalanceStrategy.consistentHashing,
                child: Text(strings.policyConsistentHashing),
              ),
              DropdownMenuItem(
                value: NodeBalanceStrategy.stickySessions,
                child: Text(strings.policyStickySessions),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _balanceStrategy = value);
            },
          ),
        ],
        const SizedBox(height: 16),
        PolicyPreferenceEditor(
          compact: true,
          value: _preferences,
          onChanged: (values) => setState(() => _preferences = values),
        ),
        if (_preferences.any(
          (preference) => preference.type == NodePreferenceType.source,
        )) ...[
          const SizedBox(height: 12),
          Text(strings.policySourceOrderHint),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: _sources.length,
            onReorderItem: (oldIndex, newIndex) {
              final sources = _sources.toList();
              final source = sources.removeAt(oldIndex);
              sources.insert(newIndex, source);
              setState(() => _sources = sources.toSet());
            },
            itemBuilder: (context, index) {
              final id = _sources.elementAt(index);
              return ListTile(
                key: ValueKey('source-order-$id'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_indicator, size: 18),
                ),
                title: Text(_sourceOptions[id] ?? id),
              );
            },
          ),
        ],
        const SizedBox(height: 12),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(strings.policySchedule),
          subtitle: Text(
            _scheduleValue.windows.isEmpty
                ? strings.policyScheduleAllDay
                : strings.policyNodeSetTimed,
          ),
          maintainState: true,
          children: [
            PolicyScheduleEditor(
              value: _scheduleValue,
              onChanged: (value) => setState(() => _scheduleValue = value),
            ),
          ],
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(strings.policyAutoCheck),
          value: _automatic,
          onChanged: _busy
              ? null
              : (value) => setState(() => _automatic = value),
        ),
        ExpansionTile(
          key: const ValueKey('node-set-advanced-settings'),
          tilePadding: EdgeInsets.zero,
          title: Text(strings.advancedConfig),
          initiallyExpanded: _advanced,
          maintainState: true,
          onExpansionChanged: (value) => setState(() => _advanced = value),
          children: [_advancedContent()],
        ),
        if (widget.referencedRules.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            '${strings.policySharedSetImpact}: ${widget.referencedRules.join(' · ')}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Widget _members() {
    if (_lastFingerprint != _fingerprint) {
      _lastFingerprint = _fingerprint;
      _details = null;
      _statusEpoch++;
      _statusLoading = false;
      _statusTicks = 0;
    }
    PolicyNodeSet? set;
    try {
      set = _value();
    } catch (_) {}
    final allNodes = _nodes
        .map(
          (node) => LocalNode(
            id: node.id,
            sourceId: node.sourceId,
            label: node.label,
            sourceLabel: node.sourceLabel,
            protocol: node.protocol,
            raw: node.raw,
            attributes: _attributes[node.id] ?? node.attributes,
          ),
        )
        .toList();
    final matches = allNodes
        .where((node) => set != null && set.exclusion(node) == null)
        .toList();
    final snapshot = widget.snapshot['nodeSets'];
    final matching = snapshot is List
        ? snapshot
              .whereType<Map>()
              .where((entry) => entry['policyId'] == widget.existing?.id)
              .firstOrNull
        : null;
    final live = _fingerprint == _initial ? _details : null;
    final rows =
        live?['nodes'] ??
        (widget.loadStatus == null ? (matching?['nodes']) : null);
    final probeUnchanged =
        set != null &&
        widget.existing != null &&
        policyDigest(set.probe.toJson()) ==
            policyDigest(widget.existing!.probe.toJson());
    final states = <String, Map<String, Object?>>{
      if (rows is List && probeUnchanged && _fingerprint == _initial)
        for (final row in rows.whereType<Map>())
          if (row['nodeId'] is String)
            row['nodeId'] as String: Map<String, Object?>.from(row),
    };
    return PolicyNodeSetMembersView(
      key: _membersKey,
      nodes: matches,
      states: states,
      sourceSummaries:
          widget.loadSourceSummaries?.call() ?? widget.sourceSummaries,
      assumeUnknownMultiplier: _unknown == UnknownMultiplier.assumeOne,
      loading: _statusLoading,
      draft: widget.existing == null || _fingerprint != _initial,
      busy: _busy || _managingSources,
      onCheck:
          _fingerprint == _initial &&
              (live != null || matching != null) &&
              widget.onCheck != null &&
              widget.existing != null
          ? _checkNow
          : null,
      onEditAttributes: _busy || _managingSources ? null : _editAttributes,
    );
  }

  Future<void> _editAttributes(LocalNode node) async {
    final strings = context.appLocalizations;
    var region = node.attributes.region ?? '';
    var multiplier = node.attributes.multiplier?.toString() ?? '';
    final result = await showDialog<NodeAttributes>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${strings.policyManualAttribute} · ${node.label}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: region,
              onChanged: (value) => region = value,
              decoration: InputDecoration(
                labelText: '${strings.policyRegions} · ISO 3166-1',
              ),
            ),
            TextFormField(
              initialValue: multiplier,
              onChanged: (value) => multiplier = value,
              decoration: InputDecoration(
                labelText: strings.policyMultiplierLimit,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () {
              try {
                final r = region.trim().toUpperCase();
                final m = multiplier.trim();
                final value = NodeAttributes.fromJson({
                  'region': r.isEmpty ? null : r,
                  'multiplier': m.isEmpty ? null : double.parse(m),
                  'regionBasis': r.isEmpty ? 'unknown' : 'manual',
                  'multiplierBasis': m.isEmpty ? 'unknown' : 'manual',
                });
                Navigator.pop(context, value);
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(strings.policyInvalidData)),
                );
              }
            },
            child: Text(strings.save),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      setState(() => _attributes[node.id] = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.appLocalizations;
    final theme = Theme.of(context);
    final localTheme = theme.copyWith(
      textTheme: theme.textTheme.copyWith(
        bodyLarge: theme.textTheme.bodyLarge?.copyWith(fontSize: 14),
        bodyMedium: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
        bodySmall: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
        labelLarge: theme.textTheme.labelLarge?.copyWith(fontSize: 14),
        labelMedium: theme.textTheme.labelMedium?.copyWith(fontSize: 13),
        titleSmall: theme.textTheme.titleSmall?.copyWith(fontSize: 14),
        titleMedium: theme.textTheme.titleMedium?.copyWith(fontSize: 18),
        titleLarge: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
      ),
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: const OutlineInputBorder(),
      ),
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Theme(
        data: localTheme,
        child: LayoutBuilder(
          builder: (context, viewport) => Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            child: SizedBox(
              width: (viewport.maxWidth - 32).clamp(0, 1760),
              height:
                  (viewport.maxHeight -
                          MediaQuery.viewInsetsOf(context).bottom -
                          48)
                      .clamp(180, 1200),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: _busy || _managingSources
                                    ? null
                                    : _leave,
                                tooltip: strings.cancel,
                                icon: const Icon(Icons.arrow_back),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  strings.policyNodeSetEditTitle,
                                  style: localTheme.textTheme.titleLarge,
                                ),
                              ),
                            ],
                          ),
                          _field('label', strings.name, required: false),
                        ],
                      ),
                    ),
                    if (_busy || _managingSources)
                      const LinearProgressIndicator(minHeight: 2),
                    const Divider(height: 1),
                    Expanded(
                      child: AbsorbPointer(
                        absorbing: _busy || _managingSources,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final settings = Scrollbar(
                              controller: _settingsScroll,
                              thumbVisibility: constraints.maxWidth >= 900,
                              child: SingleChildScrollView(
                                key: const ValueKey('node-set-settings-scroll'),
                                controller: _settingsScroll,
                                padding: const EdgeInsets.all(16),
                                child: _formContent(),
                              ),
                            );
                            final members = _members();
                            if (constraints.maxWidth >= 900) {
                              final scale =
                                  MediaQuery.textScalerOf(context).scale(14) /
                                  14;
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    width: (324 * scale).clamp(304, 410),
                                    child: settings,
                                  ),
                                  const VerticalDivider(width: 1),
                                  Expanded(child: members),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: SegmentedButton<bool>(
                                    key: const ValueKey('node-set-mobile-view'),
                                    showSelectedIcon: false,
                                    segments: [
                                      ButtonSegment(
                                        value: false,
                                        label: Text(strings.general),
                                      ),
                                      ButtonSegment(
                                        value: true,
                                        label: Text(strings.policyNodes),
                                      ),
                                    ],
                                    selected: {_showMembers},
                                    onSelectionChanged: (values) => setState(
                                      () => _showMembers = values.single,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: IndexedStack(
                                    index: _showMembers ? 1 : 0,
                                    children: [settings, members],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: OverflowBar(
                        alignment: MainAxisAlignment.end,
                        spacing: 12,
                        children: [
                          TextButton(
                            onPressed: _busy || _managingSources
                                ? null
                                : _leave,
                            child: Text(strings.cancel),
                          ),
                          FilledButton(
                            onPressed: _busy || _managingSources ? null : _save,
                            child: Text(strings.policyCheckSave),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
