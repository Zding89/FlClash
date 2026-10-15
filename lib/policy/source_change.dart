import 'package:fl_clash/models/profile.dart';

import 'models.dart';
import 'quota_overview.dart';

const localSourceChangeValidationKey = 'localSourceChange';

final class LocalSourceChangeTotals {
  const LocalSourceChangeTotals({
    required this.sourceCount,
    required this.nodeCount,
    required this.remainingBytes,
    this.unresolvedNodeSources = const [],
    this.unknownQuotaSources = const [],
  });

  final int sourceCount;
  final int nodeCount;
  final int remainingBytes;
  final List<String> unresolvedNodeSources;
  final List<String> unknownQuotaSources;

  bool get nodesComplete => unresolvedNodeSources.isEmpty;
  bool get quotaComplete => unknownQuotaSources.isEmpty;

  factory LocalSourceChangeTotals.fromJson(Map<String, Object?> json) =>
      LocalSourceChangeTotals(
        sourceCount: _count(json['sourceCount']),
        nodeCount: _count(json['nodeCount']),
        remainingBytes: _count(json['remainingBytes']),
        unresolvedNodeSources: _labels(json['unresolvedNodeSources']),
        unknownQuotaSources: _labels(json['unknownQuotaSources']),
      );

  Map<String, Object?> toJson() => {
    'sourceCount': sourceCount,
    'nodeCount': nodeCount,
    'remainingBytes': remainingBytes,
    'unresolvedNodeSources': unresolvedNodeSources,
    'unknownQuotaSources': unknownQuotaSources,
  };
}

final class LocalSourceChangeSummary {
  const LocalSourceChangeSummary({
    required this.addedSources,
    required this.removedSources,
    required this.before,
    required this.after,
  });

  final List<String> addedSources;
  final List<String> removedSources;
  final LocalSourceChangeTotals before;
  final LocalSourceChangeTotals after;

  static LocalSourceChangeSummary? tryParse(Object? value) {
    try {
      final json = policyObject(value, 'sourceChange');
      return LocalSourceChangeSummary(
        addedSources: _labels(json['addedSources']),
        removedSources: _labels(json['removedSources']),
        before: LocalSourceChangeTotals.fromJson(
          policyObject(json['before'], 'before'),
        ),
        after: LocalSourceChangeTotals.fromJson(
          policyObject(json['after'], 'after'),
        ),
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Map<String, Object?> toJson() => {
    'addedSources': addedSources,
    'removedSources': removedSources,
    'before': before.toJson(),
    'after': after.toJson(),
  };
}

int _count(Object? value) {
  if (value is! int || value < 0) {
    throw const FormatException('Invalid source change count');
  }
  return value;
}

List<String> _labels(Object? value) {
  if (value is! List || value.any((entry) => entry is! String)) {
    throw const FormatException('Invalid source labels');
  }
  return List.unmodifiable(value.cast<String>());
}

Future<LocalSourceChangeSummary?> summarizeLocalSourceChange({
  required LocalPolicyDocument before,
  required LocalPolicyDocument after,
  required List<Profile> profiles,
  required Future<List<LocalNode>> Function(Profile profile) loadNodes,
}) async {
  final previous = before.asStandalone();
  final next = after.asStandalone();
  final previousIds = previous.localProfile.sourceProfileIds;
  final nextIds = next.localProfile.sourceProfileIds;
  if (policyDigest(previousIds) == policyDigest(nextIds)) return null;
  Map<String, Object?> withoutSources(LocalPolicyDocument document) => {
    ...document.toJson(),
    'revision': 0,
    'integrations': [
      for (final integration in document.integrations)
        if (integration.id == localPolicyProfileId)
          {...integration.toJson(), 'sourceProfileIds': <Object?>[]}
        else
          integration.toJson(),
    ],
  };
  if (policyDigest(withoutSources(previous)) !=
      policyDigest(withoutSources(next))) {
    return null;
  }
  final byId = {for (final profile in profiles) profile.id: profile};
  final ids = {...previousIds, ...nextIds};
  if (!byId.keys.toSet().containsAll(ids)) return null;
  final nodes = <int, List<LocalNode>>{};
  final unresolved = <int>{};
  for (final id in ids) {
    try {
      nodes[id] = await loadNodes(byId[id]!);
    } catch (_) {
      unresolved.add(id);
    }
  }
  LocalSourceChangeTotals totals(List<int> selectedIds) {
    final selected = selectedIds.toSet().map((id) => byId[id]!).toList();
    final quota = const LocalQuotaOverviewCalculator().calculate(
      profiles: selected,
    );
    final integration = next.localProfile;
    final count = selectedIds
        .expand((id) => nodes[id] ?? const <LocalNode>[])
        .where((node) {
          if (integration.excludedNodeIds.contains(node.id)) return false;
          final filter = integration.nameFilter;
          return filter == null ||
              filter.isEmpty ||
              node.label.toLowerCase().contains(filter.toLowerCase());
        })
        .map((node) => node.id)
        .toSet()
        .length;
    return LocalSourceChangeTotals(
      sourceCount: selected.length,
      nodeCount: count,
      remainingBytes: quota.remainingBytes,
      unresolvedNodeSources: [
        for (final id in selectedIds.toSet())
          if (unresolved.contains(id)) byId[id]!.realLabel,
      ],
      unknownQuotaSources: [
        for (final source in quota.sources)
          if (!source.trafficKnown) source.profile.realLabel,
      ],
    );
  }

  return LocalSourceChangeSummary(
    addedSources: [
      for (final id in nextIds)
        if (!previousIds.contains(id)) byId[id]!.realLabel,
    ],
    removedSources: [
      for (final id in previousIds)
        if (!nextIds.contains(id)) byId[id]!.realLabel,
    ],
    before: totals(previousIds),
    after: totals(nextIds),
  );
}
