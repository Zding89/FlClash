import 'package:fl_clash/common/common.dart';
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
import 'package:fl_clash/views/policy/editors.dart';
import 'package:fl_clash/views/policy/rule_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

const _document = LocalPolicyDocument(
  policiesEnabled: true,
  policies: [
    LocalPolicy(
      id: 'rule',
      label: 'Priority rule',
      targetId: 'profile:1',
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
    final source = targetId.split(':').last;
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
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        builder: (context, child) {
          globalState.measure = Measure.of(context, 1);
          return child!;
        },
        home: LocalPolicyWorkbenchView(initialTab: initialTab),
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

void main() {
  testWidgets(
    'disabling one rule retains definitions and rejecting approval prevents apply',
    (tester) async {
      tester.view.physicalSize = const Size(680, 580);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _Controller();
      final container = ProviderContainer(
        overrides: [
          workbenchControllerProvider.overrideWithValue(controller),
          localPoliciesProvider.overrideWith((_) => Stream.value(_document)),
          localPolicyStatusProvider.overrideWith(
            (_) => Stream.value({'state': 'core_disconnected'}),
          ),
          workbenchChangesProvider.overrideWith((_) => Stream.value([])),
          profilesProvider.overrideWithBuild((_, _) => []),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;
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
            builder: (context, child) {
              globalState.measure = Measure.of(context, 1);
              return child!;
            },
            home: const LocalPolicyWorkbenchView(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppLocalizations.current.policyRulesTab));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(Switch).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(controller.proposed?.policies.single.enabled, false);
      expect(controller.proposed?.policies.single.candidateNodeIds, [
        '1:a',
        '1:b',
      ]);
      expect(controller.applies, 0);
      await tester.tap(find.text(AppLocalizations.current.aiReject));
      await tester.pumpAndSettle();
      expect(controller.applies, 0);
      expect(
        find.text(AppLocalizations.current.policyRejectedStatus),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final size in [const Size(360, 740), const Size(944, 568)]) {
    testWidgets('single profile saves a rule without integration at $size', (
      tester,
    ) async {
      final controller = _Controller(const LocalPolicyDocument());
      final container = await _mountWorkbench(
        tester,
        controller: controller,
        profiles: [_profiles.last],
        size: size,
      );
      final strings = AppLocalizations.current;
      expect(find.byType(Tab), findsNWidgets(4));
      await _tap(tester, find.text(strings.policyAddRule));
      expect(find.byType(LocalPolicyEditor), findsOneWidget);
      expect(find.byType(PolicyIntegrationEditor), findsNothing);
      expect(controller.loadedTargets, ['profile:2']);
      await tester.enterText(
        find.byKey(const ValueKey('root-domainSuffix-values')),
        'example.com',
      );
      await _tap(tester, find.byKey(const ValueKey('policy-processing-null')));
      await _tap(tester, find.textContaining('Node A').last);
      await tester.ensureVisible(find.text(strings.save));
      await tester.tap(find.text(strings.save));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(controller.proposed?.policies.single.targetId, 'profile:2');
      expect(controller.proposed?.integrations, isEmpty);
      await tester.tap(find.text(strings.aiApprove));
      await tester.pumpAndSettle();
      expect(controller.applies, 1);
      expect(container.read(currentProfileIdProvider), 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no profiles disables new rules and node sets at $size', (
      tester,
    ) async {
      await _mountWorkbench(
        tester,
        controller: _Controller(const LocalPolicyDocument()),
        profiles: [],
        size: size,
      );
      final strings = AppLocalizations.current;
      final addRule = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, strings.policyAddRule),
      );
      expect(addRule.onPressed, isNull);
      expect(find.text(strings.policyNoProfilesHint), findsOneWidget);
      await _tap(tester, find.widgetWithText(Tab, strings.policyNodeSets));
      final addSet = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, strings.policyNodeSet),
      );
      expect(addSet.onPressed, isNull);
      expect(find.text(strings.policyNoProfilesHint), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('enabled integration is the initial rule target', (tester) async {
    final controller = _Controller(
      const LocalPolicyDocument(
        moduleEnabled: true,
        integrationEnabled: true,
        activeIntegrationId: 'saved',
        integrations: [
          SubscriptionIntegration(
            id: 'saved',
            label: 'Saved integration',
            sourceProfileIds: [1, 2],
          ),
        ],
      ),
    );
    final container = await _mountWorkbench(tester, controller: controller);
    await _tap(tester, find.text(AppLocalizations.current.policyAddRule));
    expect(controller.loadedTargets, ['integration:saved']);
    expect(container.read(currentProfileIdProvider), 2);
    expect(controller.selectedTargets, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'node group summary uses friendly regions and explicit unrestricted filters',
    (tester) async {
      final controller = _Controller(
        const LocalPolicyDocument(
          nodeSets: [
            PolicyNodeSet(
              id: 'filtered',
              label: 'Filtered',
              targetId: 'profile:2',
              sourceIds: ['1'],
              regions: ['JP', 'HK'],
              maxMultiplier: 1,
            ),
            PolicyNodeSet(
              id: 'unrestricted',
              label: 'Unrestricted',
              targetId: 'profile:2',
              sourceIds: ['1'],
            ),
          ],
        ),
      );
      await _mountWorkbench(tester, controller: controller, initialTab: 1);
      final strings = AppLocalizations.current;
      expect(find.text(strings.policyNodeSetTarget), findsOneWidget);
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
      expect(find.textContaining('—×'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'editing target and filtering keep the running profile unchanged',
    (tester) async {
      const document = LocalPolicyDocument(
        moduleEnabled: true,
        policiesEnabled: true,
        activeIntegrationId: 'saved',
        integrations: [
          SubscriptionIntegration(
            id: 'saved',
            label: 'Saved integration',
            sourceProfileIds: [1, 2],
          ),
        ],
        nodeSets: [
          PolicyNodeSet(
            id: 'first',
            label: 'First set',
            targetId: 'profile:1',
            sourceIds: ['1'],
          ),
          PolicyNodeSet(
            id: 'second',
            label: 'Second set',
            targetId: 'profile:2',
            sourceIds: ['2'],
          ),
        ],
      );
      final controller = _Controller(document);
      final container = await _mountWorkbench(tester, controller: controller);
      final strings = AppLocalizations.current;
      await _tap(tester, find.text(strings.policyAddRule));
      expect(controller.loadedTargets, ['profile:2']);
      final editor = tester.widget<LocalPolicyEditor>(
        find.byType(LocalPolicyEditor),
      );
      expect(editor.targets.keys, [
        'profile:2',
        'profile:1',
        'integration:saved',
      ]);
      await _tap(
        tester,
        find.widgetWithText(DropdownButtonFormField<String>, 'Source 2').last,
      );
      await _tap(tester, find.text('Source 1').last);
      expect(controller.loadedTargets.last, 'profile:1');
      expect(container.read(currentProfileIdProvider), 2);
      await _tap(tester, find.text(strings.cancel));
      await _tap(tester, find.text(strings.policyDiscardChanges));
      await _tap(
        tester,
        find.widgetWithText(DropdownButtonFormField<String>, 'Source 2').first,
      );
      await _tap(tester, find.text('Source 1').last);
      await _tap(tester, find.widgetWithText(Tab, strings.policyNodeSets));
      expect(find.text('First set'), findsOneWidget);
      expect(find.text('Second set'), findsNothing);
      expect(container.read(currentProfileIdProvider), 2);
      expect(controller.proposed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'advanced keeps integrations and budgets accessible and read only',
    (tester) async {
      const document = LocalPolicyDocument(
        activeIntegrationId: 'saved',
        integrations: [
          SubscriptionIntegration(
            id: 'saved',
            label: 'Saved integration',
            sourceProfileIds: [1, 2],
          ),
        ],
        budgets: [SourceBudget(sourceId: '1', limitBytes: 1073741824)],
      );
      final controller = _Controller(document);
      await _mountWorkbench(tester, controller: controller);
      final strings = AppLocalizations.current;
      await _tap(tester, find.widgetWithText(Tab, strings.policyAdvancedTab));
      expect(find.text(strings.policyAddIntegration), findsNothing);
      expect(find.text(strings.policyAddBudget), findsNothing);
      await _tap(tester, find.text(strings.policyIntegrationTab));
      expect(find.text(strings.policyAddIntegration), findsOneWidget);
      expect(find.text('Saved integration'), findsWidgets);
      await _tap(tester, find.text(strings.policyIntegrationTab));
      await _tap(tester, find.text(strings.policyBudgetTab));
      expect(find.text(strings.policyAddBudget), findsOneWidget);
      expect(controller.proposed, isNull);
      expect(controller.applies, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'advanced explicitly selects an integration or original profile',
    (tester) async {
      final controller = _Controller(
        const LocalPolicyDocument(
          moduleEnabled: true,
          activeIntegrationId: 'saved',
          integrations: [
            SubscriptionIntegration(
              id: 'saved',
              label: 'Saved integration',
              sourceProfileIds: [1, 2],
            ),
          ],
        ),
      );
      await _mountWorkbench(tester, controller: controller);
      final strings = AppLocalizations.current;
      await _tap(tester, find.widgetWithText(Tab, strings.policyAdvancedTab));
      await _tap(tester, find.text(strings.policyIntegrationTab));
      await _tap(
        tester,
        find.byKey(const ValueKey('policy-use-integration:saved')),
      );
      expect(controller.selectedTargets.single['integrationId'], 'saved');
      await _tap(tester, find.byKey(const ValueKey('policy-use-profile:1')));
      expect(controller.selectedTargets.last['profileId'], 1);
      expect(controller.selectedTargets.length, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('legacy history deep link selects history', (tester) async {
    await _mountWorkbench(
      tester,
      controller: _Controller(const LocalPolicyDocument()),
      initialTab: 4,
    );
    final element = tester.element(find.byType(TabBar));
    expect(DefaultTabController.of(element).index, 3);
    expect(
      find.text(AppLocalizations.current.policyEmptyHistory),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
