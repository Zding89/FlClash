part of 'profile.dart';

final class SubscriptionMetadata {
  final int? usedBytes;
  final int? totalBytes;
  final int? expiryMilliseconds;
  final DateTime? trafficObservedAt;
  final DateTime? expiryObservedAt;

  const SubscriptionMetadata({
    this.usedBytes,
    this.totalBytes,
    this.expiryMilliseconds,
    this.trafficObservedAt,
    this.expiryObservedAt,
  });

  factory SubscriptionMetadata.fromInfo(
    SubscriptionInfo? info, {
    DateTime? updatedAt,
  }) {
    if (info == null) return const SubscriptionMetadata();
    final legacy = info.knownFields.isEmpty && info.observedAt == null;
    final trafficKnown =
        info.total > 0 &&
        (info.knownFields.containsAll({'total', 'upload', 'download'}) ||
            legacy);
    final expiryKnown = info.knownFields.contains('expire') || info.expire > 0;
    return SubscriptionMetadata(
      usedBytes: trafficKnown ? info.upload + info.download : null,
      totalBytes: trafficKnown ? info.total : null,
      expiryMilliseconds: expiryKnown ? info.expire * 1000 : null,
      trafficObservedAt: trafficKnown
          ? info.remainingObservedAt ?? info.observedAt ?? updatedAt
          : null,
      expiryObservedAt: expiryKnown
          ? info.expireObservedAt ?? info.observedAt ?? updatedAt
          : null,
    );
  }

  bool get trafficKnown => usedBytes != null && totalBytes != null;
  int? get remainingBytes => trafficKnown
      ? (totalBytes! - usedBytes!).clamp(0, 9007199254740991)
      : null;
  bool get expiryKnown => expiryMilliseconds != null;
  bool get unlimited => expiryMilliseconds == 0;
  DateTime? get expiresAt => expiryMilliseconds == null || unlimited
      ? null
      : DateTime.fromMillisecondsSinceEpoch(expiryMilliseconds!, isUtc: true);
  String? get expiryDate {
    final date = expiresAt?.add(const Duration(hours: 8));
    return date == null
        ? null
        : '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

extension SubscriptionInfoMetadata on SubscriptionInfo {
  SubscriptionMetadata get metadata => SubscriptionMetadata.fromInfo(this);

  SubscriptionInfo retaining(
    SubscriptionInfo? previous, {
    DateTime? updatedAt,
  }) {
    if (previous == null) return this;
    final old = SubscriptionMetadata.fromInfo(previous, updatedAt: updatedAt);
    final oldFields = {
      ...previous.knownFields,
      if (old.trafficKnown) ...{'total', 'upload', 'download'},
      if (old.expiryKnown) 'expire',
    };
    final hasTraffic = knownFields.containsAll({'total', 'upload', 'download'});
    final retainTraffic = !hasTraffic && old.trafficKnown;
    final retainExpiry = !knownFields.contains('expire') && old.expiryKnown;
    return copyWith(
      upload: retainTraffic ? previous.upload : upload,
      download: retainTraffic ? previous.download : download,
      total: retainTraffic ? previous.total : total,
      expire: retainExpiry ? previous.expire : expire,
      knownFields: {
        ...knownFields,
        if (retainTraffic) ...oldFields.where((field) => field != 'expire'),
        if (retainExpiry) 'expire',
      },
      remainingObservedAt: retainTraffic
          ? old.trafficObservedAt ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
          : remainingObservedAt,
      expireObservedAt: retainExpiry
          ? old.expiryObservedAt ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
          : expireObservedAt,
      exhausted: retainTraffic ? previous.exhausted : exhausted,
    );
  }
}
