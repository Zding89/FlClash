import 'dart:convert';

import 'package:fl_clash/ai/policy_summary.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:flutter/material.dart';

Map<String, Object?>? aiPolicyPlan(
  BuildContext context,
  ConfigurationProposal proposal,
) {
  const supportedPaths = {
    'policies.policies',
    'policies.nodeSets',
    'policies.revision',
  };
  if (proposal.differences.isEmpty ||
      proposal.differences.any(
        (difference) => !supportedPaths.contains(difference.path),
      )) {
    return null;
  }
  Object? decode(Object? value, String path) {
    if (value is String) {
      try {
        value = jsonDecode(value);
      } catch (_) {
        return null;
      }
    }
    if (value is Map) {
      return value[path] ?? value[path.split('.').last] ?? value;
    }
    return value;
  }

  for (final difference in proposal.differences) {
    if (difference.path == 'policies.revision') continue;
    final old = decode(difference.before, difference.path);
    final next = decode(difference.after, difference.path);
    if (old is! List || next is! List) return null;
    final previous = {
      for (final entry in old.whereType<Map>()) entry['id']: entry,
    };
    final rule = difference.path == 'policies.policies';
    final allowed = rule
        ? {
            'id',
            'label',
            'enabled',
            'priority',
            'scope',
            'action',
            'choices',
            'origin',
            'userModified',
            'schedule',
          }
        : {
            'id',
            'label',
            'sourceIds',
            'excludedSourceIds',
            'regions',
            'excludedRegions',
            'nameIncludes',
            'nameExcludes',
            'preferences',
            'selectionMode',
            'schedule',
            'maxMultiplier',
            'unknownMultiplier',
            'allowUnknownRegion',
            'strategy',
          };
    for (final entry in next.whereType<Map>()) {
      if (rule &&
          ((entry['candidateNodeIds'] is List &&
                  (entry['candidateNodeIds'] as List).isNotEmpty) ||
              (entry['choices'] is List &&
                  (entry['choices'] as List).whereType<Map>().any(
                    (choice) => choice['type'] != 'nodeSet',
                  )))) {
        return null;
      }
      final baseline =
          previous[entry['id']] ??
          (rule
              ? const LocalPolicy(
                  id: 'default',
                  label: 'default',
                  targetId: localPolicyTargetId,
                ).toJson()
              : const PolicyNodeSet(
                  id: 'default',
                  label: 'default',
                  targetId: localPolicyTargetId,
                  sourceIds: ['1'],
                ).toJson());
      for (final key in entry.keys) {
        if (!allowed.contains(key) &&
            jsonEncode(entry[key]) != jsonEncode(baseline[key])) {
          return null;
        }
      }
    }
  }
  final saved = proposal.validation['localPolicyPlan'];
  if (saved is Map && saved['before'] is Map && saved['after'] is Map) {
    return Map<String, Object?>.from(saved);
  }
  final documents = proposal.validation['localPolicyDocuments'];
  if (documents is Map &&
      documents['before'] is Map &&
      documents['after'] is Map) {
    final labels = documents['sourceLabels'];
    final sourceLabels = <String, String>{
      if (labels is Map)
        for (final entry in labels.entries)
          if (entry.value is String) '${entry.key}': entry.value as String,
    };
    return {
      for (final name in ['before', 'after'])
        name: policyBusinessSummary(
          LocalPolicyDocument.fromJson(
            Map<String, Object?>.from(documents[name] as Map),
          ),
          context.appLocalizations,
          sourceLabels: sourceLabels,
        ),
    };
  }
  Map<String, Object?> side(bool after) {
    final rules = <LocalPolicy>[];
    final sets = <PolicyNodeSet>[];
    for (final difference in proposal.differences) {
      final value = decode(
        after ? difference.after : difference.before,
        difference.path,
      );
      if (value is! List) continue;
      for (final item in value.whereType<Map>()) {
        try {
          if (difference.path == 'policies.policies') {
            rules.add(LocalPolicy.fromJson(Map<String, Object?>.from(item)));
          }
          if (difference.path == 'policies.nodeSets') {
            sets.add(PolicyNodeSet.fromJson(Map<String, Object?>.from(item)));
          }
        } catch (_) {
          continue;
        }
      }
    }
    return policyBusinessSummary(
      LocalPolicyDocument(policies: rules, nodeSets: sets),
      context.appLocalizations,
    );
  }

  return {'before': side(false), 'after': side(true)};
}

class AiPolicyPlanView extends StatelessWidget {
  const AiPolicyPlanView({super.key, required this.plan, this.compact = false});
  final Map<String, Object?> plan;
  final bool compact;

  List<Map<String, Object?>> _rows(Object? value) => value is List
      ? value
            .whereType<Map>()
            .map((item) => Map<String, Object?>.from(item))
            .toList()
      : [];

  @override
  Widget build(BuildContext context) {
    final s = context.appLocalizations;
    final before = Map<String, Object?>.from(plan['before']! as Map);
    final after = Map<String, Object?>.from(plan['after']! as Map);
    final rules = _rows(after['rules']);
    final groups = _rows(after['nodeSets']);
    final previousRules = _rows(before['rules']);
    final previousGroups = _rows(before['nodeSets']);
    final colors = Theme.of(context).colorScheme;
    final changedGroups = groups.where((group) {
      final old = previousGroups
          .where((entry) => entry['id'] == group['id'])
          .firstOrNull;
      return old == null || jsonEncode(old) != jsonEncode(group);
    }).toList();
    Widget changes(
      String kind,
      List<Map<String, Object?>> old,
      List<Map<String, Object?>> next,
    ) {
      final oldById = {for (final value in old) value['id']: value};
      final nextById = {for (final value in next) value['id']: value};
      final added = next
          .where((value) => !oldById.containsKey(value['id']))
          .length;
      final removed = old
          .where((value) => !nextById.containsKey(value['id']))
          .length;
      final updated = next
          .where(
            (value) =>
                oldById.containsKey(value['id']) &&
                jsonEncode(oldById[value['id']]) != jsonEncode(value),
          )
          .length;
      return Text(
        s.aiPolicyPlanChanges(kind, '$added', '$updated', '$removed'),
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return Column(
      key: const ValueKey('ai-policy-plan'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.aiPolicyPlanCounts('${rules.length}', '${groups.length}'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        changes(s.rule, previousRules, rules),
        if (changedGroups.isNotEmpty || previousGroups.length != groups.length)
          changes(s.policyNodeSets, previousGroups, groups),
        if (rules.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            s.aiPolicyPlanOrder,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          for (final row in compact ? rules.take(5) : rules)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${row['order']}.',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${row['label']}${row['enabled'] == false ? ' · ${s.aiPolicyPlanDisabled}' : ''}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${row['match']} → ${row['action']}',
                          maxLines: compact ? 3 : null,
                          overflow: compact ? TextOverflow.ellipsis : null,
                        ),
                        if (row['schedule'] != s.policyScheduleAllDay)
                          Text(
                            '${s.policySchedule}: ${row['schedule']}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (changedGroups.isNotEmpty) ...[
          const Divider(height: 24),
          Text(s.policyNodeSets, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          for (final group in compact ? changedGroups.take(3) : changedGroups)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${group['label']}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${group['details']}',
                    maxLines: compact ? 3 : null,
                    overflow: compact ? TextOverflow.ellipsis : null,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class AiPolicyChangeOverview extends StatelessWidget {
  const AiPolicyChangeOverview({super.key, required this.proposal});
  final ConfigurationProposal proposal;

  @override
  Widget build(BuildContext context) {
    final s = context.appLocalizations;
    String label(String path) => switch (path.split('.')[1]) {
      'policies' || 'policiesEnabled' => s.rule,
      'nodeSets' => s.policyNodeSets,
      'moduleEnabled' => s.policyModule,
      'integrationEnabled' => s.policyEnableIntegrations,
      'budgetsEnabled' || 'budgets' => s.policyEnableBudgets,
      'integrations' => s.policySubscriptionSources,
      'overrides' => s.policyTemporaryOverride,
      'nodeAttributes' => s.policyRegions,
      _ => s.localPolicies,
    };
    String value(Object? raw) {
      if (raw is bool) return raw ? s.start : s.stop;
      if (raw is List) {
        final names = raw
            .whereType<Map>()
            .map((entry) => entry['label'])
            .whereType<String>()
            .toList();
        return '${raw.length}${names.isEmpty ? '' : ' · ${names.take(4).join(' / ')}'}';
      }
      if (raw is Map) return '${raw.length}';
      if (raw is num) return '$raw';
      return s.aiPolicyPlanReady;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final change in proposal.differences.where(
          (change) => change.path != 'policies.revision',
        ))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label(change.path),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${s.aiBefore}: ${value(change.before)} → ${s.aiAfter}: ${value(change.after)}',
                ),
              ],
            ),
          ),
      ],
    );
  }
}
