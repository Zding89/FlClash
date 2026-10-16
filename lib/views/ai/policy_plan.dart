import 'dart:convert';

import 'package:fl_clash/ai/policy_summary.dart';
import 'package:fl_clash/ai/policy_change_summary.dart';
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
  const AiPolicyPlanView({
    super.key,
    required this.proposal,
    this.compact = false,
  });
  final ConfigurationProposal proposal;
  final bool compact;

  @override
  Widget build(BuildContext context) => AiPolicyChangeOverview(
    key: const ValueKey('ai-policy-plan'),
    proposal: proposal,
    compact: compact,
  );
}

class AiPolicyChangeOverview extends StatelessWidget {
  const AiPolicyChangeOverview({
    super.key,
    required this.proposal,
    this.compact = true,
  });
  final ConfigurationProposal proposal;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = context.appLocalizations;
    final nodeSetLabels = <String, String>{};
    final sourceLabels = <String, String>{};
    for (final key in ['localPolicyPlan', 'localPolicyDocuments']) {
      final metadata = proposal.validation[key];
      if (metadata is! Map) continue;
      final labels = metadata['sourceLabels'];
      if (labels is Map) {
        for (final entry in labels.entries) {
          if (entry.value is String) {
            sourceLabels['${entry.key}'] = entry.value as String;
          }
        }
      }
      for (final side in ['before', 'after']) {
        final document = metadata[side];
        if (document is! Map) continue;
        final groups = document['nodeSets'];
        if (groups is! List) continue;
        for (final group in groups.whereType<Map>()) {
          if (group['id'] != null && group['label'] is String) {
            nodeSetLabels['${group['id']}'] = group['label'] as String;
          }
        }
      }
    }
    final lines = aiPolicyChangeLines(
      proposal.differences,
      strings: s,
      nodeSetLabels: nodeSetLabels,
      sourceLabels: sourceLabels,
      includeAddedDetails: !compact,
    );
    final summary = proposal.summary.trim();
    final legacySummary = {
      '',
      s.localPolicies,
      s.rule,
      s.aiPolicyPlanTitle,
      '本地规则',
      'Local rules',
      'Local policies',
    }.contains(summary);
    final displayed = compact && !legacySummary
        ? [summary]
        : compact
        ? [
            ...lines.take(4),
            if (lines.length > 4) s.aiPolicyChangeMore('${lines.length - 4}'),
          ]
        : lines;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact) ...[
          Text(
            s.aiPolicyChangeBaseline,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 12),
        ],
        if (displayed.isEmpty) Text(s.aiNoDifferences),
        for (final line in displayed)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(line)),
      ],
    );
  }
}
