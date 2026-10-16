import 'package:drift/native.dart';
import 'package:fl_clash/ai/history.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/ai/history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _conversationId = '0123456789abcdef0123456789abcdef';

Future<void> _mount(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      workbenchControllerProvider.overrideWith(
        (_) => throw StateError('History must not create a runtime controller'),
      ),
    ],
  );
  globalState.container = container;
  addTearDown(container.dispose);
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
        builder: (context, child) {
          globalState.measure = Measure.of(context, 1);
          return child!;
        },
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _historyWidgetTest(
  String description,
  Future<void> Function(WidgetTester) body,
) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });
}

void main() {
  late WorkbenchDatabase database;
  late AiHistoryStore history;

  setUp(() {
    database = WorkbenchDatabase(NativeDatabase.memory());
  });

  tearDown(() async => database.close());

  Future<void> journal(
    String id, {
    required String summary,
    String status = 'draft',
    String category = 'settings',
    Map<String, Object?> before = const {'mode': 'rule'},
    Map<String, Object?> after = const {'mode': 'global'},
  }) async {
    await database.saveChange(
      id: id,
      category: category,
      summary: summary,
      highRisk: true,
      fingerprint: 'fixture-version',
      before: before,
      after: after,
      createdAt: 1791907200000,
      expiresAt: 9999999999999,
    );
    await database.changeStatus(id, status);
  }

  _historyWidgetTest(
    'a saved local rule journal does not claim current activation',
    (tester) async {
      await journal(
        'local-saved',
        summary: 'Saved local rules',
        category: 'policies',
        status: 'applied',
      );
      await _mount(
        tester,
        AiLinkedChangesView(store: database, ids: const ['local-saved']),
      );
      final strings = AppLocalizations.current;
      expect(find.textContaining(strings.policySaved), findsOneWidget);
      expect(find.textContaining(strings.policyAppliedStatus), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  _historyWidgetTest(
    'linked journals filter IDs, display terminal conflict and refresh live state',
    (tester) async {
      await journal('linked', summary: 'Linked journal', status: 'conflict');
      await journal('unrelated', summary: 'Unrelated journal');
      await _mount(
        tester,
        AiLinkedChangesView(store: database, ids: const ['linked', 'missing']),
      );
      final strings = AppLocalizations.current;
      expect(find.text('Linked journal'), findsOneWidget);
      expect(find.text('Unrelated journal'), findsNothing);
      expect(find.textContaining(strings.aiChangeFailed), findsOneWidget);
      expect(find.textContaining(strings.policyPreparingStatus), findsNothing);
      expect(find.text(strings.aiChangesUnavailable), findsOneWidget);
      expect(find.text(strings.aiManageChanges), findsOneWidget);
      expect(tester.takeException(), isNull);

      await database.changeStatus('linked', 'applied');
      await tester.pumpAndSettle();
      expect(find.textContaining(strings.policyAppliedStatus), findsOneWidget);
      expect(find.textContaining(strings.aiChangeFailed), findsNothing);
      expect(find.text('Unrelated journal'), findsNothing);

      await database.changeStatus('linked', 'proposal_ready');
      await tester.pumpAndSettle();
      expect(find.textContaining(strings.policyDraftStatus), findsOneWidget);
      expect(find.textContaining(strings.policyPreparingStatus), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  _historyWidgetTest('linked differences redact secrets and fit a 360px dialog', (
    tester,
  ) async {
    await journal(
      'redacted',
      summary: 'Redacted change',
      before: const {
        'settings': {'mode': 'rule', 'password': 'before-password'},
        'profile': {
          'protectedContent': 'before-source-private',
          'url':
              'https://before-user:before-pass@example.com/feed?token=before-token&name=public',
        },
      },
      after: const {
        'settings': {'mode': 'global', 'password': 'after-password'},
        'profile': {
          'protectedContent': 'after-source-private',
          'url':
              'https://after-user:after-pass@example.com/feed?token=after-token&name=public',
        },
      },
    );
    await _mount(
      tester,
      AiLinkedChangesView(store: database, ids: const ['redacted']),
    );
    await tester.tap(find.text('Redacted change'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('settings.mode'), findsNothing);
    expect(find.text(AppLocalizations.current.mode), findsOneWidget);
    final values = [
      ...tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .map((widget) => widget.data ?? widget.textSpan!.toPlainText()),
      ...tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? ''),
    ].join('\n');
    expect(values, contains(AppLocalizations.current.rule));
    expect(values, contains(AppLocalizations.current.global));
    expect(values, contains('example.com'));
    expect(values, isNot(contains('name=public')));
    for (final secret in [
      'before-password',
      'after-password',
      'before-source-private',
      'after-source-private',
      'before-user',
      'before-pass',
      'after-user',
      'after-pass',
      'before-token',
      'after-token',
    ]) {
      expect(values, isNot(contains(secret)), reason: secret);
    }
    final dialog = tester.getRect(find.byType(AlertDialog));
    expect(dialog.left, greaterThanOrEqualTo(0));
    expect(dialog.right, lessThanOrEqualTo(360));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(AppLocalizations.current.aiReviewClose));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  _historyWidgetTest(
    'deleting a conversation keeps its durable journal unchanged',
    (tester) async {
      history = AiHistoryStore(database);
      await journal('kept', summary: 'Keep this journal', status: 'applied');
      final original = (await database.readChange('kept'))!.toJson();
      await history.save(
        const AiConversation(
          id: _conversationId,
          updatedAt: 1791907200000,
          targetLabel: '当前订阅配置',
          messages: [
            {'role': 'user', 'content': 'Only remove this conversation'},
            {'role': 'assistant', 'content': 'Saved textual response'},
          ],
          changeIds: ['kept'],
        ),
      );
      await _mount(tester, AiConversationHistoryView(store: history));
      final strings = AppLocalizations.current;
      expect(find.text('Only remove this conversation'), findsOneWidget);
      expect(find.byTooltip(strings.aiLinkedChanges), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip(strings.delete));
      await tester.pumpAndSettle();
      expect(find.text('Only remove this conversation'), findsNothing);
      expect(find.text(strings.aiEmptyHistory), findsOneWidget);
      expect(await history.list(), isEmpty);
      expect((await database.readChange('kept'))!.toJson(), original);
      expect(tester.takeException(), isNull);
    },
  );

  _historyWidgetTest(
    'selecting history returns text without resuming pending work',
    (tester) async {
      history = AiHistoryStore(database);
      await journal(
        'never-approved',
        summary: 'Never approved',
        status: 'pending_confirmation',
      );
      final original = (await database.readChange('never-approved'))!.toJson();
      await history.save(
        const AiConversation(
          id: _conversationId,
          updatedAt: 1791907200000,
          messages: [
            {'role': 'user', 'content': 'Restore these words'},
            {'role': 'tool', 'content': 'Never restore tool output'},
            {
              'role': 'assistant',
              'content': 'A saved answer',
              'approval': 'Never restore approval authority',
            },
          ],
          changeIds: ['never-approved'],
        ),
      );
      AiConversation? selected;
      await _mount(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await Navigator.of(context).push<AiConversation>(
                  MaterialPageRoute(
                    builder: (_) => AiConversationHistoryView(store: history),
                  ),
                );
              },
              child: const Text('Open saved conversations'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open saved conversations'));
      await tester.pumpAndSettle();
      expect(find.text('Restore these words'), findsOneWidget);
      expect(find.text('Never restore tool output'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Restore these words'));
      await tester.pumpAndSettle();
      expect(find.byType(AiConversationHistoryView), findsNothing);
      expect(selected, isNotNull);
      expect(selected!.id, _conversationId);
      expect(selected!.messages, const [
        {'role': 'user', 'content': 'Restore these words'},
        {'role': 'assistant', 'content': 'A saved answer'},
      ]);
      expect(selected!.changeIds, ['never-approved']);
      expect((await database.readChange('never-approved'))!.toJson(), original);
      expect(tester.takeException(), isNull);
    },
  );
}
