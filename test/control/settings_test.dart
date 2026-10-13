import 'package:fl_clash/control/service.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/views/control/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'service_test.dart' show MemoryStore, FakeTransport;

void main() {
  testWidgets(
    'desktop and narrow settings remain scrollable and cancel does not rotate',
    (tester) async {
      final store = MemoryStore();
      final service = LocalControlService(
        passwordStore: store,
        transport: FakeTransport(),
        supported: true,
        executor: (_) async => {'status': 'completed'},
      );
      addTearDown(() async {
        await service.close();
        service.dispose();
      });
      Future<void> pump(Size size) async {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              viewSizeProvider.overrideWithBuild((ref, notifier) => size),
            ],
            child: MaterialApp(
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.delegate.supportedLocales,
              locale: const Locale('en'),
              home: Scaffold(body: LocalControlSettings(service: service)),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pump(const Size(1100, 850));
      expect(find.byType(SwitchListTile), findsOneWidget);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      final password = store.value;
      expect(service.enabled, true);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(LocalControlSettings)),
      );
      await tester.tap(find.text(l10n.localControlChangePassword));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'different-password-123',
      );
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();
      expect(store.value, password);
      expect(store.writes, 1);
      await pump(const Size(390, 700));
      expect(tester.takeException(), null);
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text(l10n.localControlExitHint), findsOneWidget);
      expect(tester.takeException(), null);
      await service.close();
      await tester.pumpAndSettle();
    },
  );
}
