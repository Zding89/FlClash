import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/profiles/profiles.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _profiles = [
  Profile(
    id: 1,
    label: 'Example subscription',
    url: 'https://example.com/sub',
    autoUpdateDuration: Duration.zero,
    subscriptionInfo: SubscriptionInfo(
      upload: 1024,
      download: 2048,
      total: 8192,
      expire: 2000000000,
    ),
  ),
  Profile(id: 2, label: 'Local profile', autoUpdateDuration: Duration.zero),
];
const _integration = SubscriptionIntegration(
  id: 'merged',
  label: 'Merged profile',
  sourceProfileIds: [1, 2],
);
const _document = LocalPolicyDocument(
  moduleEnabled: true,
  integrationEnabled: true,
  activeIntegrationId: 'merged',
  integrations: [_integration],
  policies: [
    LocalPolicy(
      id: 'rule',
      label: 'Rule',
      targetId: 'integration:merged',
      action: PolicyAction.direct,
    ),
  ],
);

Future<void> _mount(
  WidgetTester tester,
  Size size, {
  GlobalKey? capture,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      profilesProvider.overrideWithBuild((_, _) => _profiles),
      currentProfileIdProvider.overrideWithBuild((_, _) => 1),
      localPoliciesProvider.overrideWith((_) => Stream.value(_document)),
      localPolicyStatusProvider.overrideWith(
        (_) => Stream.value({
          'targetId': 'integration:merged',
          'documentRevision': _document.revision,
        }),
      ),
    ],
  );
  addTearDown(container.dispose);
  globalState.container = container;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('zh', 'CN'),
        theme: ThemeData(fontFamily: 'FixtureFont'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        builder: (context, child) {
          globalState.measure = Measure.of(context, 1);
          globalState.theme = CommonTheme.of(context, 1);
          return child!;
        },
        home: RepaintBoundary(key: capture, child: const ProfilesView()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    final font = File('/System/Library/Fonts/Supplemental/Arial Unicode.ttf');
    final data = font.existsSync()
        ? ByteData.sublistView(await font.readAsBytes())
        : await rootBundle.load('assets/fonts/JetBrainsMono-Regular.ttf');
    await (FontLoader('FixtureFont')..addFont(Future.value(data))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final width in [944.0, 1411.0]) {
    testWidgets(
      'desktop profiles follow horizontal reference cards at $width',
      (tester) async {
        final capture = GlobalKey();
        await _mount(tester, Size(width, 1000), capture: capture);
        final strings = AppLocalizations.current;
        final collection = find.byKey(
          const ValueKey('profiles-local-collection'),
        );
        final first = find.byKey(const ValueKey('profile-card-1'));
        final second = find.byKey(const ValueKey('profile-card-2'));
        expect(find.text(strings.profilesUpdateAll), findsOneWidget);
        expect(find.text(strings.addProfile), findsOneWidget);
        expect(find.byType(CommonFloatingActionButton), findsNothing);
        expect(find.byType(Radio<bool>), findsNWidgets(3));
        expect(find.byIcon(Icons.layers_outlined), findsOneWidget);
        expect(find.byIcon(Icons.cloud_outlined), findsOneWidget);
        expect(find.byIcon(Icons.description_outlined), findsOneWidget);
        expect(find.text(strings.profilesSourceCount(2)), findsOneWidget);
        expect(find.text(strings.profilesRuleCount(1)), findsOneWidget);
        expect(
          tester.getTopLeft(collection).dy,
          lessThan(tester.getTopLeft(first).dy),
        );
        expect(
          tester.getTopLeft(first).dy,
          lessThan(tester.getTopLeft(second).dy),
        );
        final radio = find.descendant(
          of: first,
          matching: find.byType(Radio<bool>),
        );
        final icon = find.descendant(
          of: first,
          matching: find.byIcon(Icons.cloud_outlined),
        );
        final title = find.text('Example subscription');
        final update = find.byKey(const ValueKey('profile-update-1'));
        final edit = find.byKey(const ValueKey('profile-edit-1'));
        final progress = find.descendant(
          of: first,
          matching: find.byType(LinearProgressIndicator),
        );
        expect(tester.getCenter(radio).dx, lessThan(tester.getCenter(icon).dx));
        expect(
          tester.getCenter(icon).dx,
          lessThan(tester.getTopLeft(title).dx),
        );
        expect(tester.getSize(progress).width, lessThanOrEqualTo(520));
        expect(
          tester.getTopRight(progress).dx,
          lessThan(tester.getTopLeft(update).dx),
        );
        expect(
          tester.getCenter(update).dx,
          lessThan(tester.getCenter(edit).dx),
        );
        expect(tester.widget<OutlinedButton>(update).onPressed, isNotNull);
        expect(tester.widget<OutlinedButton>(edit).onPressed, isNotNull);
        final module = find.byKey(const ValueKey('profiles-module-card'));
        expect(tester.widget(module), isA<Card>());
        expect(
          find.descendant(
            of: module,
            matching: find.byIcon(Icons.rule_outlined),
          ),
          findsOneWidget,
        );
        expect(
          tester.getTopLeft(module).dy,
          greaterThan(tester.getTopLeft(second).dy),
        );
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment(
          'GENERATE_PROFILES_LAYOUT_SCREENSHOTS',
        )) {
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            try {
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                '/private/tmp/flclash-profiles-$width.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
            } finally {
              image.dispose();
            }
          });
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('narrow profiles retain compact selection and add FAB', (
    tester,
  ) async {
    await _mount(tester, const Size(390, 900));
    final strings = AppLocalizations.current;
    expect(find.byType(CommonFloatingActionButton), findsOneWidget);
    expect(find.text(strings.profilesUpdateSubscription), findsNothing);
    expect(find.byKey(const ValueKey('profile-edit-1')), findsNothing);
    expect(find.byType(Radio<bool>), findsNWidgets(3));
    expect(find.byIcon(Icons.more_vert), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('profile radio and card preserve the same selection callback', (
    tester,
  ) async {
    int calls = 0;
    int? selected;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          home: Scaffold(
            body: ProfileItem(
              profile: _profiles.first,
              groupValue: null,
              onChanged: (id) {
                calls++;
                selected = id;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Radio<bool>));
    expect(calls, 1);
    expect(selected, 1);
    await tester.tap(find.text('Example subscription'));
    expect(calls, 2);
    expect(selected, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
