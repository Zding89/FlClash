import 'package:fl_clash/models/profile.dart';

import 'compiler.dart';
import 'models.dart';
import 'sources.dart';

final class PolicyProfileService {
  final PolicySourceLoader loader;
  final LocalPolicyCompiler compiler;

  const PolicyProfileService({
    required this.loader,
    this.compiler = const LocalPolicyCompiler(),
  });

  List<Profile> requiredProfiles({
    required LocalPolicyDocument document,
    required List<Profile> profiles,
    required int? profileId,
  }) {
    final integration = document.moduleEnabled && document.integrationEnabled
        ? document.activeIntegration
        : null;
    final ids = integration != null
        ? integration.sourceProfileIds.toSet()
        : !document.isStandalone &&
              document.moduleEnabled &&
              document.policiesEnabled
        ? document.sourceProfileIdsForTarget('profile:$profileId')
        : {?profileId};
    final selected = profiles
        .where((profile) => ids.contains(profile.id))
        .toList();
    if (selected.length != ids.length) {
      throw const FormatException('A policy source profile is missing');
    }
    return selected;
  }

  Future<CompiledPolicyProfile> compile({
    required LocalPolicyDocument document,
    required List<Profile> profiles,
    required int? profileId,
    required Map<String, Object?> baseConfig,
    bool persistCache = false,
    bool allowNetwork = false,
    bool enforceCandidateReferences = false,
  }) async {
    if (document.isStandalone &&
        !(document.moduleEnabled && document.integrationEnabled)) {
      return compiler.compile(
        document: document,
        profileId: profileId,
        baseConfig: baseConfig,
        sources: const [],
        enforceCandidateReferences: enforceCandidateReferences,
      );
    }
    final selected = requiredProfiles(
      document: document,
      profiles: profiles,
      profileId: profileId,
    );
    final sources = await loader.load(
      selected,
      persistCache: persistCache,
      allowNetwork: allowNetwork,
    );
    return compiler.compile(
      document: document,
      profileId: profileId,
      baseConfig: baseConfig,
      sources: sources,
      enforceCandidateReferences: enforceCandidateReferences,
    );
  }

  Future<List<LocalNode>> nodesForTarget({
    required LocalPolicyDocument document,
    required List<Profile> profiles,
    required String targetId,
    bool refresh = false,
    bool includeAllSources = false,
  }) async {
    if (document.isStandalone && targetId != localPolicyTargetId) {
      throw const FormatException('Only the local configuration owns rules');
    }
    final parts = targetId.split(':');
    if (parts.length != 2) throw const FormatException('Invalid policy target');
    List<Profile> selected;
    SubscriptionIntegration? integration;
    if (parts.first == 'integration') {
      for (final entry in document.integrations) {
        if (entry.id == parts.last) integration = entry;
      }
      if (integration == null) {
        throw const FormatException('Missing integration');
      }
      selected = profiles
          .where(
            (profile) => integration!.sourceProfileIds.contains(profile.id),
          )
          .toList();
      if (selected.length != integration.sourceProfileIds.length) {
        throw const FormatException('A source profile is missing');
      }
    } else if (parts.first == 'profile') {
      final id = int.tryParse(parts.last);
      if (!profiles.any((profile) => profile.id == id)) {
        throw const FormatException('Missing profile');
      }
      final ids = document.sourceProfileIdsForTarget(targetId);
      selected = includeAllSources
          ? profiles
          : profiles.where((profile) => ids.contains(profile.id)).toList();
      if (!includeAllSources && selected.length != ids.length) {
        throw const FormatException('A source profile is missing');
      }
    } else {
      throw const FormatException('Invalid policy target type');
    }
    final requiredIds = document.sourceProfileIdsForTarget(targetId);
    final sources = <PolicySource>[];
    for (final profile in selected) {
      try {
        sources.addAll(
          await loader.load(
            [profile],
            allowNetwork: refresh,
            persistCache: refresh,
          ),
        );
      } catch (_) {
        if (!includeAllSources || requiredIds.contains(profile.id)) rethrow;
      }
    }
    final nodes = sources
        .expand(compiler.extractNodes)
        .map(
          (node) => LocalNode(
            id: node.id,
            sourceId: node.sourceId,
            label: node.label,
            sourceLabel: node.sourceLabel,
            protocol: node.protocol,
            raw: node.raw,
            attributes: document.nodeAttributes[node.id] ?? node.attributes,
          ),
        )
        .where((node) {
          final selectedIntegration = integration;
          if (selectedIntegration == null) return true;
          if (selectedIntegration.excludedNodeIds.contains(node.id)) {
            return false;
          }
          final filter = selectedIntegration.nameFilter;
          return filter == null ||
              filter.isEmpty ||
              node.label.toLowerCase().contains(filter.toLowerCase());
        })
        .toList();
    if (nodes.length > 5000) {
      throw const FormatException('At most 5000 nodes are supported');
    }
    return nodes;
  }
}
