import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/policy/quota_overview.dart';
import 'package:flutter/material.dart';

import 'selection_fields.dart';
import 'widgets.dart';

enum _MemberStatus {
  noResult,
  unchecked,
  checking,
  expired,
  restricted,
  failed,
  healthy,
}

class PolicyNodeSetMembersView extends StatefulWidget {
  const PolicyNodeSetMembersView({
    super.key,
    required this.nodes,
    required this.states,
    this.sourceSummaries = const {},
    this.loading = false,
    this.draft = false,
    this.busy = false,
    this.assumeUnknownMultiplier = false,
    this.onCheck,
    this.onEditAttributes,
  });

  final List<LocalNode> nodes;
  final Map<String, Map<String, Object?>> states;
  final Map<String, QuotaSourceSummary> sourceSummaries;
  final bool loading;
  final bool draft;
  final bool busy;
  final bool assumeUnknownMultiplier;
  final VoidCallback? onCheck;
  final ValueChanged<LocalNode>? onEditAttributes;

  @override
  State<PolicyNodeSetMembersView> createState() =>
      _PolicyNodeSetMembersViewState();
}

class _PolicyNodeSetMembersViewState extends State<PolicyNodeSetMembersView> {
  static const _pageSize = 50;
  static const _unknown = '?';
  final _vertical = ScrollController();
  final _horizontal = ScrollController();
  String _query = '';
  String? _source;
  String? _region;
  String? _multiplier;
  _MemberStatus? _status;
  int _offset = 0;
  int _sortColumn = 0;
  bool _ascending = true;

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  _MemberStatus _health(LocalNode node) {
    if (widget.draft) return _MemberStatus.unchecked;
    final state = widget.states[node.id];
    if (state == null) return _MemberStatus.noResult;
    final reason = state['reason'];
    if (reason is String &&
        (reason.startsWith('source_') ||
            reason.startsWith('metadata_') ||
            reason.startsWith('budget_') ||
            const {
              'ledger_untrusted',
              'schedule_inactive',
              'missing_node',
              'outside_node_set',
            }.contains(reason))) {
      return _MemberStatus.restricted;
    }
    if (state['probePending'] == true ||
        state['pending'] == true ||
        state['probing'] == true ||
        state['state'] == 'pending' ||
        state['state'] == 'probing' ||
        reason == 'pending' ||
        reason == 'probing') {
      return _MemberStatus.checking;
    }
    if (reason == 'probe_expired') return _MemberStatus.expired;
    final checked = state['lastProbeAt'];
    if (checked is! int || checked <= 0) return _MemberStatus.unchecked;
    if (state['healthy'] == false || reason == 'unhealthy') {
      return _MemberStatus.failed;
    }
    if (state['healthy'] == true) return _MemberStatus.healthy;
    return _MemberStatus.noResult;
  }

  String _statusLabel(BuildContext context, _MemberStatus status) {
    final strings = context.appLocalizations;
    return switch (status) {
      _MemberStatus.noResult => strings.policyMembersNoResult,
      _MemberStatus.unchecked => strings.policyMembersUnchecked,
      _MemberStatus.checking => strings.policyMembersChecking,
      _MemberStatus.expired => strings.policyMembersExpired,
      _MemberStatus.restricted => strings.policyMembersRestricted,
      _MemberStatus.failed => strings.policyMembersFailed,
      _MemberStatus.healthy => strings.policyMembersHealthy,
    };
  }

  double? _effectiveMultiplier(LocalNode node) =>
      node.attributes.multiplier ?? (widget.assumeUnknownMultiplier ? 1 : null);

  String _multiplierKey(LocalNode node) {
    final value = _effectiveMultiplier(node);
    if (value == null) return _unknown;
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  num? _latency(LocalNode node) {
    final health = _health(node);
    if (health != _MemberStatus.healthy && health != _MemberStatus.restricted) {
      return null;
    }
    final state = widget.states[node.id];
    if (state?['lastProbeAt'] is! int || state?['healthy'] != true) return null;
    final latency = state?['latencyMillis'];
    return latency is num && latency.isFinite && latency >= 0 ? latency : null;
  }

  void _filter(VoidCallback update) => setState(() {
    update();
    _offset = 0;
  });

  Widget _dropdown<T>({
    required String keyName,
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) => SizedBox(
    width: 164,
    child: DropdownButtonFormField<T>(
      key: ValueKey(keyName),
      initialValue: value,
      isExpanded: true,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      items: items,
      onChanged: onChanged,
    ),
  );

  Widget _cell(String text, double width, {Color? color, String? tooltip}) =>
      Tooltip(
        message: tooltip ?? text,
        child: SizedBox(
          width: width,
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: color),
          ),
        ),
      );

  String _expiry(QuotaSourceSummary? source) {
    final strings = context.appLocalizations;
    if (source == null || source.expiryBucket == QuotaExpiryBucket.unknown) {
      return strings.policyQuotaUnknownExpiry;
    }
    if (source.expiryBucket == QuotaExpiryBucket.unlimited) {
      return strings.policyQuotaUnlimited;
    }
    final at = source.expiryMilliseconds;
    return at == null
        ? strings.policyQuotaUnknownExpiry
        : policyBeijingTime(at).split(' ').first;
  }

  String _lastChecked(LocalNode node) {
    final at = widget.states[node.id]?['lastProbeAt'];
    return !widget.draft && at is int && at > 0 ? policyBeijingTime(at) : '—';
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.appLocalizations;
    final colors = Theme.of(context).colorScheme;
    final sourceNames = {
      for (final node in widget.nodes) node.sourceId: node.sourceLabel,
    };
    final regions =
        widget.nodes
            .map((node) => node.attributes.region ?? _unknown)
            .toSet()
            .toList()
          ..sort();
    final regionNames = policyRegionOptions(
      context,
      regions.where((region) => region != _unknown),
    );
    final multipliers = widget.nodes.map(_multiplierKey).toSet().toList()
      ..sort(
        (a, b) => a == b
            ? 0
            : a == _unknown
            ? 1
            : b == _unknown
            ? -1
            : double.parse(a).compareTo(double.parse(b)),
      );
    final source = sourceNames.containsKey(_source) ? _source : null;
    final region = regions.contains(_region) ? _region : null;
    final multiplier = multipliers.contains(_multiplier) ? _multiplier : null;
    final filtered = widget.nodes.where((node) {
      final nodeRegion = node.attributes.region ?? _unknown;
      return (source == null || source == node.sourceId) &&
          (region == null || region == nodeRegion) &&
          (multiplier == null || multiplier == _multiplierKey(node)) &&
          (_status == null || _status == _health(node)) &&
          ('${node.label} ${node.sourceLabel} ${regionNames[nodeRegion] ?? nodeRegion}'
              .toLowerCase()
              .contains(_query));
    }).toList();
    filtered.sort((a, b) {
      if (_sortColumn == 7) {
        final left = _latency(a);
        final right = _latency(b);
        if (left == null && right != null) return 1;
        if (left != null && right == null) return -1;
        if (left != null && right != null && left != right) {
          return _ascending ? left.compareTo(right) : right.compareTo(left);
        }
      }
      final names = a.label.toLowerCase().compareTo(b.label.toLowerCase());
      final order = names == 0 ? a.id.compareTo(b.id) : names;
      return _ascending ? order : -order;
    });
    final maxOffset = filtered.isEmpty
        ? 0
        : ((filtered.length - 1) ~/ _pageSize) * _pageSize;
    final offset = math.min(_offset, maxOffset);
    final shown = filtered.skip(offset).take(_pageSize).toList();
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    void sort(int column, bool ascending) => setState(() {
      _sortColumn = column;
      _ascending = ascending;
      _offset = 0;
    });
    return Scrollbar(
      controller: _vertical,
      child: SingleChildScrollView(
        key: const ValueKey('node-members-scroll'),
        controller: _vertical,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final title = Text(
                  '${strings.policyMembersTitle} · ${widget.nodes.length}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontSize: 18),
                );
                final check = widget.draft
                    ? null
                    : OutlinedButton.icon(
                        key: const ValueKey('node-members-check'),
                        onPressed: widget.busy || widget.loading
                            ? null
                            : widget.onCheck,
                        icon: const Icon(Icons.network_check, size: 18),
                        label: Text(
                          strings.policyCheckNow,
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                if (constraints.maxWidth >= 600) {
                  return Row(
                    children: [
                      Expanded(child: title),
                      if (check != null) ...[const SizedBox(width: 16), check],
                    ],
                  );
                }
                return Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 8,
                  children: [title, ?check],
                );
              },
            ),
            if (widget.draft) ...[
              const SizedBox(height: 8),
              Text(
                strings.policyMembersDraft,
                style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              strings.policyMembersFilters,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 252,
                  child: TextField(
                    key: const ValueKey('node-members-search'),
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: strings.policySearchNodes,
                      labelStyle: const TextStyle(fontSize: 12),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                    ),
                    onChanged: (value) =>
                        _filter(() => _query = value.trim().toLowerCase()),
                  ),
                ),
                _dropdown<String>(
                  keyName: 'node-members-source-filter',
                  label: strings.policyMembersSource,
                  value: source,
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(strings.policyMembersAllSources),
                    ),
                    for (final entry in sourceNames.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => _filter(() => _source = value),
                ),
                _dropdown<String>(
                  keyName: 'node-members-region-filter',
                  label: strings.policyRegions,
                  value: region,
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(strings.policyAnyRegion),
                    ),
                    for (final value in regions)
                      DropdownMenuItem(
                        value: value,
                        child: Text(
                          value == _unknown
                              ? strings.policyUnknownAttribute
                              : regionNames[value] ?? value,
                        ),
                      ),
                  ],
                  onChanged: (value) => _filter(() => _region = value),
                ),
                _dropdown<String>(
                  keyName: 'node-members-multiplier-filter',
                  label: strings.policyPreferenceMultiplier,
                  value: multiplier,
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(strings.policyAnyMultiplier),
                    ),
                    for (final value in multipliers)
                      DropdownMenuItem(
                        value: value,
                        child: Text(
                          value == _unknown
                              ? strings.policyUnknownAttribute
                              : '$value×',
                        ),
                      ),
                  ],
                  onChanged: (value) => _filter(() => _multiplier = value),
                ),
                _dropdown<_MemberStatus>(
                  keyName: 'node-members-status-filter',
                  label: strings.status,
                  value: _status,
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(strings.policyMembersAllStates),
                    ),
                    for (final value in _MemberStatus.values)
                      DropdownMenuItem(
                        value: value,
                        child: Text(_statusLabel(context, value)),
                      ),
                  ],
                  onChanged: (value) => _filter(() => _status = value),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.loading) const LinearProgressIndicator(),
            Scrollbar(
              controller: _horizontal,
              notificationPredicate: (notification) => notification.depth == 0,
              child: SingleChildScrollView(
                key: const ValueKey('node-members-horizontal-scroll'),
                controller: _horizontal,
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  key: const ValueKey('node-members-table'),
                  horizontalMargin: 12,
                  columnSpacing: 16,
                  showCheckboxColumn: false,
                  dataRowMinHeight: math.max(42.0, 42 * scale),
                  dataRowMaxHeight: math.max(42.0, 42 * scale),
                  headingRowHeight: math.max(40.0, 40 * scale),
                  headingTextStyle: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(fontSize: 12),
                  dataTextStyle: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 14),
                  sortColumnIndex: _sortColumn,
                  sortAscending: _ascending,
                  columns: [
                    DataColumn(label: Text(strings.policyNodes), onSort: sort),
                    DataColumn(label: Text(strings.policyMembersSource)),
                    DataColumn(label: Text(strings.policyRegions)),
                    DataColumn(label: Text(strings.policyPreferenceMultiplier)),
                    DataColumn(label: Text(strings.policyMembersQuota)),
                    DataColumn(label: Text(strings.policyMembersExpiry)),
                    DataColumn(label: Text(strings.status)),
                    DataColumn(label: Text(strings.delay), onSort: sort),
                    DataColumn(label: Text(strings.policyMembersLastCheck)),
                  ],
                  rows: [
                    for (final node in shown)
                      DataRow(
                        key: ValueKey('node-member-${node.id}'),
                        onSelectChanged:
                            widget.busy || widget.onEditAttributes == null
                            ? null
                            : (_) => widget.onEditAttributes!(node),
                        cells: [
                          DataCell(_cell(node.label, 180)),
                          DataCell(_cell(node.sourceLabel, 112)),
                          DataCell(
                            _cell(
                              node.attributes.region == null
                                  ? strings.policyUnknownAttribute
                                  : regionNames[node.attributes.region] ??
                                        node.attributes.region!,
                              76,
                            ),
                          ),
                          DataCell(
                            _cell(
                              node.attributes.multiplier == null &&
                                      widget.assumeUnknownMultiplier
                                  ? '1×(${strings.defaultText})'
                                  : node.attributes.multiplier == null
                                  ? strings.policyUnknownAttribute
                                  : '${_multiplierKey(node)}×',
                              86,
                              tooltip:
                                  node.attributes.multiplier == null &&
                                      widget.assumeUnknownMultiplier
                                  ? strings.policyUnknownOneHint
                                  : null,
                            ),
                          ),
                          DataCell(
                            _cell(
                              widget
                                              .sourceSummaries[node.sourceId]
                                              ?.trafficKnown ==
                                          true &&
                                      widget
                                              .sourceSummaries[node.sourceId]
                                              ?.remainingBytes !=
                                          null
                                  ? widget
                                        .sourceSummaries[node.sourceId]!
                                        .remainingBytes!
                                        .traffic
                                        .show
                                  : strings.policyQuotaUnknown,
                              106,
                            ),
                          ),
                          DataCell(
                            _cell(
                              _expiry(widget.sourceSummaries[node.sourceId]),
                              104,
                            ),
                          ),
                          DataCell(
                            _cell(
                              _statusLabel(context, _health(node)),
                              100,
                              tooltip: _health(node) == _MemberStatus.restricted
                                  ? '${_statusLabel(context, _health(node))} · ${policyReasonLabel(context, widget.states[node.id]!['reason'] as String)}'
                                  : null,
                              color: switch (_health(node)) {
                                _MemberStatus.healthy => colors.primary,
                                _MemberStatus.failed ||
                                _MemberStatus.restricted => colors.error,
                                _ => colors.onSurfaceVariant,
                              },
                            ),
                          ),
                          DataCell(
                            _cell(
                              _latency(node) == null
                                  ? '—'
                                  : '${_latency(node)!.fixed()} ms',
                              74,
                            ),
                          ),
                          DataCell(
                            _cell(
                              _lastChecked(node).split(' ').last,
                              100,
                              tooltip: _lastChecked(node),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  strings.noData,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                IconButton(
                  key: const ValueKey('node-members-previous-page'),
                  tooltip: MaterialLocalizations.of(
                    context,
                  ).previousPageTooltip,
                  onPressed: offset == 0
                      ? null
                      : () => setState(() => _offset = offset - _pageSize),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  filtered.isEmpty
                      ? '0 / 0'
                      : '${offset + 1}–${offset + shown.length} / ${filtered.length}',
                  style: const TextStyle(fontSize: 13),
                ),
                IconButton(
                  key: const ValueKey('node-members-next-page'),
                  tooltip: MaterialLocalizations.of(context).nextPageTooltip,
                  onPressed: offset + shown.length >= filtered.length
                      ? null
                      : () => setState(() => _offset = offset + _pageSize),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
