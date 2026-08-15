import 'package:drift/native.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/database/usage_database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/usage.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/usage/usage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late UsageDatabase database;
  late ProviderContainer container;

  setUp(() {
    database = UsageDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [usageStoreProvider.overrideWithValue(database)],
    );
    globalState.container = container;
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  testWidgets('shows an explicit opt-in empty state', (tester) async {
    tester.view.physicalSize = const Size(1000, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: UsageView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Usage recording is off'), findsOneWidget);
    expect(find.text('Go to settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders responsive overview and ranking tabs', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await database.setEnabled(true);
    await database.ingest(_sampleBatch());

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: UsageView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Time trend'), findsOneWidget);
    expect(find.text('Node A'), findsOneWidget);
    expect(
      find.text('Recorded locally; not billing-grade data'),
      findsOneWidget,
    );

    await tester.tap(find.text('Apps').first);
    await tester.pumpAndSettle();

    expect(find.text('Safari'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the overview usable in a narrow Mac window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(620, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await database.setEnabled(true);
    await database.ingest(_sampleBatch());

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: UsageView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Time trend'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows health warnings and loads ranking rows in pages', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await database.setEnabled(true);
    await database.ingest(
      UsageBatch(
        sessionId: 'session-paged',
        sequence: 1,
        buckets: List.generate(
          201,
          (index) => UsageBucketData(
            minute: DateTime.now().toUtc().millisecondsSinceEpoch,
            route: UsageRoute.proxy,
            node: 'Node ${index.toString().padLeft(3, '0')}',
            download: 201 - index,
          ),
        ),
      ),
    );
    container.read(usageIssuesProvider.notifier).add(UsageIssue.degraded);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: UsageView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('pending queue'), findsOneWidget);
    await tester.tap(find.text('Nodes').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Load more'),
      600,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Node 200'),
      600,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text('Node 200'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows IP-only traffic inside the unknown domain details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await database.setEnabled(true);
    await database.ingest(
      UsageBatch(
        sessionId: 'session-ip-only',
        sequence: 1,
        buckets: [
          UsageBucketData(
            minute: DateTime.now().toUtc().millisecondsSinceEpoch,
            route: UsageRoute.proxy,
            destinationIP: '1.1.1.1',
            download: 9,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: UsageView()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Domains').first);
    await tester.pumpAndSettle();

    expect(find.text('Identification coverage 0.0%'), findsOneWidget);
    expect(find.text('Unknown domain or IP'), findsOneWidget);

    await tester.tap(find.text('Unknown domain or IP'));
    await tester.pumpAndSettle();

    expect(find.text('1.1.1.1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selects one fixed hour from a sparse trend', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final start = DateTime.utc(2026, 8, 14, 10);
    await database.setEnabled(true);
    await database.ingest(
      UsageBatch(
        sessionId: 'session-sparse-widget',
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
    container
        .read(usageFilterStateProvider.notifier)
        .setRange(start, start.add(const Duration(hours: 6)));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: UsageView()),
      ),
    );
    await tester.pumpAndSettle();
    final trend = find
        .byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Time trend',
        )
        .first;
    final rect = tester.getRect(trend);

    await tester.tapAt(Offset(rect.left + 1, rect.center.dy));
    await tester.pumpAndSettle();

    final selected = container.read(usageFilterStateProvider);
    expect(selected.start.toUtc(), start);
    expect(selected.end.toUtc(), start.add(const Duration(hours: 1)));
  });

  testWidgets('ranking bars use the active sort metric', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await database.setEnabled(true);
    await database.ingest(
      UsageBatch(
        sessionId: 'session-ranking-metric',
        sequence: 1,
        buckets: [
          UsageBucketData(
            minute: DateTime.now().toUtc().millisecondsSinceEpoch,
            route: UsageRoute.proxy,
            node: 'Upload first',
            upload: 100,
          ),
          UsageBucketData(
            minute: DateTime.now().toUtc().millisecondsSinceEpoch,
            route: UsageRoute.proxy,
            node: 'Total first',
            upload: 50,
            download: 1000,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: UsageView()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nodes').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<UsageSort>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload').last);
    await tester.pumpAndSettle();

    final values = tester
        .widgetList<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        )
        .map((indicator) => indicator.value)
        .toList();
    expect(values, [1, 0.5]);
    expect(tester.takeException(), isNull);
  });
}

UsageBatch _sampleBatch() {
  return UsageBatch(
    sessionId: 'session-a',
    sequence: 1,
    buckets: [
      UsageBucketData(
        minute: DateTime.now().toUtc().millisecondsSinceEpoch,
        profileId: 42,
        profileLabel: 'Work',
        route: UsageRoute.proxy,
        node: 'Node A',
        process: 'Safari',
        processPath: '/Applications/Safari.app/Contents/MacOS/Safari',
        domain: 'example.com',
        host: 'api.example.com',
        upload: 1024,
        download: 2048,
        connections: 1,
      ),
    ],
  );
}

class _TestApp extends StatelessWidget {
  final Widget child;

  const _TestApp({required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      builder: (context, child) {
        globalState.measure = Measure.of(context, 1);
        globalState.theme = CommonTheme.of(context, 1);
        return child!;
      },
      home: child,
    );
  }
}
