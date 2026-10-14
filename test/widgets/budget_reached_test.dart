import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:drift/native.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/policy/editors.dart';
import 'package:fl_clash/views/policy/policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

const fixtureOutput = String.fromEnvironment('POLICY_BUDGET_FIXTURE_OUTPUT');
const fixtureFont = String.fromEnvironment('POLICY_BUDGET_FIXTURE_FONT');
const fixtureIcons = String.fromEnvironment('POLICY_BUDGET_FIXTURE_ICONS');
const gib = 1073741824;
final captureKey = GlobalKey();
const document = LocalPolicyDocument(
  revision: 12,
  moduleEnabled: true,
  policiesEnabled: true,
  integrationEnabled: true,
  budgetsEnabled: true,
  activeIntegrationId: 'fixture_pool',
  integrations: [
    SubscriptionIntegration(
      id: 'fixture_pool',
      label: '办公与日常测试集合',
      sourceProfileIds: [1, 2],
    ),
  ],
  budgets: [
    SourceBudget(sourceId: '1', limitBytes: 80 * gib),
    SourceBudget(sourceId: '2', limitBytes: 50 * gib),
    SourceBudget(sourceId: '3', limitBytes: 30 * gib),
  ],
);
const profiles = [
  Profile(id: 1, label: '晨光测试来源', autoUpdateDuration: Duration(hours: 24)),
  Profile(id: 2, label: '星河测试来源', autoUpdateDuration: Duration(hours: 24)),
  Profile(
    id: 3,
    label: '远山测试来源（非活动来源）',
    autoUpdateDuration: Duration(hours: 24),
  ),
];
Map<String, Object?> status({
  Map<String, Object?> patch = const {},
  Map<String, Object?> second = const {},
  bool includeSecond = true,
  List<Object?> extra = const [],
}) => {
  'enabled': true,
  'revision': 19,
  'documentRevision': 12,
  'targetId': 'integration:fixture_pool',
  'policies': <Object?>[],
  'nodeSets': <Object?>[],
  'budgets': [
    {
      'sourceId': '1',
      'usedBytes': 36 * gib,
      'limitBytes': 80 * gib,
      'trusted': true,
      'periodStart': 1790784000000,
    },
    if (includeSecond)
      {
        'sourceId': '2',
        'usedBytes': 50 * gib,
        'limitBytes': 50 * gib,
        'trusted': true,
        'periodStart': 1790784000000,
        ...second,
      },
    ...extra,
  ],
  ...patch,
};
const saved = <String, Object?>{
  '3': {
    'usedBytes': 0,
    'trusted': false,
    'periodStart': 1790784000000,
    'sampleAt': 1791939600000,
  },
};

class Workbench extends Mock implements WorkbenchController {
  Workbench(this.document);
  final LocalPolicyDocument document;
  @override
  Future<LocalPolicyDocument> readPolicies() async => document;
  @override
  Future<List<LocalNode>> loadNodes(
    String targetId, {
    bool refresh = false,
    LocalPolicyDocument? document,
  }) async => [];
  @override
  Future<void> closeAgent() async {}
}

Future<void> mount(
  WidgetTester tester, {
  LocalPolicyDocument doc = document,
  Map<String, Object?>? snapshot,
  Map<String, Object?> history = saved,
  CoreStatus core = CoreStatus.connected,
  Size size = const Size(390, 700),
  Stream<Map<String, Object?>>? statusStream,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final store = WorkbenchDatabase(NativeDatabase.memory());
  await tester.runAsync(() async {
    await store.writeSection('fixture', {});
  });
  final container = ProviderContainer(
    overrides: [
      ...buildConfigOverrides(
        const Config(themeProps: defaultThemeProps, currentProfileId: 1),
      ),
      viewSizeProvider.overrideWithBuild((ref, notifier) => size),
      workbenchDatabaseProvider.overrideWithValue(store),
      workbenchControllerProvider.overrideWithValue(Workbench(doc)),
      localPoliciesProvider.overrideWith((_) => Stream.value(doc)),
      localPolicyStatusProvider.overrideWith(
        (_) => statusStream ?? Stream.value(snapshot ?? status()),
      ),
      localBudgetHistoryProvider.overrideWith((_) => Stream.value(history)),
      workbenchChangesProvider.overrideWith((_) => Stream.value([])),
      profilesProvider.overrideWithBuild((ref, notifier) => profiles),
      coreStatusProvider.overrideWithBuild((ref, notifier) => core),
    ],
  );
  globalState.container = container;
  addTearDown(() async {
    container.dispose();
    await store.close();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        theme: ThemeData(
          fontFamily: fixtureFont == '' ? null : 'FixtureFont',
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xff9fcafd),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        builder: (context, child) {
          globalState.measure = Measure.of(context, 1);
          globalState.theme = CommonTheme.of(context, 1);
          return RepaintBoundary(
            key: captureKey,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  color: const Color(0xffe5bc58),
                  child: const Text(
                    'SYNTHETIC FIXTURE · NOT LIVE APP',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: fixtureFont == '' ? null : 'FixtureFont',
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                Expanded(child: child!),
              ],
            ),
          );
        },
        home: const LocalPolicyWorkbenchView(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tap(
    tester,
    find.widgetWithText(Tab, AppLocalizations.current.policyAdvancedTab),
  );
  await tap(
    tester,
    find.widgetWithText(
      ExpansionTile,
      AppLocalizations.current.policyBudgetTab,
    ),
  );
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  });
  await tester.pumpAndSettle();
}

Future<void> finish(WidgetTester tester) async {
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}

Future<void> capture(WidgetTester tester, String suffix) async {
  if (fixtureOutput.isEmpty) return;
  final boundary =
      captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '$fixtureOutput/fixture-06-budget-reached-$suffix.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

LocalPolicyDocument doc(Map<String, Object?> patch) =>
    LocalPolicyDocument.fromJson({...document.toJson(), ...patch});
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  setUpAll(() async {
    for (final entry in {
      'FixtureFont': fixtureFont,
      'MaterialIcons': fixtureIcons,
    }.entries) {
      if (entry.value.isEmpty) continue;
      final bytes = await File(entry.value).readAsBytes();
      await (FontLoader(
        entry.key,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });
  for (final entry in {
    'desktop': const Size(1100, 850),
    'narrow': const Size(390, 700),
  }.entries) {
    testWidgets(
      'UI-A01-06 exact trusted active-source budget reached ${entry.key}',
      (tester) async {
        await mount(tester, size: entry.value);
        final strings = AppLocalizations.current;
        expect(find.text(strings.policyBudgetReached), findsOneWidget);
        expect(find.text(strings.policyBudgetReachedHint), findsOneWidget);
        expect(
          find.byKey(const ValueKey('policy-budget-reached-2')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('policy-budget-reached-1')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('policy-budget-reached-3')),
          findsNothing,
        );
        expect(find.textContaining(strings.policyUsageUnknown), findsOneWidget);
        await capture(tester, entry.key);
        await tap(tester, find.text('星河测试来源'));
        expect(find.byType(PolicyBudgetEditor), findsOneWidget);
        await tap(tester, find.text(strings.cancel).last);
        expect(find.text(strings.policyBudgetReached), findsOneWidget);
        await finish(tester);
      },
    );
  }
  testWidgets('UI-A01-06 amount above limit also restricted', (tester) async {
    await mount(tester, snapshot: status(second: {'usedBytes': 51 * gib}));
    expect(
      find.text(AppLocalizations.current.policyBudgetReached),
      findsOneWidget,
    );
    await finish(tester);
  });
  testWidgets('UI-A01-06 original profile source also uses its active budget', (
    tester,
  ) async {
    await mount(
      tester,
      doc: doc({'integrationEnabled': false}),
      snapshot: status(
        patch: {
          'targetId': 'profile:1',
          'budgets': [
            {
              'sourceId': '1',
              'usedBytes': 80 * gib,
              'limitBytes': 80 * gib,
              'trusted': true,
              'periodStart': 1790784000000,
            },
          ],
        },
      ),
    );
    expect(
      find.byKey(const ValueKey('policy-budget-reached-1')),
      findsOneWidget,
    );
    await finish(tester);
  });
  final scenarios =
      <
        String,
        ({
          LocalPolicyDocument? document,
          Map<String, Object?>? snapshot,
          CoreStatus? core,
          Map<String, Object?>? history,
        })
      >{
        'module disabled': (
          document: doc({'moduleEnabled': false}),
          snapshot: null,
          core: null,
          history: null,
        ),
        'budgets disabled': (
          document: doc({'budgetsEnabled': false}),
          snapshot: null,
          core: null,
          history: null,
        ),
        'engine disabled': (
          document: null,
          snapshot: status(patch: {'enabled': false}),
          core: null,
          history: null,
        ),
        'Core disconnected': (
          document: null,
          snapshot: null,
          core: CoreStatus.disconnected,
          history: null,
        ),
        'stale document revision': (
          document: null,
          snapshot: status(patch: {'documentRevision': 11}),
          core: null,
          history: null,
        ),
        'wrong active target': (
          document: null,
          snapshot: status(patch: {'targetId': 'integration:other'}),
          core: null,
          history: null,
        ),
        'unknown runtime revision': (
          document: null,
          snapshot: status(patch: {'revision': null}),
          core: null,
          history: null,
        ),
        'below limit': (
          document: null,
          snapshot: status(second: {'usedBytes': 49 * gib}),
          core: null,
          history: null,
        ),
        'untrusted current ledger': (
          document: null,
          snapshot: status(second: {'trusted': false}),
          core: null,
          history: null,
        ),
        'unknown usage': (
          document: null,
          snapshot: status(second: {'usedBytes': null}),
          core: null,
          history: null,
        ),
        'unknown runtime limit': (
          document: null,
          snapshot: status(second: {'limitBytes': null}),
          core: null,
          history: null,
        ),
        'mismatching runtime limit': (
          document: null,
          snapshot: status(second: {'limitBytes': 40 * gib}),
          core: null,
          history: null,
        ),
        'cache only at limit': (
          document: null,
          snapshot: status(includeSecond: false),
          core: null,
          history: {
            '2': {
              'usedBytes': 50 * gib,
              'trusted': true,
              'periodStart': 1790784000000,
            },
          },
        ),
        'outside active collection source': (
          document: null,
          snapshot: status(
            second: {'usedBytes': 49 * gib},
            extra: [
              {
                'sourceId': '3',
                'usedBytes': 30 * gib,
                'limitBytes': 30 * gib,
                'trusted': true,
                'periodStart': 1790784000000,
              },
            ],
          ),
          core: null,
          history: null,
        ),
      };
  for (final entry in scenarios.entries) {
    testWidgets('UI-A01-06 ${entry.key} does not claim budget reached', (
      tester,
    ) async {
      final scenario = entry.value;
      await mount(
        tester,
        doc: scenario.document ?? document,
        snapshot: scenario.snapshot,
        core: scenario.core ?? CoreStatus.connected,
        history: scenario.history ?? saved,
      );
      expect(
        find.text(AppLocalizations.current.policyBudgetReached),
        findsNothing,
      );
      expect(
        find.text(AppLocalizations.current.policyBudgetReachedHint),
        findsNothing,
      );
      if (entry.key == 'untrusted current ledger') {
        expect(
          find.textContaining(AppLocalizations.current.policyLedgerUntrusted),
          findsOneWidget,
        );
      }
      if (entry.key == 'cache only at limit') {
        expect(
          find.textContaining(AppLocalizations.current.policySavedInactive),
          findsAtLeastNWidgets(1),
        );
      }
      await finish(tester);
    });
  }
  testWidgets(
    'UI-A01-06 late status of an older document removes reached indicator',
    (tester) async {
      final stream = StreamController<Map<String, Object?>>.broadcast();
      await mount(tester, statusStream: stream.stream);
      stream.add(status());
      await tester.pumpAndSettle();
      expect(
        find.text(AppLocalizations.current.policyBudgetReached),
        findsOneWidget,
      );
      stream.add(status(patch: {'documentRevision': 11}));
      await tester.pumpAndSettle();
      expect(
        find.text(AppLocalizations.current.policyBudgetReached),
        findsNothing,
      );
      await finish(tester);
      unawaited(stream.close());
      await tester.pumpAndSettle();
    },
  );
}
