import 'dart:async';
import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/database/usage_database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/usage.dart';
import 'package:fl_clash/views/application_setting.dart';
import 'package:fl_clash/views/config/config.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

const _usageTwoColumnMinWidth = 940.0;

class UsageView extends ConsumerStatefulWidget {
  const UsageView({super.key});

  @override
  ConsumerState<UsageView> createState() => _UsageViewState();
}

class _UsageViewState extends ConsumerState<UsageView> {
  UsageDimension _dimension = UsageDimension.overview;
  UsageSort _sort = UsageSort.total;
  String _search = '';
  String _preset = 'today';
  int _rankingLimit = 200;
  Timer? _searchTimer;

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  void _updateSearch(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _search = value;
          _rankingLimit = 200;
        });
      }
    });
  }

  String _tabLabel(UsageDimension value) {
    final l10n = context.appLocalizations;
    return switch (value) {
      UsageDimension.overview => l10n.usageOverview,
      UsageDimension.node => l10n.usageNodes,
      UsageDimension.application => l10n.usageApplications,
      UsageDimension.domain => l10n.usageDomains,
      UsageDimension.profile => l10n.usageProfiles,
    };
  }

  Future<void> _export() async {
    final filter = ref.read(usageFilterStateProvider).effective;
    String? path;
    if (_dimension == UsageDimension.overview) {
      final overview = await ref.read(usageOverviewProvider.future);
      if (overview.summary.total == 0 && overview.summary.connections == 0) {
        return;
      }
      path = await usageCsvExporter.exportOverview(filter, overview.trend);
    } else {
      path = await usageCsvExporter.exportRankingFromDatabase(
        ref.read(usageStoreProvider),
        filter,
        _dimension,
        sort: _sort,
        search: _search,
      );
    }
    if (path != null && mounted) {
      context.showNotifier(path);
    }
  }

  Future<void> _selectCustomRange() async {
    final current = ref.read(usageFilterStateProvider);
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 89)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: current.start,
        end: current.end.isAfter(DateTime.now()) ? DateTime.now() : current.end,
      ),
    );
    if (range == null) {
      return;
    }
    setState(() => _preset = 'custom');
    ref
        .read(usageFilterStateProvider.notifier)
        .setRange(
          DateTime(range.start.year, range.start.month, range.start.day),
          DateTime(
            range.end.year,
            range.end.month,
            range.end.day,
          ).add(const Duration(days: 1)),
        );
  }

  bool _hasData() {
    if (_dimension == UsageDimension.overview) {
      final value = ref.watch(usageOverviewProvider).value;
      return value != null &&
          (value.summary.total > 0 || value.summary.connections > 0);
    }
    return ref
            .watch(
              usageRankingProvider(
                _dimension,
                _sort,
                _search,
                _rankingLimit + 1,
              ),
            )
            .value
            ?.isNotEmpty ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.appLocalizations;
    final enabled = ref.watch(usageEnabledProvider);
    final filter = ref.watch(usageFilterStateProvider);
    final hasData = _hasData();
    return CommonScaffold(
      title: l10n.usage,
      actions: [
        IconButton(
          tooltip: l10n.exportCsv,
          onPressed: hasData ? _export : null,
          icon: const Icon(Icons.download_outlined),
        ),
        IconButton(
          tooltip: l10n.settings,
          onPressed: () {
            showExtend(context, builder: (_) => const ApplicationSettingView());
          },
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      body: enabled.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _UsageError(error: error),
        data: (value) {
          if (!value) {
            return const _UsageDisabled();
          }
          final issues = {
            ...ref.watch(usageIssuesProvider),
            if (ref.watch(usageHasDegradedDataProvider).value ?? false)
              UsageIssue.degraded,
          };
          return Column(
            children: [
              if (issues.isNotEmpty) _UsageIssueBanner(issues: issues),
              _UsageToolbar(
                preset: filter.liveEnd ? _preset : 'custom',
                onPresetChanged: (value) {
                  if (value == 'custom') {
                    _selectCustomRange();
                    return;
                  }
                  setState(() => _preset = value);
                  final notifier = ref.read(usageFilterStateProvider.notifier);
                  switch (value) {
                    case 'today':
                      notifier.setToday();
                    case '24h':
                      notifier.setLast(const Duration(hours: 24));
                    case '7d':
                      notifier.setLast(const Duration(days: 7));
                    case '30d':
                      notifier.setLast(const Duration(days: 30));
                    case 'custom':
                      break;
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: CommonTabBar<UsageDimension>(
                    proportionalWidth: true,
                    thumbColor: context.colorScheme.secondaryContainer,
                    backgroundColor: context.colorScheme.surfaceContainer,
                    groupValue: _dimension,
                    onValueChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      _searchTimer?.cancel();
                      setState(() {
                        _dimension = value;
                        _search = '';
                        _rankingLimit = 200;
                      });
                    },
                    children: {
                      for (final value in UsageDimension.values)
                        value: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(_tabLabel(value)),
                        ),
                    },
                  ),
                ),
              ),
              Expanded(
                child: _dimension == UsageDimension.overview
                    ? const _OverviewView()
                    : _RankingView(
                        key: ValueKey(_dimension),
                        dimension: _dimension,
                        sort: _sort,
                        search: _search,
                        limit: _rankingLimit,
                        onSearch: _updateSearch,
                        onSort: (value) => setState(() {
                          _sort = value;
                          _rankingLimit = 200;
                        }),
                        onLoadMore: () => setState(() {
                          _rankingLimit += 200;
                        }),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _UsageIssueBanner extends StatelessWidget {
  final Set<UsageIssue> issues;

  const _UsageIssueBanner({required this.issues});

  @override
  Widget build(BuildContext context) {
    final messages = [
      if (issues.contains(UsageIssue.persistence))
        context.appLocalizations.usagePersistenceIssue,
      if (issues.contains(UsageIssue.degraded))
        context.appLocalizations.usageDegradedIssue,
    ];
    return MaterialBanner(
      leading: const Icon(Icons.warning_amber_rounded),
      content: Text(messages.join('\n')),
      actions: const [SizedBox.shrink()],
    );
  }
}

class _UsageDisabled extends StatelessWidget {
  const _UsageDisabled();

  @override
  Widget build(BuildContext context) {
    final l10n = context.appLocalizations;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.query_stats,
                size: 64,
                color: context.colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(l10n.usageNotEnabled, style: context.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                l10n.usageNotEnabledDesc,
                textAlign: TextAlign.center,
                style: context.textTheme.bodyMedium?.toLighter,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  showExtend(
                    context,
                    builder: (_) => const ApplicationSettingView(),
                  );
                },
                icon: const Icon(Icons.settings_outlined),
                label: Text(l10n.goToSettings),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsageError extends StatelessWidget {
  final Object error;

  const _UsageError({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(error.toString(), textAlign: TextAlign.center),
      ),
    );
  }
}

class _UsageToolbar extends ConsumerWidget {
  final String preset;
  final ValueChanged<String> onPresetChanged;

  const _UsageToolbar({required this.preset, required this.onPresetChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.appLocalizations;
    final filter = ref.watch(usageFilterStateProvider);
    final notifier = ref.read(usageFilterStateProvider.notifier);
    final dimensionChips = <Widget>[
      if (filter.profileId != null)
        InputChip(
          label: Text(filter.profileLabel ?? l10n.unknownProfile),
          onDeleted: () => notifier.clearDimension(UsageDimension.profile),
        ),
      if (filter.node != null)
        InputChip(
          label: Text(filter.node!.isEmpty ? l10n.unknownNode : filter.node!),
          onDeleted: () => notifier.clearDimension(UsageDimension.node),
        ),
      if (filter.processPath != null)
        InputChip(
          label: Text(
            filter.processLabel?.isNotEmpty == true
                ? filter.processLabel!
                : l10n.unknownApplication,
          ),
          onDeleted: () => notifier.clearDimension(UsageDimension.application),
        ),
      if (filter.domain != null)
        InputChip(
          label: Text(
            filter.domain!.isEmpty ? l10n.unknownDomain : filter.domain!,
          ),
          onDeleted: () => notifier.clearDimension(UsageDimension.domain),
        ),
    ];
    return Material(
      color: context.colorScheme.surfaceContainerLowest,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(
          children: [
            for (final entry in {
              'today': l10n.usageToday,
              '24h': l10n.last24Hours,
              '7d': l10n.last7Days,
              '30d': l10n.last30Days,
              'custom': l10n.custom,
            }.entries) ...[
              ChoiceChip(
                label: Text(entry.value),
                selected: preset == entry.key,
                onSelected: (_) => onPresetChanged(entry.key),
              ),
              const SizedBox(width: 6),
            ],
            const SizedBox(width: 10),
            CommonTabBar<UsageTrafficScope>(
              thumbColor: context.colorScheme.primaryContainer,
              backgroundColor: context.colorScheme.surfaceContainerHigh,
              groupValue: filter.scope,
              onValueChanged: (value) {
                if (value != null) {
                  notifier.setScope(value);
                }
              },
              children: {
                UsageTrafficScope.proxy: Text(l10n.proxyTraffic),
                UsageTrafficScope.all: Text(l10n.allTraffic),
                UsageTrafficScope.direct: Text(l10n.directTraffic),
              },
            ),
            if (dimensionChips.isNotEmpty) ...[
              const SizedBox(width: 12),
              ...dimensionChips.expand(
                (chip) => [chip, const SizedBox(width: 6)],
              ),
              TextButton.icon(
                onPressed: notifier.resetDimensions,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: Text(l10n.resetFilters),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OverviewView extends ConsumerWidget {
  const _OverviewView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(usageOverviewProvider);
    return overview.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _UsageError(error: error),
      data: (value) {
        if (value.summary.total == 0 && value.summary.connections == 0) {
          return NullStatus(label: context.appLocalizations.noUsageData);
        }
        final l10n = context.appLocalizations;
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _usageTwoColumnMinWidth;
            final chartWidgets = [
              Expanded(
                child: _ChartCard(
                  title: l10n.timeTrend,
                  child: _UsageTrendChart(points: value.trend),
                ),
              ),
              SizedBox(width: wide ? 12 : 0, height: wide ? 0 : 12),
              Expanded(
                child: _ChartCard(
                  title: l10n.hourlyDistribution,
                  child: _HourlyChart(points: value.hourlyDistribution),
                ),
              ),
            ];
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _MetricCard(
                        label: l10n.usageTotal,
                        value: _traffic(value.summary.total),
                        icon: Icons.data_usage,
                      ),
                      _MetricCard(
                        label: l10n.upload,
                        value: _traffic(value.summary.upload),
                        icon: Icons.arrow_upward,
                      ),
                      _MetricCard(
                        label: l10n.download,
                        value: _traffic(value.summary.download),
                        icon: Icons.arrow_downward,
                      ),
                      _MetricCard(
                        label: l10n.usageConnections,
                        value: NumberFormat.compact().format(
                          value.summary.connections,
                        ),
                        icon: Icons.link,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: wide ? 280 : 572,
                    child: wide
                        ? Row(children: chartWidgets)
                        : Column(children: chartWidgets),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, inner) {
                      final width = wide
                          ? (inner.maxWidth - 12) / 2
                          : inner.maxWidth;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _TopListCard(
                            width: width,
                            title: l10n.topNodes,
                            dimension: UsageDimension.node,
                            items:
                                value.rankings[UsageDimension.node] ?? const [],
                          ),
                          _TopListCard(
                            width: width,
                            title: l10n.topApplications,
                            dimension: UsageDimension.application,
                            items:
                                value.rankings[UsageDimension.application] ??
                                const [],
                          ),
                          _TopListCard(
                            width: width,
                            title: l10n.topDomains,
                            dimension: UsageDimension.domain,
                            items:
                                value.rankings[UsageDimension.domain] ??
                                const [],
                          ),
                          _TopListCard(
                            width: width,
                            title: l10n.topProfiles,
                            dimension: UsageDimension.profile,
                            items:
                                value.rankings[UsageDimension.profile] ??
                                const [],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      l10n.localUsageNotice,
                      style: context.textTheme.bodySmall?.toLighter,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

String _traffic(int value) {
  final traffic = value.traffic;
  return '${traffic.value} ${traffic.unit}';
}

String _usageLabel(
  BuildContext context,
  UsageDimension dimension,
  UsageRankingItem item,
) {
  if (item.label.isNotEmpty) {
    return item.label;
  }
  final l10n = context.appLocalizations;
  return switch (dimension) {
    UsageDimension.node => l10n.unknownNode,
    UsageDimension.application => l10n.unknownApplication,
    UsageDimension.domain => l10n.unknownDomain,
    UsageDimension.profile => l10n.unknownProfile,
    UsageDimension.overview => l10n.unknown,
  };
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      height: 100,
      child: CommonCard(
        type: CommonCardType.filled,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: context.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodySmall?.toLighter,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.titleMedium?.toBold,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return CommonCard(
      type: CommonCardType.filled,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: context.textTheme.titleSmall?.toBold),
            const SizedBox(height: 12),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _UsageTrendChart extends ConsumerStatefulWidget {
  final List<UsageTrendPoint> points;

  const _UsageTrendChart({required this.points});

  @override
  ConsumerState<_UsageTrendChart> createState() => _UsageTrendChartState();
}

class _UsageTrendChartState extends ConsumerState<_UsageTrendChart> {
  int? _hoverIndex;
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (widget.points.isEmpty) {
      return;
    }
    final filter = ref.read(usageFilterStateProvider).effective;
    final bucketStart = widget.points[index].time;
    final usesHourlyBuckets =
        filter.end.difference(filter.start) <= const Duration(hours: 48);
    final bucketEnd = usesHourlyBuckets
        ? bucketStart.add(const Duration(hours: 1))
        : DateTime(bucketStart.year, bucketStart.month, bucketStart.day + 1);
    final start = bucketStart.isBefore(filter.start)
        ? filter.start
        : bucketStart;
    final end = bucketEnd.isAfter(filter.end) ? filter.end : bucketEnd;
    if (!end.isAfter(start)) {
      return;
    }
    ref.read(usageFilterStateProvider.notifier).setRange(start, end);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return Center(child: Text(context.appLocalizations.noUsageData));
    }
    final upColor = context.colorScheme.primary;
    final downColor = context.colorScheme.tertiary;
    return Column(
      children: [
        Row(
          children: [
            _Legend(color: upColor, label: context.appLocalizations.upload),
            const SizedBox(width: 16),
            _Legend(color: downColor, label: context.appLocalizations.download),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Focus(
                focusNode: _focusNode,
                onKeyEvent: (_, event) {
                  if (event is! KeyDownEvent) {
                    return KeyEventResult.ignored;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                      event.logicalKey == LogicalKeyboardKey.arrowRight) {
                    final offset =
                        event.logicalKey == LogicalKeyboardKey.arrowLeft
                        ? -1
                        : 1;
                    setState(() {
                      _hoverIndex = ((_hoverIndex ?? 0) + offset)
                          .clamp(0, widget.points.length - 1)
                          .toInt();
                    });
                    return KeyEventResult.handled;
                  }
                  if ({
                        LogicalKeyboardKey.enter,
                        LogicalKeyboardKey.space,
                      }.contains(event.logicalKey) &&
                      _hoverIndex != null) {
                    _select(_hoverIndex!);
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: Semantics(
                  label: context.appLocalizations.timeTrend,
                  button: true,
                  child: MouseRegion(
                    onExit: (_) => setState(() => _hoverIndex = null),
                    onHover: (event) {
                      final next =
                          ((event.localPosition.dx / max(width, 1)) *
                                  (widget.points.length - 1))
                              .round()
                              .clamp(0, widget.points.length - 1)
                              .toInt();
                      if (next != _hoverIndex) {
                        setState(() => _hoverIndex = next);
                      }
                    },
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) {
                        _focusNode.requestFocus();
                        final index =
                            ((details.localPosition.dx / max(width, 1)) *
                                    (widget.points.length - 1))
                                .round()
                                .clamp(0, widget.points.length - 1)
                                .toInt();
                        _select(index);
                      },
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _UsageChartPainter(
                                points: widget.points,
                                uploadColor: upColor,
                                downloadColor: downColor,
                                hoverIndex: _hoverIndex,
                              ),
                            ),
                          ),
                          if (_hoverIndex != null)
                            Positioned(
                              top: 4,
                              left: min(
                                max(
                                  0.0,
                                  width *
                                          _hoverIndex! /
                                          max(widget.points.length - 1, 1) -
                                      70,
                                ),
                                max(0.0, width - 150),
                              ),
                              child: _UsageTooltip(
                                point: widget.points[_hoverIndex!],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('MM-dd HH:mm').format(widget.points.first.time),
              style: context.textTheme.labelSmall?.toLighter,
            ),
            Text(
              DateFormat('MM-dd HH:mm').format(widget.points.last.time),
              style: context.textTheme.labelSmall?.toLighter,
            ),
          ],
        ),
      ],
    );
  }
}

class _UsageChartPainter extends CustomPainter {
  final List<UsageTrendPoint> points;
  final Color uploadColor;
  final Color downloadColor;
  final int? hoverIndex;

  const _UsageChartPainter({
    required this.points,
    required this.uploadColor,
    required this.downloadColor,
    required this.hoverIndex,
  });

  Path _path(Size size, int Function(UsageTrendPoint point) value, int maxY) {
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final x = points.length == 1
          ? 0.0
          : size.width * index / (points.length - 1);
      final y = size.height - size.height * value(points[index]) / maxY;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final maxY = max(
      1,
      points.fold<int>(
        0,
        (value, point) => max(value, max(point.upload, point.download)),
      ),
    );
    final gridPaint = Paint()
      ..color = uploadColor.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (var index = 1; index < 4; index++) {
      final y = size.height * index / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final uploadPaint = Paint()
      ..color = uploadColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final downloadPaint = Paint()
      ..color = downloadColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(_path(size, (point) => point.upload, maxY), uploadPaint);
    canvas.drawPath(
      _path(size, (point) => point.download, maxY),
      downloadPaint,
    );
    if (hoverIndex != null) {
      final x = points.length == 1
          ? 0.0
          : size.width * hoverIndex! / (points.length - 1);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint..color = uploadColor.withValues(alpha: 0.35),
      );
    }
  }

  @override
  bool shouldRepaint(_UsageChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.hoverIndex != hoverIndex ||
        oldDelegate.uploadColor != uploadColor ||
        oldDelegate.downloadColor != downloadColor;
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: context.textTheme.labelSmall),
      ],
    );
  }
}

class _UsageTooltip extends StatelessWidget {
  final UsageTrendPoint point;

  const _UsageTooltip({required this.point});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(8),
      color: context.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('MM-dd HH:mm').format(point.time),
              style: context.textTheme.labelSmall?.toBold,
            ),
            Text(
              '${context.appLocalizations.upload}: ${_traffic(point.upload)}',
              style: context.textTheme.labelSmall,
            ),
            Text(
              '${context.appLocalizations.download}: ${_traffic(point.download)}',
              style: context.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _HourlyChart extends StatelessWidget {
  final List<UsageTrendPoint> points;

  const _HourlyChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final maxValue = max(
      1,
      points.fold<int>(0, (value, point) => max(value, point.total)),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var index = 0; index < points.length; index++)
          Expanded(
            child: Tooltip(
              message:
                  '${index.toString().padLeft(2, '0')}:00  '
                  '${_traffic(points[index].total)}',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: points[index].total / maxValue,
                          child: Container(
                            decoration: BoxDecoration(
                              color: context.colorScheme.primary,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      index % 3 == 0 ? index.toString() : '',
                      style: context.textTheme.labelSmall?.toLighter,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TopListCard extends ConsumerWidget {
  final double width;
  final String title;
  final UsageDimension dimension;
  final List<UsageRankingItem> items;

  const _TopListCard({
    required this.width,
    required this.title,
    required this.dimension,
    required this.items,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: width,
      height: 250,
      child: CommonCard(
        type: CommonCardType.filled,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.textTheme.titleSmall?.toBold),
              const SizedBox(height: 8),
              if (items.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(context.appLocalizations.noUsageData),
                  ),
                )
              else
                for (final item in items)
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () =>
                          _showUsageDetail(context, ref, dimension, item),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _usageLabel(context, dimension, item),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _traffic(item.total),
                              style: context.textTheme.bodySmall?.toLighter,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankingView extends ConsumerWidget {
  final UsageDimension dimension;
  final UsageSort sort;
  final String search;
  final int limit;
  final ValueChanged<String> onSearch;
  final ValueChanged<UsageSort> onSort;
  final VoidCallback onLoadMore;

  const _RankingView({
    super.key,
    required this.dimension,
    required this.sort,
    required this.search,
    required this.limit,
    required this.onSearch,
    required this.onSort,
    required this.onLoadMore,
  });

  String _sortLabel(BuildContext context, UsageSort value) {
    final l10n = context.appLocalizations;
    return switch (value) {
      UsageSort.total => l10n.sortByTotal,
      UsageSort.upload => l10n.sortByUpload,
      UsageSort.download => l10n.sortByDownload,
      UsageSort.connections => l10n.sortByConnections,
    };
  }

  int _metricValue(UsageRankingItem item) {
    return switch (sort) {
      UsageSort.total => item.total,
      UsageSort.upload => item.upload,
      UsageSort.download => item.download,
      UsageSort.connections => item.connections,
    };
  }

  Widget _rankingCard(
    BuildContext context,
    WidgetRef ref,
    UsageRankingItem item,
    int index,
    int maximum,
  ) {
    return CommonCard(
      onPressed: () => _showUsageDetail(context, ref, dimension, item),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '${index + 1}',
                style: context.textTheme.titleSmall?.toBold,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _usageLabel(context, dimension, item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodyLarge?.toBold,
                  ),
                  const SizedBox(height: 7),
                  LinearProgressIndicator(
                    value: _metricValue(item) / maximum,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 16,
                    children: [
                      Text(
                        '${context.appLocalizations.upload} ${_traffic(item.upload)}',
                      ),
                      Text(
                        '${context.appLocalizations.download} ${_traffic(item.download)}',
                      ),
                      Text(
                        '${context.appLocalizations.usageConnections} ${item.connections}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _traffic(item.total),
              style: context.textTheme.titleSmall?.toBold,
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(
      usageRankingProvider(dimension, sort, search, limit + 1),
    );
    final processOff = ref.watch(
      patchClashConfigProvider.select(
        (state) => state.findProcessMode == FindProcessMode.off,
      ),
    );
    return Column(
      children: [
        if (dimension == UsageDimension.application && processOff)
          MaterialBanner(
            content: Text(context.appLocalizations.processRecognitionOff),
            actions: [
              TextButton(
                onPressed: () {
                  showExtend(context, builder: (_) => const ConfigView());
                },
                child: Text(context.appLocalizations.openProcessSettings),
              ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: onSearch,
                  decoration: InputDecoration(
                    hintText: context.appLocalizations.search,
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<UsageSort>(
                value: sort,
                onChanged: (value) {
                  if (value != null) {
                    onSort(value);
                  }
                },
                items: UsageSort.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_sortLabel(context, value)),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        Expanded(
          child: rows.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _UsageError(error: error),
            data: (items) {
              if (items.isEmpty) {
                return NullStatus(label: context.appLocalizations.noUsageData);
              }
              final visibleItems = items.take(limit).toList();
              final hasMore = items.length > limit;
              final maximum = max(
                1,
                visibleItems.fold<int>(
                  0,
                  (value, item) => max(value, _metricValue(item)),
                ),
              );
              final showCoverage = {
                UsageDimension.application,
                UsageDimension.domain,
              }.contains(dimension);
              final coverage = showCoverage
                  ? ref.watch(usageIdentificationCoverageProvider(dimension))
                  : null;
              return Column(
                children: [
                  if (showCoverage)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.fact_check_outlined,
                            size: 18,
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${context.appLocalizations.identificationCoverage} '
                            '${coverage?.value == null ? '—' : '${(coverage!.value! * 100).toStringAsFixed(1)}%'}',
                            style: context.textTheme.bodySmall?.toLighter,
                          ),
                        ],
                      ),
                    ),
                  if (dimension == UsageDimension.application &&
                      !processOff &&
                      coverage?.value == 0)
                    _UsageInfoNotice(
                      text: context
                          .appLocalizations
                          .processRecognitionUnavailable,
                    ),
                  if (dimension == UsageDimension.profile)
                    _UsageInfoNotice(
                      text: context.appLocalizations.usageProfilesDesc,
                    ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final columns =
                            constraints.maxWidth >= _usageTwoColumnMinWidth
                            ? 2
                            : 1;
                        return CustomScrollView(
                          slivers: [
                            SliverPadding(
                              padding: EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                hasMore ? 8 : 24,
                              ),
                              sliver: SliverGrid(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => _rankingCard(
                                    context,
                                    ref,
                                    visibleItems[index],
                                    index,
                                    maximum,
                                  ),
                                  childCount: visibleItems.length,
                                ),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      mainAxisExtent: 136,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                    ),
                              ),
                            ),
                            if (hasMore)
                              SliverPadding(
                                padding: const EdgeInsets.only(bottom: 24),
                                sliver: SliverToBoxAdapter(
                                  child: Center(
                                    child: OutlinedButton.icon(
                                      onPressed: onLoadMore,
                                      icon: const Icon(Icons.expand_more),
                                      label: Text(
                                        context.appLocalizations.loadMore,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UsageInfoNotice extends StatelessWidget {
  final String text;

  const _UsageInfoNotice({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: context.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: context.textTheme.bodySmall?.toLighter),
          ),
        ],
      ),
    );
  }
}

class _UsageDetailData {
  final UsageOverview overview;
  final List<UsageRankingItem> domainTargets;

  const _UsageDetailData({required this.overview, required this.domainTargets});
}

Future<_UsageDetailData> _loadUsageDetail(
  UsageDatabase database,
  UsageFilter filter,
  UsageDimension dimension,
  UsageRankingItem item,
) async {
  final overview = await database.overview(filter);
  final targets = dimension == UsageDimension.domain
      ? await database.domainTargets(filter, item.key)
      : const <UsageRankingItem>[];
  return _UsageDetailData(overview: overview, domainTargets: targets);
}

Future<void> _showUsageDetail(
  BuildContext context,
  WidgetRef ref,
  UsageDimension dimension,
  UsageRankingItem item,
) async {
  final baseFilter = ref.read(usageFilterStateProvider).effective;
  final database = ref.read(usageStoreProvider);
  final notifier = ref.read(usageFilterStateProvider.notifier);
  final selectedFilter = switch (dimension) {
    UsageDimension.node => baseFilter.copyWith(node: item.key),
    UsageDimension.application => baseFilter.copyWith(
      processPath: item.key,
      processLabel: item.label,
    ),
    UsageDimension.domain => baseFilter.copyWith(domain: item.key),
    UsageDimension.profile => baseFilter.copyWith(
      profileId: int.tryParse(item.key),
      profileLabel: item.label,
    ),
    UsageDimension.overview => baseFilter,
  };
  await showSheet<void>(
    context: context,
    props: const SheetProps(maxWidth: 440, isScrollControlled: true),
    builder: (sheetContext) {
      return AdaptiveSheetScaffold(
        title: _usageLabel(context, dimension, item),
        body: FutureBuilder<_UsageDetailData>(
          future: _loadUsageDetail(database, selectedFilter, dimension, item),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _UsageError(error: snapshot.error!);
            }
            final data = snapshot.data;
            if (data == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final overview = data.overview;
            final relatedDimensions = UsageDimension.values.where(
              (value) => value != UsageDimension.overview && value != dimension,
            );
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: context.appLocalizations.usageTotal,
                        value: _traffic(overview.summary.total),
                        icon: Icons.data_usage,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricCard(
                        label: context.appLocalizations.usageConnections,
                        value: '${overview.summary.connections}',
                        icon: Icons.link,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 230,
                  child: _ChartCard(
                    title: context.appLocalizations.timeTrend,
                    child: _UsageTrendChart(points: overview.trend),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    notifier.applyRanking(dimension, item);
                    Navigator.of(sheetContext).pop();
                  },
                  icon: const Icon(Icons.filter_alt_outlined),
                  label: Text(context.appLocalizations.confirm),
                ),
                if (data.domainTargets.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    context.appLocalizations.domainTargets,
                    style: context.textTheme.titleSmall?.toBold,
                  ),
                  for (final target in data.domainTargets)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        target.label.isEmpty
                            ? context.appLocalizations.unknownDomain
                            : target.label,
                      ),
                      trailing: Text(_traffic(target.total)),
                    ),
                ],
                for (final related in relatedDimensions) ...[
                  const SizedBox(height: 16),
                  Text(switch (related) {
                    UsageDimension.node => context.appLocalizations.usageNodes,
                    UsageDimension.application =>
                      context.appLocalizations.usageApplications,
                    UsageDimension.domain =>
                      context.appLocalizations.usageDomains,
                    UsageDimension.profile =>
                      context.appLocalizations.usageProfiles,
                    UsageDimension.overview => '',
                  }, style: context.textTheme.titleSmall?.toBold),
                  for (final relatedItem
                      in overview.rankings[related] ?? const [])
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(_usageLabel(context, related, relatedItem)),
                      trailing: Text(_traffic(relatedItem.total)),
                      onTap: () {
                        notifier.applyRanking(dimension, item);
                        notifier.applyRanking(related, relatedItem);
                        Navigator.of(sheetContext).pop();
                      },
                    ),
                ],
              ],
            );
          },
        ),
      );
    },
  );
}
