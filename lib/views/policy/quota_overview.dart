import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/models/profile.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/policy/quota_overview.dart';
import 'package:flutter/material.dart';

Color _quotaColor(BuildContext context, QuotaBarSegmentKind kind) {
  final brightness = Theme.of(context).brightness;
  return switch (kind) {
    QuotaBarSegmentKind.used => context.colorScheme.outlineVariant,
    QuotaBarSegmentKind.expiringSoon => ColorScheme.fromSeed(
      seedColor: Colors.orange,
      brightness: brightness,
    ).primary,
    QuotaBarSegmentKind.expiringLater => ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: brightness,
    ).primary,
    QuotaBarSegmentKind.unlimited => ColorScheme.fromSeed(
      seedColor: Colors.green,
      brightness: brightness,
    ).primary,
    QuotaBarSegmentKind.expired => context.colorScheme.error,
    QuotaBarSegmentKind.unknown => context.colorScheme.surfaceContainerHighest,
  };
}

final class QuotaOverviewLabels {
  const QuotaOverviewLabels({
    required this.title,
    required this.total,
    required this.remaining,
    required this.noSources,
    required this.unknown,
    required this.used,
    required this.expiringSoon,
    required this.expiringLater,
    required this.unlimited,
    required this.expired,
    required this.unknownExpiry,
    required this.partiallyUnknown,
    required this.overage,
  });

  final String title;
  final String total;
  final String remaining;
  final String noSources;
  final String unknown;
  final String used;
  final String expiringSoon;
  final String expiringLater;
  final String unlimited;
  final String expired;
  final String unknownExpiry;
  final String partiallyUnknown;
  final String overage;
}

class LocalQuotaOverview extends StatelessWidget {
  const LocalQuotaOverview({
    super.key,
    required this.profiles,
    this.nodes = const [],
    this.onManageSources,
    this.now,
    this.labels,
  });

  final List<Profile> profiles;
  final List<LocalNode> nodes;
  final VoidCallback? onManageSources;
  final DateTime? now;
  final QuotaOverviewLabels? labels;

  QuotaOverviewLabels _labels(BuildContext context) {
    final strings = context.appLocalizations;
    return labels ??
        QuotaOverviewLabels(
          title: strings.policyQuotaOverview,
          total: strings.policyQuotaTotal,
          remaining: strings.policyQuotaRemaining,
          noSources: strings.policyQuotaNoSources,
          unknown: strings.policyQuotaUnknown,
          used: strings.policyQuotaUsed,
          expiringSoon: strings.policyQuotaExpiringSoon,
          expiringLater: strings.policyQuotaExpiringLater,
          unlimited: strings.policyQuotaUnlimited,
          expired: strings.policyQuotaExpired,
          unknownExpiry: strings.policyQuotaUnknownExpiry,
          partiallyUnknown: strings.policyQuotaPartiallyUnknown,
          overage: strings.policyQuotaOverage,
        );
  }

  @override
  Widget build(BuildContext context) {
    final data = const LocalQuotaOverviewCalculator().calculate(
      profiles: profiles,
      nodes: nodes,
      now: now,
    );
    final copy = _labels(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _QuotaSummaryCard(
          data: data,
          labels: copy,
          onManageSources: onManageSources,
        ),
        const SizedBox(height: 12),
        for (final source in data.sources)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _QuotaSourceTile(source: source, labels: copy),
          ),
      ],
    );
  }
}

class _QuotaSummaryCard extends StatelessWidget {
  const _QuotaSummaryCard({
    required this.data,
    required this.labels,
    this.onManageSources,
  });

  final LocalQuotaOverviewData data;
  final QuotaOverviewLabels labels;
  final VoidCallback? onManageSources;

  @override
  Widget build(BuildContext context) {
    final strings = context.appLocalizations;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(labels.title)),
                if (onManageSources != null)
                  TextButton(
                    onPressed: onManageSources,
                    child: Text(strings.policySubscriptionSources),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _QuotaReadout(data: data, labels: labels),
            const SizedBox(height: 10),
            _QuotaBar(data: data, labels: labels),
            const SizedBox(height: 10),
            _QuotaLegend(
              data: data,
              labels: labels,
              onTap: (segment) =>
                  _showQuotaSegmentDetails(context, data, labels, segment),
            ),
            if (data.hasUnknownTraffic && data.hasKnownTraffic) ...[
              const SizedBox(height: 8),
              Text(
                labels.partiallyUnknown,
                style: context.textTheme.bodySmall?.toLight,
              ),
            ],
            if (data.overageBytes > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${labels.overage}: ${data.overageBytes.traffic.show}',
                style: context.textTheme.bodySmall?.toLight,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuotaReadout extends StatelessWidget {
  const _QuotaReadout({required this.data, required this.labels});

  final LocalQuotaOverviewData data;
  final QuotaOverviewLabels labels;

  @override
  Widget build(BuildContext context) {
    if (data.sources.isEmpty) {
      return Text(labels.noSources);
    }
    if (!data.hasKnownTraffic) {
      return Text(labels.unknown);
    }
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        Text('${labels.total} ${data.knownTotalBytes.traffic.show}'),
        Text('${labels.used} ${data.usedBytes.traffic.show}'),
        Text('${labels.remaining} ${data.remainingBytes.traffic.show}'),
      ],
    );
  }
}

class _QuotaBar extends StatelessWidget {
  const _QuotaBar({required this.data, required this.labels});

  final LocalQuotaOverviewData data;
  final QuotaOverviewLabels labels;

  String _label(QuotaBarSegmentKind kind) => switch (kind) {
    QuotaBarSegmentKind.used => labels.used,
    QuotaBarSegmentKind.expiringSoon => labels.expiringSoon,
    QuotaBarSegmentKind.expiringLater => labels.expiringLater,
    QuotaBarSegmentKind.unlimited => labels.unlimited,
    QuotaBarSegmentKind.expired => labels.expired,
    QuotaBarSegmentKind.unknown => labels.unknownExpiry,
  };

  @override
  Widget build(BuildContext context) {
    final total = data.segmentTotal;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 32,
        child: total <= 0
            ? ColoredBox(color: context.colorScheme.surfaceContainerHighest)
            : LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: [
                    for (var index = 0; index < data.segments.length; index++)
                      _QuotaSegmentPosition(
                        segment: data.segments[index],
                        total: total,
                        left: data.segments
                            .take(index)
                            .fold<int>(0, (sum, item) => sum + item.bytes),
                        width: constraints.maxWidth,
                        label:
                            '${_label(data.segments[index].kind)} ${data.segments[index].bytes.traffic.show}',
                        onTap: () => _showQuotaSegmentDetails(
                          context,
                          data,
                          labels,
                          data.segments[index],
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _QuotaSegmentPosition extends StatelessWidget {
  const _QuotaSegmentPosition({
    required this.segment,
    required this.total,
    required this.left,
    required this.width,
    required this.label,
    required this.onTap,
  });

  final QuotaBarSegment segment;
  final int total;
  final int left;
  final double width;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final segmentLeft = width * left / total;
    final segmentWidth = width * segment.bytes / total;
    return Positioned(
      left: segmentLeft,
      width: segmentWidth,
      top: 0,
      bottom: 0,
      child: Semantics(
        button: true,
        label: label,
        child: Tooltip(
          message: label,
          child: InkWell(
            key: ValueKey('quota-segment-${segment.kind.name}'),
            onTap: onTap,
            child: CustomPaint(
              painter: _QuotaStripePainter(
                color: _quotaColor(context, segment.kind),
                striped: segment.kind == QuotaBarSegmentKind.unknown,
                stripeColor: context.colorScheme.outline,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuotaLegend extends StatelessWidget {
  const _QuotaLegend({
    required this.data,
    required this.labels,
    required this.onTap,
  });

  final LocalQuotaOverviewData data;
  final QuotaOverviewLabels labels;
  final ValueChanged<QuotaBarSegment> onTap;

  String _label(QuotaBarSegmentKind kind) => switch (kind) {
    QuotaBarSegmentKind.used => labels.used,
    QuotaBarSegmentKind.expiringSoon => labels.expiringSoon,
    QuotaBarSegmentKind.expiringLater => labels.expiringLater,
    QuotaBarSegmentKind.unlimited => labels.unlimited,
    QuotaBarSegmentKind.expired => labels.expired,
    QuotaBarSegmentKind.unknown => labels.unknownExpiry,
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        for (final segment in data.segments)
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: InkWell(
              key: ValueKey('quota-legend-${segment.kind.name}'),
              onTap: () => onTap(segment),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _quotaColor(context, segment.kind),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_label(segment.kind)} ${segment.bytes.traffic.show}',
                      style: context.textTheme.labelSmall,
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

Future<void> _showQuotaSegmentDetails(
  BuildContext context,
  LocalQuotaOverviewData data,
  QuotaOverviewLabels labels,
  QuotaBarSegment segment,
) async {
  final sources = data.sources.where((source) {
    if (!source.trafficKnown) return false;
    if (segment.kind == QuotaBarSegmentKind.used) {
      return (source.usedBytes ?? 0) > 0;
    }
    if ((source.remainingBytes ?? 0) <= 0) return false;
    final kind = switch (source.expiryBucket) {
      QuotaExpiryBucket.expiringSoon => QuotaBarSegmentKind.expiringSoon,
      QuotaExpiryBucket.expiringLater => QuotaBarSegmentKind.expiringLater,
      QuotaExpiryBucket.unlimited => QuotaBarSegmentKind.unlimited,
      QuotaExpiryBucket.expired => QuotaBarSegmentKind.expired,
      QuotaExpiryBucket.unknown => QuotaBarSegmentKind.unknown,
    };
    return kind == segment.kind;
  }).toList();
  String label() => switch (segment.kind) {
    QuotaBarSegmentKind.used => labels.used,
    QuotaBarSegmentKind.expiringSoon => labels.expiringSoon,
    QuotaBarSegmentKind.expiringLater => labels.expiringLater,
    QuotaBarSegmentKind.unlimited => labels.unlimited,
    QuotaBarSegmentKind.expired => labels.expired,
    QuotaBarSegmentKind.unknown => labels.unknownExpiry,
  };
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(label()),
      content: SizedBox(
        width: 420,
        height: 420,
        child: ListView(
          children: [
            for (final source in sources)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _QuotaSourceText(
                  source: source,
                  labels: labels,
                  segmentKind: segment.kind,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.appLocalizations.cancel),
        ),
      ],
    ),
  );
}

class _QuotaSourceTile extends StatelessWidget {
  const _QuotaSourceTile({required this.source, required this.labels});

  final QuotaSourceSummary source;
  final QuotaOverviewLabels labels;

  @override
  Widget build(BuildContext context) {
    final details = _QuotaSourceText(source: source, labels: labels);
    return Card(
      child: ListTile(title: Text(source.profile.realLabel), subtitle: details),
    );
  }
}

class _QuotaSourceText extends StatelessWidget {
  const _QuotaSourceText({required this.source, this.labels, this.segmentKind});

  final QuotaSourceSummary source;
  final QuotaOverviewLabels? labels;
  final QuotaBarSegmentKind? segmentKind;

  String _expiry(BuildContext context) {
    final metadata = source.profile.subscriptionInfo?.metadata;
    if (metadata == null || !metadata.expiryKnown) {
      return labels?.unknownExpiry ??
          context.appLocalizations.policyExpiryUnknown;
    }
    if (metadata.unlimited) {
      return labels?.unlimited ?? context.appLocalizations.infiniteTime;
    }
    return metadata.expiryDate ?? context.appLocalizations.policyExpiryUnknown;
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.appLocalizations;
    final segmentBytes = segmentKind == null || !source.trafficKnown
        ? null
        : segmentKind == QuotaBarSegmentKind.used
        ? source.usedBytes
        : source.remainingBytes;
    final traffic = segmentBytes != null
        ? segmentBytes.traffic.show
        : source.trafficKnown
        ? '${source.reportedUsedBytes!.traffic.show} / ${source.totalBytes!.traffic.show}'
        : labels?.unknown ?? strings.policyQuotaUnknown;
    final overage = segmentKind == null && source.overageBytes > 0
        ? ' · +${source.overageBytes.traffic.show}'
        : '';
    final sortedRegions = source.regions.toList()..sort();
    final regions = sortedRegions.isEmpty
        ? ''
        : ' · ${sortedRegions.join(' · ')}';
    final name = segmentKind == null ? '' : '${source.profile.realLabel} · ';
    return Text('$name$traffic$overage · ${_expiry(context)}$regions');
  }
}

class _QuotaStripePainter extends CustomPainter {
  const _QuotaStripePainter({
    required this.color,
    required this.striped,
    required this.stripeColor,
  });

  final Color color;
  final bool striped;
  final Color stripeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    canvas.drawRect(Offset.zero & size, paint);
    if (!striped) return;
    final stripe = Paint()
      ..color = stripeColor.withValues(alpha: 0.8)
      ..strokeWidth = 2;
    for (var x = -size.height; x < size.width + size.height; x += 8) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        stripe,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _QuotaStripePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.striped != striped ||
      oldDelegate.stripeColor != stripeColor;
}
