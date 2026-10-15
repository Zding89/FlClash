import 'package:fl_clash/models/profile.dart';
import 'package:fl_clash/policy/models.dart';

enum QuotaExpiryBucket {
  expiringSoon,
  expiringLater,
  unlimited,
  expired,
  unknown,
}

enum QuotaBarSegmentKind {
  used,
  expiringSoon,
  expiringLater,
  unlimited,
  expired,
  unknown,
}

final class QuotaBarSegment {
  const QuotaBarSegment({required this.kind, required this.bytes});

  final QuotaBarSegmentKind kind;
  final int bytes;
}

final class QuotaSourceSummary {
  const QuotaSourceSummary({
    required this.profile,
    required this.trafficKnown,
    required this.reportedUsedBytes,
    required this.totalBytes,
    required this.usedBytes,
    required this.remainingBytes,
    required this.expiryBucket,
    required this.expiryMilliseconds,
    required this.regions,
  });

  final Profile profile;
  final bool trafficKnown;
  final int? reportedUsedBytes;
  final int? totalBytes;
  final int? usedBytes;
  final int? remainingBytes;
  final QuotaExpiryBucket expiryBucket;
  final int? expiryMilliseconds;
  final Set<String> regions;

  int get overageBytes =>
      trafficKnown &&
          reportedUsedBytes != null &&
          totalBytes != null &&
          reportedUsedBytes! > totalBytes!
      ? reportedUsedBytes! - totalBytes!
      : 0;
}

final class LocalQuotaOverviewData {
  const LocalQuotaOverviewData({
    required this.sources,
    required this.segments,
    required this.knownTotalBytes,
    required this.usedBytes,
    required this.remainingBytes,
    required this.overageBytes,
    required this.unknownTrafficSources,
  });

  final List<QuotaSourceSummary> sources;
  final List<QuotaBarSegment> segments;
  final int knownTotalBytes;
  final int usedBytes;
  final int remainingBytes;
  final int overageBytes;
  final int unknownTrafficSources;

  int get segmentTotal => segments.fold(0, (sum, item) => sum + item.bytes);
  bool get hasKnownTraffic => knownTotalBytes > 0;
  bool get hasUnknownTraffic => unknownTrafficSources > 0;
}

final class LocalQuotaOverviewCalculator {
  const LocalQuotaOverviewCalculator();

  LocalQuotaOverviewData calculate({
    required List<Profile> profiles,
    List<LocalNode> nodes = const [],
    DateTime? now,
  }) {
    final selected = <int, Profile>{};
    for (final profile in profiles) {
      selected.putIfAbsent(profile.id, () => profile);
    }

    final regionsBySource = <String, Set<String>>{};
    for (final node in nodes) {
      final region = node.attributes.region;
      if (selected.containsKey(int.tryParse(node.sourceId)) && region != null) {
        regionsBySource
            .putIfAbsent(node.sourceId, () => <String>{})
            .add(region);
      }
    }

    final clock = now ?? DateTime.now();
    final sources = [
      for (final profile in selected.values)
        _sourceSummary(
          profile,
          regionsBySource[profile.id.toString()] ?? const <String>{},
          clock,
        ),
    ];
    var knownTotal = 0;
    var used = 0;
    var overage = 0;
    var unknownTrafficSources = 0;
    final remainingByBucket = <QuotaExpiryBucket, int>{};
    for (final source in sources) {
      if (!source.trafficKnown) {
        unknownTrafficSources++;
        continue;
      }
      knownTotal += source.totalBytes!;
      used += source.usedBytes!;
      overage += source.overageBytes;
      remainingByBucket.update(
        source.expiryBucket,
        (value) => value + source.remainingBytes!,
        ifAbsent: () => source.remainingBytes!,
      );
    }

    final segments = <QuotaBarSegment>[
      if (used > 0)
        QuotaBarSegment(kind: QuotaBarSegmentKind.used, bytes: used),
      for (final entry in const [
        MapEntry(
          QuotaExpiryBucket.expiringSoon,
          QuotaBarSegmentKind.expiringSoon,
        ),
        MapEntry(
          QuotaExpiryBucket.expiringLater,
          QuotaBarSegmentKind.expiringLater,
        ),
        MapEntry(QuotaExpiryBucket.unlimited, QuotaBarSegmentKind.unlimited),
        MapEntry(QuotaExpiryBucket.expired, QuotaBarSegmentKind.expired),
        MapEntry(QuotaExpiryBucket.unknown, QuotaBarSegmentKind.unknown),
      ])
        if ((remainingByBucket[entry.key] ?? 0) > 0)
          QuotaBarSegment(
            kind: entry.value,
            bytes: remainingByBucket[entry.key]!,
          ),
    ];
    return LocalQuotaOverviewData(
      sources: List.unmodifiable(sources),
      segments: List.unmodifiable(segments),
      knownTotalBytes: knownTotal,
      usedBytes: used,
      remainingBytes: (knownTotal - used).clamp(0, knownTotal).toInt(),
      overageBytes: overage,
      unknownTrafficSources: unknownTrafficSources,
    );
  }

  QuotaSourceSummary _sourceSummary(
    Profile profile,
    Set<String> regions,
    DateTime now,
  ) {
    final metadata = profile.subscriptionInfo?.metadata;
    final trafficKnown = metadata?.trafficKnown ?? false;
    final total = trafficKnown ? metadata!.totalBytes! : null;
    final reported = trafficKnown ? metadata!.usedBytes! : null;
    final used = trafficKnown ? reported!.clamp(0, total!).toInt() : null;
    return QuotaSourceSummary(
      profile: profile,
      trafficKnown: trafficKnown,
      reportedUsedBytes: reported,
      totalBytes: total,
      usedBytes: used,
      remainingBytes: trafficKnown ? total! - used! : null,
      expiryBucket: _expiryBucket(metadata, now),
      expiryMilliseconds: metadata?.expiryMilliseconds,
      regions: Set.unmodifiable(regions),
    );
  }

  QuotaExpiryBucket _expiryBucket(
    SubscriptionMetadata? metadata,
    DateTime now,
  ) {
    if (metadata == null || !metadata.expiryKnown) {
      return QuotaExpiryBucket.unknown;
    }
    if (metadata.unlimited) return QuotaExpiryBucket.unlimited;
    final expiry = metadata.expiryMilliseconds!;
    final nowMilliseconds = now.millisecondsSinceEpoch;
    if (expiry <= nowMilliseconds) return QuotaExpiryBucket.expired;
    if (expiry <= nowMilliseconds + const Duration(days: 30).inMilliseconds) {
      return QuotaExpiryBucket.expiringSoon;
    }
    return QuotaExpiryBucket.expiringLater;
  }
}
