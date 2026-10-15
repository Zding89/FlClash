import 'package:fl_clash/models/profile.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/policy/quota_overview.dart';
import 'package:flutter_test/flutter_test.dart';

Profile _profile(
  int id, {
  int total = 0,
  int used = 0,
  int? expiry,
  bool trafficKnown = true,
}) {
  final fields = <String>{
    if (trafficKnown) ...{'total', 'upload', 'download'},
    if (expiry != null) 'expire',
  };
  return Profile(
    id: id,
    label: 'Source $id',
    autoUpdateDuration: const Duration(hours: 6),
    subscriptionInfo: SubscriptionInfo(
      total: total,
      upload: used,
      knownFields: fields,
      expire: expiry == null ? 0 : expiry ~/ 1000,
      observedAt: trafficKnown ? null : DateTime.utc(2026, 1, 1),
    ),
  );
}

LocalNode _node(int sourceId, String region) => LocalNode(
  id: '$sourceId-node-$region',
  sourceId: '$sourceId',
  label: '$region node',
  sourceLabel: 'Source $sourceId',
  protocol: 'http',
  raw: {'name': '$region node', 'type': 'http'},
  attributes: NodeAttributes(
    region: region,
    regionBasis: NodeAttributeBasis.manual,
  ),
);

void main() {
  const calculator = LocalQuotaOverviewCalculator();
  final now = DateTime.utc(2026, 10, 15, 4);

  test('keeps used and dated remaining amounts in one exact total', () {
    final result = calculator.calculate(
      profiles: [
        _profile(
          1,
          total: 100,
          used: 20,
          expiry: now.add(const Duration(days: 30)).millisecondsSinceEpoch,
        ),
        _profile(
          2,
          total: 200,
          used: 50,
          expiry: now.add(const Duration(days: 31)).millisecondsSinceEpoch,
        ),
        _profile(3, total: 300, used: 40, expiry: 0),
        _profile(4, total: 400, used: 500, expiry: now.millisecondsSinceEpoch),
        _profile(6, total: 600, used: 20),
        _profile(5, total: 500, used: 10, trafficKnown: false),
      ],
      now: now,
    );

    expect(result.knownTotalBytes, 1600);
    expect(result.usedBytes, 20 + 50 + 40 + 400 + 20);
    expect(result.remainingBytes, 1600 - result.usedBytes);
    expect(result.segmentTotal, result.knownTotalBytes);
    expect(result.overageBytes, 100);
    expect(result.unknownTrafficSources, 1);
    expect(result.sources.map((source) => source.expiryBucket), [
      QuotaExpiryBucket.expiringSoon,
      QuotaExpiryBucket.expiringLater,
      QuotaExpiryBucket.unlimited,
      QuotaExpiryBucket.expired,
      QuotaExpiryBucket.unknown,
      QuotaExpiryBucket.unknown,
    ]);
  });

  test('uses actual millisecond boundary for the 30-day bucket', () {
    final result = calculator.calculate(
      profiles: [
        _profile(
          1,
          total: 1,
          expiry: now.add(const Duration(days: 30)).millisecondsSinceEpoch,
        ),
        _profile(
          2,
          total: 1,
          expiry: now
              .add(const Duration(days: 30, seconds: 1))
              .millisecondsSinceEpoch,
        ),
      ],
      now: now,
    );

    expect(result.sources[0].expiryBucket, QuotaExpiryBucket.expiringSoon);
    expect(result.sources[1].expiryBucket, QuotaExpiryBucket.expiringLater);
  });

  test('deduplicates selected sources and keeps only their regions', () {
    final source = _profile(7, total: 100, used: 10, expiry: 0);
    final result = calculator.calculate(
      profiles: [source, source, _profile(8, trafficKnown: false)],
      nodes: [_node(7, 'JP'), _node(7, 'US'), _node(99, 'DE')],
      now: now,
    );

    expect(result.sources, hasLength(2));
    expect(result.sources.first.regions, {'JP', 'US'});
    expect(result.knownTotalBytes, 100);
  });

  test('does not divide or manufacture a bar for zero or unknown totals', () {
    final result = calculator.calculate(
      profiles: [_profile(1, total: 0), _profile(2, trafficKnown: false)],
      now: now,
    );

    expect(result.hasKnownTraffic, isFalse);
    expect(result.segments, isEmpty);
    expect(result.segmentTotal, 0);
    expect(result.unknownTrafficSources, 2);
  });

  test('keeps totals closed when several large quotas exceed the old cap', () {
    final result = calculator.calculate(
      profiles: [
        _profile(1, total: 9007199254740991, used: 1),
        _profile(2, total: 9007199254740991, used: 2),
      ],
      now: now,
    );

    expect(result.knownTotalBytes, 18014398509481982);
    expect(result.usedBytes, 3);
    expect(result.remainingBytes, result.knownTotalBytes - result.usedBytes);
    expect(result.segmentTotal, result.knownTotalBytes);
    expect(result.remainingBytes + result.usedBytes, result.knownTotalBytes);
  });
}
