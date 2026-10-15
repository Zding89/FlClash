import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/views/profiles/profiles.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/views/ai/approval.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/profile.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/policy/policy.dart';
import 'package:fl_clash/views/policy/node_set_editor.dart';
import 'package:fl_clash/views/policy/selection_fields.dart';
import 'package:fl_clash/views/policy/rule_editor.dart';
import 'package:fl_clash/views/policy/source_picker.dart';
import 'package:fl_clash/views/policy/quota_overview.dart';
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
  LocalPolicyDocument document;
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
          path: 'policies.policiesEnabled',
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
    document = proposed ?? document;
    return {'status': 'applied'};
  }
}

class _ScriptApprovalController extends _Controller {
  @override
  Future<ConfigurationProposal> proposePolicies(
    LocalPolicyDocument value,
  ) async {
    final proposal = await super.proposePolicies(value);
    return ConfigurationProposal(
      id: proposal.id,
      summary: proposal.summary,
      highRisk: proposal.highRisk,
      expiresAt: proposal.expiresAt,
      differences: proposal.differences,
      validation: const {'executionOnly': true},
    );
  }
}

class _PageController extends _Controller {
  _PageController(this.updates);
  final StreamController<LocalPolicyDocument> updates;
  bool failCommit = false;

  @override
  Future<Map<String, Object?>> commit(
    ConfigurationProposal proposal, {
    required ConfigurationApproval approve,
    bool Function()? isCurrent,
  }) async {
    if (failCommit) {
      throw const ConfigurationChangeException(
        'configuration_version_conflict',
      );
    }
    final result = await super.commit(
      proposal,
      approve: approve,
      isCurrent: isCurrent,
    );
    if (result['status'] == 'applied') updates.add(document);
    return result;
  }
}

class _FailingProposalController extends _Controller {
  @override
  Future<ConfigurationProposal> proposePolicies(
    LocalPolicyDocument value,
  ) async => throw const ConfigurationChangeException(
    'configuration_version_conflict',
  );
}

class _DelayedCommitController extends _Controller {
  final approved = Completer<void>();
  final release = Completer<void>();

  @override
  Future<Map<String, Object?>> commit(
    ConfigurationProposal proposal, {
    required ConfigurationApproval approve,
    bool Function()? isCurrent,
  }) async {
    if (!await approve(proposal)) return {'status': 'rejected'};
    approved.complete();
    await release.future;
    if (isCurrent?.call() == false) return {'status': 'rejected'};
    applies++;
    document = proposed ?? document;
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
  Stream<LocalPolicyDocument>? documents,
  double textScale = 1,
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
        (_) => documents ?? Stream.value(controller.document),
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
        locale: capture == null ? null : const Locale('zh', 'CN'),
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
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          );
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
  for (final textScale in [1.0, 1.4]) {
    testWidgets(
      'content editor keeps two columns with a sidebar and 864px content at scale $textScale',
      (tester) async {
        await _mountWorkbench(
          tester,
          controller: _Controller(),
          size: const Size(944, 700),
          textScale: textScale,
          home: const Scaffold(
            body: Row(
              children: [
                SizedBox(width: 80, child: Text('Outer navigation')),
                Expanded(child: LocalPolicyWorkbenchView(initialTab: 1)),
              ],
            ),
          ),
        );
        final strings = AppLocalizations.current;
        await _tap(
          tester,
          find.widgetWithText(FilledButton, strings.policyNodeSet),
        );
        final editor = find.byType(PolicyNodeSetEditor);
        expect(tester.getSize(editor).width, 864);
        expect(
          find.byKey(const ValueKey('node-set-mobile-view')),
          findsNothing,
        );
        final settings = find.byKey(const ValueKey('node-set-settings-scroll'));
        final members = find.byKey(const ValueKey('node-members-scroll'));
        expect(tester.getSize(settings).width, closeTo(280 * textScale, .01));
        expect(
          tester.getRect(settings).right,
          lessThanOrEqualTo(tester.getRect(members).left),
        );
        final search = find.byKey(const ValueKey('node-members-search'));
        await tester.ensureVisible(search);
        await tester.enterText(search, 'Node A');
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(DataTable),
            matching: find.text('Node A'),
          ),
          findsOneWidget,
        );
        expect(
          find
              .byKey(const ValueKey('node-members-source-filter'))
              .hitTestable(),
          findsOneWidget,
        );
        expect(
          find
              .widgetWithText(FilledButton, strings.policyCheckSave)
              .hitTestable(),
          findsOneWidget,
        );
        expect(find.byTooltip(strings.cancel).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 1));
      },
    );
  }

  for (final width in [390.0, 1200.0]) {
    testWidgets(
      'content pages keep outer navigation and rule inputs across node group editing at $width',
      (tester) async {
        final updates = StreamController<LocalPolicyDocument>();
        addTearDown(updates.close);
        final controller = _PageController(updates)..failCommit = true;
        updates.add(controller.document);
        var navigationTaps = 0;
        final navigation = TextButton(
          onPressed: () => navigationTaps++,
          child: const Text('Outer navigation'),
        );
        await _mountWorkbench(
          tester,
          controller: controller,
          documents: updates.stream,
          size: Size(width, 800),
          home: Scaffold(
            body: width >= 900
                ? Row(
                    children: [
                      SizedBox(width: 160, child: navigation),
                      const Expanded(child: LocalPolicyWorkbenchView()),
                    ],
                  )
                : Column(
                    children: [
                      const Expanded(child: LocalPolicyWorkbenchView()),
                      SizedBox(height: 48, child: navigation),
                    ],
                  ),
          ),
        );
        final outer = tester.state<NavigatorState>(
          find.byType(Navigator).first,
        );
        final strings = AppLocalizations.current;
        await _tap(tester, find.byTooltip(strings.edit));
        expect(find.byType(LocalPolicyEditor), findsOneWidget);
        expect(find.byType(Dialog), findsNothing);
        expect(outer.canPop(), isFalse);
        final editorState = tester.state(find.byType(LocalPolicyEditor));
        final name = find.descendant(
          of: find.byKey(const ValueKey('policy-rule-name')),
          matching: find.byType(TextFormField),
        );
        await tester.enterText(name, 'Preserved rule input');
        await _tap(tester, find.byKey(const ValueKey('policy-add-node-set')));
        expect(find.byType(PolicyNodeSetEditor), findsOneWidget);
        expect(find.byType(Dialog), findsNothing);
        expect(outer.canPop(), isFalse);
        expect(find.text('Outer navigation').hitTestable(), findsOneWidget);
        final groupName = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == strings.name,
        );
        await tester.enterText(groupName, 'Draft group');
        await _tap(tester, find.text(strings.policyCheckSave));
        expect(find.byType(PolicyNodeSetEditor), findsNothing);
        expect(tester.state(find.byType(LocalPolicyEditor)), same(editorState));
        expect(
          tester.widget<TextFormField>(name).controller!.text,
          'Preserved rule input',
        );
        expect(find.text('Draft group'), findsWidgets);
        await _tap(tester, find.byKey(const ValueKey('policy-edit-node-set')));
        await tester.enterText(groupName, 'Updated draft group');
        await _tap(tester, find.text(strings.policyCheckSave));
        expect(tester.state(find.byType(LocalPolicyEditor)), same(editorState));
        expect(
          tester.widget<TextFormField>(name).controller!.text,
          'Preserved rule input',
        );
        expect(find.text('Updated draft group'), findsWidgets);
        await _tap(tester, find.widgetWithText(FilledButton, strings.save));
        expect(find.byType(LocalPolicyEditor), findsOneWidget);
        expect(find.text(strings.policyOperationFailed), findsOneWidget);
        expect(
          tester.widget<TextFormField>(name).controller!.text,
          'Preserved rule input',
        );
        expect(controller.applies, 0);
        await _tap(tester, find.text('Outer navigation'));
        expect(navigationTaps, 1);
        controller.failCommit = false;
        await tester.tap(find.widgetWithText(FilledButton, strings.save));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(AiConfigurationApprovalDialog), findsNothing);
        await tester.pumpAndSettle();
        expect(find.byType(LocalPolicyEditor), findsNothing);
        expect(find.text('Preserved rule input'), findsOneWidget);
        expect(
          controller.document.nodeSets.single.label,
          'Updated draft group',
        );
        expect(
          controller.document.policies.single.choices.single.id,
          controller.document.nodeSets.single.id,
        );
        expect(controller.applies, 1);
        expect(outer.canPop(), isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 1));
      },
    );
  }

  testWidgets(
    'content editor protects dirty exit and keeps root tab and provider updates',
    (tester) async {
      final updates = StreamController<LocalPolicyDocument>();
      addTearDown(updates.close);
      final controller = _PageController(updates);
      updates.add(controller.document);
      await _mountWorkbench(
        tester,
        controller: controller,
        documents: updates.stream,
        initialTab: 1,
        size: const Size(1200, 850),
      );
      final strings = AppLocalizations.current;
      final tabState = DefaultTabController.of(
        tester.element(find.byType(TabBar)),
      );
      await _tap(
        tester,
        find.widgetWithText(FilledButton, strings.policyNodeSet),
      );
      expect(find.byType(PolicyNodeSetEditor), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      final name = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == strings.name,
      );
      await tester.enterText(name, 'Unsaved group');
      final changed = LocalPolicyDocument.fromJson({
        ...controller.document.toJson(),
        'nodeSets': [
          const PolicyNodeSet(
            id: 'external-group',
            label: 'Provider update while editing',
            targetId: localPolicyTargetId,
            sourceIds: ['1'],
          ).toJson(),
        ],
      });
      controller.document = changed;
      updates.add(changed);
      await tester.pumpAndSettle();
      final outer = tester.state<NavigatorState>(find.byType(Navigator).first);
      await outer.maybePop();
      await tester.pumpAndSettle();
      expect(find.text(strings.policyUnsavedTitle), findsOneWidget);
      await _tap(tester, find.text(strings.policyContinueEditing));
      expect(tester.widget<TextField>(name).controller!.text, 'Unsaved group');
      await _tap(tester, find.byTooltip(strings.cancel));
      await _tap(tester, find.text(strings.policyDiscardChanges));
      expect(find.byType(PolicyNodeSetEditor), findsNothing);
      expect(
        DefaultTabController.of(tester.element(find.byType(TabBar))),
        same(tabState),
      );
      expect(tabState.index, 1);
      expect(find.text('Provider update while editing'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

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
    testWidgets(
      'local workbench navigation keeps rules as the primary page at width $width',
      (tester) async {
        final key = GlobalKey();
        final controller = _Controller();
        await _mountWorkbench(
          tester,
          controller: controller,
          size: Size(width, 900),
          capture: key,
        );
        final strings = AppLocalizations.current;
        expect(
          tester.widgetList<Tab>(find.byType(Tab)).map((tab) => tab.text),
          [
            strings.policyRulesTab,
            strings.policyNodeSets,
            strings.policyQuotaOverview,
            strings.policyAdvancedTab,
            strings.policyHistoryTab,
          ],
        );
        expect(find.text(strings.policyLocalChoose), findsOneWidget);
        expect(find.text(strings.policyAddRule), findsOneWidget);
        expect(find.text(strings.policyTarget), findsNothing);
        expect(
          find.byType(DropdownButtonFormField<SourceUpdateRoute>),
          findsNothing,
        );
        expect(find.byIcon(Icons.data_object), findsNothing);
        expect(tester.takeException(), isNull);
        await _capture(tester, key, 'rules-$width');
        await _tap(tester, find.text(strings.policySubscriptionSources));
        expect(find.byType(PolicySourcePicker), findsOneWidget);
        await _tap(tester, find.text(strings.cancel));
        expect(find.byType(PolicySourcePicker), findsNothing);
        await _tap(tester, find.widgetWithText(Tab, strings.policyNodeSets));
        expect(find.text(strings.policyNodeSetHint), findsOneWidget);
        await _capture(tester, key, 'groups-$width');
        await _tap(
          tester,
          find.widgetWithText(Tab, strings.policyQuotaOverview),
        );
        expect(find.byType(LocalQuotaOverview), findsOneWidget);
        await _capture(tester, key, 'quota-$width');
        await _tap(tester, find.widgetWithText(Tab, strings.policyAdvancedTab));
        expect(find.text(strings.policyLocalAdvancedHint), findsOneWidget);
        expect(find.byType(PolicyMultiSelect), findsNothing);
        expect(find.text(strings.policyAddIntegration), findsNothing);
        expect(find.byIcon(Icons.data_object), findsOneWidget);
        await _capture(tester, key, 'advanced-$width');
        expect(controller.proposed, isNull);
        expect(controller.selectedTargets, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 1));
      },
    );
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
        expect(find.byType(Tab), findsNWidgets(5));
        expect(find.text(strings.policyTarget), findsNothing);
        expect(
          find.byTooltip(strings.policyLocalDefaultReject),
          findsOneWidget,
        );
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
        expect(find.byType(AiConfigurationApprovalDialog), findsNothing);
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
    'script execution still requires confirmation and rejection prevents apply',
    (tester) async {
      final controller = _ScriptApprovalController();
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
  testWidgets('manual rule toggle applies once without a duplicate dialog', (
    tester,
  ) async {
    final controller = _Controller();
    await _mountWorkbench(tester, controller: controller);
    await tester.ensureVisible(find.byType(Switch).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    expect(find.byType(AiConfigurationApprovalDialog), findsNothing);
    expect(controller.applies, 1);
    expect(controller.document.policies.single.enabled, isFalse);
    expect(controller.document.policies.single.candidateNodeIds, [
      '1:a',
      '1:b',
    ]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });
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
      final container = await _mountWorkbench(tester, controller: controller);
      final strings = AppLocalizations.current;
      expect(find.text(strings.policyAddIntegration), findsNothing);
      expect(find.text(strings.policyAddBudget), findsNothing);
      await _tap(tester, find.text(strings.policySubscriptionSources));
      expect(find.byType(PolicySourcePicker), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('policy-source-2')));
      await _tap(tester, find.text(strings.cancel));
      expect(controller.applies, 0);
      expect(controller.proposed, isNull);
      await _tap(tester, find.text(strings.policySubscriptionSources));
      await _tap(tester, find.byKey(const ValueKey('policy-source-2')));
      await tester.tap(find.text(strings.save));
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
      await tester.pumpAndSettle();
      expect(find.byType(AiConfigurationApprovalDialog), findsNothing);
      expect(controller.applies, 1);
      expect(find.byType(PolicySourcePicker), findsNothing);
      expect(find.text(strings.policyRejectedStatus), findsNothing);
      expect(find.text(strings.policyOperationFailed), findsNothing);
      expect(controller.document.localProfile.sourceProfileIds, [1, 2]);
      await _tap(tester, find.widgetWithText(Tab, strings.policyAdvancedTab));
      await _tap(tester, find.text(strings.policyBudgetTab));
      expect(find.text(strings.policyAddBudget), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('source save keeps real failure feedback and selected inputs', (
    tester,
  ) async {
    final controller = _FailingProposalController();
    await _mountWorkbench(tester, controller: controller);
    final strings = AppLocalizations.current;
    await _tap(tester, find.text(strings.policySubscriptionSources));
    await _tap(tester, find.byKey(const ValueKey('policy-source-1')));
    await _tap(tester, find.widgetWithText(FilledButton, strings.save));
    expect(find.byType(PolicySourcePicker), findsOneWidget);
    expect(find.text(strings.policyOperationFailed), findsOneWidget);
    expect(find.text(strings.policyRejectedStatus), findsNothing);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('policy-source-1')),
          )
          .value,
      isFalse,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, strings.save))
          .onPressed,
      isNotNull,
    );
    expect(controller.applies, 0);
    expect(controller.document.localProfile.sourceProfileIds, [1, 2]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'editing a rule after approved source management keeps the latest base document',
    (tester) async {
      final controller = _Controller();
      await _mountWorkbench(tester, controller: controller);
      final strings = AppLocalizations.current;
      await _tap(tester, find.byTooltip(strings.edit));
      expect(find.byType(LocalPolicyEditor), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('policy-rule-name')),
          matching: find.byType(TextFormField),
        ),
        '保留并更新的规则',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('policy-manage-subscription-sources')),
      );
      await tester.pumpAndSettle();
      final manageSources = tester.widget<TextButton>(
        find.byKey(const ValueKey('policy-manage-subscription-sources')),
      );
      expect(manageSources.onPressed, isNotNull);
      manageSources.onPressed!();
      await tester.pumpAndSettle();
      expect(find.byType(PolicySourcePicker), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('policy-source-1')));
      await tester.tap(
        find.descendant(
          of: find.byType(PolicySourcePicker),
          matching: find.text(strings.save),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AiConfigurationApprovalDialog), findsNothing);
      await tester.pumpAndSettle();
      expect(controller.applies, 1);
      expect(controller.document.localProfile.sourceProfileIds, [2]);
      expect(find.byType(PolicySourcePicker), findsNothing);
      expect(find.text('保留并更新的规则'), findsOneWidget);

      final saveRule = find.widgetWithText(FilledButton, strings.save);
      await tester.ensureVisible(saveRule);
      await tester.tap(saveRule);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AiConfigurationApprovalDialog), findsNothing);
      await tester.pumpAndSettle();
      expect(controller.applies, 2);
      expect(controller.document.localProfile.sourceProfileIds, [2]);
      expect(controller.document.policies.single.label, '保留并更新的规则');
      expect(find.text(strings.policyOperationFailed), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'source save stops if the workbench is disposed after explicit save',
    (tester) async {
      final controller = _DelayedCommitController();
      await _mountWorkbench(tester, controller: controller);
      final strings = AppLocalizations.current;
      await _tap(tester, find.text(strings.policySubscriptionSources));
      await _tap(tester, find.byKey(const ValueKey('policy-source-1')));
      await tester.tap(find.text(strings.save));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AiConfigurationApprovalDialog), findsNothing);
      await tester.pump(const Duration(milliseconds: 400));
      expect(controller.approved.isCompleted, isTrue);
      await tester.pumpWidget(const SizedBox());
      controller.release.complete();
      await tester.pumpAndSettle();
      expect(controller.applies, 0);
      expect(controller.document.localProfile.sourceProfileIds, [1, 2]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'source capacity errors keep the current configuration unchanged',
    (tester) async {
      final controller = _Controller();
      final profiles = [
        for (var id = 1; id <= 21; id++)
          Profile(
            id: id,
            label: 'Source $id',
            autoUpdateDuration: Duration.zero,
          ),
      ];
      await _mountWorkbench(tester, controller: controller, profiles: profiles);
      await _tap(
        tester,
        find.text(AppLocalizations.current.policySubscriptionSources),
      );
      for (var id = 1; id <= 21; id++) {
        final checkbox = find.byKey(ValueKey('policy-source-$id'));
        final tile = tester.widget<CheckboxListTile>(checkbox);
        if (tile.value != true) await _tap(tester, checkbox);
      }
      await _tap(tester, find.text(AppLocalizations.current.save));
      await tester.pumpAndSettle();
      expect(
        find.text(AppLocalizations.current.policyLocalSourceLimit),
        findsOneWidget,
      );
      expect(controller.proposed, isNull);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('policy-source-21')),
            )
            .value,
        isTrue,
      );
      await _tap(tester, find.byKey(const ValueKey('policy-source-21')));
      await _tap(tester, find.text(AppLocalizations.current.cancel));
      expect(find.byType(PolicySourcePicker), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
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
  testWidgets(
    'empty source picker can be canceled without selecting a configuration',
    (tester) async {
      final controller = _Controller(
        const LocalPolicyDocument().asStandalone(),
      );
      final container = await _mountWorkbench(
        tester,
        controller: controller,
        profiles: [],
      );
      await _tap(
        tester,
        find.text(AppLocalizations.current.policySubscriptionSources),
      );
      expect(find.byType(PolicySourcePicker), findsOneWidget);
      expect(
        find.text(AppLocalizations.current.policyLocalNoSubscriptions),
        findsOneWidget,
      );
      await _tap(tester, find.text(AppLocalizations.current.cancel));
      expect(container.read(currentProfileIdProvider), 2);
      expect(controller.selectedTargets, isEmpty);
      expect(controller.proposed, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  testWidgets(
    'profiles shortcut returns through stacked routes without configuration writes',
    (tester) async {
      final controller = _Controller(
        const LocalPolicyDocument().asStandalone(),
      );
      final container = await _mountWorkbench(
        tester,
        controller: controller,
        profiles: [],
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Column(
              children: [
                Text('Root page: ${ref.watch(currentPageLabelProvider).name}'),
                TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (intermediateContext) => Scaffold(
                        body: Column(
                          children: [
                            const Text('Intermediate page'),
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(intermediateContext).push<void>(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const LocalPolicyWorkbenchView(),
                                    ),
                                  ),
                              child: const Text('Open workbench'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Open intermediate page'),
                ),
              ],
            ),
          ),
        ),
      );
      await _tap(tester, find.text('Open intermediate page'));
      await _tap(tester, find.text('Open workbench'));
      expect(find.byType(LocalPolicyWorkbenchView), findsOneWidget);
      await _tap(tester, find.text(AppLocalizations.current.policyLocalChoose));
      expect(find.text('Root page: profiles'), findsOneWidget);
      expect(find.text('Intermediate page', skipOffstage: false), findsNothing);
      expect(
        find.byType(LocalPolicyWorkbenchView, skipOffstage: false),
        findsNothing,
      );
      expect(
        Navigator.of(tester.element(find.text('Root page: profiles'))).canPop(),
        false,
      );
      expect(container.read(currentPageLabelProvider), PageLabel.profiles);
      expect(container.read(currentProfileIdProvider), 2);
      expect(controller.selectedTargets, isEmpty);
      expect(controller.proposed, isNull);
      expect(controller.applies, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  testWidgets(
    'selected local configuration shows its saved changes apply there',
    (tester) async {
      final controller = _Controller(
        LocalPolicyDocument.fromJson({
          ..._document.toJson(),
          'moduleEnabled': true,
          'integrationEnabled': true,
        }),
      );
      await _mountWorkbench(tester, controller: controller);
      expect(
        find.text(AppLocalizations.current.policyLocalSelected),
        findsOneWidget,
      );
      expect(
        find.text(AppLocalizations.current.policyLocalChoose),
        findsNothing,
      );
      expect(controller.selectedTargets, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  testWidgets('history remains available as the fifth tab', (tester) async {
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
