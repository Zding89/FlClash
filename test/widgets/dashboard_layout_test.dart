import 'package:drift/native.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/database/usage_database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/providers/usage.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/dashboard/dashboard.dart';
import 'package:fl_clash/widgets/grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dashboard limits a wide grid to 16 centered columns', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        dashboardStateProvider.overrideWithValue(
          const DashboardState(dashboardWidgets: []),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: DashboardView()),
      ),
    );
    await tester.pump();

    final grid = find.byType(Grid);
    expect(tester.widget<Grid>(grid).crossAxisCount, 16);
    expect(tester.getSize(grid).width, 1120);
    expect(tester.getTopLeft(grid).dx, 240);
    expect(tester.takeException(), null);
  });

  testWidgets('unsupported dashboard does not access usage storage', (
    tester,
  ) async {
    final database = _CountingUsageDatabase();
    addTearDown(database.close);
    final container = ProviderContainer(
      overrides: [
        dashboardStateProvider.overrideWithValue(
          const DashboardState(
            dashboardWidgets: [DashboardWidget.trafficUsage],
          ),
        ),
        usagePlatformSupportedProvider.overrideWithValue(false),
        usageStoreProvider.overrideWithValue(database),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: DashboardView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(database.isEnabledReads, 0);
    expect(database.watchEnabledReads, 0);
    expect(database.todaySummaryReads, 0);
    expect(tester.takeException(), null);
  });
}

class _CountingUsageDatabase extends UsageDatabase {
  int isEnabledReads = 0;
  int watchEnabledReads = 0;
  int todaySummaryReads = 0;

  _CountingUsageDatabase() : super(NativeDatabase.memory());

  @override
  Future<bool> isEnabled() async {
    isEnabledReads++;
    return false;
  }

  @override
  Stream<bool> watchEnabled() {
    watchEnabledReads++;
    return const Stream.empty();
  }

  @override
  Future<UsageSummary> todayProxySummary({DateTime? now}) async {
    todaySummaryReads++;
    return const UsageSummary();
  }
}

class _TestApp extends StatelessWidget {
  final Widget child;

  const _TestApp({required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: globalState.navigatorKey,
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
