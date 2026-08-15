import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fl_clash/database/usage_database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late UsageDatabase database;
  final minute = DateTime.utc(2026, 8, 14, 10).millisecondsSinceEpoch;
  final filter = UsageFilter(
    start: DateTime.utc(2026, 8, 14, 9),
    end: DateTime.utc(2026, 8, 14, 11),
  );

  UsageBatch batch({int sequence = 1}) {
    return UsageBatch(
      sessionId: 'session-a',
      sequence: sequence,
      buckets: [
        UsageBucketData(
          minute: minute,
          profileId: 42,
          profileLabel: 'Work',
          route: UsageRoute.proxy,
          node: 'Node A',
          process: 'Safari',
          processPath: '/Applications/Safari.app/Contents/MacOS/Safari',
          domain: 'example.com',
          host: 'api.example.com',
          destinationIP: '1.1.1.1',
          upload: 12,
          download: 34,
          connections: 1,
        ),
        UsageBucketData(
          minute: minute,
          profileLabel: 'Direct',
          route: UsageRoute.direct,
          node: 'DIRECT',
          process: 'Terminal',
          processPath: '/System/Applications/Utilities/Terminal.app',
          destinationIP: '8.8.8.8',
          upload: 5,
          download: 7,
          connections: 2,
        ),
      ],
    );
  }

  setUp(() {
    database = UsageDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('defaults to disabled and keeps setting separate from data', () async {
    expect(await database.isEnabled(), isFalse);
    expect(await database.hasConsent(), isFalse);

    await database.setEnabled(true);
    await database.setEnabled(false);
    await database.ingest(batch());
    await database.clearUsage();

    expect(await database.isEnabled(), isFalse);
    expect(await database.hasConsent(), isTrue);
    expect(await database.summary(filter), const UsageSummary());
    expect(await database.trend(filter), isEmpty);
  });

  test('ingests batches idempotently and filters traffic scopes', () async {
    expect(await database.ingest(batch()), isTrue);
    expect(await database.ingest(batch()), isFalse);
    expect(await database.ingest(batch(sequence: 2)), isTrue);
    expect(await database.ingest(batch()), isFalse);

    final sessionCount = await database
        .customSelect('SELECT COUNT(*) AS count FROM usage_ingest_sessions')
        .getSingle();
    expect(sessionCount.read<int>('count'), 1);

    expect(
      await database.summary(filter),
      const UsageSummary(upload: 24, download: 68, connections: 2),
    );
    expect(
      await database.summary(filter.copyWith(scope: UsageTrafficScope.all)),
      const UsageSummary(upload: 34, download: 82, connections: 6),
    );
    expect(
      await database.summary(filter.copyWith(scope: UsageTrafficScope.direct)),
      const UsageSummary(upload: 10, download: 14, connections: 4),
    );
  });

  test('does not reuse an in-flight overview for a different filter', () async {
    await database.ingest(batch());

    final results = await Future.wait([
      database.overview(filter),
      database.overview(filter.copyWith(scope: UsageTrafficScope.direct)),
    ]);

    expect(
      results[0].summary,
      const UsageSummary(upload: 12, download: 34, connections: 1),
    );
    expect(
      results[1].summary,
      const UsageSummary(upload: 5, download: 7, connections: 2),
    );
  });

  test('aggregates rankings and preserves profile label snapshots', () async {
    await database.ingest(batch());
    await database.ingest(
      UsageBatch(
        sessionId: 'session-a',
        sequence: 2,
        buckets: [
          UsageBucketData(
            minute: minute,
            profileId: 42,
            profileLabel: 'Work',
            route: UsageRoute.proxy,
            node: 'Node A',
            process: 'Safari',
            processPath: '/Applications/Safari.app/Contents/MacOS/Safari',
            domain: 'example.com',
            host: 'cdn.example.com',
            upload: 8,
            download: 6,
            connections: 1,
          ),
        ],
      ),
    );

    final nodes = await database.ranking(filter, UsageDimension.node);
    final profiles = await database.ranking(filter, UsageDimension.profile);
    final targets = await database.domainTargets(filter, 'example.com');

    expect(nodes.single.total, 60);
    expect(profiles.single.label, 'Work');
    expect(targets.map((item) => item.label), {
      'api.example.com',
      'cdn.example.com',
    });
  });

  test('uses the latest profile label and paginates ranking results', () async {
    await database.ingest(batch());
    await database.ingest(
      UsageBatch(
        sessionId: 'session-a',
        sequence: 2,
        buckets: [
          UsageBucketData(
            minute: minute + const Duration(minutes: 1).inMilliseconds,
            profileId: 42,
            profileLabel: 'Personal',
            route: UsageRoute.proxy,
            node: 'Node B',
            download: 100,
          ),
        ],
      ),
    );

    final profiles = await database.ranking(filter, UsageDimension.profile);
    final firstPage = await database.ranking(
      filter.copyWith(scope: UsageTrafficScope.all),
      UsageDimension.node,
      limit: 1,
    );
    final secondPage = await database.ranking(
      filter.copyWith(scope: UsageTrafficScope.all),
      UsageDimension.node,
      limit: 1,
      offset: 1,
    );

    expect(profiles.single.label, 'Personal');
    expect(firstPage, hasLength(1));
    expect(secondPage, hasLength(1));
    expect(firstPage.single.key, isNot(secondPage.single.key));
  });

  test('application search keeps complete totals and latest label', () async {
    const processPath = '/Applications/Browser.app/Contents/MacOS/Browser';
    await database.ingest(
      UsageBatch(
        sessionId: 'session-app-label',
        sequence: 1,
        buckets: [
          UsageBucketData(
            minute: minute,
            route: UsageRoute.proxy,
            process: 'Old Browser',
            processPath: processPath,
            download: 10,
          ),
          UsageBucketData(
            minute: minute + const Duration(minutes: 1).inMilliseconds,
            route: UsageRoute.proxy,
            process: 'New Browser',
            processPath: processPath,
            download: 20,
          ),
        ],
      ),
    );

    final applications = await database.ranking(
      filter,
      UsageDimension.application,
      search: 'new browser',
    );

    expect(applications.single.key, processPath);
    expect(applications.single.label, 'New Browser');
    expect(applications.single.download, 30);
  });

  test('streams a stable ranking snapshot in bounded pages', () async {
    await database.ingest(batch());
    final exported = <UsageRankingItem>[];

    await database.forEachRankingPage(
      filter.copyWith(scope: UsageTrafficScope.all),
      UsageDimension.node,
      sort: UsageSort.total,
      search: '',
      pageSize: 1,
      onPage: (rows) async => exported.addAll(rows),
    );

    expect(exported.map((item) => item.key), ['Node A', 'DIRECT']);
  });

  test(
    'groups IP-only traffic under unknown domain with zero coverage',
    () async {
      await database.ingest(
        UsageBatch(
          sessionId: 'session-domain',
          sequence: 1,
          buckets: [
            UsageBucketData(
              minute: minute,
              route: UsageRoute.proxy,
              download: 4,
            ),
            UsageBucketData(
              minute: minute,
              route: UsageRoute.proxy,
              destinationIP: '1.1.1.1',
              download: 9,
            ),
          ],
        ),
      );

      expect(
        await database.summary(filter.copyWith(domain: '')),
        const UsageSummary(download: 13),
      );
      expect(
        await database.identificationCoverage(filter, UsageDimension.domain),
        0,
      );
      expect(await database.ranking(filter, UsageDimension.domain), [
        const UsageRankingItem(key: '', label: '', download: 13),
      ]);
      expect(await database.domainTargets(filter, ''), [
        const UsageRankingItem(key: '1.1.1.1', label: '1.1.1.1', download: 9),
        const UsageRankingItem(key: '', label: '', download: 4),
      ]);
    },
  );

  test('migrates schema 3 IP fallback keys into the unknown domain', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp(
      'flclash-usage-migration-',
    );
    final file = File('${directory.path}/usage.sqlite');
    addTearDown(() => directory.delete(recursive: true));

    final legacyDatabase = _UsageDatabaseV3(NativeDatabase(file));
    await legacyDatabase.ingest(
      UsageBatch(
        sessionId: 'legacy-domain',
        sequence: 1,
        buckets: [
          UsageBucketData(
            minute: minute,
            route: UsageRoute.proxy,
            destinationIP: '1.1.1.1',
            download: 9,
          ),
        ],
      ),
    );
    await legacyDatabase.customUpdate(
      "UPDATE usage_buckets SET domain_key = '1.1.1.1'",
    );
    await legacyDatabase.close();

    final upgradedDatabase = UsageDatabase(NativeDatabase(file));
    addTearDown(upgradedDatabase.close);

    expect(await upgradedDatabase.ranking(filter, UsageDimension.domain), [
      const UsageRankingItem(key: '', label: '', download: 9),
    ]);
    expect(await upgradedDatabase.domainTargets(filter, ''), [
      const UsageRankingItem(key: '1.1.1.1', label: '1.1.1.1', download: 9),
    ]);
  });

  test('today proxy summary uses the lightweight daily aggregate', () async {
    final local = DateTime(2026, 8, 14, 18);
    await database.ingest(
      UsageBatch(
        sessionId: 'session-today',
        sequence: 1,
        buckets: [
          UsageBucketData(
            minute: local.toUtc().millisecondsSinceEpoch,
            route: UsageRoute.proxy,
            upload: 2,
            download: 3,
            connections: 1,
          ),
        ],
      ),
    );

    expect(
      await database.todayProxySummary(now: local),
      const UsageSummary(upload: 2, download: 3, connections: 1),
    );
  });

  test('calendar today filter recomputes midnight after a day change', () {
    final filter = UsageFilter(
      start: DateTime(2026, 8, 14),
      end: DateTime(2026, 8, 14, 23, 59),
      liveEnd: true,
      calendarToday: true,
    );

    final effective = filter.effectiveAt(DateTime(2026, 8, 15, 0, 1));

    expect(effective.start, DateTime(2026, 8, 15));
    expect(effective.end, DateTime(2026, 8, 15, 0, 1));
  });

  test('ingests a maximum Core batch with bounded session metadata', () async {
    final buckets = List.generate(
      2000,
      (index) => UsageBucketData(
        minute: minute,
        route: UsageRoute.proxy,
        host: '$index.example.com',
        domain: 'example.com',
        download: 1,
      ),
    );

    expect(
      await database.ingest(
        UsageBatch(sessionId: 'session-large', sequence: 1, buckets: buckets),
      ),
      isTrue,
    );

    expect(await database.summary(filter), const UsageSummary(download: 2000));
    final sessionCount = await database
        .customSelect('SELECT COUNT(*) AS count FROM usage_ingest_sessions')
        .getSingle();
    expect(sessionCount.read<int>('count'), 1);
  });

  test('groups long-range trends by local calendar day', () async {
    final localTime = DateTime(2026, 8, 14, 18, 30);
    await database.ingest(
      UsageBatch(
        sessionId: 'session-day',
        sequence: 1,
        buckets: [
          UsageBucketData(
            minute: localTime.toUtc().millisecondsSinceEpoch,
            route: UsageRoute.proxy,
            download: 1,
          ),
        ],
      ),
    );

    final points = await database.trend(
      UsageFilter(start: DateTime(2026, 8, 11), end: DateTime(2026, 8, 15)),
    );

    expect(points, hasLength(4));
    expect(points.map((point) => point.download), [0, 0, 0, 1]);
    expect(points.last.time, DateTime(2026, 8, 14));
  });

  test('fills sparse hourly trends with zero-value buckets', () async {
    final start = DateTime.utc(2026, 8, 14, 10);
    await database.ingest(
      UsageBatch(
        sessionId: 'session-sparse-trend',
        sequence: 1,
        buckets: [
          UsageBucketData(
            minute: start.millisecondsSinceEpoch,
            route: UsageRoute.proxy,
            download: 1,
          ),
          UsageBucketData(
            minute: start.add(const Duration(hours: 5)).millisecondsSinceEpoch,
            route: UsageRoute.proxy,
            download: 2,
          ),
        ],
      ),
    );

    final points = await database.trend(
      UsageFilter(start: start, end: start.add(const Duration(hours: 6))),
    );

    expect(points, hasLength(6));
    expect(points.map((point) => point.download), [1, 0, 0, 0, 0, 2]);
    expect(
      points.map((point) => point.time.toUtc()),
      List.generate(6, (index) => start.add(Duration(hours: index))),
    );
  });

  test(
    'groups hourly distribution with persisted local calendar fields',
    () async {
      final localTime = DateTime(2026, 8, 14, 18, 30);
      await database.ingest(
        UsageBatch(
          sessionId: 'session-hour',
          sequence: 1,
          buckets: [
            UsageBucketData(
              minute: localTime.toUtc().millisecondsSinceEpoch,
              route: UsageRoute.proxy,
              download: 3,
            ),
          ],
        ),
      );

      final points = await database.hourlyDistribution(
        UsageFilter(start: DateTime(2026, 8, 14), end: DateTime(2026, 8, 15)),
      );

      expect(points[18].download, 3);
      expect(points.where((point) => point.download > 0), hasLength(1));
    },
  );

  test('persists degraded intervals and respects filter overlap', () async {
    await database.ingest(
      UsageBatch(
        sessionId: 'session-quality',
        sequence: 1,
        degraded: true,
        degradedStartMinute: minute - const Duration(hours: 2).inMilliseconds,
        degradedEndMinute: minute + const Duration(hours: 3).inMilliseconds,
        buckets: [
          UsageBucketData(minute: minute, route: UsageRoute.proxy, download: 1),
        ],
      ),
    );

    expect(await database.hasAnyDegradedData(), isTrue);
    expect(await database.hasDegradedData(filter), isTrue);
    expect(
      await database.hasDegradedData(
        UsageFilter(
          start: DateTime.utc(2026, 8, 14, 7),
          end: DateTime.utc(2026, 8, 14, 9),
        ),
      ),
      isTrue,
    );
    expect(
      await database.hasDegradedData(
        UsageFilter(
          start: DateTime.utc(2026, 8, 15),
          end: DateTime.utc(2026, 8, 16),
        ),
      ),
      isFalse,
    );

    await database.clearUsage();
    expect(await database.hasAnyDegradedData(), isFalse);
  });

  test('cleans details and ingest markers older than 90 days', () async {
    await database.ingest(batch().copyWith(degraded: true));
    await (database.update(database.usageIngestSessions)..where(
          (table) => table.sessionId.equals('session-a'),
        ))
        .write(
          UsageIngestSessionsCompanion(
            updatedAt: Value(DateTime.utc(2026, 8, 14, 10)),
          ),
        );

    await database.cleanup(now: DateTime.utc(2026, 11, 13, 10));

    expect(await database.summary(filter), const UsageSummary());
    expect(await database.ingest(batch()), isTrue);
    expect(await database.hasAnyDegradedData(), isFalse);
  });
}

class _UsageDatabaseV3 extends UsageDatabase {
  _UsageDatabaseV3(super.executor);

  @override
  int get schemaVersion => 3;
}
