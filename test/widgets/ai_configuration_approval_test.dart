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
}) async {
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
  testWidgets(
    'approval displays concrete changes and returns explicit choice',
    (tester) async {
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
      expect(find.text('config.mode'), findsOneWidget);
      expect(find.text('"rule"'), findsOneWidget);
      expect(find.text('"global"'), findsOneWidget);
      await tester.tap(find.text(AppLocalizations.current.aiReject));
      await tester.pumpAndSettle();
      expect(approval, false);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppLocalizations.current.aiApprove));
      await tester.pumpAndSettle();
      expect(approval, true);
    },
  );

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
    expect(find.text('12 → 30'), findsOneWidget);
    expect(
      find.text('${1073741824.traffic.show} → ${2147483648.traffic.show}'),
      findsOneWidget,
    );
    expect(find.text(strings.aiHighRisk), findsOneWidget);
    await tester.tap(find.text(strings.aiReject));
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
    expect(find.text('12 → 8 ($partial)'), findsOneWidget);
    expect(
      find.text(
        '${1073741824.traffic.show} ($partial) → ${0.traffic.show} ($partial)',
      ),
      findsOneWidget,
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
        '${strings.aiAfter} · ${strings.policySourceChangeUnresolvedNodes}',
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
    final unknown = AppLocalizations.current.policyUnknownAttribute;
    expect(find.text('12 → $unknown'), findsOneWidget);
    expect(find.text('${1073741824.traffic.show} → $unknown'), findsOneWidget);
    expect(find.text('12 → 0'), findsNothing);
  });

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
    expect(find.text('12 → 0'), findsOneWidget);
    expect(
      find.text('${1073741824.traffic.show} → ${0.traffic.show}'),
      findsOneWidget,
    );
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
    expect(find.text('config.mode'), findsOneWidget);
    expect(find.text('"rule"'), findsOneWidget);
    expect(find.text('"global"'), findsOneWidget);
    expect(find.text('policies.integrations'), findsOneWidget);
  });

  testWidgets('script execution approval retains original confirmation', (
    tester,
  ) async {
    bool? approval;
    await _openApproval(
      tester,
      _sourceProposal(validation: {'executionOnly': true}),
      onChoice: (value) => approval = value,
    );
    final strings = AppLocalizations.current;
    expect(find.byType(LocalSourceChangeSummaryView), findsNothing);
    expect(find.text('policies.integrations'), findsOneWidget);
    expect(find.text(strings.aiScriptExecutionOnly), findsOneWidget);
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
        validation: {
          'finalConfigDifferences': [
            {'path': 'dns.enable', 'before': false, 'after': true},
          ],
        },
      ),
    );
    expect(find.byType(LocalSourceChangeSummaryView), findsNothing);
    expect(find.text('policies.integrations'), findsOneWidget);
    expect(find.text('dns.enable'), findsOneWidget);
    expect(find.text('false'), findsOneWidget);
    expect(find.text('true'), findsOneWidget);
  });

  testWidgets(
    'long source names scroll on a narrow screen and allow approval',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      bool? approval;
      final longName = List.filled(8, 'Long subscription name').join(' ');
      await _openApproval(
        tester,
        _sourceProposal(
          added: [longName],
          after: _totals(unresolvedNodes: [longName], unknownQuota: [longName]),
        ),
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
