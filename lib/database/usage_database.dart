import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';

part 'generated/usage_database.g.dart';

@TableIndex(name: 'usage_bucket_route_minute', columns: {#route, #minute})
@TableIndex(name: 'usage_bucket_profile_minute', columns: {#profileId, #minute})
@TableIndex(name: 'usage_bucket_node_minute', columns: {#node, #minute})
@TableIndex(
  name: 'usage_bucket_process_path_minute',
  columns: {#processPath, #minute},
)
@TableIndex(
  name: 'usage_bucket_domain_key_minute',
  columns: {#domainKey, #minute},
)
class UsageBuckets extends Table {
  IntColumn get minute => integer()();

  TextColumn get localDay => text().withDefault(const Constant(''))();

  IntColumn get localHour => integer().withDefault(const Constant(0))();

  IntColumn get localDayStart => integer().withDefault(const Constant(0))();

  TextColumn get bucketKey => text()();

  IntColumn get profileId => integer().nullable()();

  TextColumn get profileLabel => text().withDefault(const Constant(''))();

  TextColumn get route => text()();

  TextColumn get node => text().withDefault(const Constant(''))();

  TextColumn get process => text().withDefault(const Constant(''))();

  TextColumn get processPath => text().withDefault(const Constant(''))();

  TextColumn get domain => text().withDefault(const Constant(''))();

  TextColumn get host => text().withDefault(const Constant(''))();

  TextColumn get destinationIp => text().withDefault(const Constant(''))();

  TextColumn get domainKey => text().withDefault(const Constant(''))();

  IntColumn get upload => integer().withDefault(const Constant(0))();

  IntColumn get download => integer().withDefault(const Constant(0))();

  IntColumn get connections => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {minute, bucketKey};
}

class UsageIngestSessions extends Table {
  TextColumn get sessionId => text()();

  IntColumn get maxSequence => integer()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {sessionId};
}

class UsageDailyTotals extends Table {
  TextColumn get day => text()();

  TextColumn get route => text()();

  IntColumn get upload => integer().withDefault(const Constant(0))();

  IntColumn get download => integer().withDefault(const Constant(0))();

  IntColumn get connections => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {day, route};
}

class UsageProfileLabels extends Table {
  TextColumn get profileKey => text()();

  TextColumn get label => text().withDefault(const Constant(''))();

  IntColumn get lastSeenMinute => integer()();

  @override
  Set<Column> get primaryKey => {profileKey};
}

class UsageApplicationLabels extends Table {
  TextColumn get processPathKey => text()();

  TextColumn get label => text().withDefault(const Constant(''))();

  IntColumn get lastSeenMinute => integer()();

  @override
  Set<Column> get primaryKey => {processPathKey};
}

class UsageQualityIntervals extends Table {
  TextColumn get sessionId => text()();

  IntColumn get sequence => integer()();

  IntColumn get startMinute => integer()();

  IntColumn get endMinute => integer()();

  @override
  Set<Column> get primaryKey => {sessionId, sequence};
}

class UsageSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();

  BoolColumn get enabled => boolean().withDefault(const Constant(false))();

  BoolColumn get consentAccepted =>
      boolean().withDefault(const Constant(false))();

  DateTimeColumn get updatedAt => dateTime()();

  DateTimeColumn get lastCleanup => dateTime().nullable()();

  IntColumn get localTimezoneOffsetMinutes => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    UsageBuckets,
    UsageIngestSessions,
    UsageDailyTotals,
    UsageProfileLabels,
    UsageApplicationLabels,
    UsageQualityIntervals,
    UsageSettings,
  ],
)
class UsageDatabase extends _$UsageDatabase {
  UsageDatabase([QueryExecutor? executor])
    : super(executor ?? _openConnection());

  static const _domainKey = 'domain_key';
  int _exportSequence = 0;
  Future<UsageOverview>? _overviewOperation;
  UsageFilter? _overviewFilter;

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await customStatement('DROP TABLE IF EXISTS usage_ingest_batches');
        await migrator.createTable(usageIngestSessions);
        await migrator.createTable(usageDailyTotals);
        await migrator.createTable(usageProfileLabels);
        await customStatement(
          'CREATE INDEX IF NOT EXISTS usage_bucket_route_minute '
          'ON usage_buckets (route, minute)',
        );
      }
      if (from < 3) {
        await migrator.addColumn(usageBuckets, usageBuckets.localDay);
        await migrator.addColumn(usageBuckets, usageBuckets.localHour);
        await migrator.addColumn(usageBuckets, usageBuckets.localDayStart);
        await migrator.addColumn(usageBuckets, usageBuckets.domainKey);
        await migrator.addColumn(
          usageSettings,
          usageSettings.localTimezoneOffsetMinutes,
        );
        await migrator.createTable(usageApplicationLabels);
        await migrator.createTable(usageQualityIntervals);
        await customStatement(
          'CREATE INDEX IF NOT EXISTS usage_bucket_profile_minute '
          'ON usage_buckets (profile_id, minute)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS usage_bucket_node_minute '
          'ON usage_buckets (node, minute)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS usage_bucket_process_path_minute '
          'ON usage_buckets (process_path, minute)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS usage_bucket_domain_key_minute '
          'ON usage_buckets (domain_key, minute)',
        );
        await _rebuildLocalCalendarColumns();
        await _rebuildDerivedTables();
      }
      if (from < 4) {
        await _rebuildDomainKeys();
      }
    },
  );

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final databaseFile = File(await appPath.usageDatabasePath);
      return NativeDatabase.createInBackground(databaseFile);
    });
  }

  Future<bool> isEnabled() async {
    final row = await (select(
      usageSettings,
    )..where((t) => t.id.equals(0))).getSingleOrNull();
    return row?.enabled ?? false;
  }

  Stream<bool> watchEnabled() {
    return (select(usageSettings)..where((t) => t.id.equals(0)))
        .watchSingleOrNull()
        .map((row) => row?.enabled ?? false);
  }

  Future<void> setEnabled(bool enabled) async {
    final previous = await (select(
      usageSettings,
    )..where((t) => t.id.equals(0))).getSingleOrNull();
    await into(usageSettings).insertOnConflictUpdate(
      UsageSettingsCompanion.insert(
        id: const Value(0),
        enabled: Value(enabled),
        consentAccepted: Value(enabled || (previous?.consentAccepted ?? false)),
        updatedAt: DateTime.now().toUtc(),
        lastCleanup: Value(previous?.lastCleanup),
        localTimezoneOffsetMinutes: Value(previous?.localTimezoneOffsetMinutes),
      ),
    );
  }

  Future<bool> hasConsent() async {
    final row = await (select(
      usageSettings,
    )..where((t) => t.id.equals(0))).getSingleOrNull();
    return row?.consentAccepted ?? false;
  }

  Future<bool> ingest(UsageBatch batchData) async {
    return transaction(() async {
      final session =
          await (select(usageIngestSessions)
                ..where((t) => t.sessionId.equals(batchData.sessionId)))
              .getSingleOrNull();
      if (session != null && session.maxSequence >= batchData.sequence) {
        return false;
      }

      final dailyTotals = <String, _MutableUsageTotals>{};
      final profileLabels = <String, _ProfileLabelSnapshot>{};
      final applicationLabels = <String, _ProfileLabelSnapshot>{};
      await batch((batch) {
        for (final bucket in batchData.buckets) {
          final localCalendar = _localCalendar(bucket.minute);
          final domainKey = _domainValue(bucket);
          batch.customStatement(
            'INSERT INTO usage_buckets '
            '(minute, local_day, local_hour, local_day_start, bucket_key, '
            'profile_id, profile_label, route, node, process, process_path, '
            'domain, host, destination_ip, domain_key, upload, download, '
            'connections) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, '
            '?, ?, ?, ?) ON CONFLICT(minute, bucket_key) DO UPDATE SET '
            'upload = usage_buckets.upload + excluded.upload, '
            'download = usage_buckets.download + excluded.download, '
            'connections = usage_buckets.connections + excluded.connections',
            [
              bucket.minute,
              localCalendar.day,
              localCalendar.hour,
              localCalendar.dayStart,
              _bucketKey(bucket),
              bucket.profileId,
              bucket.profileLabel,
              bucket.route.name,
              bucket.node,
              bucket.process,
              bucket.processPath,
              bucket.domain,
              bucket.host,
              bucket.destinationIP,
              domainKey,
              bucket.upload,
              bucket.download,
              bucket.connections,
            ],
          );

          final day = localCalendar.day;
          final dailyKey = '$day\u0000${bucket.route.name}';
          dailyTotals
              .putIfAbsent(dailyKey, _MutableUsageTotals.new)
              .add(bucket);

          if (bucket.profileLabel.isNotEmpty) {
            final profileKey = '${bucket.profileId ?? 0}';
            final current = profileLabels[profileKey];
            if (current == null || bucket.minute >= current.minute) {
              profileLabels[profileKey] = _ProfileLabelSnapshot(
                label: bucket.profileLabel,
                minute: bucket.minute,
              );
            }
          }
          if (bucket.processPath.isNotEmpty && bucket.process.isNotEmpty) {
            final current = applicationLabels[bucket.processPath];
            if (current == null || bucket.minute >= current.minute) {
              applicationLabels[bucket.processPath] = _ProfileLabelSnapshot(
                label: bucket.process,
                minute: bucket.minute,
              );
            }
          }
        }

        for (final entry in dailyTotals.entries) {
          final separator = entry.key.indexOf('\u0000');
          final day = entry.key.substring(0, separator);
          final route = entry.key.substring(separator + 1);
          final totals = entry.value;
          batch.customStatement(
            'INSERT INTO usage_daily_totals '
            '(day, route, upload, download, connections) VALUES (?, ?, ?, ?, ?) '
            'ON CONFLICT(day, route) DO UPDATE SET '
            'upload = usage_daily_totals.upload + excluded.upload, '
            'download = usage_daily_totals.download + excluded.download, '
            'connections = usage_daily_totals.connections + excluded.connections',
            [day, route, totals.upload, totals.download, totals.connections],
          );
        }

        for (final entry in profileLabels.entries) {
          batch.customStatement(
            'INSERT INTO usage_profile_labels '
            '(profile_key, label, last_seen_minute) VALUES (?, ?, ?) '
            'ON CONFLICT(profile_key) DO UPDATE SET '
            'label = CASE WHEN excluded.last_seen_minute >= '
            'usage_profile_labels.last_seen_minute THEN excluded.label '
            'ELSE usage_profile_labels.label END, '
            'last_seen_minute = MAX(usage_profile_labels.last_seen_minute, '
            'excluded.last_seen_minute)',
            [entry.key, entry.value.label, entry.value.minute],
          );
        }

        for (final entry in applicationLabels.entries) {
          batch.customStatement(
            'INSERT INTO usage_application_labels '
            '(process_path_key, label, last_seen_minute) VALUES (?, ?, ?) '
            'ON CONFLICT(process_path_key) DO UPDATE SET '
            'label = CASE WHEN excluded.last_seen_minute >= '
            'usage_application_labels.last_seen_minute THEN excluded.label '
            'ELSE usage_application_labels.label END, '
            'last_seen_minute = MAX('
            'usage_application_labels.last_seen_minute, '
            'excluded.last_seen_minute)',
            [entry.key, entry.value.label, entry.value.minute],
          );
        }

        if (batchData.degraded && batchData.buckets.isNotEmpty) {
          final minutes = batchData.buckets.map((bucket) => bucket.minute);
          final fallbackStartMinute = minutes.reduce(min);
          final fallbackEndMinute =
              minutes.reduce(max) + const Duration(minutes: 1).inMilliseconds;
          final startMinute = batchData.degradedStartMinute > 0
              ? batchData.degradedStartMinute
              : fallbackStartMinute;
          final endMinute = batchData.degradedEndMinute > startMinute
              ? batchData.degradedEndMinute
              : fallbackEndMinute;
          batch.customStatement(
            'INSERT OR REPLACE INTO usage_quality_intervals '
            '(session_id, sequence, start_minute, end_minute) '
            'VALUES (?, ?, ?, ?)',
            [batchData.sessionId, batchData.sequence, startMinute, endMinute],
          );
        }
      });

      await into(usageIngestSessions).insertOnConflictUpdate(
        UsageIngestSessionsCompanion.insert(
          sessionId: batchData.sessionId,
          maxSequence: batchData.sequence,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      return true;
    });
  }

  String _bucketKey(UsageBucketData bucket) {
    return sha256
        .convert(
          utf8.encode(
            jsonEncode([
              bucket.profileId,
              bucket.profileLabel,
              bucket.route.name,
              bucket.node,
              bucket.process,
              bucket.processPath,
              bucket.domain,
              bucket.host,
              bucket.destinationIP,
            ]),
          ),
        )
        .toString();
  }

  ({String day, int hour, int dayStart}) _localCalendar(
    int millisecondsSinceEpoch,
  ) {
    final value = DateTime.fromMillisecondsSinceEpoch(
      millisecondsSinceEpoch,
      isUtc: true,
    ).toLocal();
    final day =
        '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
    return (
      day: day,
      hour: value.hour,
      dayStart: DateTime(
        value.year,
        value.month,
        value.day,
      ).millisecondsSinceEpoch,
    );
  }

  String _domainValue(UsageBucketData bucket) {
    if (bucket.domain.isNotEmpty) {
      return bucket.domain;
    }
    if (bucket.host.isNotEmpty) {
      return bucket.host;
    }
    return '';
  }

  Future<UsageSummary> todayProxySummary({DateTime? now}) async {
    final current = now ?? DateTime.now();
    final day =
        '${current.year.toString().padLeft(4, '0')}-'
        '${current.month.toString().padLeft(2, '0')}-'
        '${current.day.toString().padLeft(2, '0')}';
    final row =
        await (select(usageDailyTotals)..where(
              (t) => t.day.equals(day) & t.route.equals(UsageRoute.proxy.name),
            ))
            .getSingleOrNull();
    return UsageSummary(
      upload: row?.upload ?? 0,
      download: row?.download ?? 0,
      connections: row?.connections ?? 0,
    );
  }

  Future<UsageSummary> summary(UsageFilter filter) async {
    final query = _query(
      filter,
      'SELECT COALESCE(SUM(upload), 0) AS upload, '
      'COALESCE(SUM(download), 0) AS download, '
      'COALESCE(SUM(connections), 0) AS connections '
      'FROM usage_buckets',
    );
    final row = await query.getSingle();
    return UsageSummary(
      upload: row.read<int>('upload'),
      download: row.read<int>('download'),
      connections: row.read<int>('connections'),
    );
  }

  Future<List<UsageTrendPoint>> trend(UsageFilter filter) async {
    final usesHourlyBuckets =
        filter.end.difference(filter.start) <= const Duration(hours: 48);
    final timeExpression = usesHourlyBuckets
        ? '(minute / ${const Duration(hours: 1).inMilliseconds}) * '
              '${const Duration(hours: 1).inMilliseconds}'
        : 'local_day_start';
    final query = _query(
      filter,
      'SELECT $timeExpression AS time, '
      'SUM(upload) AS upload, SUM(download) AS download, '
      'SUM(connections) AS connections FROM usage_buckets',
      suffix: 'GROUP BY time ORDER BY time ASC',
    );
    final rows = await query.get();
    if (rows.isEmpty) {
      return const [];
    }
    final byTime = <int, UsageTrendPoint>{
      for (final row in rows)
        row.read<int>('time'): UsageTrendPoint(
          time: DateTime.fromMillisecondsSinceEpoch(row.read<int>('time')),
          upload: row.read<int>('upload'),
          download: row.read<int>('download'),
          connections: row.read<int>('connections'),
        ),
    };
    final points = <UsageTrendPoint>[];
    if (usesHourlyBuckets) {
      const hour = Duration(hours: 1);
      final startMilliseconds =
          (filter.start.toUtc().millisecondsSinceEpoch ~/ hour.inMilliseconds) *
          hour.inMilliseconds;
      var cursor = DateTime.fromMillisecondsSinceEpoch(startMilliseconds);
      while (cursor.isBefore(filter.end)) {
        points.add(
          byTime[cursor.millisecondsSinceEpoch] ??
              UsageTrendPoint(time: cursor),
        );
        cursor = cursor.add(hour);
      }
      return points;
    }
    final localStart = filter.start.toLocal();
    var cursor = DateTime(localStart.year, localStart.month, localStart.day);
    while (cursor.isBefore(filter.end)) {
      points.add(
        byTime[cursor.millisecondsSinceEpoch] ?? UsageTrendPoint(time: cursor),
      );
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }
    return points;
  }

  Future<List<UsageTrendPoint>> hourlyDistribution(UsageFilter filter) async {
    final query = _query(
      filter,
      'SELECT local_hour AS hour, SUM(upload) AS upload, '
      'SUM(download) AS download, SUM(connections) AS connections '
      'FROM usage_buckets',
      suffix: 'GROUP BY hour ORDER BY hour ASC',
    );
    final byHour = <int, UsageTrendPoint>{};
    for (final row in await query.get()) {
      final hour = row.read<int>('hour');
      byHour[hour] = UsageTrendPoint(
        time: DateTime(2000, 1, 1, hour),
        upload: row.read<int>('upload'),
        download: row.read<int>('download'),
        connections: row.read<int>('connections'),
      );
    }
    return List.generate(
      24,
      (hour) =>
          byHour[hour] ?? UsageTrendPoint(time: DateTime(2000, 1, 1, hour)),
    );
  }

  Future<List<UsageRankingItem>> ranking(
    UsageFilter filter,
    UsageDimension dimension, {
    UsageSort sort = UsageSort.total,
    String search = '',
    int limit = 200,
    int offset = 0,
  }) async {
    final (key, label, order) = _rankingDefinition(dimension, sort);
    final where = _usageWhere(filter);
    final searchClause = search.trim().isEmpty
        ? ''
        : 'WHERE LOWER(item_label) LIKE ?';
    final variables = <Variable<Object>>[
      ...where.arguments.map((value) => Variable<Object>(value)),
      if (search.trim().isNotEmpty)
        Variable<String>('%${search.trim().toLowerCase()}%'),
    ];
    final safeLimit = limit.clamp(1, 5000);
    final safeOffset = offset < 0 ? 0 : offset;
    final query = customSelect(
      'SELECT item_key, item_label, upload, download, total, connections FROM ('
      'SELECT $key AS item_key, $label AS item_label, '
      'SUM(upload) AS upload, SUM(download) AS download, '
      'SUM(upload + download) AS total, '
      'SUM(connections) AS connections FROM usage_buckets '
      'WHERE ${where.clauses.join(' AND ')} GROUP BY item_key) '
      '$searchClause ORDER BY $order DESC, item_label ASC, item_key ASC '
      'LIMIT $safeLimit OFFSET $safeOffset',
      variables: variables,
      readsFrom: {usageBuckets, usageProfileLabels, usageApplicationLabels},
    );
    return (await query.get())
        .map(
          (row) => UsageRankingItem(
            key: row.read<String>('item_key'),
            label: row.read<String>('item_label'),
            upload: row.read<int>('upload'),
            download: row.read<int>('download'),
            connections: row.read<int>('connections'),
          ),
        )
        .toList();
  }

  (String, String, String) _rankingDefinition(
    UsageDimension dimension,
    UsageSort sort,
  ) {
    final (key, label) = switch (dimension) {
      UsageDimension.node => ('node', 'node'),
      UsageDimension.application => (
        "CASE WHEN process_path <> '' THEN process_path ELSE '' END",
        'COALESCE((SELECT label FROM usage_application_labels WHERE '
            'process_path_key = process_path), process_path)',
      ),
      UsageDimension.domain => (_domainKey, _domainKey),
      UsageDimension.profile => (
        'CAST(COALESCE(profile_id, 0) AS TEXT)',
        'COALESCE((SELECT label FROM usage_profile_labels WHERE profile_key = '
            "CAST(COALESCE(profile_id, 0) AS TEXT)), '')",
      ),
      UsageDimension.overview => throw ArgumentError.value(dimension),
    };
    final order = switch (sort) {
      UsageSort.total => 'total',
      UsageSort.upload => 'upload',
      UsageSort.download => 'download',
      UsageSort.connections => 'connections',
    };
    return (key, label, order);
  }

  Future<void> forEachRankingPage(
    UsageFilter filter,
    UsageDimension dimension, {
    required UsageSort sort,
    required String search,
    int pageSize = 1000,
    required Future<void> Function(List<UsageRankingItem> rows) onPage,
  }) async {
    final (key, label, order) = _rankingDefinition(dimension, sort);
    final where = _usageWhere(filter);
    final table =
        'usage_export_${DateTime.now().microsecondsSinceEpoch}_'
        '${_exportSequence++}';
    await customStatement(
      'CREATE TEMP TABLE $table AS SELECT $key AS item_key, '
      '$label AS item_label, SUM(upload) AS upload, '
      'SUM(download) AS download, SUM(upload + download) AS total, '
      'SUM(connections) AS connections FROM usage_buckets '
      'WHERE ${where.clauses.join(' AND ')} GROUP BY item_key',
      where.arguments,
    );
    try {
      var offset = 0;
      final safePageSize = pageSize.clamp(1, 5000);
      final searchClause = search.trim().isEmpty
          ? ''
          : 'WHERE LOWER(item_label) LIKE ?';
      final searchVariables = search.trim().isEmpty
          ? const <Variable<Object>>[]
          : <Variable<Object>>[
              Variable<String>('%${search.trim().toLowerCase()}%'),
            ];
      while (true) {
        final rows = await customSelect(
          'SELECT item_key, item_label, upload, download, total, connections '
          'FROM $table $searchClause '
          'ORDER BY $order DESC, item_label ASC, item_key ASC '
          'LIMIT $safePageSize OFFSET $offset',
          variables: searchVariables,
        ).get();
        final items = rows
            .map(
              (row) => UsageRankingItem(
                key: row.read<String>('item_key'),
                label: row.read<String>('item_label'),
                upload: row.read<int>('upload'),
                download: row.read<int>('download'),
                connections: row.read<int>('connections'),
              ),
            )
            .toList();
        if (items.isEmpty) {
          break;
        }
        await onPage(items);
        if (items.length < safePageSize) {
          break;
        }
        offset += items.length;
      }
    } finally {
      await customStatement('DROP TABLE IF EXISTS $table');
    }
  }

  Future<double> identificationCoverage(
    UsageFilter filter,
    UsageDimension dimension,
  ) async {
    final key = switch (dimension) {
      UsageDimension.application =>
        "CASE WHEN process_path <> '' THEN process_path ELSE '' END",
      UsageDimension.domain => _domainKey,
      _ => throw ArgumentError.value(dimension),
    };
    final row = await _query(
      filter,
      'SELECT COALESCE(SUM(upload + download), 0) AS total, '
      'COALESCE(SUM(CASE WHEN $key = \'\' THEN upload + download '
      'ELSE 0 END), 0) AS unknown FROM usage_buckets',
    ).getSingle();
    final total = row.read<int>('total');
    if (total == 0) {
      return 0;
    }
    return (total - row.read<int>('unknown')) / total;
  }

  Future<UsageOverview> overview(UsageFilter filter) {
    final activeOperation = _overviewOperation;
    if (activeOperation != null && _overviewFilter == filter) {
      return activeOperation;
    }
    late Future<UsageOverview> operation;
    operation = _loadOverview(filter).whenComplete(() {
      if (identical(_overviewOperation, operation)) {
        _overviewOperation = null;
        _overviewFilter = null;
      }
    });
    _overviewOperation = operation;
    _overviewFilter = filter;
    return operation;
  }

  Future<UsageOverview> _loadOverview(UsageFilter filter) async {
    final values = await Future.wait<Object>([
      summary(filter),
      trend(filter),
      hourlyDistribution(filter),
      ranking(filter, UsageDimension.node, limit: 5),
      ranking(filter, UsageDimension.application, limit: 5),
      ranking(filter, UsageDimension.domain, limit: 5),
      ranking(filter, UsageDimension.profile, limit: 5),
    ]);
    return UsageOverview(
      summary: values[0] as UsageSummary,
      trend: values[1] as List<UsageTrendPoint>,
      hourlyDistribution: values[2] as List<UsageTrendPoint>,
      rankings: {
        UsageDimension.node: values[3] as List<UsageRankingItem>,
        UsageDimension.application: values[4] as List<UsageRankingItem>,
        UsageDimension.domain: values[5] as List<UsageRankingItem>,
        UsageDimension.profile: values[6] as List<UsageRankingItem>,
      },
    );
  }

  Future<bool> hasDegradedData(UsageFilter filter) async {
    final row = await customSelect(
      'SELECT 1 FROM usage_quality_intervals '
      'WHERE start_minute < ? AND end_minute > ? LIMIT 1',
      variables: [
        Variable<int>(filter.end.toUtc().millisecondsSinceEpoch),
        Variable<int>(filter.start.toUtc().millisecondsSinceEpoch),
      ],
      readsFrom: {usageQualityIntervals},
    ).getSingleOrNull();
    return row != null;
  }

  Future<bool> hasAnyDegradedData() async {
    final row = await customSelect(
      'SELECT 1 FROM usage_quality_intervals LIMIT 1',
      readsFrom: {usageQualityIntervals},
    ).getSingleOrNull();
    return row != null;
  }

  Future<List<UsageRankingItem>> domainTargets(
    UsageFilter filter,
    String domain, {
    int limit = 200,
  }) async {
    final scopedFilter = filter.copyWith(domain: domain);
    const key =
        "CASE WHEN host <> '' THEN host WHEN destination_ip <> '' "
        "THEN destination_ip ELSE '' END";
    final query = _query(
      scopedFilter,
      'SELECT $key AS item_key, $key AS item_label, '
      'SUM(upload) AS upload, SUM(download) AS download, '
      'SUM(upload + download) AS total, '
      'SUM(connections) AS connections FROM usage_buckets',
      suffix:
          'GROUP BY item_key ORDER BY total DESC, item_label ASC '
          'LIMIT ${limit.clamp(1, 1000)}',
    );
    return (await query.get())
        .map(
          (row) => UsageRankingItem(
            key: row.read<String>('item_key'),
            label: row.read<String>('item_label'),
            upload: row.read<int>('upload'),
            download: row.read<int>('download'),
            connections: row.read<int>('connections'),
          ),
        )
        .toList();
  }

  Selectable<QueryRow> _query(
    UsageFilter filter,
    String prefix, {
    List<String> extraClauses = const [],
    List<Variable<Object>> extraVariables = const [],
    String suffix = '',
  }) {
    final where = _usageWhere(filter);
    final clauses = where.clauses;
    final variables = where.arguments
        .map<Variable<Object>>((value) => Variable<Object>(value))
        .toList();
    clauses.addAll(extraClauses);
    variables.addAll(extraVariables);
    return customSelect(
      '$prefix WHERE ${clauses.join(' AND ')} ${suffix.trim()}',
      variables: variables,
      readsFrom: {usageBuckets, usageProfileLabels},
    );
  }

  ({List<String> clauses, List<Object> arguments}) _usageWhere(
    UsageFilter filter,
  ) {
    final clauses = <String>['minute >= ?', 'minute < ?'];
    final arguments = <Object>[
      filter.start.toUtc().millisecondsSinceEpoch,
      filter.end.toUtc().millisecondsSinceEpoch,
    ];
    switch (filter.scope) {
      case UsageTrafficScope.proxy:
        clauses.add("route = 'proxy'");
      case UsageTrafficScope.direct:
        clauses.add("route = 'direct'");
      case UsageTrafficScope.all:
        break;
    }
    if (filter.profileId != null) {
      if (filter.profileId == 0) {
        clauses.add('profile_id IS NULL');
      } else {
        clauses.add('profile_id = ?');
        arguments.add(filter.profileId!);
      }
    }
    if (filter.node != null) {
      clauses.add('node = ?');
      arguments.add(filter.node!);
    }
    if (filter.processPath != null) {
      clauses.add('process_path = ?');
      arguments.add(filter.processPath!);
    }
    if (filter.domain != null) {
      clauses.add('$_domainKey = ?');
      arguments.add(filter.domain!);
    }
    return (clauses: clauses, arguments: arguments);
  }

  Future<void> cleanup({DateTime? now}) async {
    final cutoff = (now ?? DateTime.now()).toUtc().subtract(
      const Duration(days: 90),
    );
    await transaction(() async {
      final deleted =
          await (delete(usageBuckets)..where(
                (t) =>
                    t.minute.isSmallerThanValue(cutoff.millisecondsSinceEpoch),
              ))
              .go();
      await (delete(
        usageIngestSessions,
      )..where((t) => t.updatedAt.isSmallerThanValue(cutoff))).go();
      await (delete(usageQualityIntervals)..where(
            (t) =>
                t.endMinute.isSmallerThanValue(cutoff.millisecondsSinceEpoch),
          ))
          .go();
      if (deleted > 0) {
        await _rebuildDerivedTables();
      }
      final setting = await (select(
        usageSettings,
      )..where((t) => t.id.equals(0))).getSingleOrNull();
      await into(usageSettings).insertOnConflictUpdate(
        UsageSettingsCompanion.insert(
          id: const Value(0),
          enabled: Value(setting?.enabled ?? false),
          consentAccepted: Value(setting?.consentAccepted ?? false),
          updatedAt: DateTime.now().toUtc(),
          lastCleanup: Value(DateTime.now().toUtc()),
          localTimezoneOffsetMinutes: Value(
            setting?.localTimezoneOffsetMinutes,
          ),
        ),
      );
    });
    await customStatement('PRAGMA optimize');
  }

  Future<void> _rebuildDerivedTables() async {
    await delete(usageDailyTotals).go();
    await customStatement(
      'INSERT INTO usage_daily_totals '
      '(day, route, upload, download, connections) '
      'SELECT local_day, '
      'route, SUM(upload), SUM(download), SUM(connections) '
      'FROM usage_buckets GROUP BY 1, route',
    );
    await delete(usageProfileLabels).go();
    await customStatement(
      'INSERT INTO usage_profile_labels '
      '(profile_key, label, last_seen_minute) '
      'SELECT CAST(COALESCE(source.profile_id, 0) AS TEXT), '
      '(SELECT latest.profile_label FROM usage_buckets AS latest '
      'WHERE COALESCE(latest.profile_id, 0) = '
      'COALESCE(source.profile_id, 0) AND latest.profile_label <> \'\' '
      'ORDER BY latest.minute DESC, latest.rowid DESC LIMIT 1), '
      'MAX(source.minute) FROM usage_buckets AS source '
      'WHERE source.profile_label <> \'\' '
      'GROUP BY COALESCE(source.profile_id, 0)',
    );
    await delete(usageApplicationLabels).go();
    await customStatement(
      'INSERT INTO usage_application_labels '
      '(process_path_key, label, last_seen_minute) '
      'SELECT source.process_path, '
      '(SELECT latest.process FROM usage_buckets AS latest '
      'WHERE latest.process_path = source.process_path '
      'AND latest.process <> \'\' '
      'ORDER BY latest.minute DESC, latest.rowid DESC LIMIT 1), '
      'MAX(source.minute) FROM usage_buckets AS source '
      'WHERE source.process_path <> \'\' AND source.process <> \'\' '
      'GROUP BY source.process_path',
    );
  }

  Future<void> syncLocalCalendar({DateTime? now}) async {
    final current = now ?? DateTime.now();
    final offset = current.timeZoneOffset.inMinutes;
    final setting = await (select(
      usageSettings,
    )..where((t) => t.id.equals(0))).getSingleOrNull();
    if (setting?.localTimezoneOffsetMinutes == offset) {
      return;
    }
    await transaction(() async {
      await _rebuildLocalCalendarColumns();
      await _rebuildDerivedTables();
      await into(usageSettings).insertOnConflictUpdate(
        UsageSettingsCompanion.insert(
          id: const Value(0),
          enabled: Value(setting?.enabled ?? false),
          consentAccepted: Value(setting?.consentAccepted ?? false),
          updatedAt: DateTime.now().toUtc(),
          lastCleanup: Value(setting?.lastCleanup),
          localTimezoneOffsetMinutes: Value(offset),
        ),
      );
    });
  }

  Future<void> _rebuildLocalCalendarColumns() async {
    await customStatement(
      'UPDATE usage_buckets SET '
      "local_day = strftime('%Y-%m-%d', minute / 1000, 'unixepoch', "
      "'localtime'), "
      "local_hour = CAST(strftime('%H', minute / 1000, 'unixepoch', "
      "'localtime') AS INTEGER), "
      "local_day_start = CAST(strftime('%s', minute / 1000, 'unixepoch', "
      "'localtime', 'start of day', 'utc') AS INTEGER) * 1000, "
      "domain_key = CASE WHEN domain <> '' THEN domain "
      "WHEN host <> '' THEN host ELSE '' END",
    );
  }

  Future<void> _rebuildDomainKeys() async {
    await customStatement(
      "UPDATE usage_buckets SET domain_key = CASE WHEN domain <> '' "
      "THEN domain WHEN host <> '' THEN host ELSE '' END",
    );
  }

  Future<void> clearUsage() async {
    await transaction(() async {
      await delete(usageBuckets).go();
      await delete(usageIngestSessions).go();
      await delete(usageDailyTotals).go();
      await delete(usageProfileLabels).go();
      await delete(usageApplicationLabels).go();
      await delete(usageQualityIntervals).go();
    });
    await customStatement('VACUUM');
  }
}

class _MutableUsageTotals {
  int upload = 0;
  int download = 0;
  int connections = 0;

  void add(UsageBucketData bucket) {
    upload += bucket.upload;
    download += bucket.download;
    connections += bucket.connections;
  }
}

class _ProfileLabelSnapshot {
  final String label;
  final int minute;

  const _ProfileLabelSnapshot({required this.label, required this.minute});
}

final usageDatabase = UsageDatabase();
