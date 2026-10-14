import 'package:fl_clash/models/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retained legacy traffic is usable without inventing an expiry', () {
    final stamp = DateTime.utc(2026, 10, 13);
    final metadata = SubscriptionMetadata.fromInfo(
      const SubscriptionInfo(total: 1234, upload: 5, download: 70),
      updatedAt: stamp,
    );
    expect(metadata.remainingBytes, 1159);
    expect(metadata.trafficObservedAt, stamp);
    expect(metadata.expiryKnown, isFalse);
    expect(metadata.unlimited, isFalse);
  });

  test('explicit zero expiry is unlimited and dates use Beijing time', () {
    expect(SubscriptionInfo.formHString('expire=0').metadata.unlimited, isTrue);
    expect(const SubscriptionInfo().metadata.unlimited, isFalse);
    final info = SubscriptionInfo(
      expire: DateTime.utc(2026, 11, 21, 17).millisecondsSinceEpoch ~/ 1000,
    );
    expect(info.metadata.expiryDate, '2026-11-22');
  });

  test('partial new counters stay unknown without a complete prior record', () {
    for (final value in [
      'total=100;download=10',
      'upload=1;download=2',
      'upload=0;download=0;total=0',
    ]) {
      expect(
        SubscriptionInfo.formHString(value).metadata.trafficKnown,
        isFalse,
      );
    }
  });

  test('missing headers retain fields and their own observation times', () {
    final oldStamp = DateTime.utc(2026, 10, 1);
    final previous = SubscriptionInfo(
      total: 100,
      download: 20,
      expire: 100,
      knownFields: const {'upload', 'download', 'total', 'expire'},
      observedAt: oldStamp,
    );
    final retained = SubscriptionInfo.formHString(null).retaining(previous);
    expect(retained.metadata.remainingBytes, 80);
    expect(retained.metadata.trafficObservedAt, oldStamp);
    expect(retained.metadata.expiryObservedAt, oldStamp);
    final unlimited = SubscriptionInfo.formHString(
      'expire=0',
    ).retaining(previous);
    expect(unlimited.expire, 0);
    expect(unlimited.metadata.unlimited, isTrue);
    expect(unlimited.metadata.trafficObservedAt, oldStamp);
    final fresh = SubscriptionInfo.formHString(
      'upload=1;download=9;total=200',
    ).retaining(previous);
    expect(fresh.metadata.remainingBytes, 190);
    expect(fresh.metadata.expiryObservedAt, oldStamp);
  });

  test('legacy fields without any date never gain fresh observation time', () {
    final retained = SubscriptionInfo.formHString(
      'expire=0',
    ).retaining(const SubscriptionInfo(total: 100, download: 20));
    expect(retained.metadata.remainingBytes, 80);
    expect(retained.metadata.trafficObservedAt?.millisecondsSinceEpoch, 0);
  });
}
