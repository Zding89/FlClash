import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/database/usage_database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generated/usage.g.dart';

enum UsageIssue { persistence, degraded }

typedef _UsageCoreConfiguration = ({
  bool enabled,
  int? profileId,
  String profileLabel,
});

@Riverpod(keepAlive: true)
bool usagePlatformSupported(Ref ref) => system.isMacOS;

@Riverpod(keepAlive: true)
List<Duration> usageConfigurationRetrySchedule(Ref ref) => const [
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 4),
  Duration(seconds: 8),
  Duration(seconds: 16),
  Duration(seconds: 30),
];

@Riverpod(keepAlive: true)
UsageDatabase usageStore(Ref ref) => usageDatabase;

@Riverpod(keepAlive: true)
CoreController usageCore(Ref ref) => coreController;

@Riverpod(keepAlive: true)
Stream<bool> usageEnabled(Ref ref) {
  return ref.watch(usageStoreProvider).watchEnabled();
}

@Riverpod(keepAlive: true)
class UsageRevision extends _$UsageRevision {
  @override
  int build() => 0;

  void bump() => state++;
}

@Riverpod(keepAlive: true)
class UsageAnalyticsRevision extends _$UsageAnalyticsRevision {
  @override
  int build() => 0;

  void bump() => state++;
}

@riverpod
class UsageClock extends _$UsageClock {
  @override
  DateTime build() => DateTime.now();

  void refresh() {
    state = DateTime.now();
  }

  void update(DateTime value) {
    state = value;
  }

  void tick() {
    final now = DateTime.now();
    if (now.year != state.year ||
        now.month != state.month ||
        now.day != state.day ||
        now.hour != state.hour ||
        now.minute != state.minute) {
      state = now;
    }
  }
}

@Riverpod(keepAlive: true)
class UsageIssues extends _$UsageIssues {
  @override
  Set<UsageIssue> build() => const {};

  void add(UsageIssue issue) => state = {...state, issue};

  void remove(UsageIssue issue) {
    if (state.contains(issue)) {
      state = {...state}..remove(issue);
    }
  }

  void clear() => state = const {};
}

@Riverpod(keepAlive: true)
class UsageFilterState extends _$UsageFilterState {
  @override
  UsageFilter build() {
    final now = DateTime.now();
    return UsageFilter(
      start: DateTime(now.year, now.month, now.day),
      end: now,
      liveEnd: true,
      calendarToday: true,
    );
  }

  void setToday() {
    final now = DateTime.now();
    state = state.copyWith(
      start: DateTime(now.year, now.month, now.day),
      end: now,
      liveEnd: true,
      calendarToday: true,
      rollingWindow: null,
    );
  }

  void setLast(Duration duration) {
    final now = DateTime.now();
    state = state.copyWith(
      start: now.subtract(duration),
      end: now,
      liveEnd: true,
      calendarToday: false,
      rollingWindow: duration,
    );
  }

  void setRange(DateTime start, DateTime end) {
    state = state.copyWith(
      start: start,
      end: end,
      liveEnd: false,
      calendarToday: false,
      rollingWindow: null,
    );
  }

  void setScope(UsageTrafficScope scope) {
    state = state.copyWith(scope: scope);
  }

  void applyRanking(UsageDimension dimension, UsageRankingItem item) {
    state = switch (dimension) {
      UsageDimension.node => state.copyWith(node: item.key),
      UsageDimension.application => state.copyWith(
        processPath: item.key,
        processLabel: item.label,
      ),
      UsageDimension.domain => state.copyWith(domain: item.key),
      UsageDimension.profile => state.copyWith(
        profileId: int.tryParse(item.key),
        profileLabel: item.label,
      ),
      UsageDimension.overview => state,
    };
  }

  void clearDimension(UsageDimension dimension) {
    state = switch (dimension) {
      UsageDimension.node => state.copyWith(node: null),
      UsageDimension.application => state.copyWith(
        processPath: null,
        processLabel: null,
      ),
      UsageDimension.domain => state.copyWith(domain: null),
      UsageDimension.profile => state.copyWith(
        profileId: null,
        profileLabel: null,
      ),
      UsageDimension.overview => state,
    };
  }

  void resetDimensions() {
    state = state.copyWith(
      profileId: null,
      profileLabel: null,
      node: null,
      processPath: null,
      processLabel: null,
      domain: null,
    );
  }
}

@riverpod
Future<UsageOverview> usageOverview(Ref ref) async {
  ref.watch(usageAnalyticsRevisionProvider);
  final now = ref.watch(usageClockProvider);
  final filter = ref.watch(usageFilterStateProvider).effectiveAt(now);
  return ref.watch(usageStoreProvider).overview(filter);
}

@riverpod
Future<List<UsageRankingItem>> usageRanking(
  Ref ref,
  UsageDimension dimension,
  UsageSort sort,
  String search,
  int limit,
) async {
  ref.watch(usageAnalyticsRevisionProvider);
  final now = ref.watch(usageClockProvider);
  final filter = ref.watch(usageFilterStateProvider).effectiveAt(now);
  return ref
      .watch(usageStoreProvider)
      .ranking(filter, dimension, sort: sort, search: search, limit: limit);
}

@riverpod
Future<double> usageIdentificationCoverage(
  Ref ref,
  UsageDimension dimension,
) async {
  ref.watch(usageAnalyticsRevisionProvider);
  final now = ref.watch(usageClockProvider);
  final filter = ref.watch(usageFilterStateProvider).effectiveAt(now);
  return ref
      .watch(usageStoreProvider)
      .identificationCoverage(filter, dimension);
}

@riverpod
Future<UsageSummary> todayProxyUsage(Ref ref) async {
  ref.watch(usageRevisionProvider);
  final now = ref.watch(usageClockProvider);
  return ref.watch(usageStoreProvider).todayProxySummary(now: now);
}

@riverpod
Future<bool> usageHasDegradedData(Ref ref) {
  ref.watch(usageAnalyticsRevisionProvider);
  final now = ref.watch(usageClockProvider);
  final filter = ref.watch(usageFilterStateProvider).effectiveAt(now);
  return ref.watch(usageStoreProvider).hasDegradedData(filter);
}

@riverpod
Future<bool> usageHasAnyDegradedData(Ref ref) {
  ref.watch(usageAnalyticsRevisionProvider);
  return ref.watch(usageStoreProvider).hasAnyDegradedData();
}

@Riverpod(keepAlive: true)
class UsageRuntime extends _$UsageRuntime {
  Timer? _pollTimer;
  Timer? _cleanupTimer;
  Timer? _analyticsTimer;
  Timer? _configurationRetryTimer;
  late UsageDatabase _store;
  late CoreController _core;
  bool _enabled = false;
  bool _disposed = false;
  bool _analyticsPending = false;
  int _configurationRevision = 0;
  int _configurationRetryAttempt = 0;
  _UsageCoreConfiguration? _desiredCoreConfiguration;
  final Completer<void> _ready = Completer<void>();
  Object? _initializationError;
  StackTrace? _initializationStackTrace;
  Future<void>? _flushOperation;
  Future<void> _controlTail = Future.value();

  @override
  Future<void> build() async {
    try {
      _store = ref.read(usageStoreProvider);
      _core = ref.read(usageCoreProvider);
      ref.onDispose(() {
        _disposed = true;
        _pollTimer?.cancel();
        _cleanupTimer?.cancel();
        _analyticsTimer?.cancel();
        _configurationRetryTimer?.cancel();
      });
      _enabled = await _store.isEnabled();
      if (_enabled) {
        _setDesiredCoreConfiguration(_coreConfiguration(true));
        try {
          await _applyDesiredCoreConfiguration();
        } catch (error) {
          commonPrint.log(
            'Failed to restore usage collection: $error',
            logLevel: LogLevel.warning,
          );
        }
        _startTimers();
      }
      try {
        await _runMaintenance();
      } catch (error) {
        commonPrint.log(
          'Failed to maintain usage history: $error',
          logLevel: LogLevel.warning,
        );
      }
    } catch (error, stackTrace) {
      _initializationError = error;
      _initializationStackTrace = stackTrace;
      rethrow;
    } finally {
      if (!_ready.isCompleted) {
        _ready.complete();
      }
    }
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _controlTail = _controlTail.catchError((_) {}).then((_) async {
      try {
        await _ready.future;
        final initializationError = _initializationError;
        if (initializationError != null) {
          Error.throwWithStackTrace(
            initializationError,
            _initializationStackTrace!,
          );
        }
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> setEnabled(bool enabled) {
    return _serialize(() async {
      if (enabled == _enabled) {
        return;
      }
      state = const AsyncLoading();
      try {
        if (enabled) {
          final configuration = _coreConfiguration(true);
          try {
            await _sendCoreConfiguration(configuration);
          } catch (error, stackTrace) {
            await _compensateFailedEnable(configuration);
            Error.throwWithStackTrace(error, stackTrace);
          }
          try {
            await _store.setEnabled(true);
          } catch (error, stackTrace) {
            await _compensateFailedEnable(configuration);
            Error.throwWithStackTrace(error, stackTrace);
          }
          _enabled = true;
          _setDesiredCoreConfiguration(configuration);
          _configurationApplied(configuration);
          _startTimers();
        } else {
          final previousConfiguration =
              _desiredCoreConfiguration ?? _coreConfiguration(true);
          try {
            await _sendCoreConfiguration((
              enabled: false,
              profileId: previousConfiguration.profileId,
              profileLabel: previousConfiguration.profileLabel,
            ));
          } catch (error, stackTrace) {
            _setDesiredCoreConfiguration(previousConfiguration);
            try {
              await _applyDesiredCoreConfiguration();
            } catch (rollbackError) {
              commonPrint.log(
                'Failed to restore usage collection after pause rejection: '
                '$rollbackError',
                logLevel: LogLevel.warning,
              );
            }
            Error.throwWithStackTrace(error, stackTrace);
          }
          try {
            await flush(strict: true);
            await _store.setEnabled(false);
          } catch (error, stackTrace) {
            _setDesiredCoreConfiguration(previousConfiguration);
            try {
              await _applyDesiredCoreConfiguration();
            } catch (rollbackError) {
              commonPrint.log(
                'Failed to restore usage collection after pause failure: '
                '$rollbackError',
                logLevel: LogLevel.warning,
              );
            }
            Error.throwWithStackTrace(error, stackTrace);
          }
          _enabled = false;
          _setDesiredCoreConfiguration((
            enabled: false,
            profileId: previousConfiguration.profileId,
            profileLabel: previousConfiguration.profileLabel,
          ));
          _configurationApplied(_desiredCoreConfiguration!);
          _pollTimer?.cancel();
        }
        state = const AsyncData(null);
      } catch (error, stackTrace) {
        state = AsyncError(error, stackTrace);
        rethrow;
      }
      ref.invalidate(usageEnabledProvider);
    });
  }

  Future<void> syncCore({bool throwOnError = false}) {
    return _serialize(() async {
      if (!_enabled) {
        final desired = _desiredCoreConfiguration;
        if (desired != null && !desired.enabled) {
          try {
            await _applyDesiredCoreConfiguration();
          } catch (error) {
            commonPrint.log(
              'Failed to sync disabled usage collection: $error',
              logLevel: LogLevel.warning,
            );
            if (throwOnError) {
              rethrow;
            }
          }
        }
        return;
      }
      _setDesiredCoreConfiguration(_coreConfiguration(true));
      try {
        await _applyDesiredCoreConfiguration();
      } catch (error) {
        commonPrint.log(
          'Failed to sync usage collection: $error',
          logLevel: LogLevel.warning,
        );
        if (throwOnError) {
          rethrow;
        }
      }
    });
  }

  Future<void> syncProfile({
    required int? profileId,
    required String profileLabel,
    bool throwOnError = false,
  }) {
    return _serialize(() async {
      if (!_enabled) {
        return;
      }
      _setDesiredCoreConfiguration(
        _coreConfiguration(
          true,
          profile: (profileId: profileId, profileLabel: profileLabel),
        ),
      );
      try {
        await _applyDesiredCoreConfiguration();
      } catch (error) {
        commonPrint.log(
          'Failed to sync applied usage profile: $error',
          logLevel: LogLevel.warning,
        );
        if (throwOnError) {
          rethrow;
        }
      }
    });
  }

  Future<void> syncLocalCalendar() {
    return _serialize(() async {
      await _store.syncLocalCalendar();
      if (!_disposed) {
        ref.read(usageRevisionProvider.notifier).bump();
        ref.read(usageAnalyticsRevisionProvider.notifier).bump();
      }
    });
  }

  Future<void> prepareForShutdown() {
    return _serialize(() async {
      if (!_enabled) {
        return;
      }
      final desired = _desiredCoreConfiguration ?? _coreConfiguration(true);
      await _sendCoreConfiguration((
        enabled: false,
        profileId: desired.profileId,
        profileLabel: desired.profileLabel,
      ));
      try {
        await flush(strict: true);
      } catch (_) {
        await _sendCoreConfiguration(desired);
        rethrow;
      }
    });
  }

  _UsageCoreConfiguration _coreConfiguration(
    bool enabled, {
    ({int? profileId, String profileLabel})? profile,
  }) {
    final currentProfileId = ref.read(currentProfileIdProvider);
    final currentProfile = ref
        .read(profilesProvider)
        .getProfile(currentProfileId);
    final profileContext =
        profile ??
        (
          profileId: currentProfileId,
          profileLabel: currentProfile?.label ?? '',
        );
    return (
      enabled: enabled,
      profileId: profileContext.profileId,
      profileLabel: profileContext.profileLabel,
    );
  }

  Future<void> _sendCoreConfiguration(
    _UsageCoreConfiguration configuration,
  ) async {
    final configured = await _core.configureUsageCollection(
      UsageCollectionParams(
        enabled: configuration.enabled,
        profileId: configuration.profileId,
        profileLabel: configuration.profileLabel,
        revision: ++_configurationRevision,
      ),
    );
    if (!configured) {
      throw StateError('Core rejected usage collection configuration');
    }
  }

  void _setDesiredCoreConfiguration(_UsageCoreConfiguration configuration) {
    if (_desiredCoreConfiguration == configuration) {
      return;
    }
    _desiredCoreConfiguration = configuration;
    _configurationRetryAttempt = 0;
    _configurationRetryTimer?.cancel();
    _configurationRetryTimer = null;
  }

  Future<void> _applyDesiredCoreConfiguration() async {
    final configuration = _desiredCoreConfiguration;
    if (configuration == null) {
      return;
    }
    try {
      await _sendCoreConfiguration(configuration);
      _configurationApplied(configuration);
    } catch (_) {
      _scheduleConfigurationRetry();
      rethrow;
    }
  }

  void _configurationApplied(_UsageCoreConfiguration configuration) {
    if (_desiredCoreConfiguration != configuration) {
      return;
    }
    _configurationRetryAttempt = 0;
    _configurationRetryTimer?.cancel();
    _configurationRetryTimer = null;
  }

  void _scheduleConfigurationRetry() {
    final configuration = _desiredCoreConfiguration;
    if (_disposed ||
        configuration == null ||
        _configurationRetryTimer != null) {
      return;
    }
    final schedule = ref.read(usageConfigurationRetryScheduleProvider);
    final delay = schedule.isEmpty
        ? const Duration(seconds: 30)
        : schedule[min(_configurationRetryAttempt, schedule.length - 1)];
    _configurationRetryAttempt++;
    _configurationRetryTimer = Timer(delay, () {
      _configurationRetryTimer = null;
      if (_disposed) {
        return;
      }
      unawaited(
        _serialize(() async {
          if (_desiredCoreConfiguration != configuration) {
            return;
          }
          try {
            await _applyDesiredCoreConfiguration();
          } catch (error) {
            commonPrint.log(
              'Failed to retry usage collection configuration: $error',
              logLevel: LogLevel.warning,
            );
          }
        }),
      );
    });
  }

  Future<void> _compensateFailedEnable(
    _UsageCoreConfiguration configuration,
  ) async {
    final disabledConfiguration = (
      enabled: false,
      profileId: configuration.profileId,
      profileLabel: configuration.profileLabel,
    );
    _setDesiredCoreConfiguration(disabledConfiguration);
    try {
      await _applyDesiredCoreConfiguration();
    } catch (error) {
      commonPrint.log(
        'Failed to compensate usage collection enablement: $error',
        logLevel: LogLevel.warning,
      );
    }
  }

  void _startTimers() {
    _pollTimer?.cancel();
    _cleanupTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      ref.read(usageClockProvider.notifier).tick();
      unawaited(flush());
    });
    _cleanupTimer = Timer.periodic(const Duration(days: 1), (_) {
      unawaited(
        _runMaintenance().catchError((Object error) {
          commonPrint.log(
            'Failed to clean usage history: $error',
            logLevel: LogLevel.warning,
          );
        }),
      );
    });
  }

  Future<void> _runMaintenance() async {
    await _store.syncLocalCalendar();
    await _store.cleanup();
  }

  Future<void> flush({bool strict = false}) {
    if (!_enabled) {
      return Future.value();
    }
    var operation = _flushOperation;
    if (operation == null) {
      late Future<void> tracked;
      tracked = _flushOnce().whenComplete(() {
        if (identical(_flushOperation, tracked)) {
          _flushOperation = null;
        }
      });
      _flushOperation = tracked;
      operation = tracked;
    }
    if (strict) {
      return operation;
    }
    return operation.catchError((Object error) {
      commonPrint.log(
        'Failed to flush usage batch: $error',
        logLevel: LogLevel.warning,
      );
    });
  }

  Future<void> _flushOnce() async {
    if (!_enabled) {
      return;
    }
    try {
      while (true) {
        final batch = await _core.readUsageBatch();
        if (batch == null) {
          break;
        }
        await _store.ingest(batch);
        final acknowledged = await _core.ackUsageBatch(
          UsageBatchAck(sessionId: batch.sessionId, sequence: batch.sequence),
        );
        if (!acknowledged) {
          throw StateError('Core rejected usage batch acknowledgement');
        }
        if (!_disposed) {
          ref.read(usageRevisionProvider.notifier).bump();
          _scheduleAnalyticsRefresh();
        }
      }
      if (!_disposed) {
        ref.read(usageIssuesProvider.notifier).remove(UsageIssue.persistence);
      }
    } catch (error) {
      if (!_disposed) {
        ref.read(usageIssuesProvider.notifier).add(UsageIssue.persistence);
      }
      rethrow;
    }
  }

  void _scheduleAnalyticsRefresh() {
    if (_analyticsTimer == null) {
      ref.read(usageAnalyticsRevisionProvider.notifier).bump();
      _analyticsTimer = Timer(const Duration(seconds: 15), _refreshAnalytics);
      return;
    }
    _analyticsPending = true;
  }

  void _refreshAnalytics() {
    _analyticsTimer = null;
    if (_disposed || !_analyticsPending) {
      return;
    }
    _analyticsPending = false;
    ref.read(usageAnalyticsRevisionProvider.notifier).bump();
    _analyticsTimer = Timer(const Duration(seconds: 15), _refreshAnalytics);
  }

  Future<void> clear() {
    return _serialize(() async {
      state = const AsyncLoading();
      var paused = false;
      try {
        if (_enabled) {
          final desired = _desiredCoreConfiguration ?? _coreConfiguration(true);
          try {
            await _sendCoreConfiguration((
              enabled: false,
              profileId: desired.profileId,
              profileLabel: desired.profileLabel,
            ));
          } catch (error, stackTrace) {
            _setDesiredCoreConfiguration(desired);
            try {
              await _applyDesiredCoreConfiguration();
            } catch (rollbackError) {
              commonPrint.log(
                'Failed to restore usage collection after clear rejection: '
                '$rollbackError',
                logLevel: LogLevel.warning,
              );
            }
            Error.throwWithStackTrace(error, stackTrace);
          }
          paused = true;
        }
        try {
          if (paused) {
            await flush(strict: true);
          }
          await _store.clearUsage();
        } finally {
          if (paused) {
            await _applyDesiredCoreConfiguration();
          }
        }
        ref.read(usageIssuesProvider.notifier).clear();
        ref.read(usageRevisionProvider.notifier).bump();
        ref.read(usageAnalyticsRevisionProvider.notifier).bump();
        state = const AsyncData(null);
      } catch (error, stackTrace) {
        state = AsyncError(error, stackTrace);
        rethrow;
      }
    });
  }
}

class UsageCsvExporter {
  String _escape(Object? value) {
    final text = value?.toString() ?? '';
    return '"${text.replaceAll('"', '""')}"';
  }

  String _range(UsageFilter filter) {
    final format = DateFormat('yyyy-MM-dd HH:mm');
    return '${format.format(filter.start)} - ${format.format(filter.end)}';
  }

  List<Object?> _rankingRow(
    UsageFilter filter,
    UsageDimension dimension,
    UsageRankingItem item,
  ) {
    return [
      _range(filter),
      filter.scope.name,
      dimension.name,
      item.label,
      dimension == UsageDimension.profile
          ? item.label
          : filter.profileLabel ?? '',
      item.upload,
      item.download,
      item.total,
      item.connections,
    ];
  }

  List<Object?> get _header => const [
    'time_range',
    'traffic_scope',
    'dimension',
    'value',
    'subscription',
    'upload_bytes',
    'download_bytes',
    'total_bytes',
    'connections',
  ];

  Future<String?> exportOverview(
    UsageFilter filter,
    List<UsageTrendPoint> rows,
  ) {
    final data = rows.map((item) {
      return [
        _range(filter),
        filter.scope.name,
        'time',
        DateFormat('yyyy-MM-dd HH:mm').format(item.time),
        filter.profileLabel ?? '',
        item.upload,
        item.download,
        item.total,
        item.connections,
      ];
    });
    return _save(data);
  }

  Future<String?> exportRankingFromDatabase(
    UsageDatabase database,
    UsageFilter filter,
    UsageDimension dimension, {
    required UsageSort sort,
    required String search,
  }) async {
    final fileName = _fileName();
    final tempPath = '${await appPath.tempFilePath}.csv';
    final file = File(tempPath);
    final sink = file.openWrite();
    try {
      sink.add(const [0xEF, 0xBB, 0xBF]);
      sink.write('${_line(_header)}\r\n');
      await database.forEachRankingPage(
        filter,
        dimension,
        sort: sort,
        search: search,
        onPage: (rows) async {
          for (final item in rows) {
            sink.write('${_line(_rankingRow(filter, dimension, item))}\r\n');
          }
          await sink.flush();
        },
      );
      await sink.flush();
      await sink.close();
      return await picker.saveFileWithPath(fileName, tempPath);
    } catch (_) {
      await sink.close();
      await file.safeDelete();
      rethrow;
    }
  }

  Future<String?> _save(Iterable<List<Object?>> data) async {
    return picker.saveFile(_fileName(), encodeCsv(data));
  }

  String _fileName() {
    return 'flclash-usage-'
        '${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.csv';
  }

  String _line(List<Object?> row) => row.map(_escape).join(',');

  Uint8List encodeCsv(Iterable<List<Object?>> data) {
    final rows = <List<Object?>>[_header, ...data];
    final csv = rows.map(_line).join('\r\n');
    return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode('$csv\r\n')]);
  }
}

final usageCsvExporter = UsageCsvExporter();
