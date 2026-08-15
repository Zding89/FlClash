import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/desktop/model.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/database/usage_database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/usage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

enum _ConfigurationBehavior { apply, reject, applyThenThrow, throwBeforeApply }

class _UsageCoreHandler extends CoreHandlerInterface {
  UsageBatch? batch;
  UsageBatch? finalBatch;
  bool acknowledged = false;
  bool failNextRead = false;
  bool rejectNextConfiguration = false;
  bool coreUsageEnabled = false;
  final List<_ConfigurationBehavior> configurationBehaviors = [];
  final List<UsageCollectionParams> configurations = [];
  final configurationEvents =
      StreamController<UsageCollectionParams>.broadcast();

  Future<void> closeConfigurationEvents() => configurationEvents.close();

  @override
  Future<CoreLifecycleResult> start() async => const CoreLifecycleResult(
    revision: 1,
    outcome: CoreLifecycleOutcome.applied,
  );

  @override
  Future<CoreLifecycleResult> restart() => start();

  @override
  Future<CoreLifecycleResult> stop() => start();

  @override
  Future<CoreLifecycleResult> close() => start();

  @override
  Future<T?> invokeMethod<T>({
    required CoreMethod method,
    Object? arguments,
    Duration? timeout,
  }) async {
    if (method == CoreMethod.configureUsageCollection) {
      final configuration = UsageCollectionParams.fromJson(
        Map<String, Object?>.from(arguments! as Map),
      );
      configurations.add(configuration);
      configurationEvents.add(configuration);
      if (rejectNextConfiguration) {
        rejectNextConfiguration = false;
        return false as T;
      }
      final behavior = configurationBehaviors.isEmpty
          ? _ConfigurationBehavior.apply
          : configurationBehaviors.removeAt(0);
      switch (behavior) {
        case _ConfigurationBehavior.apply:
          coreUsageEnabled = configuration.enabled;
          break;
        case _ConfigurationBehavior.reject:
          return false as T;
        case _ConfigurationBehavior.applyThenThrow:
          coreUsageEnabled = configuration.enabled;
          throw const CoreMethodException(
            code: 'transport_error',
            message: 'response lost after apply',
          );
        case _ConfigurationBehavior.throwBeforeApply:
          throw const CoreMethodException(
            code: 'transport_error',
            message: 'request not applied',
          );
      }
      if (!configuration.enabled && finalBatch != null) {
        batch = finalBatch;
        finalBatch = null;
        acknowledged = false;
      }
      return true as T;
    }
    if (method == CoreMethod.readUsageBatch) {
      if (failNextRead) {
        failNextRead = false;
        throw const CoreMethodException(
          code: 'transport_error',
          message: 'temporary',
        );
      }
      if (batch == null || acknowledged) {
        return null;
      }
      return jsonDecode(jsonEncode(batch)) as T;
    }
    if (method == CoreMethod.ackUsageBatch) {
      acknowledged = true;
      return true as T;
    }
    return null;
  }
}

void main() {
  late UsageDatabase database;
  late _UsageCoreHandler handler;
  late ProviderContainer container;

  setUp(() {
    database = UsageDatabase(NativeDatabase.memory());
    handler = _UsageCoreHandler();
    container = ProviderContainer(
      overrides: [
        usageStoreProvider.overrideWithValue(database),
        usageCoreProvider.overrideWithValue(CoreController.test(handler)),
        currentProfileIdProvider.overrideWithValue(null),
        profilesProvider.overrideWithValue(const []),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await handler.closeConfigurationEvents();
    await database.close();
  });

  test('enables, polls, persists, acknowledges and pauses', () async {
    await container.read(usageRuntimeProvider.future);
    handler.batch = UsageBatch(
      sessionId: 'session-a',
      sequence: 1,
      buckets: [
        UsageBucketData(
          minute: DateTime.utc(2026, 8, 14, 10).millisecondsSinceEpoch,
          route: UsageRoute.proxy,
          node: 'Node A',
          upload: 10,
          download: 20,
          connections: 1,
        ),
      ],
    );

    await container.read(usageRuntimeProvider.notifier).setEnabled(true);
    await container.read(usageRuntimeProvider.notifier).flush();

    expect(await database.isEnabled(), isTrue);
    expect(handler.acknowledged, isTrue);
    expect(
      await database.summary(
        UsageFilter(
          start: DateTime.utc(2026, 8, 14, 9),
          end: DateTime.utc(2026, 8, 14, 11),
        ),
      ),
      const UsageSummary(upload: 10, download: 20, connections: 1),
    );

    await container.read(usageRuntimeProvider.notifier).clear();

    expect(
      await database.summary(
        UsageFilter(
          start: DateTime.utc(2026, 8, 14, 9),
          end: DateTime.utc(2026, 8, 14, 11),
        ),
      ),
      const UsageSummary(),
    );
    expect(handler.configurations.last.enabled, isTrue);

    await container.read(usageRuntimeProvider.notifier).setEnabled(false);

    expect(await database.isEnabled(), isFalse);
    expect(handler.configurations.last.enabled, isFalse);
    expect(
      handler.configurations.map((item) => item.revision),
      orderedEquals(
        List.generate(handler.configurations.length, (index) => index + 1),
      ),
    );
  });

  test('retries a failed read and resyncs after core reconnect', () async {
    await container.read(usageRuntimeProvider.future);
    await container.read(usageRuntimeProvider.notifier).setEnabled(true);
    handler.batch = UsageBatch(
      sessionId: 'session-b',
      sequence: 1,
      buckets: [
        UsageBucketData(
          minute: DateTime.now().toUtc().millisecondsSinceEpoch,
          route: UsageRoute.proxy,
          upload: 3,
        ),
      ],
    );
    handler.failNextRead = true;

    await container.read(usageRuntimeProvider.notifier).flush();
    expect(handler.acknowledged, isFalse);
    expect(
      container.read(usageIssuesProvider),
      contains(UsageIssue.persistence),
    );

    await container.read(usageRuntimeProvider.notifier).flush();
    await container.read(usageRuntimeProvider.notifier).syncCore();

    expect(handler.acknowledged, isTrue);
    expect(handler.configurations.where((item) => item.enabled), hasLength(2));
    expect(
      container.read(usageIssuesProvider),
      isNot(contains(UsageIssue.persistence)),
    );
  });

  test('syncs the profile snapshot that Core actually applied', () async {
    await container.read(usageRuntimeProvider.future);
    await container.read(usageRuntimeProvider.notifier).setEnabled(true);

    await container
        .read(usageRuntimeProvider.notifier)
        .syncProfile(profileId: 42, profileLabel: 'Applied profile');
    await container
        .read(usageRuntimeProvider.notifier)
        .syncProfile(profileId: 84, profileLabel: 'Next profile');

    expect(
      handler.configurations
          .where((configuration) => configuration.enabled)
          .map(
            (configuration) =>
                (configuration.profileId, configuration.profileLabel),
          ),
      [(null, ''), (42, 'Applied profile'), (84, 'Next profile')],
    );
  });

  test('waits for persisted settings before syncing a profile', () async {
    container.dispose();
    await database.close();
    final delayedDatabase = _DelayedUsageDatabase(NativeDatabase.memory());
    database = delayedDatabase;
    handler = _UsageCoreHandler();
    container = ProviderContainer(
      overrides: [
        usageStoreProvider.overrideWithValue(database),
        usageCoreProvider.overrideWithValue(CoreController.test(handler)),
        currentProfileIdProvider.overrideWithValue(null),
        profilesProvider.overrideWithValue(const []),
      ],
    );

    final synchronization = container
        .read(usageRuntimeProvider.notifier)
        .syncProfile(profileId: 42, profileLabel: 'Applied profile');
    await Future<void>.delayed(Duration.zero);

    expect(handler.configurations, isEmpty);
    delayedDatabase.enabledCompleter.complete(true);
    await synchronization;

    expect(
      handler.configurations.map(
        (configuration) =>
            (configuration.profileId, configuration.profileLabel),
      ),
      [(null, ''), (42, 'Applied profile')],
    );
  });

  test(
    'automatically retries when Core is unavailable during startup',
    () async {
      container.dispose();
      await handler.closeConfigurationEvents();
      handler = _UsageCoreHandler();
      container = ProviderContainer(
        overrides: [
          usageStoreProvider.overrideWithValue(database),
          usageCoreProvider.overrideWithValue(CoreController.test(handler)),
          usageConfigurationRetryScheduleProvider.overrideWithValue(const [
            Duration.zero,
          ]),
          currentProfileIdProvider.overrideWithValue(null),
          profilesProvider.overrideWithValue(const []),
        ],
      );
      await database.setEnabled(true);
      handler.rejectNextConfiguration = true;
      final retried = handler.configurationEvents.stream.firstWhere(
        (_) => handler.configurations.length >= 2,
      );

      await container.read(usageRuntimeProvider.future);
      await retried.timeout(const Duration(seconds: 1));

      expect(handler.configurations, hasLength(2));
      expect(handler.configurations.every((item) => item.enabled), isTrue);
    },
  );

  test('retries the exact applied profile without a Core transition', () async {
    container.dispose();
    await handler.closeConfigurationEvents();
    handler = _UsageCoreHandler();
    container = ProviderContainer(
      overrides: [
        usageStoreProvider.overrideWithValue(database),
        usageCoreProvider.overrideWithValue(CoreController.test(handler)),
        usageConfigurationRetryScheduleProvider.overrideWithValue(const [
          Duration.zero,
        ]),
        currentProfileIdProvider.overrideWithValue(null),
        profilesProvider.overrideWithValue(const []),
      ],
    );
    await container.read(usageRuntimeProvider.future);
    await container.read(usageRuntimeProvider.notifier).setEnabled(true);
    handler.rejectNextConfiguration = true;
    final retried = handler.configurationEvents.stream.firstWhere(
      (_) =>
          handler.configurations
              .where(
                (item) =>
                    item.profileId == 42 &&
                    item.profileLabel == 'Applied profile',
              )
              .length >=
          2,
    );

    await container
        .read(usageRuntimeProvider.notifier)
        .syncProfile(profileId: 42, profileLabel: 'Applied profile');
    await retried.timeout(const Duration(seconds: 1));

    final profileAttempts = handler.configurations.where(
      (item) => item.profileId == 42,
    );
    expect(profileAttempts, hasLength(2));
    expect(
      profileAttempts.every(
        (item) => item.enabled && item.profileLabel == 'Applied profile',
      ),
      isTrue,
    );
  });

  test(
    'strict final flush prevents disabling after a persistence error',
    () async {
      await container.read(usageRuntimeProvider.future);
      await container.read(usageRuntimeProvider.notifier).setEnabled(true);
      handler.batch = UsageBatch(
        sessionId: 'session-strict',
        sequence: 1,
        buckets: [
          UsageBucketData(
            minute: DateTime.now().toUtc().millisecondsSinceEpoch,
            route: UsageRoute.proxy,
            upload: 3,
          ),
        ],
      );
      handler.failNextRead = true;

      await expectLater(
        container.read(usageRuntimeProvider.notifier).setEnabled(false),
        throwsA(isA<CoreMethodException>()),
      );

      expect(await database.isEnabled(), isTrue);
      expect(handler.configurations.last.enabled, isTrue);
      expect(
        container.read(usageIssuesProvider),
        contains(UsageIssue.persistence),
      );
    },
  );

  test('reasserts enabled state after an ambiguous pause rejection', () async {
    await container.read(usageRuntimeProvider.future);
    await container.read(usageRuntimeProvider.notifier).setEnabled(true);
    handler.rejectNextConfiguration = true;

    await expectLater(
      container.read(usageRuntimeProvider.notifier).setEnabled(false),
      throwsStateError,
    );

    expect(await database.isEnabled(), isTrue);
    expect(
      handler.configurations
          .skip(handler.configurations.length - 2)
          .map((item) => item.enabled),
      [false, true],
    );
  });

  test(
    'converges a failed enable and failed compensation back to disabled',
    () async {
      container.dispose();
      await handler.closeConfigurationEvents();
      handler = _UsageCoreHandler();
      container = ProviderContainer(
        overrides: [
          usageStoreProvider.overrideWithValue(database),
          usageCoreProvider.overrideWithValue(CoreController.test(handler)),
          usageConfigurationRetryScheduleProvider.overrideWithValue(const [
            Duration.zero,
          ]),
          currentProfileIdProvider.overrideWithValue(null),
          profilesProvider.overrideWithValue(const []),
        ],
      );
      await container.read(usageRuntimeProvider.future);
      handler.configurationBehaviors.addAll(const [
        _ConfigurationBehavior.applyThenThrow,
        _ConfigurationBehavior.throwBeforeApply,
      ]);
      final disabled = handler.configurationEvents.stream.firstWhere(
        (_) =>
            handler.configurations.length >= 3 &&
            !handler.configurations.last.enabled,
      );

      await expectLater(
        container.read(usageRuntimeProvider.notifier).setEnabled(true),
        throwsA(isA<CoreMethodException>()),
      );
      await disabled.timeout(const Duration(seconds: 1));

      expect(handler.configurations.map((item) => item.enabled), [
        true,
        false,
        false,
      ]);
      expect(handler.coreUsageEnabled, isFalse);
      expect(await database.isEnabled(), isFalse);
    },
  );

  test('reasserts a pending disabled intent after Core reconnects', () async {
    container.dispose();
    await handler.closeConfigurationEvents();
    handler = _UsageCoreHandler();
    container = ProviderContainer(
      overrides: [
        usageStoreProvider.overrideWithValue(database),
        usageCoreProvider.overrideWithValue(CoreController.test(handler)),
        usageConfigurationRetryScheduleProvider.overrideWithValue(const [
          Duration(days: 1),
        ]),
        currentProfileIdProvider.overrideWithValue(null),
        profilesProvider.overrideWithValue(const []),
      ],
    );
    await container.read(usageRuntimeProvider.future);
    handler.configurationBehaviors.addAll(const [
      _ConfigurationBehavior.applyThenThrow,
      _ConfigurationBehavior.throwBeforeApply,
    ]);

    await expectLater(
      container.read(usageRuntimeProvider.notifier).setEnabled(true),
      throwsA(isA<CoreMethodException>()),
    );

    expect(handler.coreUsageEnabled, isTrue);
    expect(handler.configurations.map((item) => item.enabled), [true, false]);

    await container
        .read(usageRuntimeProvider.notifier)
        .syncCore(throwOnError: true);

    expect(handler.configurations.map((item) => item.enabled), [
      true,
      false,
      false,
    ]);
    expect(handler.coreUsageEnabled, isFalse);
    expect(await database.isEnabled(), isFalse);
  });

  test('pauses Core before draining the final batch', () async {
    await container.read(usageRuntimeProvider.future);
    await container.read(usageRuntimeProvider.notifier).setEnabled(true);
    final minute = DateTime.utc(2026, 8, 14, 10).millisecondsSinceEpoch;
    handler.finalBatch = UsageBatch(
      sessionId: 'session-final',
      sequence: 1,
      buckets: [
        UsageBucketData(
          minute: minute,
          route: UsageRoute.proxy,
          upload: 7,
          download: 11,
        ),
      ],
    );

    await container.read(usageRuntimeProvider.notifier).setEnabled(false);

    expect(handler.acknowledged, isTrue);
    expect(handler.configurations.last.enabled, isFalse);
    expect(
      await database.summary(
        UsageFilter(
          start: DateTime.utc(2026, 8, 14, 9),
          end: DateTime.utc(2026, 8, 14, 11),
        ),
      ),
      const UsageSummary(upload: 7, download: 11),
    );
  });

  test('reports degraded Core batches after preserving them', () async {
    await container.read(usageRuntimeProvider.future);
    await container.read(usageRuntimeProvider.notifier).setEnabled(true);
    handler.batch = UsageBatch(
      sessionId: 'session-degraded',
      sequence: 1,
      degraded: true,
      buckets: [
        UsageBucketData(
          minute: DateTime.now().toUtc().millisecondsSinceEpoch,
          route: UsageRoute.proxy,
          download: 5,
        ),
      ],
    );

    await container.read(usageRuntimeProvider.notifier).flush(strict: true);

    expect(await database.hasAnyDegradedData(), isTrue);
    expect(await container.read(usageHasDegradedDataProvider.future), isTrue);
    expect(
      container.read(usageIssuesProvider),
      isNot(contains(UsageIssue.degraded)),
    );
  });

  test('clock invalidates the cached today summary across midnight', () async {
    final firstDay = DateTime(2026, 8, 14, 23, 59);
    await database.ingest(
      UsageBatch(
        sessionId: 'session-midnight',
        sequence: 1,
        buckets: [
          UsageBucketData(
            minute: firstDay.toUtc().millisecondsSinceEpoch,
            route: UsageRoute.proxy,
            download: 9,
          ),
        ],
      ),
    );
    container.read(usageClockProvider.notifier).update(firstDay);

    expect(
      await container.read(todayProxyUsageProvider.future),
      const UsageSummary(download: 9),
    );

    container
        .read(usageClockProvider.notifier)
        .update(DateTime(2026, 8, 15, 0, 1));
    expect(
      await container.read(todayProxyUsageProvider.future),
      const UsageSummary(),
    );
  });

  test('CSV uses a UTF-8 BOM, CRLF and RFC 4180 escaping', () {
    final bytes = usageCsvExporter.encodeCsv([
      ['range', 'proxy', 'domain', 'a,"b\n.example', '', 1, 2, 3, 4],
    ]);
    final content = utf8.decode(bytes.sublist(3));

    expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
    expect(content, contains('\r\n'));
    expect(content, contains('"a,""b\n.example"'));
  });
}

class _DelayedUsageDatabase extends UsageDatabase {
  final Completer<bool> enabledCompleter = Completer<bool>();

  _DelayedUsageDatabase(super.executor);

  @override
  Future<bool> isEnabled() => enabledCompleter.future;
}
