import 'dart:convert';

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/policy/models.dart';

String _inline(String text) => text
    .replaceAll(RegExp(r'[\r\n]+'), ' ')
    .replaceAllMapped(
      RegExp(r'([\\`*_{}\[\]<>|])'),
      (match) => '\\${match[0]}',
    );

String _region(AppLocalizations s, String code) => switch (code) {
  'CN' => s.policyRegionCN,
  'HK' => s.policyRegionHK,
  'US' => s.policyRegionUS,
  'JP' => s.policyRegionJP,
  'TW' => s.policyRegionTW,
  'SG' => s.policyRegionSG,
  'KR' => s.policyRegionKR,
  'GB' => s.policyRegionGB,
  'DE' => s.policyRegionDE,
  'FR' => s.policyRegionFR,
  'CA' => s.policyRegionCA,
  'AU' => s.policyRegionAU,
  _ => code,
};

String _match(AppLocalizations s, PolicyMatch match) {
  if (match.type == PolicyMatchType.global) return s.policyRemainingTraffic;
  if (match.children.isNotEmpty) {
    final operation = switch (match.type) {
      PolicyMatchType.all => s.policyMatchAll,
      PolicyMatchType.any => s.policyMatchAny,
      _ => s.policyMatchNot,
    };
    return '$operation (${match.children.map((value) => _match(s, value)).join(' / ')})';
  }
  if (match.type == PolicyMatchType.destinationRegion) {
    return '${match.values.map((value) => value == 'CN'
        ? s.policyDomestic
        : value == '!CN'
        ? s.policyForeign
        : value.startsWith('!')
        ? '${s.policyMatchNot}: ${_region(s, value.substring(1))}'
        : _region(s, value)).join(' / ')} (GeoIP)';
  }
  final label = switch (match.type) {
    PolicyMatchType.domain => s.policyDomainScope,
    PolicyMatchType.domainSuffix => s.policyDomainSuffix,
    PolicyMatchType.domainKeyword => s.policyDomainKeyword,
    PolicyMatchType.processName => s.policyProcessName,
    PolicyMatchType.processPath ||
    PolicyMatchType.processPathRegex => s.policyProcessPath,
    PolicyMatchType.ipCidr || PolicyMatchType.ipCidr6 => 'IP',
    _ => s.rule,
  };
  return '$label: ${match.values.join(' / ')}';
}

String _schedule(AppLocalizations s, PolicySchedule schedule) {
  if (schedule.windows.isEmpty) return s.policyScheduleAllDay;
  String time(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
  return '${schedule.timeZone} · ${schedule.windows.map((window) => '${window.weekdays.join(',')} ${time(window.startMinute)}–${time(window.endMinute)}').join(' / ')}';
}

Map<String, Object?> policyPlanValidation(LocalPolicyDocument document) {
  final rules = orderedPolicies(document.policies);
  final issues = <Map<String, Object?>>[];
  final warnings = <Map<String, Object?>>[];
  final seen = <String, String>{};
  final priorities = <int>{};
  for (var i = 0; i < rules.length; i++) {
    final rule = rules[i];
    if (!rule.enabled) continue;
    if (!priorities.add(rule.priority)) {
      issues.add({'code': 'ambiguous_rule_order', 'ruleId': rule.id});
    }
    final semantics = rule.toJson()
      ..removeWhere(
        (key, _) =>
            {'id', 'label', 'priority', 'origin', 'userModified'}.contains(key),
      );
    final fingerprint = jsonEncode(semantics);
    final previous = seen[fingerprint];
    if (previous != null) {
      issues.add({
        'code': 'duplicate_rule',
        'ruleId': rule.id,
        'previousRuleId': previous,
        'label': rule.label,
      });
    }
    seen[fingerprint] = rule.id;
    if (rule.scope.type == PolicyMatchType.global && i < rules.length - 1) {
      warnings.add({'code': 'global_before_later_rules', 'ruleId': rule.id});
    }
  }
  return {'valid': issues.isEmpty, 'issues': issues, 'warnings': warnings};
}

Map<String, Object?> policyBusinessSummary(
  LocalPolicyDocument document,
  AppLocalizations s, {
  Map<String, String> sourceLabels = const {},
}) {
  final groups = {for (final set in document.nodeSets) set.id: set};
  final rules = orderedPolicies(document.policies);
  final rows = <Map<String, Object?>>[];
  for (var i = 0; i < rules.length; i++) {
    final rule = rules[i];
    final labels = [
      for (final choice in rule.choices)
        choice.type == PolicyChoiceType.nodeSet
            ? groups[choice.id]?.label ?? s.policyNodeSet
            : '${s.proxies}: ${choice.id}',
    ];
    final action = switch (rule.action) {
      PolicyAction.direct => s.policyActionDirect,
      PolicyAction.reject => s.policyActionReject,
      PolicyAction.proxy =>
        labels.isEmpty ? s.policyActionProxy : labels.join(' → '),
    };
    rows.add({
      'id': rule.id,
      'label': rule.label,
      'order': i + 1,
      'enabled': rule.enabled,
      'match': _match(s, rule.scope),
      'action': action,
      'nodeGroupLabels': labels,
      'choices': rule.choices.map((choice) => choice.toJson()).toList(),
      'schedule': _schedule(s, rule.schedule),
    });
  }
  String sources(List<String> ids) =>
      ids.map((id) => sourceLabels[id] ?? s.policySources).toSet().join(' / ');
  final sets = [
    for (final set in document.nodeSets)
      {
        'id': set.id,
        'label': set.label,
        'details': [
          if (set.sourceIds.isNotEmpty)
            '${s.policyIncludeSources}: ${sources(set.sourceIds)}',
          if (set.excludedSourceIds.isNotEmpty)
            '${s.policyExcludeSources}: ${sources(set.excludedSourceIds)}',
          if (set.regions.isNotEmpty)
            '${s.policyIncludeRegions}: ${set.regions.map((code) => _region(s, code)).join(' / ')}',
          if (set.excludedRegions.isNotEmpty)
            '${s.policyExcludeRegions}: ${set.excludedRegions.map((code) => _region(s, code)).join(' / ')}',
          if (set.allowUnknownRegion) s.aiPolicyUnknownRegionAllowed,
          if (set.nameIncludes.isNotEmpty)
            '${s.policyNameIncludes}: ${set.nameIncludes.join(' / ')}',
          if (set.nameExcludes.isNotEmpty)
            '${s.policyNameExcludes}: ${set.nameExcludes.join(' / ')}',
          if (set.maxMultiplier != null)
            '${s.policyMultiplierLimit}: ${set.maxMultiplier}×',
          if (set.maxMultiplier != null ||
              set.preferences.any(
                (preference) =>
                    preference.type == NodePreferenceType.multiplier,
              ))
            switch (set.unknownMultiplier) {
              UnknownMultiplier.assumeOne => s.policyUnknownOne,
              UnknownMultiplier.exclude => s.aiPolicyUnknownMultiplierExcluded,
              UnknownMultiplier.allow => s.policyUnknownMultiplierAllowed,
            },
          set.selectionMode == NodeSelectionMode.loadBalance
              ? s.policyBalanceMode
              : s.policyPriorityMode,
          if (set.preferences.isEmpty)
            switch (set.strategy) {
              NodeSetStrategy.stable => s.policyStableFirst,
              NodeSetStrategy.latency => s.policyLatencyFirst,
              NodeSetStrategy.multiplier => s.policyMultiplierFirst,
            },
          for (final preference in set.preferences)
            '${switch (preference.type) {
              NodePreferenceType.expiry => s.policyPreferenceExpiry,
              NodePreferenceType.remaining => s.policyPreferenceRemaining,
              NodePreferenceType.latency => s.policyPreferenceLatency,
              NodePreferenceType.multiplier => s.policyPreferenceMultiplier,
              NodePreferenceType.source => s.policyPreferenceSource,
            }}: ${switch (preference.type) {
              NodePreferenceType.expiry => preference.direction == SortDirection.ascending ? s.policyEarlierFirst : s.policyLaterFirst,
              NodePreferenceType.remaining => preference.direction == SortDirection.ascending ? s.policyLessFirst : s.policyMoreFirst,
              _ => preference.direction == SortDirection.ascending ? s.policyLowerFirst : s.policyHigherFirst,
            }}',
          if (set.schedule.windows.isNotEmpty)
            '${s.policySchedule}: ${_schedule(s, set.schedule)}',
        ].join(' · '),
      },
  ];
  final reply = [
    s.aiPolicyPlanReady,
    '',
    s.aiPolicyPlanCounts('${rows.length}', '${sets.length}'),
    '',
    '**${s.aiPolicyPlanOrder}**',
    if (rows.isEmpty) s.aiPolicyPlanNoRules,
    for (final row in rows)
      '${row['order']}. **${_inline(row['label'] as String)}**${row['enabled'] == false ? ' (${s.aiPolicyPlanDisabled})' : ''}\n   ${_inline(row['match'] as String)} → ${_inline(row['action'] as String)}${row['schedule'] != s.policyScheduleAllDay ? '\n   ${_inline(row['schedule'] as String)}' : ''}',
    if (sets.isNotEmpty) ...[
      '',
      '**${s.policyNodeSets}**',
      for (final set in sets)
        '- **${_inline(set['label']!)}**: ${_inline(set['details']!)}',
    ],
    '',
    s.policyContinueNextRule,
  ].join('\n');
  return {
    'version': 1,
    'targetId': localPolicyTargetId,
    'ruleCount': rows.length,
    'nodeSetCount': sets.length,
    'rules': rows,
    'nodeSets': sets,
    'reply': reply,
  };
}
