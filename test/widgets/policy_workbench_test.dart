import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/views/profiles/profiles.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/profile.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/policy/policy.dart';
import 'package:fl_clash/views/policy/selection_fields.dart';
import 'package:fl_clash/views/policy/rule_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

const _document = LocalPolicyDocument(
  schemaVersion: 4,
  activeIntegrationId: localPolicyProfileId,
  integrations: [
    SubscriptionIntegration(
      id: localPolicyProfileId,
      label: 'Local',
      sourceProfileIds: [1, 2],
    ),
  ],
  policiesEnabled: true,
  policies: [
    LocalPolicy(
      id: 'rule',
      label: 'Priority rule',
      targetId: localPolicyTargetId,
      candidateNodeIds: ['1:a', '1:b'],
    ),
  ],
);

class _Database extends Mock implements WorkbenchDatabase {
  @override
  Stream<Map<String, Object?>?> watchSection(String section) =>
      Stream.value(null);
}

class _Controller extends Mock implements WorkbenchController {
  _Controller([this.document = _document]);
  final LocalPolicyDocument document;
  final loadedTargets = <String>[];
  final selectedTargets = <Map<String, Object?>>[];
  LocalPolicyDocument? proposed;
  int applies = 0;
  @override
  Future<LocalPolicyDocument> readPolicies() async => document;
  @override
  Future<List<LocalNode>> loadNodes(
    String targetId, {
    bool refresh = false,
    LocalPolicyDocument? document,
  }) async {
    loadedTargets.add(targetId);
    const source = '1';
    return [
      LocalNode(
        id: '$source:a',
        sourceId: source,
        label: 'Node A',
        sourceLabel: 'Source $source',
        protocol: 'ss',
        raw: {},
      ),
    ];
  }

  @override
  Future<Map<String, Object?>> selectPolicyTarget({
    int? profileId,
    String? integrationId,
    bool? moduleEnabled,
    required ConfigurationApproval approve,
  }) async {
    selectedTargets.add({
      'profileId': profileId,
      'integrationId': integrationId,
      'moduleEnabled': moduleEnabled,
    });
    return {'status': 'applied'};
  }

  @override
  Future<ConfigurationProposal> proposePolicies(
    LocalPolicyDocument value,
  ) async {
    proposed = value;
    return const ConfigurationProposal(
      id: 'proposal',
      summary: 'Change local policies',
      highRisk: true,
      expiresAt: 9999999999999,
      differences: [
        ConfigurationDifference(
          path: 'policiesEnabled',
          before: true,
          after: false,
        ),
      ],
      validation: {},
    );
  }

  @override
  Future<Map<String, Object?>> commit(
    ConfigurationProposal proposal, {
    required ConfigurationApproval approve,
    bool Function()? isCurrent,
  }) async {
    if (!await approve(proposal) || isCurrent?.call() == false) {
      return {'status': 'rejected'};
    }
    applies++;
    return {'status': 'applied'};
  }
}

const _profiles = [
  Profile(id: 1, label: 'Source 1', autoUpdateDuration: Duration.zero),
  Profile(id: 2, label: 'Source 2', autoUpdateDuration: Duration.zero),
];

Future<ProviderContainer> _mountWorkbench(
  WidgetTester tester, {
  required _Controller controller,
  List<Profile> profiles = _profiles,
  int initialTab = 0,
  Size size = const Size(944, 568),
  GlobalKey? capture,
  Widget? home,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      workbenchControllerProvider.overrideWithValue(controller),
      workbenchDatabaseProvider.overrideWithValue(_Database()),
      localPoliciesProvider.overrideWith(
        (_) => Stream.value(controller.document),
      ),
      localPolicyStatusProvider.overrideWith(
        (_) => Stream.value({'state': 'core_disconnected'}),
      ),
      localBudgetHistoryProvider.overrideWith((_) => Stream.value({})),
      workbenchChangesProvider.overrideWith((_) => Stream.value([])),
      profilesProvider.overrideWithBuild((_, _) => profiles),
      currentProfileIdProvider.overrideWithBuild((_, _) => 2),
    ],
  );
  addTearDown(container.dispose);
  globalState.container = container;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: capture == null ? null : ThemeData(fontFamily: 'StandaloneFont'),
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
        home: RepaintBoundary(
          key: capture,
          child: home ?? LocalPolicyWorkbenchView(initialTab: initialTab),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('GENERATE_STANDALONE_SCREENSHOTS')) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '/private/tmp/flclash-standalone-$name.png',
      ).writeAsBytes(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  setUpAll(() async {
    if (!const bool.fromEnvironment('GENERATE_STANDALONE_SCREENSHOTS')) return;
    final file = File('/System/Library/Fonts/Supplemental/Arial Unicode.ttf');
    final data = file.existsSync()
        ? ByteData.sublistView(await file.readAsBytes())
        : await rootBundle.load('assets/fonts/JetBrainsMono-Regular.ttf');
    await (FontLoader('StandaloneFont')..addFont(Future.value(data))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final width in [390.0, 1200.0]) {
    testWidgets(
      'standalone profile card retains the original layout at width $width',
      (tester) async {
        final key = GlobalKey();
        await _mountWorkbench(
          tester,
          controller: _Controller(),
          size: Size(width, 900),
          capture: key,
          home: const ProfilesView(),
        );
        expect(find.byKey(const ValueKey('profiles-local')), findsOneWidget);
        expect(find.byType(SwitchListTile), findsNothing);
        expect(tester.takeException(), isNull);
        await _capture(tester, key, 'profiles-$width');
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 1));
      },
    );
    testWidgets('standalone rules and sources fit width $width', (
      tester,
    ) async {
      final key = GlobalKey();
      await _mountWorkbench(
        tester,
        controller: _Controller(),
        size: Size(width, 900),
        capture: key,
      );
      expect(find.text(AppLocalizations.current.policyTarget), findsNothing);
      expect(
        find.text(AppLocalizations.current.policyLocalDefaultReject),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await _capture(tester, key, 'rules-$width');
      await _tap(
        tester,
        find.widgetWithText(Tab, AppLocalizations.current.policyAdvancedTab),
      );
      expect(find.byType(PolicyMultiSelect), findsOneWidget);
      expect(
        find.text(AppLocalizations.current.policyAddIntegration),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await _capture(tester, key, 'sources-$width');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    });
  }
  for (final size in [const Size(360, 740), const Size(944, 568)]) {
    testWidgets(
      'empty local configuration saves direct rules without sources at $size',
      (tester) async {
        final controller = _Controller(
          const LocalPolicyDocument().asStandalone(),
        );
        final container = await _mountWorkbench(
          tester,
          controller: controller,
          profiles: [],
          size: size,
        );
        final strings = AppLocalizations.current;
        expect(find.byType(Tab), findsNWidgets(4));
        expect(find.text(strings.policyTarget), findsNothing);
        expect(find.text(strings.policyLocalDefaultReject), findsOneWidget);
        await _tap(tester, find.text(strings.policyAddRule));
        expect(find.byType(LocalPolicyEditor), findsOneWidget);
        expect(find.text(strings.policyTarget), findsNothing);
        expect(controller.loadedTargets, [localPolicyTargetId]);
        await tester.enterText(
          find.byKey(const ValueKey('root-domainSuffix-values')),
          'example.com',
        );
        await _tap(tester, find.text(strings.policyActionDirect).first);
        await tester.ensureVisible(find.text(strings.save));
        await tester.tap(find.text(strings.save));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          controller.proposed!.policies.single.targetId,
          localPolicyTargetId,
        );
        expect(
          controller.proposed!.policies.single.action,
          PolicyAction.direct,
        );
        expect(controller.proposed!.localProfile.sourceProfileIds, isEmpty);
        await tester.tap(find.text(strings.aiApprove));
        await tester.pumpAndSettle();
        expect(controller.applies, 1);
        expect(container.read(currentProfileIdProvider), 2);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 1));
      },
    );
  }
  testWidgets(
    'disabling a local rule retains choices and rejecting approval prevents apply',
    (tester) async {
      final controller = _Controller();
      await _mountWorkbench(tester, controller: controller);
      await tester.ensureVisible(find.byType(Switch).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(controller.proposed!.policies.single.enabled, false);
      expect(controller.proposed!.policies.single.candidateNodeIds, [
        '1:a',
        '1:b',
      ]);
      await tester.tap(find.text(AppLocalizations.current.aiReject));
      await tester.pumpAndSettle();
      expect(controller.applies, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
  testWidgets(
    'local group list has no target binding and uses friendly filter summaries',
    (tester) async {
      final document = LocalPolicyDocument.fromJson({
        ..._document.toJson(),
        'nodeSets': [
          const PolicyNodeSet(
            id: 'filtered',
            label: 'Filtered',
            targetId: localPolicyTargetId,
            sourceIds: ['1'],
            regions: ['JP', 'HK'],
            maxMultiplier: 1,
          ).toJson(),
          const PolicyNodeSet(
            id: 'unrestricted',
            label: 'Unrestricted',
            targetId: localPolicyTargetId,
            sourceIds: ['1'],
          ).toJson(),
        ],
      });
      await _mountWorkbench(
        tester,
        controller: _Controller(document),
        initialTab: 1,
      );
      final strings = AppLocalizations.current;
      expect(find.text(strings.policyNodeSetTarget), findsNothing);
      expect(
        find.textContaining(
          '${strings.policyRegionJP} · ${strings.policyRegionHK}',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          '${strings.policyAnyRegion} · ${strings.policyAnyMultiplier}',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
  testWidgets(
    'source selection updates only the local integration and keeps legacy records and rules',
    (tester) async {
      final document = LocalPolicyDocument.fromJson({
        ..._document.toJson(),
        'nodeSets': [
          const PolicyNodeSet(
            id: 'preserved-group',
            label: 'Preserved group',
            targetId: localPolicyTargetId,
            sourceIds: ['1'],
          ).toJson(),
        ],
        'integrations': [
          const SubscriptionIntegration(
            id: localPolicyProfileId,
            label: 'Local',
            sourceProfileIds: [1],
            nameFilter: 'preserved',
            excludedNodeIds: ['1:excluded'],
          ).toJson(),
          const SubscriptionIntegration(
            id: 'legacy',
            label: 'Legacy preserved',
            sourceProfileIds: [2],
          ).toJson(),
        ],
      });
      final controller = _Controller(document);
      final container = await _mountWorkbench(
        tester,
        controller: controller,
        initialTab: 2,
      );
      final strings = AppLocalizations.current;
      expect(find.text(strings.policyAddIntegration), findsNothing);
      expect(find.text(strings.policyAddBudget), findsNothing);
      final select = find.widgetWithText(
        PolicyMultiSelect,
        strings.policySubscriptionSources,
      );
      await _tap(tester, select);
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Source 2'));
      await tester.tap(find.text(strings.confirm));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(controller.proposed!.localProfile.sourceProfileIds, [1, 2]);
      expect(controller.proposed!.localProfile.nameFilter, 'preserved');
      expect(controller.proposed!.localProfile.excludedNodeIds, ['1:excluded']);
      expect(controller.proposed!.integrations.last.id, 'legacy');
      expect(
        controller.proposed!.nodeSets.single.toJson(),
        document.nodeSets.single.toJson(),
      );
      expect(
        controller.proposed!.policies.single.toJson(),
        document.policies.single.toJson(),
      );
      expect(container.read(currentProfileIdProvider), 2);
      expect(controller.selectedTargets, isEmpty);
      await tester.tap(find.text(strings.aiReject));
      await tester.pumpAndSettle();
      expect(controller.applies, 0);
      await _tap(tester, find.text(strings.policyBudgetTab));
      expect(find.text(strings.policyAddBudget), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
  testWidgets(
    'source capacity errors keep the current configuration unchanged',
    (tester) async {
      final controller = _Controller();
      await _mountWorkbench(tester, controller: controller, initialTab: 2);
      tester
          .widget<PolicyMultiSelect>(find.byType(PolicyMultiSelect))
          .onChanged(List.generate(21, (index) => '${index + 1}'));
      await tester.pumpAndSettle();
      expect(
        find.text(AppLocalizations.current.policyLocalSourceLimit),
        findsOneWidget,
      );
      expect(controller.proposed, isNull);
      expect(tester.takeException(), isNull);
      final callback = tester
          .widget<PolicyMultiSelect>(find.byType(PolicyMultiSelect))
          .onChanged;
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
      callback(['1']);
      expect(tester.takeException(), isNull);
      expect(controller.proposed, isNull);
    },
  );

  testWidgets(
    'legacy rules are paused with a static review notice and do not select a profile',
    (tester) async {
      final controller = _Controller(
        const LocalPolicyDocument(
          policiesEnabled: true,
          policies: [
            LocalPolicy(
              id: 'legacy',
              label: 'Legacy rule',
              targetId: 'profile:1',
              candidateNodeIds: ['1:a'],
            ),
          ],
        ),
      );
      await _mountWorkbench(tester, controller: controller);
      final strings = AppLocalizations.current;
      expect(find.text(strings.policyLocalMigrationReview), findsOneWidget);
      expect(find.text('Legacy rule'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch).last).value, false);
      expect(controller.proposed, isNull);
      expect(controller.selectedTargets, isEmpty);
      expect(find.text(strings.policyTarget), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
  testWidgets('history remains available as the fourth tab', (tester) async {
    await _mountWorkbench(tester, controller: _Controller(), initialTab: 4);
    expect(
      find.text(AppLocalizations.current.policyEmptyHistory),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
