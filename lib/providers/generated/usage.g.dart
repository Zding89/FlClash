// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../usage.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(usagePlatformSupported)
final usagePlatformSupportedProvider = UsagePlatformSupportedProvider._();

final class UsagePlatformSupportedProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  UsagePlatformSupportedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'usagePlatformSupportedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$usagePlatformSupportedHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return usagePlatformSupported(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$usagePlatformSupportedHash() =>
    r'0aa1b550b251ace208854b1afd3630a838e1ff2b';

@ProviderFor(usageConfigurationRetrySchedule)
final usageConfigurationRetryScheduleProvider =
    UsageConfigurationRetryScheduleProvider._();

final class UsageConfigurationRetryScheduleProvider
    extends $FunctionalProvider<List<Duration>, List<Duration>, List<Duration>>
    with $Provider<List<Duration>> {
  UsageConfigurationRetryScheduleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'usageConfigurationRetryScheduleProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$usageConfigurationRetryScheduleHash();

  @$internal
  @override
  $ProviderElement<List<Duration>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<Duration> create(Ref ref) {
    return usageConfigurationRetrySchedule(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Duration> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Duration>>(value),
    );
  }
}

String _$usageConfigurationRetryScheduleHash() =>
    r'7c17bf1c7cc74c0fc649984db929aaa8c8e11a68';

@ProviderFor(usageStore)
final usageStoreProvider = UsageStoreProvider._();

final class UsageStoreProvider
    extends $FunctionalProvider<UsageDatabase, UsageDatabase, UsageDatabase>
    with $Provider<UsageDatabase> {
  UsageStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'usageStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$usageStoreHash();

  @$internal
  @override
  $ProviderElement<UsageDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UsageDatabase create(Ref ref) {
    return usageStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UsageDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UsageDatabase>(value),
    );
  }
}

String _$usageStoreHash() => r'2b68ada330db3bef887a145846775f3cf0840844';

@ProviderFor(usageCore)
final usageCoreProvider = UsageCoreProvider._();

final class UsageCoreProvider
    extends $FunctionalProvider<CoreController, CoreController, CoreController>
    with $Provider<CoreController> {
  UsageCoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'usageCoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$usageCoreHash();

  @$internal
  @override
  $ProviderElement<CoreController> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CoreController create(Ref ref) {
    return usageCore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CoreController value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CoreController>(value),
    );
  }
}

String _$usageCoreHash() => r'cd6bfcf131679fd1275583d21209f4a0017ef165';

@ProviderFor(usageEnabled)
final usageEnabledProvider = UsageEnabledProvider._();

final class UsageEnabledProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  UsageEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'usageEnabledProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$usageEnabledHash();

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    return usageEnabled(ref);
  }
}

String _$usageEnabledHash() => r'13513de824f894a6c9d488db11c8748a336d2251';

@ProviderFor(UsageRevision)
final usageRevisionProvider = UsageRevisionProvider._();

final class UsageRevisionProvider
    extends $NotifierProvider<UsageRevision, int> {
  UsageRevisionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'usageRevisionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$usageRevisionHash();

  @$internal
  @override
  UsageRevision create() => UsageRevision();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$usageRevisionHash() => r'680dce44ac14d29b10b839eea8eccd782364054a';

abstract class _$UsageRevision extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(UsageAnalyticsRevision)
final usageAnalyticsRevisionProvider = UsageAnalyticsRevisionProvider._();

final class UsageAnalyticsRevisionProvider
    extends $NotifierProvider<UsageAnalyticsRevision, int> {
  UsageAnalyticsRevisionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'usageAnalyticsRevisionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$usageAnalyticsRevisionHash();

  @$internal
  @override
  UsageAnalyticsRevision create() => UsageAnalyticsRevision();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$usageAnalyticsRevisionHash() =>
    r'cd6317b9b4dd8192264f2b8484241f492e2ec85d';

abstract class _$UsageAnalyticsRevision extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(UsageClock)
final usageClockProvider = UsageClockProvider._();

final class UsageClockProvider extends $NotifierProvider<UsageClock, DateTime> {
  UsageClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'usageClockProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$usageClockHash();

  @$internal
  @override
  UsageClock create() => UsageClock();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime>(value),
    );
  }
}

String _$usageClockHash() => r'f6d66bd32348b3e88cba36cf0e6bdaa691b94e03';

abstract class _$UsageClock extends $Notifier<DateTime> {
  DateTime build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DateTime, DateTime>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DateTime, DateTime>,
              DateTime,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(UsageIssues)
final usageIssuesProvider = UsageIssuesProvider._();

final class UsageIssuesProvider
    extends $NotifierProvider<UsageIssues, Set<UsageIssue>> {
  UsageIssuesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'usageIssuesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$usageIssuesHash();

  @$internal
  @override
  UsageIssues create() => UsageIssues();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<UsageIssue> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<UsageIssue>>(value),
    );
  }
}

String _$usageIssuesHash() => r'a7e02df8fb0e2832c45cfb9bab2726036f4def5d';

abstract class _$UsageIssues extends $Notifier<Set<UsageIssue>> {
  Set<UsageIssue> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Set<UsageIssue>, Set<UsageIssue>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<UsageIssue>, Set<UsageIssue>>,
              Set<UsageIssue>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(UsageFilterState)
final usageFilterStateProvider = UsageFilterStateProvider._();

final class UsageFilterStateProvider
    extends $NotifierProvider<UsageFilterState, UsageFilter> {
  UsageFilterStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'usageFilterStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$usageFilterStateHash();

  @$internal
  @override
  UsageFilterState create() => UsageFilterState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UsageFilter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UsageFilter>(value),
    );
  }
}

String _$usageFilterStateHash() => r'76a2bfdcecb2ac2dd4625cb0e521d951ebb83d3b';

abstract class _$UsageFilterState extends $Notifier<UsageFilter> {
  UsageFilter build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<UsageFilter, UsageFilter>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<UsageFilter, UsageFilter>,
              UsageFilter,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(usageOverview)
final usageOverviewProvider = UsageOverviewProvider._();

final class UsageOverviewProvider
    extends
        $FunctionalProvider<
          AsyncValue<UsageOverview>,
          UsageOverview,
          FutureOr<UsageOverview>
        >
    with $FutureModifier<UsageOverview>, $FutureProvider<UsageOverview> {
  UsageOverviewProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'usageOverviewProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$usageOverviewHash();

  @$internal
  @override
  $FutureProviderElement<UsageOverview> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<UsageOverview> create(Ref ref) {
    return usageOverview(ref);
  }
}

String _$usageOverviewHash() => r'091938b70640fd64854a284dbca7d975013c2d40';

@ProviderFor(usageRanking)
final usageRankingProvider = UsageRankingFamily._();

final class UsageRankingProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<UsageRankingItem>>,
          List<UsageRankingItem>,
          FutureOr<List<UsageRankingItem>>
        >
    with
        $FutureModifier<List<UsageRankingItem>>,
        $FutureProvider<List<UsageRankingItem>> {
  UsageRankingProvider._({
    required UsageRankingFamily super.from,
    required (UsageDimension, UsageSort, String, int) super.argument,
  }) : super(
         retry: null,
         name: r'usageRankingProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$usageRankingHash();

  @override
  String toString() {
    return r'usageRankingProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<UsageRankingItem>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<UsageRankingItem>> create(Ref ref) {
    final argument = this.argument as (UsageDimension, UsageSort, String, int);
    return usageRanking(
      ref,
      argument.$1,
      argument.$2,
      argument.$3,
      argument.$4,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is UsageRankingProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$usageRankingHash() => r'8028056139ffb8f7e7ec0202d0f324b5afa5151c';

final class UsageRankingFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<UsageRankingItem>>,
          (UsageDimension, UsageSort, String, int)
        > {
  UsageRankingFamily._()
    : super(
        retry: null,
        name: r'usageRankingProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  UsageRankingProvider call(
    UsageDimension dimension,
    UsageSort sort,
    String search,
    int limit,
  ) => UsageRankingProvider._(
    argument: (dimension, sort, search, limit),
    from: this,
  );

  @override
  String toString() => r'usageRankingProvider';
}

@ProviderFor(usageIdentificationCoverage)
final usageIdentificationCoverageProvider =
    UsageIdentificationCoverageFamily._();

final class UsageIdentificationCoverageProvider
    extends $FunctionalProvider<AsyncValue<double>, double, FutureOr<double>>
    with $FutureModifier<double>, $FutureProvider<double> {
  UsageIdentificationCoverageProvider._({
    required UsageIdentificationCoverageFamily super.from,
    required UsageDimension super.argument,
  }) : super(
         retry: null,
         name: r'usageIdentificationCoverageProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$usageIdentificationCoverageHash();

  @override
  String toString() {
    return r'usageIdentificationCoverageProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<double> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<double> create(Ref ref) {
    final argument = this.argument as UsageDimension;
    return usageIdentificationCoverage(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is UsageIdentificationCoverageProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$usageIdentificationCoverageHash() =>
    r'da74ad3d42b052e60ddad80aac0a51169ee9de40';

final class UsageIdentificationCoverageFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<double>, UsageDimension> {
  UsageIdentificationCoverageFamily._()
    : super(
        retry: null,
        name: r'usageIdentificationCoverageProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  UsageIdentificationCoverageProvider call(UsageDimension dimension) =>
      UsageIdentificationCoverageProvider._(argument: dimension, from: this);

  @override
  String toString() => r'usageIdentificationCoverageProvider';
}

@ProviderFor(todayProxyUsage)
final todayProxyUsageProvider = TodayProxyUsageProvider._();

final class TodayProxyUsageProvider
    extends
        $FunctionalProvider<
          AsyncValue<UsageSummary>,
          UsageSummary,
          FutureOr<UsageSummary>
        >
    with $FutureModifier<UsageSummary>, $FutureProvider<UsageSummary> {
  TodayProxyUsageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'todayProxyUsageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$todayProxyUsageHash();

  @$internal
  @override
  $FutureProviderElement<UsageSummary> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<UsageSummary> create(Ref ref) {
    return todayProxyUsage(ref);
  }
}

String _$todayProxyUsageHash() => r'720130878434600a3945b8d057d508c4d7756e02';

@ProviderFor(usageHasDegradedData)
final usageHasDegradedDataProvider = UsageHasDegradedDataProvider._();

final class UsageHasDegradedDataProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  UsageHasDegradedDataProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'usageHasDegradedDataProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$usageHasDegradedDataHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return usageHasDegradedData(ref);
  }
}

String _$usageHasDegradedDataHash() =>
    r'e2fd6373f288eb1a095a12d3d65487ed5d45e975';

@ProviderFor(usageHasAnyDegradedData)
final usageHasAnyDegradedDataProvider = UsageHasAnyDegradedDataProvider._();

final class UsageHasAnyDegradedDataProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  UsageHasAnyDegradedDataProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'usageHasAnyDegradedDataProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$usageHasAnyDegradedDataHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return usageHasAnyDegradedData(ref);
  }
}

String _$usageHasAnyDegradedDataHash() =>
    r'3ec39b7ed5fd334344fb801fbfe67e1d28e1f158';

@ProviderFor(UsageRuntime)
final usageRuntimeProvider = UsageRuntimeProvider._();

final class UsageRuntimeProvider
    extends $AsyncNotifierProvider<UsageRuntime, void> {
  UsageRuntimeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'usageRuntimeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$usageRuntimeHash();

  @$internal
  @override
  UsageRuntime create() => UsageRuntime();
}

String _$usageRuntimeHash() => r'100aa9249826bde0385e0b78250f8c3e79a53bc9';

abstract class _$UsageRuntime extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
