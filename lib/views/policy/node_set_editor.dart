import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:flutter/material.dart';

import 'widgets.dart';

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
  final Map<String, NodeAttributes> attributes;
  final Map<String, Object?> snapshot;
  final List<String> referencedRules;
  final Future<void> Function(PolicyNodeSetEdit)? onSave;
  final Future<void> Function(String)? onCheck;
  final Future<Map<String, Object?>> Function(Map<String, Object?>)? loadStatus;
  const PolicyNodeSetEditor({
    super.key,
    this.existing,
    required this.targetId,
    required this.sources,
    required this.nodes,
    this.attributes = const {},
    this.snapshot = const {},
    this.referencedRules = const [],
    this.onSave,
    this.onCheck,
    this.loadStatus,
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
  late bool _hide;
  late bool _automatic;
  late bool _unknownRegion;
  late String _method;
  bool _advanced = false;
  bool _showAll = false;
  bool _busy = false;
  bool _validityEdited = false;
  bool _updatingValidity = false;
  String _validityText = '';
  String? _error;
  String _initial = '';
  String _lastFingerprint = '';
  final _attributes = <String, NodeAttributes>{};
  Timer? _statusTimer;
  Map<String, Object?>? _details;
  int _statusEpoch = 0;
  int _offset = 0;
  bool _statusLoading = false;
  static const _pageSize = 100;
  @override
  void initState() {
    super.initState();
    final set = widget.existing;
    final probe =
        set?.probe ??
        const PolicyProbe(
          intervalSeconds: 60,
          method: 'GET',
          expectedStatus: '204',
        );
    _sources = {...?set?.sourceIds};
    _regions = {...?set?.regions};
    _unknown = set?.unknownMultiplier ?? UnknownMultiplier.exclude;
    _strategy = set?.strategy ?? NodeSetStrategy.stable;
    _hide = set?.hideUnavailable ?? true;
    _automatic = probe.automatic;
    _unknownRegion = set?.allowUnknownRegion ?? false;
    _method = probe.method;
    _attributes.addAll(widget.attributes);
    for (final entry in {
      'label': set?.label ?? '',
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
      if (!_statusLoading) unawaited(_refreshStatus());
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
        _fingerprint != _initial) {
      return;
    }
    final epoch = ++_statusEpoch;
    final fingerprint = _fingerprint;
    final offset = _offset;
    final includeUnavailable = _showAll || !_hide;
    setState(() => _statusLoading = true);
    try {
      final result = await load({
        'revision': revision,
        'nodeSetId': widget.existing!.id,
        'offset': offset,
        'limit': _pageSize,
        'includeUnavailable': includeUnavailable,
      });
      if (!mounted ||
          epoch != _statusEpoch ||
          fingerprint != _fingerprint ||
          offset != _offset ||
          includeUnavailable != (_showAll || !_hide)) {
        return;
      }
      final probe = result['probe'];
      if (result['revision'] != revision ||
          result['nodeSetId'] != widget.existing!.id ||
          result['offset'] != offset ||
          probe is! Map ||
          policyDigest(probe) !=
              policyDigest(widget.existing!.probe.toJson())) {
        setState(() => _details = null);
        return;
      }
      setState(() => _details = result);
    } catch (_) {
      if (mounted && epoch == _statusEpoch) setState(() => _details = null);
    } finally {
      if (mounted && epoch == _statusEpoch) {
        setState(() => _statusLoading = false);
      }
    }
  }

  void _changePage(int offset, {bool? showAll}) {
    setState(() {
      _offset = offset;
      if (showAll != null) _showAll = showAll;
      _details = null;
    });
    unawaited(_refreshStatus());
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
    final tasks = (widget.nodes.length + existingTasks).clamp(0, 5000);
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

  @override
  void didUpdateWidget(covariant PolicyNodeSetEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateDefaultValidity();
  }

  String get _fingerprint => policyDigest({
    'fields': _fields.map((k, v) => MapEntry(k, v.text)),
    'sources': _sources.toList()..sort(),
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
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _leave() async {
    if (_busy) return;
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
              : _regions.join(' · ')
        : _fields['label']!.text.trim(),
    'targetId': widget.targetId,
    'sourceIds': _sources.toList(),
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
      numeric: !{'url', 'label', 'status'}.contains(key),
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
        if (_advanced) ...[
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
        Text(strings.policyCheckMeasurementHint),
      ],
    );
  }

  Widget _formContent() {
    final strings = context.appLocalizations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(strings.general)),
            ButtonSegment(value: true, label: Text(strings.advancedConfig)),
          ],
          selected: {_advanced},
          onSelectionChanged: (values) =>
              setState(() => _advanced = values.single),
        ),
        const SizedBox(height: 16),
        _field('label', strings.name, required: false),
        Text(strings.policySourcesCollection),
        Wrap(
          spacing: 8,
          children: [
            for (final source in widget.sources.entries)
              FilterChip(
                label: Text(source.value),
                selected: _sources.contains(source.key),
                onSelected: _busy
                    ? null
                    : (v) => setState(
                        () => v
                            ? _sources.add(source.key)
                            : _sources.remove(source.key),
                      ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(strings.policyRegions),
        Wrap(
          spacing: 8,
          children: [
            for (final region in {
              'JP',
              'HK',
              'TW',
              'US',
              'SG',
              'KR',
              'DE',
              'GB',
              ..._regions,
            })
              FilterChip(
                label: Text(region),
                selected: _regions.contains(region),
                onSelected: _busy
                    ? null
                    : (v) => setState(
                        () =>
                            v ? _regions.add(region) : _regions.remove(region),
                      ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _field('cap', strings.policyMultiplierLimit, required: false),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(strings.policyUnknownOne),
          subtitle: Text(strings.policyUnknownOneHint),
          value: _unknown == UnknownMultiplier.assumeOne,
          onChanged: _busy
              ? null
              : (v) => setState(
                  () => _unknown = v
                      ? UnknownMultiplier.assumeOne
                      : UnknownMultiplier.exclude,
                ),
        ),
        DropdownButtonFormField<NodeSetStrategy>(
          initialValue: _strategy,
          isExpanded: true,
          decoration: InputDecoration(labelText: strings.policyNodeSet),
          items: [
            DropdownMenuItem(
              value: NodeSetStrategy.stable,
              child: Text(strings.policyStableFirst),
            ),
            DropdownMenuItem(
              value: NodeSetStrategy.latency,
              child: Text(strings.policyLatencyFirst),
            ),
            DropdownMenuItem(
              value: NodeSetStrategy.multiplier,
              child: Text(strings.policyMultiplierFirst),
            ),
          ],
          onChanged: _busy
              ? null
              : (v) {
                  if (v != null) setState(() => _strategy = v);
                },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(strings.policyHideUnavailable),
          value: _hide,
          onChanged: _busy ? null : (v) => setState(() => _hide = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(strings.policyAutoCheck),
          value: _automatic,
          onChanged: _busy ? null : (v) => setState(() => _automatic = v),
        ),
        _checks(),
        if (widget.referencedRules.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '${strings.policySharedSetImpact}: ${widget.referencedRules.join(' · ')}',
            ),
          ),
      ],
    );
  }

  Widget _members() {
    if (_lastFingerprint != _fingerprint) {
      _lastFingerprint = _fingerprint;
      _details = null;
      _statusEpoch++;
      _statusLoading = false;
      _offset = 0;
    }
    final strings = context.appLocalizations;
    PolicyNodeSet? set;
    try {
      set = _value();
    } catch (_) {}
    final allNodes = widget.nodes
        .map(
          (n) => LocalNode(
            id: n.id,
            sourceId: n.sourceId,
            label: n.label,
            sourceLabel: n.sourceLabel,
            protocol: n.protocol,
            raw: n.raw,
            attributes: _attributes[n.id] ?? n.attributes,
          ),
        )
        .toList();
    final matches = allNodes
        .where((n) => set?.exclusion(n) == null && set != null)
        .toList();
    final status = widget.snapshot['nodeSets'];
    final matching = status is List
        ? status
              .whereType<Map>()
              .where((s) => s['policyId'] == widget.existing?.id)
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
    final states = rows is List && probeUnchanged
        ? {for (final row in rows.whereType<Map>()) row['nodeId']: row}
        : <Object?, Map>{};
    final filtered = matches
        .where((n) => _showAll || !_hide || states[n.id]?['eligible'] != false)
        .toList();
    final offset = _fingerprint == _initial ? _offset : 0;
    final total = live?['total'] is int
        ? live!['total'] as int
        : filtered.length;
    final shown = live != null && rows is List
        ? [
            for (final row in rows.whereType<Map>().take(_pageSize))
              ...matches.where((node) => node.id == row['nodeId']).take(1),
          ]
        : filtered.skip(offset).take(_pageSize).toList();
    final hasMore =
        live?['hasMore'] == true ||
        (live == null && offset + shown.length < total);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${strings.policyMemberPreview} · ${matches.length}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (live != null)
          Text(
            '${strings.policyAvailableMembers}: ${live['availableCount'] ?? 0} · ${strings.policyPendingMembers}: ${live['pendingCount'] ?? 0} · ${strings.policyRestrictedMembers}: ${live['restrictedCount'] ?? 0}',
          ),
        if (_statusLoading) const LinearProgressIndicator(),
        if (matches.isEmpty) Text(strings.policyNoMembers),
        for (final node in shown)
          Card(
            child: ListTile(
              onTap: _busy ? null : () => _editAttributes(node),
              title: Text(node.label),
              subtitle: Text(
                '${node.attributes.region ?? strings.policyUnknownAttribute} · ${node.attributes.multiplier ?? strings.policyUnknownAttribute}${node.attributes.multiplier == null && _unknown == UnknownMultiplier.assumeOne ? ' · 1×' : ''}\n${node.sourceLabel} · ${_basis(node.attributes.regionBasis)} / ${_basis(node.attributes.multiplierBasis)}\n${states[node.id]?['lastProbeAt'] is int ? policyBeijingTime(states[node.id]!['lastProbeAt'] as int) : strings.policyCheckPending}',
              ),
              isThreeLine: true,
              trailing: Text(
                states[node.id]?['latencyMillis'] is num
                    ? '${states[node.id]!['latencyMillis']} ms'
                    : strings.policyCheckPending,
              ),
            ),
          ),
        if (!_showAll && _hide)
          TextButton(
            onPressed: _statusLoading
                ? null
                : () => _changePage(0, showAll: true),
            child: Text(strings.policyShowUnavailable),
          ),
        if (total > _pageSize || offset > 0)
          Row(
            children: [
              IconButton(
                key: const ValueKey('node-set-previous-page'),
                tooltip: MaterialLocalizations.of(context).previousPageTooltip,
                onPressed: _statusLoading || offset == 0
                    ? null
                    : () => _changePage((offset - _pageSize).clamp(0, 5000)),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                total == 0
                    ? '0 / 0'
                    : '${offset + 1}–${offset + shown.length} / $total',
              ),
              IconButton(
                key: const ValueKey('node-set-next-page'),
                tooltip: MaterialLocalizations.of(context).nextPageTooltip,
                onPressed: _statusLoading || !hasMore
                    ? null
                    : () => _changePage(offset + _pageSize),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        const SizedBox(height: 12),
        Text(
          '${strings.policyChecksWaiting}: ${live?['checksWaiting'] ?? widget.snapshot['checksWaiting'] ?? '—'} · ${strings.policyChecksInFlight}: ${live?['checksInFlight'] ?? widget.snapshot['checksInFlight'] ?? '—'}',
        ),
        if (live?['sampleAt'] is int)
          Text(
            '${strings.policyPageSampleAt}: ${policyBeijingTime(live!['sampleAt'] as int)}',
          ),
        if (widget.onCheck != null && widget.existing != null)
          OutlinedButton.icon(
            onPressed: _busy || _fingerprint != _initial
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      await widget.onCheck!(widget.existing!.id);
                    } catch (_) {
                      if (mounted) {
                        setState(() => _error = strings.policyOperationFailed);
                      }
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            icon: const Icon(Icons.network_check),
            label: Text(strings.policyCheckNow),
          ),
      ],
    );
  }

  Future<void> _editAttributes(LocalNode node) async {
    final strings = context.appLocalizations;
    final region = TextEditingController(text: node.attributes.region ?? '');
    final multiplier = TextEditingController(
      text: node.attributes.multiplier?.toString() ?? '',
    );
    try {
      final result = await showDialog<NodeAttributes>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${strings.policyManualAttribute} · ${node.label}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: region,
                decoration: InputDecoration(
                  labelText: '${strings.policyRegions} · ISO 3166-1',
                ),
              ),
              TextField(
                controller: multiplier,
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
                  final r = region.text.trim().toUpperCase();
                  final m = multiplier.text.trim();
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
    } finally {
      region.dispose();
      multiplier.dispose();
    }
  }

  String _basis(NodeAttributeBasis basis) => switch (basis) {
    NodeAttributeBasis.unknown =>
      context.appLocalizations.policyUnknownAttribute,
    NodeAttributeBasis.name => context.appLocalizations.policyNameAttribute,
    NodeAttributeBasis.subscription =>
      context.appLocalizations.policyDeclaredAttribute,
    NodeAttributeBasis.manual => context.appLocalizations.policyManualAttribute,
  };
  @override
  Widget build(BuildContext context) {
    final strings = context.appLocalizations;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: AlertDialog(
        title: Text(widget.existing?.label ?? strings.policyNodeSet),
        content: SizedBox(
          width: 1000,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final form = _formContent();
                  final members = _members();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_busy) const LinearProgressIndicator(),
                      if (constraints.maxWidth >= 760)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: form),
                            const SizedBox(width: 24),
                            Expanded(child: members),
                          ],
                        )
                      else ...[
                        form,
                        const SizedBox(height: 24),
                        members,
                      ],
                      if (_error != null)
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                    ],
                  );
                },
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
            child: Text(strings.policyCheckSave),
          ),
        ],
      ),
    );
  }
}
