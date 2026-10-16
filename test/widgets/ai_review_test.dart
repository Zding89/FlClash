import 'dart:async';

import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/configuration/settings.dart';
import 'package:fl_clash/capabilities/manifest.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/views/ai/approval.dart';
import 'package:fl_clash/views/ai/presentation.dart';
import 'package:fl_clash/views/ai/review.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

ConfigurationProposal _proposal({
  Map<String, Object?> validation = const {},
  String after = 'dark',
}) => ConfigurationProposal(
  id: 'review',
  summary: 'Settings',
  highRisk: false,
  expiresAt: 9999999999999,
  differences: [
    ConfigurationDifference(
      path: 'config.themeProps.themeMode',
      before: 'light',
      after: after,
    ),
  ],
  validation: validation,
);

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('zh', 'CN'),
  supportedLocales: AppLocalizations.delegate.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(body: child),
);

void main() {
  setUp(() async => AppLocalizations.load(const Locale('zh', 'CN')));

  test(
    'review consent is single use and compares full business validation',
    () async {
      var reviews = 0;
      var current = true;
      final approve = aiAfterReviewApproval(
        _proposal(
          validation: {'reviewStatus': 'draft', 'reviewCategory': 'settings'},
        ),
        onReview: (_) async {
          reviews++;
          return true;
        },
        isCurrent: () => current,
      );
      expect(await approve(_proposal()), true);
      expect(reviews, 0);
      expect(await approve(_proposal()), true);
      expect(reviews, 1);
      expect(
        await approve(_proposal(validation: {'executionOnly': true})),
        true,
      );
      expect(reviews, 2);
      current = false;
      expect(await approve(_proposal()), false);
      expect(reviews, 2);
    },
  );

  test(
    'changed content or new final stage cannot reuse initial consent',
    () async {
      for (final changed in [
        _proposal(after: 'system'),
        _proposal(validation: {'requiresScriptExecutionApproval': true}),
        _proposal(
          validation: {
            'finalConfigValidated': true,
            'finalConfigDifferences': [
              {'path': 'mode', 'after': 'global'},
            ],
          },
        ),
      ]) {
        var reviews = 0;
        final approve = aiAfterReviewApproval(
          _proposal(),
          onReview: (_) async {
            reviews++;
            return false;
          },
        );
        expect(await approve(changed), false);
        expect(reviews, 1);
      }
    },
  );

  test(
    'capability metadata resolves side-specific names and actual node changes',
    () {
      final s = AppLocalizations.current;
      final rows = aiReviewRows(
        s,
        _proposal(
          validation: {
            'agentReview': {
              'command': 'profile_select',
              'before': {'profileId': 'private-old'},
              'after': {'profileId': 'private-new'},
              'labels': {'before.profileId': '旧机场', 'after.profileId': '新机场'},
            },
          },
        ),
      );
      expect(rows.single.before, '旧机场');
      expect(rows.single.after, '新机场');
      final node = aiReviewRows(
        s,
        _proposal(
          validation: {
            'agentReview': {
              'command': 'proxy_select',
              'before': {'group': '自动选择', 'node': '美国节点'},
              'after': {'group': '自动选择', 'node': '香港节点'},
              'labels': {},
            },
          },
        ),
      );
      expect(node.last.before, '美国节点');
      expect(node.last.after, '香港节点');
      expect(node.first.before, isNull);
    },
  );

  testWidgets('settings use local labels and secret/unknown fields stay safe', (
    tester,
  ) async {
    const proposal = ConfigurationProposal(
      id: 'settings',
      summary: 'technical-summary',
      highRisk: true,
      expiresAt: 9999999999999,
      differences: [
        ConfigurationDifference(
          path: 'config.patchClashConfig.mode',
          before: 'rule',
          after: 'global',
        ),
        ConfigurationDifference(
          path: 'config.networkProps.systemProxy',
          before: false,
          after: true,
        ),
        ConfigurationDifference(
          path: 'config.appSettingProps.locale',
          before: 'en',
          after: 'zh_CN',
        ),
        ConfigurationDifference(
          path: 'config.patchClashConfig.secret',
          before: 'old-secret',
          after: 'new-secret',
        ),
        ConfigurationDifference(
          path: 'config.private.internalPath',
          before: 'private-old',
          after: 'private-new',
        ),
      ],
      validation: {},
    );
    await tester.pumpWidget(
      _app(const AiToolResultCard(proposal: proposal, expanded: true)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('规则 → 全局'), findsOneWidget);
    expect(find.text(AppLocalizations.current.systemProxy), findsOneWidget);
    expect(find.textContaining('old-secret'), findsNothing);
    expect(find.textContaining('new-secret'), findsNothing);
    expect(find.textContaining('private-'), findsNothing);
    expect(find.textContaining('config.'), findsNothing);
    expect(find.textContaining('technical-summary'), findsNothing);
  });

  testWidgets(
    'pending card only opens review or cancels and locks while reviewing',
    (tester) async {
      var reviews = 0;
      await tester.pumpWidget(
        _app(
          AiToolResultCard(
            proposal: _proposal(),
            awaitingApproval: true,
            onReview: () => reviews++,
            onApprove: () => fail('direct confirm'),
            onCancel: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(AppLocalizations.current.aiApprove), findsNothing);
      await tester.tap(find.text(AppLocalizations.current.aiReviewAndConfirm));
      expect(reviews, 1);
      await tester.pumpWidget(
        _app(
          AiToolResultCard(
            proposal: _proposal(),
            awaitingApproval: true,
            reviewing: true,
            onReview: () => reviews++,
            onCancel: () {},
          ),
        ),
      );
      await tester.pump();
      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNull);
      expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('read-only review has no confirm and cancelled sessions close', (
    tester,
  ) async {
    final cancelled = Completer<void>();
    bool? result;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showAiConfigurationApproval(
                context,
                _proposal(),
                readOnly: true,
                cancelled: cancelled.future,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(AiConfigurationApprovalDialog), findsOneWidget);
    expect(find.text(AppLocalizations.current.aiApprove), findsNothing);
    cancelled.complete();
    await tester.pumpAndSettle();
    expect(result, false);
    expect(find.byType(AiConfigurationApprovalDialog), findsNothing);
  });

  test('batched nested proposals retain one reviewable item per proposal', () {
    final first = _proposal();
    final second = ConfigurationProposal(
      id: 'second',
      summary: first.summary,
      highRisk: false,
      expiresAt: first.expiresAt,
      differences: first.differences,
      validation: const {},
    );
    expect(
      aiResultProposals({
        'result': {
          'proposals': [
            {'proposal': first.toJson()},
            {
              'result': {'proposal': second.toJson()},
            },
          ],
        },
      }).map((proposal) => proposal.id),
      ['review', 'second'],
    );
  });

  test('every manifest capability has a local business title', () {
    final s = AppLocalizations.current;
    for (final capability in applicationCapabilities) {
      expect(
        aiReviewCommandTitle(s, capability.command),
        isNot(s.aiReviewUnknownAction),
        reason: capability.command,
      );
    }
  });

  testWidgets('backup review shows safe file name and full restore scope', (
    tester,
  ) async {
    final proposal = _proposal(
      validation: {
        'agentReview': {
          'command': 'backup_restore',
          'before': {},
          'after': {'fileGrantId': 'opaque-file-grant', 'option': 'all'},
          'labels': {'fileGrantId': '备份-2026.zip'},
        },
      },
    );
    await tester.pumpWidget(
      _app(AiToolResultCard(proposal: proposal, expanded: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('备份-2026.zip'), findsOneWidget);
    expect(find.text(AppLocalizations.current.restoreAllData), findsOneWidget);
    expect(find.textContaining('opaque'), findsNothing);
    final onlyProfiles = aiReviewRows(
      AppLocalizations.current,
      _proposal(
        validation: {
          'agentReview': {
            'command': 'backup_restore',
            'before': {},
            'after': {'option': 'onlyProfiles'},
            'labels': {},
          },
        },
      ),
    );
    expect(
      onlyProfiles.single.after,
      AppLocalizations.current.restoreOnlyConfig,
    );
  });

  test(
    'resource target, name and URL are readable without private URL data',
    () {
      final rows = aiReviewRows(
        AppLocalizations.current,
        const ConfigurationProposal(
          id: 'refresh',
          summary: 'Profiles',
          highRisk: true,
          expiresAt: 9999999999999,
          differences: [
            ConfigurationDifference(
              path: 'profile.label',
              before: '旧机场',
              after: '新机场',
            ),
            ConfigurationDifference(
              path: 'profile.url',
              before: 'https://user:pass@old.example/feed?token=private-old',
              after: 'https://new.example/feed?token=private-new',
            ),
            ConfigurationDifference(
              path: 'protectedContent',
              before: null,
              after: null,
            ),
          ],
          validation: {'reviewTarget': '新机场'},
        ),
      );
      expect(rows.first.after, '新机场');
      expect(rows[1].before, '旧机场');
      expect(rows[1].after, '新机场');
      expect(rows[2].before, 'https://old.example');
      expect(rows[2].after, 'https://new.example');
      expect(rows.last.label, AppLocalizations.current.aiReviewContent);
      expect(rows.last.after, AppLocalizations.current.aiReviewChanged);
    },
  );

  test('profile order and file write grants use human names and intent', () {
    final s = AppLocalizations.current;
    final order = aiReviewRows(
      s,
      _proposal(
        validation: {
          'agentReview': {
            'command': 'profiles_reorder',
            'before': {
              'ids': ['private-a', 'private-b'],
            },
            'after': {
              'ids': ['private-b', 'private-a'],
            },
            'labels': {'profile.private-a': '机场甲', 'profile.private-b': '机场乙'},
          },
        },
      ),
    );
    expect(order.single.before, '机场甲 / 机场乙');
    expect(order.single.after, '机场乙 / 机场甲');
    final grant = aiReviewRows(
      s,
      _proposal(
        validation: {
          'agentReview': {
            'command': 'file_grant',
            'before': {},
            'after': {'mode': 'write'},
            'labels': {},
          },
        },
      ),
    );
    expect(grant.single.after, s.aiReviewWriteFile);
  });

  testWidgets(
    'ordinary capability review is quiet while restore keeps its warning',
    (tester) async {
      for (final command in [
        'proxy_select',
        'backup_restore',
        'profiles_refresh_all',
      ]) {
        final proposal = ConfigurationProposal(
          id: command,
          summary: 'internal',
          highRisk: true,
          expiresAt: 9999999999999,
          differences: const [],
          validation: {
            'agentReview': {
              'command': command,
              'before': {},
              'after': {},
              'labels': {},
            },
          },
        );
        await tester.pumpWidget(
          _app(AiConfigurationApprovalDialog(proposal: proposal)),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(AppLocalizations.current.aiHighRisk),
          command == 'backup_restore' ? findsOneWidget : findsNothing,
        );
        if (command == 'profiles_refresh_all') {
          expect(
            find.text(AppLocalizations.current.aiReviewFetchThenApply),
            findsOneWidget,
          );
          expect(
            find.text(
              '${AppLocalizations.current.confirm} · ${AppLocalizations.current.download}',
            ),
            findsOneWidget,
          );
          expect(find.text(AppLocalizations.current.aiApprove), findsNothing);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  test(
    'resource rules expose added removed and changed matches and routes by identity',
    () {
      final s = AppLocalizations.current;
      const unchanged = {
        'id': 4,
        'ruleAction': 'DOMAIN',
        'content': 'unchanged.test',
        'ruleTarget': 'DIRECT',
      };
      const proposal = ConfigurationProposal(
        id: 'rules',
        summary: 'rule',
        highRisk: true,
        expiresAt: 9999999999999,
        differences: [
          ConfigurationDifference(
            path: 'customRules',
            before: [
              {
                'id': 1,
                'ruleAction': 'DOMAIN_SUFFIX',
                'content': 'example.com',
                'ruleTarget': '美国',
              },
              {
                'id': 2,
                'ruleAction': 'DOMAIN',
                'content': 'old.test',
                'ruleTarget': 'DIRECT',
              },
              unchanged,
            ],
            after: [
              {
                'id': 1,
                'ruleAction': 'DOMAIN_SUFFIX',
                'content': 'example.com',
                'ruleTarget': '香港',
              },
              {
                'id': 3,
                'ruleAction': 'DOMAIN',
                'content': 'new.test',
                'ruleTarget': 'REJECT',
              },
              unchanged,
            ],
          ),
        ],
        validation: {},
      );
      expect(aiReviewTitle(s, proposal), s.rule);
      final rows = aiReviewRows(s, proposal);
      expect(rows, hasLength(3));
      expect(
        rows.map((row) => '${row.label} ${row.before} ${row.after}').join(),
        contains('old.test'),
      );
      expect(rows.map((row) => row.after).join(), contains('new.test'));
      final edited = rows.singleWhere((row) => row.before != null);
      expect(edited.before, contains('example.com → 美国'));
      expect(edited.after, contains('example.com → 香港'));
      expect(
        rows.map((row) => '${row.label} ${row.after}').join(),
        isNot(contains('unchanged.test')),
      );
    },
  );

  test(
    'resource groups expose names and member changes without raw identifiers',
    () {
      final s = AppLocalizations.current;
      final rows = aiReviewRows(
        s,
        const ConfigurationProposal(
          id: 'groups',
          summary: 'groups',
          highRisk: true,
          expiresAt: 9999999999999,
          differences: [
            ConfigurationDifference(
              path: 'groups',
              before: [
                {
                  'id': 111,
                  'name': '自动选择',
                  'proxies': ['美国', '日本'],
                },
                {
                  'name': '备用组',
                  'proxies': ['台湾'],
                },
              ],
              after: [
                {
                  'id': 111,
                  'name': '低倍率节点',
                  'proxies': ['香港', '日本'],
                },
                {
                  'name': '备用组',
                  'proxies': ['台湾'],
                },
              ],
            ),
          ],
          validation: {},
        ),
      );
      expect(rows, hasLength(2));
      expect(rows.first.before, '自动选择');
      expect(rows.first.after, '低倍率节点');
      expect(rows.last.before, '美国 / 日本');
      expect(rows.last.after, '香港 / 日本');
      expect(
        rows.map((row) => '${row.label} ${row.after}').join(),
        isNot(contains('111')),
      );
      expect(
        rows.map((row) => '${row.label} ${row.after}').join(),
        isNot(contains('备用组')),
      );
    },
  );

  test(
    'whole profile and script additions show their names and action only',
    () {
      final s = AppLocalizations.current;
      final rows = aiReviewRows(
        s,
        const ConfigurationProposal(
          id: 'objects',
          summary: 'objects',
          highRisk: true,
          expiresAt: 9999999999999,
          differences: [
            ConfigurationDifference(
              path: 'profile',
              before: null,
              after: {
                'id': 'opaque-profile',
                'label': '新机场',
                'url': 'https://user:pass@example.com/sub?token=secret',
              },
            ),
            ConfigurationDifference(
              path: 'script',
              before: null,
              after: {
                'id': 'opaque-script',
                'label': '本地脚本',
                'content': 'private-script-content',
              },
            ),
          ],
          validation: {},
        ),
      );
      final text = rows.map((row) => '${row.label} ${row.after}').join();
      expect(text, contains('新机场'));
      expect(text, contains('本地脚本'));
      expect(text, contains(s.aiPolicyChangeAdded(s.profiles, '新机场')));
      expect(text, contains('https://example.com'));
      expect(text, isNot(contains('private-script-content')));
      expect(text, isNot(contains('opaque')));
      expect(text, isNot(contains('token')));
    },
  );

  test(
    'large resource edits are bounded and primitive lists show actual changed values',
    () {
      final s = AppLocalizations.current;
      final rows = aiReviewRows(
        s,
        ConfigurationProposal(
          id: 'many',
          summary: 'many',
          highRisk: true,
          expiresAt: 9999999999999,
          differences: [
            ConfigurationDifference(
              path: 'addedRules',
              before: const [],
              after: [
                for (var index = 0; index < 5000; index++)
                  {
                    'id': index,
                    'ruleAction': 'DOMAIN',
                    'content': 'rule$index.test',
                    'ruleTarget': 'DIRECT',
                  },
              ],
            ),
          ],
          validation: const {},
        ),
      );
      expect(rows.length, lessThanOrEqualTo(24));
      expect(rows.fold<int>(0, (sum, row) => sum + row.changeCount), 5000);
      expect(rows.last.after, s.aiPolicyChangeMore('4977'));
      final lists = aiReviewRows(
        s,
        const ConfigurationProposal(
          id: 'lists',
          summary: 'lists',
          highRisk: true,
          expiresAt: 9999999999999,
          differences: [
            ConfigurationDifference(
              path: 'config.patchClashConfig.dns.nameserver',
              before: ['1.1.1.1'],
              after: ['8.8.8.8'],
            ),
            ConfigurationDifference(
              path: 'config.networkProps.bypassDomain',
              before: ['old.test'],
              after: ['new.test'],
            ),
          ],
          validation: {},
        ),
      );
      expect(lists.first.before, '1.1.1.1');
      expect(lists.first.after, '8.8.8.8');
      expect(lists.last.before, 'old.test');
      expect(lists.last.after, 'new.test');
      final refresh = aiReviewRows(
        s,
        _proposal(
          validation: {
            'agentReview': {
              'command': 'profiles_refresh_all',
              'before': {},
              'after': {
                'profiles': ['机场甲', '机场乙'],
              },
              'labels': {},
            },
          },
        ),
      );
      expect(refresh.single.after, '机场甲 / 机场乙');
    },
  );

  test('every supported setting has a local review label', () {
    final s = AppLocalizations.current;
    final paths = SettingsCatalog().capabilities.keys;
    expect(paths, hasLength(89));
    for (final path in paths) {
      expect(aiReviewFieldLabel(s, 'config.$path'), isNotNull, reason: path);
    }
    for (final path in [
      'ai.enabled',
      'ai.selectedConnectionId',
      'ai.connections',
    ]) {
      expect(aiReviewFieldLabel(s, path), isNotNull, reason: path);
    }
  });

  test('AI connections show safe changed fields by identity', () {
    final s = AppLocalizations.current;
    const unchanged = {
      'id': 'private-unchanged',
      'label': '保持连接',
      'model': 'same',
    };
    final rows = aiReviewRows(
      s,
      const ConfigurationProposal(
        id: 'ai-settings',
        summary: 'AI',
        highRisk: false,
        expiresAt: 9999999999999,
        differences: [
          ConfigurationDifference(
            path: 'ai.connections',
            before: [
              unchanged,
              {
                'id': 'private-current',
                'label': '工作连接',
                'model': 'old-model',
                'baseUrl':
                    'https://private:secret@example.com/v1?token=private',
                'maxTokens': 1024,
                'apiKey': 'private-key',
              },
            ],
            after: [
              {
                'id': 'private-current',
                'label': '工作连接',
                'model': 'new-model',
                'baseUrl': 'https://another.example.com/api?key=secret',
                'maxTokens': 4096,
                'apiKey': 'new-private-key',
              },
              unchanged,
            ],
          ),
        ],
        validation: {},
      ),
    );
    expect(rows, hasLength(3));
    final model = rows.singleWhere((row) => row.label.contains(s.aiModel));
    expect(model.before, 'old-model');
    expect(model.after, 'new-model');
    final tokens = rows.singleWhere((row) => row.label.contains(s.aiMaxTokens));
    expect(tokens.before, '1024');
    expect(tokens.after, '4096');
    final url = rows.singleWhere((row) => row.label.contains(s.aiBaseUrl));
    expect(url.before, 'https://example.com');
    expect(url.after, 'https://another.example.com');
    final text = rows
        .map((row) => '${row.label} ${row.before} ${row.after}')
        .join();
    expect(text, contains('工作连接'));
    expect(text, isNot(contains('保持连接')));
    expect(text, isNot(contains('private')));
    expect(text, isNot(contains('secret')));
  });

  test(
    'AI connection selection uses saved safe names without array differences',
    () {
      final s = AppLocalizations.current;
      final rows = aiReviewRows(
        s,
        const ConfigurationProposal(
          id: 'ai-selected',
          summary: 'AI',
          highRisk: false,
          expiresAt: 9999999999999,
          differences: [
            ConfigurationDifference(
              path: 'ai.selectedConnectionId',
              before: 'private-old',
              after: 'private-new',
            ),
          ],
          validation: {
            'aiReviewConnections': {
              'before': {'private-old': '原连接'},
              'after': {'private-new': '新连接'},
            },
          },
        ),
      );
      expect(rows.single.label, s.aiCurrentConnection);
      expect(rows.single.before, '原连接');
      expect(rows.single.after, '新连接');
    },
  );

  test(
    'completed preparation is read only even without an explicit card status',
    () {
      final parent = _proposal(
        validation: {
          'reviewStatus': 'proposal_ready',
          'reviewCategory': 'capability:profiles_refresh_all',
          'agentReview': {'command': 'profiles_refresh_all'},
        },
      );
      expect(aiReviewCanConfirm(parent, 'proposal_ready'), false);
      expect(aiReviewCanConfirm(parent, null), false);
      expect(
        aiReviewCanConfirm(
          _proposal(validation: {'reviewStatus': 'draft'}),
          null,
        ),
        true,
      );
    },
  );
}
