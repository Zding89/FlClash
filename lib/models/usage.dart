import 'package:fl_clash/enum/enum.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/usage.freezed.dart';
part 'generated/usage.g.dart';

@freezed
abstract class UsageCollectionParams with _$UsageCollectionParams {
  const factory UsageCollectionParams({
    required bool enabled,
    int? profileId,
    required String profileLabel,
    @Default(0) int revision,
  }) = _UsageCollectionParams;

  factory UsageCollectionParams.fromJson(Map<String, Object?> json) =>
      _$UsageCollectionParamsFromJson(json);
}

@freezed
abstract class UsageBatchAck with _$UsageBatchAck {
  const factory UsageBatchAck({
    required String sessionId,
    required int sequence,
  }) = _UsageBatchAck;

  factory UsageBatchAck.fromJson(Map<String, Object?> json) =>
      _$UsageBatchAckFromJson(json);
}

@freezed
abstract class UsageBucketData with _$UsageBucketData {
  const factory UsageBucketData({
    required int minute,
    int? profileId,
    @Default('') String profileLabel,
    @Default(UsageRoute.unknown) UsageRoute route,
    @Default('') String node,
    @Default('') String process,
    @Default('') String processPath,
    @Default('') String domain,
    @Default('') String host,
    @Default('') String destinationIP,
    @Default(0) int upload,
    @Default(0) int download,
    @Default(0) int connections,
  }) = _UsageBucketData;

  factory UsageBucketData.fromJson(Map<String, Object?> json) =>
      _$UsageBucketDataFromJson(json);
}

@freezed
abstract class UsageBatch with _$UsageBatch {
  const factory UsageBatch({
    required String sessionId,
    required int sequence,
    @Default([]) List<UsageBucketData> buckets,
    @Default(false) bool degraded,
    @Default(0) int degradedStartMinute,
    @Default(0) int degradedEndMinute,
  }) = _UsageBatch;

  factory UsageBatch.fromJson(Map<String, Object?> json) =>
      _$UsageBatchFromJson(json);
}

@freezed
abstract class UsageFilter with _$UsageFilter {
  const factory UsageFilter({
    required DateTime start,
    required DateTime end,
    @Default(UsageTrafficScope.proxy) UsageTrafficScope scope,
    int? profileId,
    String? profileLabel,
    String? node,
    String? processPath,
    String? processLabel,
    String? domain,
    @Default(false) bool liveEnd,
    @Default(false) bool calendarToday,
    Duration? rollingWindow,
  }) = _UsageFilter;
}

extension UsageFilterExt on UsageFilter {
  UsageFilter effectiveAt(DateTime now) {
    if (!liveEnd) {
      return this;
    }
    return copyWith(
      start: calendarToday
          ? DateTime(now.year, now.month, now.day)
          : rollingWindow == null
          ? start
          : now.subtract(rollingWindow!),
      end: now,
    );
  }

  UsageFilter get effective => effectiveAt(DateTime.now());
}

@freezed
abstract class UsageSummary with _$UsageSummary {
  const factory UsageSummary({
    @Default(0) int upload,
    @Default(0) int download,
    @Default(0) int connections,
  }) = _UsageSummary;

  const UsageSummary._();

  int get total => upload + download;
}

@freezed
abstract class UsageTrendPoint with _$UsageTrendPoint {
  const factory UsageTrendPoint({
    required DateTime time,
    @Default(0) int upload,
    @Default(0) int download,
    @Default(0) int connections,
  }) = _UsageTrendPoint;

  const UsageTrendPoint._();

  int get total => upload + download;
}

@freezed
abstract class UsageRankingItem with _$UsageRankingItem {
  const factory UsageRankingItem({
    required String key,
    required String label,
    @Default(0) int upload,
    @Default(0) int download,
    @Default(0) int connections,
  }) = _UsageRankingItem;

  const UsageRankingItem._();

  int get total => upload + download;
}

@freezed
abstract class UsageOverview with _$UsageOverview {
  const factory UsageOverview({
    required UsageSummary summary,
    @Default([]) List<UsageTrendPoint> trend,
    @Default([]) List<UsageTrendPoint> hourlyDistribution,
    @Default({}) Map<UsageDimension, List<UsageRankingItem>> rankings,
  }) = _UsageOverview;
}
