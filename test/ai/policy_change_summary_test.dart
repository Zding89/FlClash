import 'package:fl_clash/ai/policy_change_summary.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

List<ConfigurationDifference> _changes(String kind, List before, List after) =>
    configurationDifferences(
      {
        'policies': {kind: before},
      },
      {
        'policies': {kind: after},
      },
    );

void main() {
  setUp(() async => AppLocalizations.load(const Locale('zh', 'CN')));

  test('one node group field omits unchanged groups and fields', () {
    final before = [
      {
        'id': 'one',
        'label': '香港组',
        'maxMultiplier': 1,
        'regions': ['HK'],
      },
      {
        'id': 'two',
        'label': '美国组',
        'maxMultiplier': 1,
        'regions': ['US'],
      },
    ];
    final summary = aiPolicyChangeSummary(
      _changes('nodeSets', before, [
        {...before[0], 'maxMultiplier': 0.2},
        before[1],
      ]),
    );
    expect(summary, contains('香港组'));
    expect(summary, contains('1× → 0.2×'));
    expect(summary, isNot(contains('美国组')));
    expect(summary, isNot(contains('地区')));
    expect(summary, isNot(contains('nodeSets')));
    expect(summary, isNot(contains('one')));
  });

  test('rename addition removal and movement retain resource identity', () {
    final rename = aiPolicyChangeSummary(
      _changes(
        'nodeSets',
        [
          {'id': 'one', 'label': '香港组'},
          {'id': 'removed', 'label': '旧节点组'},
        ],
        [
          {'id': 'one', 'label': '香港低倍率'},
          {'id': 'added', 'label': '日本组'},
        ],
      ),
    );
    expect(rename, contains('香港组 → 香港低倍率'));
    expect(rename, contains('新增节点组“日本组”'));
    expect(rename, contains('删除节点组“旧节点组”'));
    final lines = aiPolicyChangeLines(
      _changes(
        'policies',
        [
          {'id': 'a', 'label': 'AI', 'priority': 1},
          {'id': 'b', 'label': '国内', 'priority': 2},
          {'id': 'c', 'label': '其他', 'priority': 3},
        ],
        [
          {'id': 'b', 'label': '国内', 'priority': 1},
          {'id': 'a', 'label': 'AI', 'priority': 2},
          {'id': 'c', 'label': '其他', 'priority': 3},
        ],
      ),
    );
    expect(lines, hasLength(2));
    expect(lines.join(), contains('第 1 位 → 第 2 位'));
    expect(lines.join(), contains('第 2 位 → 第 1 位'));
    expect(lines.join(), isNot(contains('其他')));
  });

  test('inserting a rule does not report unchanged rules as moved', () {
    final summary = aiPolicyChangeSummary(
      _changes(
        'policies',
        [
          {'id': 'b', 'label': '国内', 'priority': 1},
          {'id': 'c', 'label': '其他', 'priority': 2},
        ],
        [
          {'id': 'a', 'label': 'AI', 'priority': 1},
          {'id': 'b', 'label': '国内', 'priority': 2},
          {'id': 'c', 'label': '其他', 'priority': 3},
        ],
      ),
    );
    expect(summary, '新增规则“AI”');
  });

  test(
    'source references probe URLs and complex filters never leak values',
    () {
      final before = [
        {
          'id': 'private-id',
          'label': '香港组',
          'sourceIds': ['source-private-A'],
          'nameIncludes': ['香港节点'],
          'probe': {
            'url': 'https://user:old@example.test/?token=old',
            'intervalSeconds': 60,
          },
        },
      ];
      final lines = aiPolicyChangeLines(
        _changes('nodeSets', before, [
          {
            ...before.single,
            'sourceIds': ['source-private-B'],
            'nameIncludes': ['低倍率节点'],
            'probe': {
              'url': 'https://user:new@example.test/?token=new',
              'intervalSeconds': 90,
            },
          },
        ]),
      );
      final text = lines.join('\n');
      expect(text, contains(AppLocalizations.current.policyIncludeSources));
      expect(text, contains(AppLocalizations.current.policyNameIncludes));
      expect(text, contains('香港节点 → 低倍率节点'));
      expect(text, contains('60 → 90'));
      expect(text, isNot(contains('private')));
      expect(text, isNot(contains('https://')));
      expect(text, isNot(contains('token')));
      expect(text, isNot(contains('{')));
    },
  );

  test(
    'routing and source changes show names without exposing reference IDs',
    () {
      final summary = aiPolicyChangeSummary(
        _changes(
          'policies',
          [
            {
              'id': 'route',
              'label': 'AI',
              'choices': [
                {'type': 'nodeSet', 'id': 'set-private-us'},
              ],
            },
          ],
          [
            {
              'id': 'route',
              'label': 'AI',
              'choices': [
                {'type': 'nodeSet', 'id': 'set-private-hk'},
              ],
            },
          ],
        ),
        nodeSetLabels: {'set-private-us': '美国', 'set-private-hk': '香港'},
      );
      expect(summary, contains('美国 → 香港'));
      expect(summary, isNot(contains('set-private')));
      final sources = aiPolicyChangeSummary(
        _changes(
          'nodeSets',
          [
            {
              'id': 'set',
              'label': '香港',
              'sourceIds': ['private-source-a'],
            },
          ],
          [
            {
              'id': 'set',
              'label': '香港',
              'sourceIds': ['private-source-b'],
            },
          ],
        ),
        sourceLabels: {'private-source-a': '机场甲', 'private-source-b': '机场乙'},
      );
      expect(sources, contains('机场甲 → 机场乙'));
      expect(sources, isNot(contains('private-source')));
    },
  );

  test(
    'unknown references show item count and added details show actual filters',
    () {
      final differences = _changes('policies', [], [
        {
          'id': 'route',
          'label': 'AI',
          'action': 'proxy',
          'scope': {
            'type': 'domainKeyword',
            'values': ['chatgpt', 'https://secret.test/?token=private-value'],
          },
          'choices': [
            {'type': 'nodeSet', 'id': 'private-set'},
          ],
        },
      ]);
      expect(aiPolicyChangeSummary(differences), '新增规则“AI”');
      final details = aiPolicyChangeLines(
        differences,
        includeAddedDetails: true,
      ).join('\n');
      expect(details, contains('chatgpt'));
      expect(details, contains('1 项'));
      expect(details, isNot(contains('private')));
      expect(details, isNot(contains('https://')));
    },
  );

  test('large summaries are bounded while details retain every change', () {
    final differences = _changes('nodeSets', [], [
      for (var index = 0; index < 20; index++)
        {'id': '$index', 'label': '节点组$index'},
    ]);
    final summary = aiPolicyChangeSummary(differences);
    expect(summary.split('\n'), hasLength(5));
    expect(summary, contains('另有 16 项更改'));
    expect(aiPolicyChangeLines(differences), hasLength(20));
  });
}
