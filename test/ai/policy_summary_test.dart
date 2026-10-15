import 'package:fl_clash/ai/policy_summary.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async => AppLocalizations.load(const Locale('zh', 'CN')));

  LocalPolicy rule(
    String id,
    int priority, {
    PolicyMatch? scope,
    String set = 'us',
    PolicyAction action = PolicyAction.proxy,
  }) => LocalPolicy(
    id: id,
    label: id,
    priority: priority,
    targetId: localPolicyTargetId,
    scope: scope ?? const PolicyMatch(type: PolicyMatchType.global),
    action: action,
    choices: action == PolicyAction.proxy
        ? [PolicyChoice(type: PolicyChoiceType.nodeSet, id: set)]
        : [],
  );

  test(
    'country matching and actual ordered rules form the authoritative reply',
    () {
      final document = LocalPolicyDocument(
        policies: [
          rule('国外', 3, set: 'hk'),
          rule(
            '国内',
            2,
            action: PolicyAction.direct,
            scope: const PolicyMatch(
              type: PolicyMatchType.destinationRegion,
              values: ['CN'],
            ),
          ),
          rule(
            'AI',
            1,
            scope: const PolicyMatch(
              type: PolicyMatchType.domainKeyword,
              values: ['chatgpt', 'claude'],
            ),
          ),
        ],
        nodeSets: const [
          PolicyNodeSet(
            id: 'us',
            label: '美国低倍率',
            targetId: localPolicyTargetId,
            sourceIds: ['7'],
            regions: ['US'],
            maxMultiplier: 0.1,
            preferences: [
              NodePreference(
                type: NodePreferenceType.multiplier,
                direction: SortDirection.ascending,
              ),
            ],
          ),
          PolicyNodeSet(
            id: 'hk',
            label: '香港',
            targetId: localPolicyTargetId,
            sourceIds: ['7'],
            regions: ['HK'],
          ),
        ],
      );
      final summary = policyBusinessSummary(
        document,
        AppLocalizations.current,
        sourceLabels: {'7': '测试机场'},
      );
      final rows = summary['rules'] as List;
      expect(summary['ruleCount'], 3);
      expect(rows.map((row) => (row as Map)['label']), ['AI', '国内', '国外']);
      expect((rows[1] as Map)['match'], '国内（中国） (GeoIP)');
      expect((rows[1] as Map)['action'], '直连');
      final reply = summary['reply'] as String;
      expect(reply, contains('3 条规则 · 2 个节点组'));
      expect(reply.indexOf('**AI**'), lessThan(reply.indexOf('**国内**')));
      expect(reply, contains('0.1×'));
      expect(reply, contains('测试机场'));
      expect(reply, isNot(contains(r'\n')));
      expect(reply, isNot(contains('policies.')));
      expect(reply, isNot(contains('integration:')));
    },
  );

  test(
    'obsolete identical global is rejected while empty-group continuation remains allowed',
    () {
      final duplicate = LocalPolicyDocument(
        policies: [
          rule('旧全部香港', 1, set: 'hk'),
          rule(
            '国内',
            2,
            action: PolicyAction.direct,
            scope: const PolicyMatch(
              type: PolicyMatchType.destinationRegion,
              values: ['CN'],
            ),
          ),
          rule('新全部香港', 3, set: 'hk'),
        ],
      );
      final invalid = policyPlanValidation(duplicate);
      expect(invalid['valid'], false);
      expect((invalid['issues'] as List).single['code'], 'duplicate_rule');
      final valid = policyPlanValidation(
        LocalPolicyDocument(
          policies: [
            rule('先试美国', 1),
            rule('再试香港', 2, set: 'hk'),
          ],
        ),
      );
      expect(valid['valid'], true);
      expect(
        (valid['warnings'] as List).single['code'],
        'global_before_later_rules',
      );
    },
  );

  test('ambiguous priority is not passed off as an established rule order', () {
    expect(
      policyPlanValidation(
        LocalPolicyDocument(
          policies: [
            rule('美国', 1),
            rule('香港', 1, set: 'hk'),
          ],
        ),
      )['valid'],
      false,
    );
  });
  test('disabled rule sharing an enabled priority stays a valid document', () {
    final enabled = rule('enabled', 1);
    final disabled = LocalPolicy.fromJson({
      ...rule('disabled', 1, set: 'hk').toJson(),
      'enabled': false,
    });
    expect(
      policyPlanValidation(
        LocalPolicyDocument(policies: [enabled, disabled]),
      )['valid'],
      true,
    );
  });
}
