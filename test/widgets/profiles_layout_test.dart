import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/profiles/profiles.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

final _updatedAt = DateTime.utc(2026, 10, 14);
final _profiles = [
  Profile(
    id: 1,
    label: 'Example subscription',
    url: 'https://example.com/sub',
    autoUpdateDuration: Duration.zero,
    lastUpdateDate: _updatedAt,
    subscriptionInfo: const SubscriptionInfo(
      upload: 1024,
      download: 2048,
      total: 8192,
      expire: 2000000000,
    ),
  ),
  const Profile(
    id: 2,
    label: 'Local profile',
    autoUpdateDuration: Duration.zero,
  ),
];
const _integration = SubscriptionIntegration(
  id: localPolicyProfileId,
  label: 'Merged profile',
  sourceProfileIds: [1, 2],
);
const _document = LocalPolicyDocument(
  moduleEnabled: true,
  integrationEnabled: true,
  schemaVersion: 4,
  activeIntegrationId: localPolicyProfileId,
  integrations: [_integration],
);

class _Controller extends Mock implements WorkbenchController {
  final selections = <Map<String, Object?>>[];
  ConfigurationApproval? approval;

  @override
  Future<Map<String, Object?>> selectPolicyTarget({
    int? profileId,
    String? integrationId,
    bool? moduleEnabled,
    required ConfigurationApproval approve,
  }) async {
    approval = approve;
    selections.add({
      'profileId': profileId,
      'integrationId': integrationId,
      'moduleEnabled': moduleEnabled,
    });
    return {'status': 'applied'};
  }
}

Future<ProviderContainer> _mount(
  WidgetTester tester,
  Size size, {
  List<Profile>? profiles,
  _Controller? controller,
  LocalPolicyDocument document = _document,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      profilesProvider.overrideWithBuild((_, _) => profiles ?? _profiles),
      currentProfileIdProvider.overrideWithBuild((_, _) => 2),
      if (controller != null)
        workbenchControllerProvider.overrideWithValue(controller),
      localPoliciesProvider.overrideWith((_) => Stream.value(document)),
      localPolicyStatusProvider.overrideWith(
        (_) => Stream.value({
          'targetId': localPolicyTargetId,
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
        locale: const Locale('en'),
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
        home: const ProfilesView(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final entry in {390.0: 1, 944.0: 3, 1411.0: 4}.entries) {
    final width = entry.key;
    testWidgets(
      'profiles retain adaptive columns original actions and FAB at $width',
      (tester) async {
        await _mount(tester, Size(width, 1000));
        final strings = AppLocalizations.current;
        expect(
          tester.widget<Grid>(find.byType(Grid)).crossAxisCount,
          entry.value,
        );
        expect(find.byType(CommonFloatingActionButton), findsOneWidget);
        expect(find.widgetWithIcon(IconButton, Icons.sync), findsOneWidget);
        expect(find.widgetWithIcon(IconButton, Icons.sort), findsOneWidget);
        expect(find.byType(ProfileItem), findsNWidgets(2));
        expect(find.byIcon(Icons.more_vert), findsNWidgets(2));
        expect(find.byKey(const ValueKey('profile-update-1')), findsNothing);
        if (system.isMacOS) {
          expect(find.text(strings.policyLocalCollection), findsOneWidget);
          expect(
            find.widgetWithText(SwitchListTile, strings.policyModule),
            findsNothing,
          );
        }
        final usage = tester.widget<SubscriptionInfoView>(
          find.byType(SubscriptionInfoView),
        );
        expect(usage.subscriptionInfo, _profiles.first.subscriptionInfo);
        expect(usage.updatedAt, _updatedAt);
        expect(find.textContaining('3KB / 8KB'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'empty local configuration is selectable without enabling a module or creating an integration',
    (tester) async {
      final controller = _Controller();
      await _mount(
        tester,
        const Size(390, 800),
        profiles: const [],
        controller: controller,
        document: const LocalPolicyDocument(),
      );
      final strings = AppLocalizations.current;
      expect(find.byKey(const ValueKey('profiles-local')), findsOneWidget);
      expect(
        find.textContaining(
          '${strings.profilesSourceCount(0)} · ${strings.profilesRuleCount(0)}',
        ),
        findsOneWidget,
      );
      expect(find.byType(SwitchListTile), findsNothing);
      expect(controller.selections, isEmpty);
      await _tap(tester, find.text(strings.policyLocalCollection));
      expect(
        controller.selections.single['integrationId'],
        localPolicyProfileId,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip: !system.isMacOS,
  );
  testWidgets('profiles empty state retains add FAB', (tester) async {
    await _mount(tester, const Size(944, 700), profiles: const []);
    expect(
      find.byType(NullStatus),
      system.isMacOS ? findsNothing : findsOneWidget,
    );
    if (system.isMacOS) {
      expect(find.byKey(const ValueKey('profiles-local')), findsOneWidget);
    }
    expect(find.byType(CommonFloatingActionButton), findsOneWidget);
    expect(find.byType(ProfileItem), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'local and subscription selections keep the approval controller boundary',
    (tester) async {
      final controller = _Controller();
      final container = await _mount(
        tester,
        const Size(944, 1000),
        controller: controller,
      );
      final strings = AppLocalizations.current;
      await _tap(tester, find.text('Example subscription'));
      expect(controller.selections.last['profileId'], 1);
      expect(container.read(currentProfileIdProvider), 2);
      await _tap(tester, find.text(strings.policyLocalCollection));
      expect(controller.selections.last['integrationId'], localPolicyProfileId);
      expect(
        find.widgetWithText(SwitchListTile, strings.policyModule),
        findsNothing,
      );
      expect(controller.approval, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip: !system.isMacOS,
  );
}
