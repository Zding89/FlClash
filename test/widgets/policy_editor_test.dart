import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/views/policy/editors.dart';
import 'package:fl_clash/views/policy/rule_editor.dart';
import 'package:fl_clash/views/policy/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

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
  testWidgets(
    'candidate order retains exact identities including missing nodes',
    (tester) async {
      var selected = ['a', 'missing', 'b'];
      final nodes = [
        for (final id in ['a', 'b'])
          LocalNode(
            id: id,
            sourceId: '1',
            label: 'same label',
            sourceLabel: 'Source',
            protocol: 'ss',
            raw: {},
          ),
      ];
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: OrderedPolicyNodes(
                nodes: nodes,
                value: selected,
                onChanged: (value) => setState(() => selected = value),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('policy-node-up-b')));
      await tester.pump();
      expect(selected, ['a', 'b', 'missing']);
      expect(
        find.text(AppLocalizations.current.policyMissingNode),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'advanced JSON rejects unsupported fields without closing editor',
    (tester) async {
      await tester.pumpWidget(
        _app(
          PolicyJsonDialog<LocalPolicyDocument>(
            initial: const LocalPolicyDocument().toJson(),
            parse: LocalPolicyDocument.fromJson,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('policy-json')),
        '{"arbitraryCode":"execute"}',
      );
      await tester.tap(find.text(AppLocalizations.current.save));
      await tester.pumpAndSettle();
      expect(
        find.text(AppLocalizations.current.policyInvalidData),
        findsOneWidget,
      );
      expect(
        find.byType(PolicyJsonDialog<LocalPolicyDocument>),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('budget editing preserves exact byte limit and rejects zero', (
    tester,
  ) async {
    const budget = SourceBudget(
      sourceId: '1',
      limitBytes: 1073741825,
      resetDay: 28,
    );
    SourceBudget? saved;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              saved = await showDialog<SourceBudget>(
                context: context,
                builder: (_) => const PolicyBudgetEditor(
                  existing: budget,
                  sources: {'1': 'Source'},
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizations.current.save));
    await tester.pumpAndSettle();
    expect(saved?.limitBytes, budget.limitBytes);
    expect(saved?.resetDay, 28);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('policy-budget-limit')),
      '0',
    );
    await tester.tap(find.text(AppLocalizations.current.save));
    await tester.pumpAndSettle();
    expect(
      find.text(AppLocalizations.current.policyInvalidData),
      findsOneWidget,
    );
    expect(find.byType(PolicyBudgetEditor), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'rule editor rejects invalid probe timing before returning a draft',
    (tester) async {
      const existing = LocalPolicy(
        id: 'rule',
        label: 'Rule',
        targetId: 'profile:1',
        candidateNodeIds: ['1:a'],
      );
      LocalPolicy? saved;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                saved = await showDialog<LocalPolicy>(
                  context: context,
                  builder: (_) => LocalPolicyEditor(
                    existing: existing,
                    targets: const {'profile:1': 'Source'},
                    loadNodes: (_) async => [
                      LocalNode(
                        id: '1:a',
                        sourceId: '1',
                        label: 'Node A',
                        sourceLabel: 'Source',
                        protocol: 'ss',
                        raw: {},
                      ),
                    ],
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('policy-more-settings')),
      );
      await tester.tap(find.text(AppLocalizations.current.policyMoreSettings));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.text(AppLocalizations.current.policyProbe),
      );
      await tester.tap(find.text(AppLocalizations.current.policyProbe));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('policy-rule-interval')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('policy-rule-interval')),
        '5',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('policy-rule-timeout')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('policy-rule-timeout')),
        '5',
      );
      await tester.tap(find.text(AppLocalizations.current.save));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(find.byType(LocalPolicyEditor), findsOneWidget);
      expect(
        find.text(AppLocalizations.current.policyInvalidData),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('policy-rule-timeout')),
        '2',
      );
      await tester.tap(find.text(AppLocalizations.current.save));
      await tester.pumpAndSettle();
      expect(saved?.id, 'rule');
      expect(saved?.candidateNodeIds, ['1:a']);
      expect(saved?.probe.timeoutSeconds, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
