import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/l10n/l10n.dart';

const _equality = DeepCollectionEquality();

String aiPolicyChangeSummary(
  Iterable<ConfigurationDifference> differences, {
  Map<String, String> nodeSetLabels = const {},
  Map<String, String> sourceLabels = const {},
}) {
  final strings = AppLocalizations.current;
  final lines = aiPolicyChangeLines(
    differences,
    strings: strings,
    nodeSetLabels: nodeSetLabels,
    sourceLabels: sourceLabels,
  );
  if (lines.isEmpty) return strings.aiNoDifferences;
  return [
    ...lines.take(4),
    if (lines.length > 4) strings.aiPolicyChangeMore('${lines.length - 4}'),
  ].join('\n');
}

List<String> aiPolicyChangeLines(
  Iterable<ConfigurationDifference> differences, {
  AppLocalizations? strings,
  Map<String, String> nodeSetLabels = const {},
  Map<String, String> sourceLabels = const {},
  bool includeAddedDetails = false,
}) {
  final s = strings ?? AppLocalizations.current;
  final changes = differences.toList();
  final groups = {
    ..._resourceLabels(changes, 'policies.nodeSets'),
    ...nodeSetLabels,
  };
  final sources = {
    ..._resourceLabels(changes, 'policies.sources'),
    ...sourceLabels,
  };
  String transition(String field, Object? before, Object? after) =>
      _transition(field, before, after, s, groups, sources);
  final lines = <String>[];
  for (final difference in changes) {
    if (!difference.path.startsWith('policies.')) continue;
    final path = difference.path.substring('policies.'.length);
    if ({'revision', 'schemaVersion'}.contains(path)) continue;
    final before = _decode(difference.before);
    final after = _decode(difference.after);
    final kind = _kind(path, s);
    if (before is List && after is List) {
      final previous = _byId(before);
      final next = _byId(after);
      if (previous.length == before.length && next.length == after.length) {
        final beforeOrder = _order(previous, path);
        final afterOrder = _order(next, path);
        final sharedBefore = beforeOrder.where(next.containsKey).toList();
        final sharedAfter = afterOrder.where(previous.containsKey).toList();
        final reordered =
            path == 'policies' && !_equality.equals(sharedBefore, sharedAfter);
        for (final entry in previous.entries) {
          if (!next.containsKey(entry.key)) {
            lines.add(s.aiPolicyChangeRemoved(kind, _label(entry.value, s)));
          }
        }
        for (final entry in next.entries) {
          final old = previous[entry.key];
          final label = _label(entry.value, s);
          if (old == null) {
            lines.add(s.aiPolicyChangeAdded(kind, label));
            if (includeAddedDetails) {
              for (final field in [
                'scope',
                'action',
                'choices',
                'sourceIds',
                'excludedSourceIds',
                'regions',
                'excludedRegions',
                'nameIncludes',
                'nameExcludes',
                'maxMultiplier',
              ]) {
                final raw = entry.value[field];
                if (raw == null || (raw is List && raw.isEmpty)) continue;
                final value = _value(field, raw, s, groups, sources);
                if (value == null) continue;
                lines.add(
                  s.aiPolicyChangeField(kind, label, _field(field, s), value),
                );
              }
            }
            continue;
          }
          final fields = {...old.keys, ...entry.value.keys};
          for (final field in fields) {
            if ({
              'id',
              'targetId',
              'origin',
              'userModified',
              'priority',
            }.contains(field)) {
              continue;
            }
            if (_equality.equals(old[field], entry.value[field])) continue;
            if (field == 'probe' &&
                old[field] is Map &&
                entry.value[field] is Map) {
              final oldProbe = old[field] as Map;
              final nextProbe = entry.value[field] as Map;
              for (final probeField in {...oldProbe.keys, ...nextProbe.keys}) {
                if (_equality.equals(
                  oldProbe[probeField],
                  nextProbe[probeField],
                )) {
                  continue;
                }
                lines.add(
                  s.aiPolicyChangeField(
                    kind,
                    label,
                    '${s.policyProbe} · ${_field('$probeField', s)}',
                    transition(
                      '$probeField',
                      oldProbe[probeField],
                      nextProbe[probeField],
                    ),
                  ),
                );
              }
              continue;
            }
            lines.add(
              s.aiPolicyChangeField(
                kind,
                field == 'label' ? _label(old, s) : label,
                _field('$field', s),
                transition('$field', old[field], entry.value[field]),
              ),
            );
          }
          if (reordered &&
              sharedBefore.indexOf(entry.key) !=
                  sharedAfter.indexOf(entry.key)) {
            lines.add(
              s.aiPolicyChangeField(
                kind,
                label,
                s.aiPolicyChangeRuleOrder,
                '${s.aiPolicyChangePosition('${beforeOrder.indexOf(entry.key) + 1}')} → ${s.aiPolicyChangePosition('${afterOrder.indexOf(entry.key) + 1}')}',
              ),
            );
          }
        }
        continue;
      }
    }
    lines.add('${_field(path, s)}: ${transition(path, before, after)}');
  }
  return lines.toSet().toList();
}

Map<String, String> _resourceLabels(
  List<ConfigurationDifference> differences,
  String path,
) => {
  for (final difference in differences.where((entry) => entry.path == path))
    for (final raw in [difference.before, difference.after])
      if (_decode(raw) case final List values)
        for (final value in values.whereType<Map>())
          if (value['id'] != null && value['label'] is String)
            '${value['id']}': value['label'] as String,
};

Object? _decode(Object? value) {
  if (value is! String) return value;
  try {
    return jsonDecode(value);
  } catch (_) {
    return value;
  }
}

Map<Object, Map> _byId(List values) => {
  for (final value in values)
    if (value is Map && value['id'] != null) value['id'] as Object: value,
};

List<Object> _order(Map<Object, Map> values, String path) {
  final entries = values.entries.toList();
  final positions = {
    for (final entry in entries.indexed) entry.$2.key: entry.$1,
  };
  if (path == 'policies') {
    entries.sort((a, b) {
      final priority = (a.value['priority'] as num? ?? 100).compareTo(
        b.value['priority'] as num? ?? 100,
      );
      return priority == 0
          ? positions[a.key]!.compareTo(positions[b.key]!)
          : priority;
    });
  }
  return entries.map((entry) => entry.key).toList();
}

String _label(Map value, AppLocalizations s) =>
    _safeText(value['label'] is String ? value['label'] as String : s.unnamed);

String _safeText(String value, {int limit = 64}) {
  final safe = value
      .replaceAll(RegExp(r'https?://\S+', caseSensitive: false), '…')
      .replaceAll(RegExp(r'[\r\n\x00-\x1f]+'), ' ')
      .trim();
  return safe.length > limit ? '${safe.substring(0, limit)}…' : safe;
}

String _kind(String path, AppLocalizations s) => switch (path) {
  'nodeSets' => s.policyNodeSet,
  'policies' => s.rule,
  'sources' || 'integrations' => s.policySources,
  'budgets' => s.policyEnableBudgets,
  _ => s.localPolicies,
};

String _field(String field, AppLocalizations s) => switch (field) {
  'label' => s.name,
  'enabled' => s.status,
  'policiesEnabled' => s.policyEnableRules,
  'moduleEnabled' => s.policyModule,
  'integrationEnabled' => s.policyEnableIntegrations,
  'budgetsEnabled' || 'budgets' => s.policyEnableBudgets,
  'sourceIds' || 'sourceProfileIds' => s.policyIncludeSources,
  'excludedSourceIds' => s.policyExcludeSources,
  'regions' => s.policyIncludeRegions,
  'excludedRegions' => s.policyExcludeRegions,
  'allowUnknownRegion' => s.aiPolicyUnknownRegionAllowed,
  'maxMultiplier' => s.policyMultiplierLimit,
  'unknownMultiplier' => s.policyUnknownAttribute,
  'nameIncludes' => s.policyNameIncludes,
  'nameExcludes' => s.policyNameExcludes,
  'scope' => s.aiPolicyFilterConditions,
  'selectionMode' => s.policySelectionMode,
  'strategy' || 'balanceStrategy' => s.policyNodeSetStrategy,
  'preferences' => s.policyPreferences,
  'action' => s.action,
  'choices' => s.policyNodeSets,
  'candidateNodeIds' => s.proxies,
  'schedule' => s.policySchedule,
  'probe' => s.policyProbe,
  'url' => s.policyProbeUrl,
  'intervalSeconds' => s.policyProbeInterval,
  'timeoutSeconds' => s.policyProbeTimeout,
  'failureThreshold' => s.policyFailures,
  'successThreshold' => s.policySuccesses,
  'expectedStatus' => s.policyExpectedStatus,
  'method' => s.policyMethod,
  'automatic' => s.policyAutoCheck,
  'retrySeconds' => s.policyRetrySeconds,
  'validitySeconds' => s.policyValiditySeconds,
  'guard' => s.policyAdmission,
  'autoRecover' => s.policyAutoRecover,
  'recoverySeconds' => s.policyRecoverySeconds,
  'cooldownSeconds' => s.policyCooldownSeconds,
  'fallback' => s.policyFallback,
  'terminateConnectionsOnExclusion' => s.policyTerminate,
  'hideUnavailable' => s.policyHideUnavailable,
  'improvementPercent' => s.policyImprovementPercent,
  'integrations' || 'sources' => s.policySources,
  'activeIntegrationId' => s.policyActiveIntegration,
  'sourceUpdateRoute' => s.policySources,
  'overrides' => s.policyTemporaryOverride,
  'nodeAttributes' => s.policyRegions,
  _ => s.aiPolicyChangeOtherFields,
};

String _transition(
  String field,
  Object? before,
  Object? after,
  AppLocalizations s,
  Map<String, String> nodeSetLabels,
  Map<String, String> sourceLabels,
) {
  final old = _value(field, before, s, nodeSetLabels, sourceLabels);
  final next = _value(field, after, s, nodeSetLabels, sourceLabels);
  if (old == null || next == null) return s.aiPolicyChangeAdjusted;
  if (old == next) return '${s.aiPolicyChangeAdjusted} ($next)';
  return '$old → $next';
}

String? _value(
  String field,
  Object? value,
  AppLocalizations s,
  Map<String, String> nodeSetLabels,
  Map<String, String> sourceLabels,
) {
  if (value == null) return s.aiPolicyChangeEmpty;
  if (value is bool) {
    return value ? s.aiPolicyChangeEnabled : s.aiPolicyChangeDisabled;
  }
  if (value is num &&
      {
        'maxMultiplier',
        'intervalSeconds',
        'timeoutSeconds',
        'failureThreshold',
        'successThreshold',
        'retrySeconds',
        'validitySeconds',
        'recoverySeconds',
        'cooldownSeconds',
        'improvementPercent',
      }.contains(field)) {
    return field == 'maxMultiplier' ? '$value×' : '$value';
  }
  if (field == 'label' && value is String) return _safeText(value);
  if (value is List) {
    if ({
      'sourceIds',
      'sourceProfileIds',
      'excludedSourceIds',
    }.contains(field)) {
      return _references(value.map((id) => sourceLabels['$id']), s);
    }
    if (field == 'choices') {
      return _references(
        value.map(
          (choice) => choice is Map && choice['type'] == 'nodeSet'
              ? nodeSetLabels['${choice['id']}']
              : null,
        ),
        s,
      );
    }
    if (field == 'candidateNodeIds') {
      return s.aiPolicyChangeReferences('${value.length}');
    }
    if ({'nameIncludes', 'nameExcludes'}.contains(field)) {
      return _filterValues(value, s);
    }
  }
  if (field == 'scope' && value is Map) {
    return _safeText(_scope(value, s), limit: 240);
  }
  if (field == 'expectedStatus' &&
      value is String &&
      RegExp(r'^\d{3}(?:-\d{3})?$').hasMatch(value)) {
    return value;
  }
  if ({'regions', 'excludedRegions'}.contains(field) && value is List) {
    if (value.isEmpty) return s.aiPolicyChangeEmpty;
    final regions = value
        .take(4)
        .map(
          (region) => switch (region) {
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
            _ => s.policyUnknownAttribute,
          },
        );
    return '${regions.join(' / ')}${value.length > 4 ? ' / …' : ''}';
  }
  return switch ('$field:$value') {
    'action:direct' || 'fallback:direct' => s.policyActionDirect,
    'action:reject' || 'fallback:reject' => s.policyActionReject,
    'action:proxy' => s.policyActionProxy,
    'selectionMode:loadBalance' => s.policyBalanceMode,
    'selectionMode:priority' => s.policyPriorityMode,
    'strategy:stable' => s.policyStableFirst,
    'strategy:latency' => s.policyLatencyFirst,
    'strategy:multiplier' => s.policyMultiplierFirst,
    'unknownMultiplier:assumeOne' => s.policyUnknownOne,
    'unknownMultiplier:allow' => s.policyUnknownMultiplierAllowed,
    'unknownMultiplier:exclude' => s.aiPolicyUnknownMultiplierExcluded,
    'method:HEAD' => 'HEAD',
    'method:GET' => 'GET',
    _ => null,
  };
}

String _references(Iterable<String?> names, AppLocalizations s) {
  final values = names.toList();
  if (values.isEmpty) return s.aiPolicyChangeEmpty;
  final labels = values.whereType<String>().map(_safeText).take(4).toList();
  final unknown = values.where((value) => value == null).length;
  if (unknown > 0) labels.add(s.aiPolicyChangeReferences('$unknown'));
  if (values.whereType<String>().length > 4) labels.add('…');
  return labels.join(' / ');
}

String _filterValues(List values, AppLocalizations s) {
  if (values.isEmpty) return s.aiPolicyChangeEmpty;
  final labels = values.whereType<String>().take(3).map(_safeText);
  return '${labels.join(' / ')}${values.length > 3 ? ' / …' : ''}';
}

String _scope(Map value, AppLocalizations s, [int depth = 0]) {
  if (depth >= 3) return s.aiPolicyFilterConditions;
  if (value['type'] == 'global') return s.policyRemainingTraffic;
  final type = switch (value['type']) {
    'domain' => s.policyDomainScope,
    'domainSuffix' => s.policyDomainSuffix,
    'domainKeyword' => s.policyDomainKeyword,
    'processName' => s.policyProcessName,
    'processPath' || 'processPathRegex' => s.policyProcessPath,
    'destinationRegion' => s.policyRegions,
    'all' => s.policyMatchAll,
    'any' => s.policyMatchAny,
    'not' => s.policyMatchNot,
    _ => s.aiPolicyFilterConditions,
  };
  final children = value['children'];
  if (children is List && children.isNotEmpty) {
    return '$type (${children.whereType<Map>().take(3).map((child) => _scope(child, s, depth + 1)).join(' / ')})';
  }
  final values = value['values'];
  return values is List ? '$type: ${_filterValues(values, s)}' : type;
}
