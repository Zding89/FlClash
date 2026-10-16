import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/policy/source_change.dart';
import 'package:fl_clash/views/ai/approval.dart';
import 'package:fl_clash/views/policy/source_change_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _openApproval(
  WidgetTester tester,
  ConfigurationProposal proposal, {
  ValueChanged<bool>? onChoice,
  ThemeData? theme,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh', 'CN'),
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final choice = await showAiConfigurationApproval(
                context,
                proposal,
              );
              onChoice?.call(choice);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Finder _metricCard(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(Card));

void _expectMetricValues(String title, String before, String after) {
  final card = _metricCard(title);
  expect(card, findsOneWidget);
  expect(
    find.descendant(
      of: card,
      matching: find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == before,
      ),
    ),
    findsOneWidget,
  );
  expect(
    find.descendant(
      of: card,
      matching: find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == after,
      ),
    ),
    findsOneWidget,
  );
}

Map<String, Object?> _totals({
  int sources = 1,
  int nodes = 12,
  int remaining = 1073741824,
  List<String> unresolvedNodes = const [],
  List<String> unknownQuota = const [],
}) => {
  'sourceCount': sources,
  'nodeCount': nodes,
  'remainingBytes': remaining,
  'unresolvedNodeSources': unresolvedNodes,
  'unknownQuotaSources': unknownQuota,
};

ConfigurationProposal _sourceProposal({
  List<String> added = const ['New Airport'],
  List<String> removed = const ['Old Airport'],
  Map<String, Object?>? before,
  Map<String, Object?>? after,
  Map<String, Object?> validation = const {},
  List<ConfigurationDifference> extraDifferences = const [],
  bool highRisk = false,
}) => ConfigurationProposal(
  id: 'source-proposal',
  summary: 'technical fallback summary',
  highRisk: highRisk,
  expiresAt: 1000,
  differences: [
    const ConfigurationDifference(
      path: 'policies.revision',
      before: 3,
      after: 4,
    ),
    const ConfigurationDifference(
      path: 'policies.integrations',
      before: [
        {
          'sourceProfileIds': [1],
        },
      ],
      after: [
        {
          'sourceProfileIds': [2],
        },
      ],
    ),
    ...extraDifferences,
  ],
  validation: {
    localSourceChangeValidationKey: {
      'addedSources': added,
      'removedSources': removed,
      'before': before ?? _totals(),
      'after': after ?? _totals(nodes: 30, remaining: 2147483648),
    },
    ...validation,
  },
);

void main() {
  testWidgets('approval displays concrete changes and returns explicit choice', (
    tester,
  ) async {
    bool? approval;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                approval = await showAiConfigurationApproval(
                  context,
                  const ConfigurationProposal(
                    id: 'proposal-1',
                    summary: 'Proxy mode',
                    highRisk: true,
                    expiresAt: 1000,
                    differences: [
                      ConfigurationDifference(
                        path: 'config.mode',
                        before: 'rule',
                        after: 'global',
                      ),
                    ],
                    validation: {},
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text(AppLocalizations.current.aiHighRisk), findsOneWidget);
    expect(find.text('config.mode'), findsNothing);
    expect(find.text(AppLocalizations.current.mode), findsOneWidget);
    expect(
      find.text(
        '${AppLocalizations.current.rule} → ${AppLocalizations.current.global}',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text(AppLocalizations.current.cancel));
    await tester.pumpAndSettle();
    expect(approval, false);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizations.current.aiApprove));
    await tester.pumpAndSettle();
    expect(approval, true);
  });

  testWidgets('source approval replaces raw fields with concrete totals', (
    tester,
  ) async {
    bool? approval;
    await _openApproval(
      tester,
      _sourceProposal(highRisk: true),
      onChoice: (value) => approval = value,
    );
    final strings = AppLocalizations.current;
    expect(find.byType(LocalSourceChangeSummaryView), findsOneWidget);
    expect(find.text('policies.revision'), findsNothing);
    expect(find.text('policies.integrations'), findsNothing);
    expect(find.text('technical fallback summary'), findsNothing);
    expect(find.text('New Airport'), findsOneWidget);
    expect(find.text('Old Airport'), findsOneWidget);
    expect(find.text(strings.policySourceChangeAdded), findsOneWidget);
    expect(find.text(strings.policySourceChangeRemoved), findsOneWidget);
    expect(find.text(strings.policySourceChangeNodeTotal), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(LocalSourceChangeSummaryView),
        matching: find.byType(Card),
      ),
      findsNWidgets(2),
    );
    _expectMetricValues(strings.policySourceChangeNodeTotal, '12', '30');
    _expectMetricValues(
      strings.policySourceChangeRemaining,
      1073741824.traffic.show,
      2147483648.traffic.show,
    );
    expect(find.text(strings.aiHighRisk), findsNothing);
    await tester.tap(find.text(strings.cancel));
    await tester.pumpAndSettle();
    expect(approval, false);
  });

  testWidgets('partial totals identify unknown sources before and after', (
    tester,
  ) async {
    await _openApproval(
      tester,
      _sourceProposal(
        before: _totals(sources: 2, unknownQuota: ['Old quota unknown']),
        after: _totals(
          sources: 2,
          nodes: 8,
          remaining: 0,
          unresolvedNodes: ['New nodes unresolved'],
          unknownQuota: ['New quota unknown'],
        ),
      ),
    );
    final strings = AppLocalizations.current;
    final partial = strings.policySourceChangePartiallyUnknown;
    _expectMetricValues(strings.policySourceChangeNodeTotal, '12', '8');
    _expectMetricValues(
      strings.policySourceChangeRemaining,
      1073741824.traffic.show,
      0.traffic.show,
    );
    expect(
      find.descendant(
        of: _metricCard(strings.policySourceChangeNodeTotal),
        matching: find.textContaining(partial),
      ),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: _metricCard(strings.policySourceChangeRemaining),
        matching: find.textContaining(partial),
      ),
      findsWidgets,
    );
    expect(find.text('Old quota unknown'), findsOneWidget);
    expect(find.text('New nodes unresolved'), findsOneWidget);
    expect(find.text('New quota unknown'), findsOneWidget);
    expect(
      find.text('${strings.aiBefore} · ${strings.policyQuotaUnknown}'),
      findsOneWidget,
    );
    expect(
      find.text(
        '${strings.aiAfter} · ${strings.policySourceChangeNodesUnavailable}',
      ),
      findsOneWidget,
    );
  });

  testWidgets('fully unknown sources are not displayed as zero totals', (
    tester,
  ) async {
    await _openApproval(
      tester,
      _sourceProposal(
        after: _totals(
          sources: 1,
          nodes: 0,
          remaining: 0,
          unresolvedNodes: ['Unresolved Airport'],
          unknownQuota: ['Unresolved Airport'],
        ),
      ),
    );
    final strings = AppLocalizations.current;
    final unknown = strings.policyUnknownAttribute;
    _expectMetricValues(strings.policySourceChangeNodeTotal, '12', unknown);
    _expectMetricValues(
      strings.policySourceChangeRemaining,
      1073741824.traffic.show,
      unknown,
    );
    expect(find.text('0'), findsNothing);
    expect(find.text(0.traffic.show), findsNothing);
  });

  testWidgets('unchanged missing details merge both metrics and both sides', (
    tester,
  ) async {
    final unknownTotals = _totals(
      sources: 1,
      nodes: 0,
      remaining: 0,
      unresolvedNodes: ['AfeiCloud'],
      unknownQuota: ['AfeiCloud'],
    );
    await _openApproval(
      tester,
      _sourceProposal(
        added: [],
        removed: [],
        before: unknownTotals,
        after: unknownTotals,
      ),
    );
    final strings = AppLocalizations.current;
    final reasons = [
      strings.policySourceChangeNodesUnavailable,
      strings.policyQuotaUnknown,
    ].join(' · ');
    expect(find.text('AfeiCloud'), findsOneWidget);
    expect(find.textContaining('AfeiCloud'), findsOneWidget);
    expect(find.text(reasons), findsOneWidget);
    expect(find.text('${strings.aiBefore} · $reasons'), findsNothing);
    expect(find.text('${strings.aiAfter} · $reasons'), findsNothing);
    expect(find.text(strings.policyUnknownAttribute), findsNWidgets(4));
    expect(find.text('0'), findsNothing);
    expect(find.text(0.traffic.show), findsNothing);
  });

  testWidgets(
    'changed missing reasons keep their before and after attribution',
    (tester) async {
      await _openApproval(
        tester,
        _sourceProposal(
          before: _totals(sources: 2, unresolvedNodes: ['AfeiCloud']),
          after: _totals(sources: 2, unknownQuota: ['AfeiCloud']),
        ),
      );
      final strings = AppLocalizations.current;
      expect(find.text('AfeiCloud'), findsOneWidget);
      expect(
        find.text(
          '${strings.aiBefore} · ${strings.policySourceChangeNodesUnavailable}',
        ),
        findsOneWidget,
      );
      expect(
        find.text('${strings.aiAfter} · ${strings.policyQuotaUnknown}'),
        findsOneWidget,
      );
    },
  );

  testWidgets('empty source selection has explicit zero totals', (
    tester,
  ) async {
    await _openApproval(
      tester,
      _sourceProposal(
        added: [],
        after: _totals(sources: 0, nodes: 0, remaining: 0),
      ),
    );
    final strings = AppLocalizations.current;
    _expectMetricValues(strings.policySourceChangeNodeTotal, '12', '0');
    _expectMetricValues(
      strings.policySourceChangeRemaining,
      1073741824.traffic.show,
      0.traffic.show,
    );
    expect(find.text(strings.policyUnknownAttribute), findsNothing);
    expect(
      find.textContaining(
        AppLocalizations.current.policySourceChangePartiallyUnknown,
      ),
      findsNothing,
    );
  });

  testWidgets('other settings retain their complete differences', (
    tester,
  ) async {
    await _openApproval(
      tester,
      _sourceProposal(
        highRisk: true,
        extraDifferences: const [
          ConfigurationDifference(
            path: 'config.mode',
            before: 'rule',
            after: 'global',
          ),
        ],
      ),
    );
    expect(find.byType(LocalSourceChangeSummaryView), findsNothing);
    expect(find.text('config.mode'), findsNothing);
    expect(find.text(AppLocalizations.current.mode), findsOneWidget);
    expect(
      find.text(
        '${AppLocalizations.current.rule} → ${AppLocalizations.current.global}',
      ),
      findsOneWidget,
    );
    expect(find.text('policies.integrations'), findsNothing);
    expect(find.text(AppLocalizations.current.aiHighRisk), findsOneWidget);
  });

  testWidgets('script execution approval retains original confirmation', (
    tester,
  ) async {
    bool? approval;
    await _openApproval(
      tester,
      _sourceProposal(highRisk: true, validation: {'executionOnly': true}),
      onChoice: (value) => approval = value,
    );
    final strings = AppLocalizations.current;
    expect(find.byType(LocalSourceChangeSummaryView), findsNothing);
    expect(find.text('policies.integrations'), findsNothing);
    expect(find.text(strings.aiScriptExecutionOnly), findsOneWidget);
    expect(find.text(strings.aiHighRisk), findsOneWidget);
    await tester.tap(find.text(strings.aiApproveScriptExecution));
    await tester.pumpAndSettle();
    expect(approval, true);
  });

  testWidgets('final configuration differences keep the full confirmation', (
    tester,
  ) async {
    await _openApproval(
      tester,
      _sourceProposal(
        highRisk: true,
        validation: {
          'finalConfigDifferences': [
            {'path': 'dns.enable', 'before': false, 'after': true},
          ],
        },
      ),
    );
    expect(find.byType(LocalSourceChangeSummaryView), findsNothing);
    expect(find.text('policies.integrations'), findsNothing);
    expect(find.text('dns.enable'), findsNothing);
    expect(find.text(AppLocalizations.current.aiReviewDns), findsOneWidget);
    expect(
      find.text(
        '${AppLocalizations.current.aiPolicyChangeDisabled} → ${AppLocalizations.current.aiPolicyChangeEnabled}',
      ),
      findsOneWidget,
    );
    expect(find.text(AppLocalizations.current.aiHighRisk), findsOneWidget);
  });

  for (final largeDark in [false, true]) {
    testWidgets(
      'long source names scroll and allow approval at 320px, large dark: $largeDark',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 568));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        bool? approval;
        final longName = List.filled(8, 'Long subscription name').join(' ');
        await _openApproval(
          tester,
          _sourceProposal(
            added: [longName],
            after: _totals(
              unresolvedNodes: [longName],
              unknownQuota: [longName],
            ),
          ),
          theme: largeDark ? ThemeData.dark(useMaterial3: true) : null,
          textScale: largeDark ? 1.3 : 1,
          onChoice: (value) => approval = value,
        );
        expect(tester.takeException(), isNull);
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -800),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(AppLocalizations.current.aiApprove));
        await tester.pumpAndSettle();
        expect(approval, true);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('nested credentials and URL secrets are hidden from approval display', () {
    final text = aiDisplayValue({
      'entries': [
        {
          'apiKey': 'private-key',
          'url':
              'https://user:pass@example.com/api?token=private-token&model=test',
        },
      ],
    });
    expect(text, isNot(contains('private-key')));
    expect(text, isNot(contains('private-token')));
    expect(text, isNot(contains('user:pass')));
    expect(text, contains('model=test'));
  });
}
