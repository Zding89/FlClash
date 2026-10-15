import 'dart:async';

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/views/policy/node_set_editor.dart';
import 'package:fl_clash/views/policy/rule_editor.dart';
import 'package:fl_clash/views/policy/schedule_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _mount(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1200, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  Finder ruleField(String name) => find.descendant(
    of: find.byKey(ValueKey('policy-rule-$name')),
    matching: find.byType(TextFormField),
  );

  Finder nodeSetFields() => find.descendant(
    of: find.byType(PolicyNodeSetEditor),
    matching: find.byType(TextFormField),
  );

  testWidgets('a rule can add a node group with no loaded nodes', (
    tester,
  ) async {
    LocalPolicy? savedRule;
    List<PolicyNodeSet>? savedSets;
    await _mount(
      tester,
      LocalPolicyEditor(
        sources: const {'42': '机场 A'},
        loadNodes: (_) async => [],
        onSave: (rule, sets, _) async {
          savedRule = rule;
          savedSets = sets;
        },
      ),
    );

    final add = find.byKey(const ValueKey('policy-add-node-set'));
    expect(tester.widget<TextButton>(add).onPressed, isNotNull);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.byType(PolicyNodeSetEditor), findsOneWidget);

    await tester.tap(find.text(AppLocalizations.current.policyCheckSave));
    await tester.pumpAndSettle();
    expect(find.byType(PolicyNodeSetEditor), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('root-domainSuffix-values')),
      'example.com',
    );
    await tester.tap(
      find.widgetWithText(FilledButton, AppLocalizations.current.save),
    );
    await tester.pumpAndSettle();

    expect(savedRule, isNotNull);
    expect(savedRule!.choices.single.type, PolicyChoiceType.nodeSet);
    expect(savedSets, hasLength(1));
    expect(savedSets!.single.id, savedRule!.choices.single.id);
    expect(savedSets!.single.sourceIds, ['42']);
  });

  testWidgets('editing the selected node group does not duplicate it', (
    tester,
  ) async {
    const set = PolicyNodeSet(
      id: 'shared',
      label: '共享组',
      targetId: localPolicyTargetId,
      sourceIds: ['42'],
    );
    const rule = LocalPolicy(
      id: 'rule',
      label: '规则',
      targetId: localPolicyTargetId,
      scope: PolicyMatch(
        type: PolicyMatchType.domainSuffix,
        values: ['example.com'],
      ),
      choices: [PolicyChoice(type: PolicyChoiceType.nodeSet, id: 'shared')],
    );
    List<PolicyNodeSet>? savedSets;
    await _mount(
      tester,
      LocalPolicyEditor(
        existing: rule,
        sources: const {'42': '机场 A'},
        nodeSets: const [set],
        loadNodes: (_) async => [],
        onSave: (_, sets, _) async => savedSets = sets,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('policy-edit-node-set')));
    await tester.pumpAndSettle();
    expect(find.byType(PolicyNodeSetEditor), findsOneWidget);
    await tester.tap(find.text(AppLocalizations.current.policyCheckSave));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, AppLocalizations.current.save),
    );
    await tester.pumpAndSettle();

    expect(savedSets, hasLength(1));
    expect(savedSets!.single.id, 'shared');
  });

  testWidgets('manual node attributes make canceling the rule prompt', (
    tester,
  ) async {
    const set = PolicyNodeSet(
      id: 'shared',
      label: '共享组',
      targetId: localPolicyTargetId,
      sourceIds: ['42'],
    );
    const rule = LocalPolicy(
      id: 'rule-attributes',
      label: '规则',
      targetId: localPolicyTargetId,
      scope: PolicyMatch(
        type: PolicyMatchType.domainSuffix,
        values: ['example.com'],
      ),
      choices: [PolicyChoice(type: PolicyChoiceType.nodeSet, id: 'shared')],
    );
    var saved = false;
    await _mount(
      tester,
      LocalPolicyEditor(
        existing: rule,
        sources: const {'42': '机场 A'},
        nodeSets: const [set],
        loadNodes: (_) async => [
          LocalNode(
            id: '42:node',
            sourceId: '42',
            sourceLabel: '机场 A',
            label: 'Node A',
            protocol: 'ss',
            raw: {},
          ),
        ],
        onSave: (_, _, _) async => saved = true,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('policy-edit-node-set')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Node A'));
    await tester.pumpAndSettle();
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.first, 'JP');
    final attributeDialog = find.byType(AlertDialog).last;
    await tester.tap(
      find.descendant(
        of: attributeDialog,
        matching: find.widgetWithText(
          FilledButton,
          AppLocalizations.current.save,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizations.current.policyCheckSave));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizations.current.cancel));
    await tester.pumpAndSettle();
    expect(
      find.text(AppLocalizations.current.policyUnsavedTitle),
      findsOneWidget,
    );
    expect(saved, isFalse);
    await tester.tap(find.text(AppLocalizations.current.policyDiscardChanges));
    await tester.pumpAndSettle();
    expect(find.byType(LocalPolicyEditor), findsNothing);
  });

  testWidgets('rule draft survives adding a node group', (tester) async {
    LocalPolicy? saved;
    List<PolicyNodeSet>? savedSets;
    await _mount(
      tester,
      LocalPolicyEditor(
        sources: const {'42': '机场 A'},
        loadNodes: (_) async => [],
        onSave: (rule, sets, _) async {
          saved = rule;
          savedSets = sets;
        },
      ),
    );
    await tester.enterText(ruleField('name'), '保留的规则名称');
    await tester.enterText(
      find.byKey(const ValueKey('root-domainSuffix-values')),
      'keep.example',
    );
    final scheduleChanged = tester
        .widget<PolicyScheduleEditor>(find.byType(PolicyScheduleEditor))
        .onChanged;
    scheduleChanged(
      const PolicySchedule(
        windows: [PolicyWindow(startMinute: 120, endMinute: 360)],
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('policy-add-node-set')));
    await tester.pumpAndSettle();
    await tester.enterText(nodeSetFields().first, '临时组');
    await tester.tap(find.text(AppLocalizations.current.policyCheckSave));
    await tester.pumpAndSettle();
    expect(find.text('保留的规则名称'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('root-domainSuffix-values')),
          )
          .initialValue,
      'keep.example',
    );

    await tester.tap(
      find.widgetWithText(FilledButton, AppLocalizations.current.save),
    );
    await tester.pumpAndSettle();
    expect(saved?.label, '保留的规则名称');
    expect(saved?.scope.values, ['keep.example']);
    expect(saved?.schedule.windows.single.startMinute, 120);
    expect(savedSets, hasLength(1));
    expect(savedSets!.single.label, '临时组');
  });

  testWidgets(
    'canceling a group and then the rule does not save either draft',
    (tester) async {
      LocalPolicy? saved;
      List<PolicyNodeSet>? savedSets;
      await _mount(
        tester,
        LocalPolicyEditor(
          sources: const {'42': '机场 A'},
          loadNodes: (_) async => [],
          onSave: (rule, sets, _) async {
            saved = rule;
            savedSets = sets;
          },
        ),
      );
      await tester.tap(find.byKey(const ValueKey('policy-add-node-set')));
      await tester.pumpAndSettle();
      await tester.enterText(nodeSetFields().first, '取消组');
      await tester.tap(
        find.descendant(
          of: find.byType(PolicyNodeSetEditor),
          matching: find.widgetWithText(
            TextButton,
            AppLocalizations.current.cancel,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(AppLocalizations.current.policyDiscardChanges),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PolicyNodeSetEditor), findsNothing);
      await tester.tap(
        find.descendant(
          of: find.byType(LocalPolicyEditor),
          matching: find.widgetWithText(
            TextButton,
            AppLocalizations.current.cancel,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(savedSets, isNull);
    },
  );

  testWidgets(
    'source refresh keeps node group draft and shared references visible',
    (tester) async {
      final sourceRefresh = Completer<Map<String, String>>();
      var nodeLoads = 0;
      await _mount(
        tester,
        PolicyNodeSetEditor(
          targetId: localPolicyTargetId,
          sources: const {'42': '旧机场'},
          nodes: const [],
          referencedRules: const ['规则 A', '规则 B'],
          onManageSources: () => sourceRefresh.future,
          loadNodes: () async {
            nodeLoads++;
            return const [];
          },
        ),
      );
      expect(
        find.textContaining(AppLocalizations.current.policySharedSetImpact),
        findsOneWidget,
      );
      await tester.enterText(nodeSetFields().first, '保留的组名');
      await tester.tap(
        find.byKey(const ValueKey('policy-node-set-manage-sources')),
      );
      await tester.pump();
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('policy-node-set-manage-sources')),
            )
            .onPressed,
        isNull,
      );
      sourceRefresh.complete(const {'99': '新机场'});
      await tester.pumpAndSettle();
      expect(nodeLoads, 1);
      expect(
        tester.widget<TextFormField>(nodeSetFields().first).controller!.text,
        '保留的组名',
      );
    },
  );

  testWidgets('source management failure and disposal leave no pending work', (
    tester,
  ) async {
    var fail = true;
    final pending = Completer<Map<String, String>>();
    await _mount(
      tester,
      LocalPolicyEditor(
        sources: const {'42': '机场 A'},
        loadNodes: (_) async => [],
        onManageSources: () async {
          if (fail) throw StateError('source failure');
          return pending.future;
        },
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey('policy-manage-subscription-sources')),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(AppLocalizations.current.policyOperationFailed),
      findsOneWidget,
    );
    fail = false;
    await tester.tap(
      find.byKey(const ValueKey('policy-manage-subscription-sources')),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    pending.complete(const {'99': '新机场'});
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
