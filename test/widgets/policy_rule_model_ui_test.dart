import 'dart:async';

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/policy/applications.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/views/policy/application_picker.dart';
import 'package:fl_clash/views/policy/rule_editor.dart';
import 'package:fl_clash/views/policy/node_set_editor.dart';
import 'package:fl_clash/views/policy/preference_editor.dart';
import 'package:fl_clash/views/policy/schedule_editor.dart';
import 'package:fl_clash/views/policy/selection_fields.dart';
import 'package:fl_clash/views/policy/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _Catalog extends PolicyApplicationCatalog {
  _Catalog(this.read);
  final Future<List<PolicyApplication>> Function() read;
  @override
  Future<List<PolicyApplication>> load() => read();
}

Future<void> mount(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1200, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
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
  await tester.pump();
}

void main() {
  testWidgets(
    'application selection has loading, bounded bundle selection and disposal safety',
    (tester) async {
      final loaded = Completer<List<PolicyApplication>>();
      var value = const PolicyMatch(type: PolicyMatchType.processPathRegex);
      await mount(
        tester,
        StatefulBuilder(
          builder: (context, update) => PolicyApplicationPicker(
            value: value,
            onChanged: (next) => update(() => value = next),
            catalog: _Catalog(() => loaded.future),
          ),
        ),
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      const app = PolicyApplication(
        path: '/Applications/Browser.app',
        label: 'Browser',
        executable: '/Applications/Browser.app/Contents/MacOS/Browser',
      );
      loaded.complete([app]);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      expect(value.type, PolicyMatchType.processPathRegex);
      expect(value.values, [app.processPathPattern]);
      expect(
        RegExp(
          value.values.single,
        ).hasMatch('/Applications/Browser.app/Contents/Helpers/Network'),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'application loading failure can refresh without losing selected values',
    (tester) async {
      var calls = 0;
      await mount(
        tester,
        PolicyApplicationPicker(
          value: const PolicyMatch(
            type: PolicyMatchType.processPathRegex,
            values: [r'^/Applications/Old\.app/Contents/.*$'],
          ),
          onChanged: (_) {},
          catalog: _Catalog(() async {
            if (calls++ == 0) throw StateError('read failed');
            return [];
          }),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(AppLocalizations.current.policyAppsFailed),
        findsOneWidget,
      );
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();
      expect(
        find.text(AppLocalizations.current.policyAppsFailed),
        findsNothing,
      );
      expect(find.byType(InputChip), findsOneWidget);
    },
  );
  testWidgets(
    'multi selection uses a dropdown dialog and preserves selection order',
    (tester) async {
      var value = <String>[];
      await mount(
        tester,
        StatefulBuilder(
          builder: (context, update) => PolicyMultiSelect(
            label: 'Providers',
            options: const {'a': 'Alpha', 'b': 'Beta'},
            value: value,
            onChanged: (next) => update(() => value = next),
          ),
        ),
      );
      await tester.tap(find.byType(InputDecorator));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beta'));
      await tester.tap(find.text('Alpha'));
      await tester.tap(find.text(AppLocalizations.current.confirm));
      await tester.pumpAndSettle();
      expect(value, ['b', 'a']);
      expect(find.byType(InputChip), findsNWidgets(2));
    },
  );
  testWidgets(
    'a direct rule saves without nodes and exposes no backup or fallback editor',
    (tester) async {
      LocalPolicy? result;
      await mount(
        tester,
        LocalPolicyEditor(
          existing: const LocalPolicy(
            id: 'direct',
            label: 'Direct CN',
            targetId: localPolicyTargetId,
            action: PolicyAction.direct,
            scope: PolicyMatch(
              type: PolicyMatchType.destinationRegion,
              values: ['CN'],
            ),
          ),
          targets: const {'profile:1': 'Profile'},
          loadNodes: (_) async => [],
          onSave: (rule, _, _) async => result = rule,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(AppLocalizations.current.policyAddBackup), findsNothing);
      expect(find.text(AppLocalizations.current.policyFallback), findsNothing);
      await tester.tap(
        find.widgetWithText(FilledButton, AppLocalizations.current.save),
      );
      await tester.pumpAndSettle();
      expect(result?.action, PolicyAction.direct);
      expect(result?.choices, isEmpty);
      expect(result?.scope.values, ['CN']);
    },
  );
  testWidgets(
    'editing a legacy multi-choice rule preserves its selections until replacement',
    (tester) async {
      LocalPolicy? result;
      await mount(
        tester,
        LocalPolicyEditor(
          existing: const LocalPolicy(
            id: 'legacy',
            label: 'Legacy',
            targetId: localPolicyTargetId,
            candidateNodeIds: ['one', 'two'],
            scope: PolicyMatch(
              type: PolicyMatchType.domainSuffix,
              values: ['example.com'],
            ),
          ),
          targets: const {'profile:1': 'Profile'},
          loadNodes: (_) async => [
            for (final id in ['one', 'two'])
              LocalNode(
                id: id,
                sourceId: '1',
                sourceLabel: 'Provider',
                label: id,
                protocol: 'ss',
                raw: const {},
              ),
          ],
          onSave: (rule, _, _) async => result = rule,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, AppLocalizations.current.save),
      );
      await tester.pumpAndSettle();
      expect(result?.candidateNodeIds, ['one', 'two']);
    },
  );
  for (final width in [1200.0, 390.0]) {
    testWidgets(
      'node group preferences, load balancing and overnight schedule save at $width',
      (tester) async {
        PolicyNodeSetEdit? saved;
        const original = PolicyNodeSet(
          id: 'group',
          label: 'Group',
          targetId: localPolicyTargetId,
          sourceIds: ['1', '2'],
          regions: ['JP'],
          preferences: [
            NodePreference(
              type: NodePreferenceType.expiry,
              direction: SortDirection.descending,
            ),
            NodePreference(
              type: NodePreferenceType.latency,
              direction: SortDirection.ascending,
            ),
          ],
          schedule: PolicySchedule(
            windows: [PolicyWindow(startMinute: 1380, endMinute: 60)],
          ),
        );
        await mount(
          tester,
          PolicyNodeSetEditor(
            existing: original,
            targetId: localPolicyTargetId,
            sources: const {'1': 'Alpha', '2': 'Beta'},
            nodes: const [],
            onSave: (value) async => saved = value,
          ),
        );
        tester.view.physicalSize = Size(width, 1400);
        await tester.pumpAndSettle();
        final unknown = find.widgetWithText(
          CheckboxListTile,
          AppLocalizations.current.policyUnknownOne,
        );
        await tester.ensureVisible(unknown);
        expect(tester.widget<CheckboxListTile>(unknown).value, isTrue);
        final preferences = tester.widget<PolicyPreferenceEditor>(
          find.byType(PolicyPreferenceEditor),
        );
        preferences.onChanged(original.preferences.reversed.toList());
        await tester.pump();
        final mode = find.byWidgetPredicate(
          (widget) => widget is SegmentedButton<NodeSelectionMode>,
        );
        await tester.ensureVisible(mode);
        tester
            .widget<SegmentedButton<NodeSelectionMode>>(mode)
            .onSelectionChanged!({NodeSelectionMode.loadBalance});
        await tester.pump();
        final balance = find.byWidgetPredicate(
          (widget) => widget is DropdownButtonFormField<NodeBalanceStrategy>,
        );
        await tester.ensureVisible(balance);
        tester
            .widget<DropdownButtonFormField<NodeBalanceStrategy>>(balance)
            .onChanged!(NodeBalanceStrategy.stickySessions);
        await tester.pump();
        final schedule = tester.widget<PolicyScheduleEditor>(
          find.byType(PolicyScheduleEditor),
        );
        expect(schedule.value.windows.single.startMinute, 1380);
        expect(schedule.value.windows.single.endMinute, 60);
        await tester.ensureVisible(
          find.widgetWithText(
            FilledButton,
            AppLocalizations.current.policyCheckSave,
          ),
        );
        await tester.tap(
          find.widgetWithText(
            FilledButton,
            AppLocalizations.current.policyCheckSave,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          saved?.nodeSet.preferences.map((preference) => preference.type),
          [NodePreferenceType.latency, NodePreferenceType.expiry],
        );
        expect(saved?.nodeSet.selectionMode, NodeSelectionMode.loadBalance);
        expect(
          saved?.nodeSet.balanceStrategy,
          NodeBalanceStrategy.stickySessions,
        );
        expect(saved?.nodeSet.unknownMultiplier, UnknownMultiplier.assumeOne);
        expect(saved?.nodeSet.schedule.windows.single.startMinute, 1380);
        expect(saved?.nodeSet.schedule.windows.single.endMinute, 60);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'common regions use friendly labels and legacy strategies remain visible',
    (tester) async {
      await mount(
        tester,
        Builder(
          builder: (context) {
            final labels = policyRegionOptions(context, const []);
            expect(labels['FR'], AppLocalizations.current.policyRegionFR);
            expect(labels['MO'], AppLocalizations.current.policyRegionMO);
            expect(
              policyMatchDescription(
                context,
                const PolicyMatch(
                  type: PolicyMatchType.destinationRegion,
                  values: ['FR'],
                ),
              ),
              labels['FR'],
            );
            expect(
              policyMatchDescription(
                context,
                const PolicyMatch(
                  type: PolicyMatchType.processPathRegex,
                  values: [
                    r'^/Applications/Office\x28Work\x29\x2cApp\.app/Contents/.*$',
                  ],
                ),
              ),
              'Office(Work),App',
            );
            return const SizedBox();
          },
        ),
      );
      for (final strategy in [
        NodeSetStrategy.latency,
        NodeSetStrategy.multiplier,
      ]) {
        await mount(
          tester,
          PolicyNodeSetEditor(
            key: ValueKey(strategy),
            existing: PolicyNodeSet(
              id: 'legacy-group',
              label: 'Legacy',
              targetId: localPolicyTargetId,
              sourceIds: const ['1'],
              strategy: strategy,
            ),
            targetId: localPolicyTargetId,
            sources: const {'1': 'Provider'},
            nodes: const [],
          ),
        );
        await tester.pumpAndSettle();
        final preferences = tester
            .widget<PolicyPreferenceEditor>(find.byType(PolicyPreferenceEditor))
            .value;
        expect(
          preferences.single.type,
          strategy == NodeSetStrategy.latency
              ? NodePreferenceType.latency
              : NodePreferenceType.multiplier,
        );
        expect(preferences.single.direction, SortDirection.ascending);
      }
    },
  );
  testWidgets('late application enumeration cannot update a disposed picker', (
    tester,
  ) async {
    final pending = Completer<List<PolicyApplication>>();
    await mount(
      tester,
      PolicyApplicationPicker(
        value: const PolicyMatch(type: PolicyMatchType.processPathRegex),
        onChanged: (_) {},
        catalog: _Catalog(() => pending.future),
      ),
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    pending.complete(const []);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
