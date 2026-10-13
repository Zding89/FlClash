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
    final integration = document.integrationEnabled
        ? document.activeIntegration
        : null;
    final ids = integration == null
        ? {?profileId}
        : integration.sourceProfileIds.toSet();
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
  }) async {
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
      selected = profiles.where((profile) => profile.id == id).toList();
      if (selected.length != 1) throw const FormatException('Missing profile');
    } else {
      throw const FormatException('Invalid policy target type');
    }
    final sources = await loader.load(
      selected,
      allowNetwork: refresh,
      persistCache: refresh,
    );
    return sources.expand(compiler.extractNodes).where((node) {
      final selectedIntegration = integration;
      if (selectedIntegration == null) return true;
      if (selectedIntegration.excludedNodeIds.contains(node.id)) return false;
      final filter = selectedIntegration.nameFilter;
      return filter == null ||
          filter.isEmpty ||
          node.label.toLowerCase().contains(filter.toLowerCase());
    }).toList();
  }
}
