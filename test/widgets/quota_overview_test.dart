import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/profile.dart';
import 'package:fl_clash/views/policy/quota_overview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Profile _profile(int id, {int total = 100, int used = 20, int? expiry}) {
  return Profile(
    id: id,
    label: 'Source $id',
    autoUpdateDuration: const Duration(hours: 6),
    subscriptionInfo: SubscriptionInfo(
      total: total,
      upload: used,
      knownFields: {
        'total',
        'upload',
        'download',
        if (expiry != null) 'expire',
      },
      expire: expiry == null ? 0 : expiry ~/ 1000,
    ),
  );
}

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.delegate.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('shows the segmented bar, source rows, and manage action', (
    tester,
  ) async {
    var managed = false;
    await tester.pumpWidget(
      _app(
        LocalQuotaOverview(
          profiles: [
            _profile(
              1,
              expiry: DateTime.now()
                  .add(const Duration(days: 10))
                  .millisecondsSinceEpoch,
            ),
            _profile(2, expiry: 0),
            _profile(3, used: 0, expiry: 0),
          ],
          onManageSources: () => managed = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final strings = AppLocalizations.current;
    expect(find.textContaining(strings.policyQuotaUsed), findsWidgets);
    expect(
      find.byKey(const ValueKey('quota-legend-unlimited')),
      findsOneWidget,
    );
    expect(find.text('Source 1'), findsOneWidget);
    expect(find.text('Source 2'), findsOneWidget);
    await tester.tap(find.text(strings.policySubscriptionSources));
    expect(managed, isTrue);

    await tester.tap(find.byKey(const ValueKey('quota-segment-used')));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(
      find.descendant(of: dialog, matching: find.textContaining('Source 1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.textContaining('Source 3')),
      findsNothing,
    );
    await tester.tap(find.text(AppLocalizations.current.cancel));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quota-legend-used')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('Source 1'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text(AppLocalizations.current.cancel));
    await tester.pumpAndSettle();
  });

  testWidgets('keeps the compact layout usable at narrow and wide widths', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final child = LocalQuotaOverview(
      profiles: [_profile(1, total: 1024, used: 1)],
    );
    for (final width in [390.0, 1200.0]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(_app(child));
      await tester.pumpAndSettle();
      expect(find.text('Source 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('scrolls a long source list and opens a segment legend', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      _app(
        LocalQuotaOverview(
          profiles: [for (var id = 1; id <= 20; id++) _profile(id)],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Source 20'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Source 20'),
      600,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Source 20'), findsOneWidget);
  });
}
