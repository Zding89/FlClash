import 'package:collection/collection.dart';
import 'package:fl_clash/core/controller.dart';

import 'compiler.dart';
import 'models.dart';

typedef PolicySimulationInvoke =
    Future<Map<String, Object?>> Function(Map<String, Object?> input);

final class PolicySimulationResult {
  final Map<String, Object?> snapshot;
  final List<Map<String, Object?>> timeline;
  final List<Map<String, Object?>> results;

  const PolicySimulationResult({
    required this.snapshot,
    required this.timeline,
    required this.results,
  });
}

final class LocalPolicySimulation {
  final LocalPolicyCompiler compiler;
  final PolicySimulationInvoke invoke;

  LocalPolicySimulation({
    this.compiler = const LocalPolicyCompiler(),
    PolicySimulationInvoke? invoke,
  }) : invoke = invoke ?? coreController.simulateLocalPolicies;

  Future<PolicySimulationResult> run({
    required LocalPolicyDocument document,
    required String targetId,
    required List<PolicySource> sources,
    required Map<String, bool?> health,
    required DateTime now,
    Map<String, int> localUsage = const {},
    List<Map<String, Object?>> steps = const [],
  }) async {
    if (document.isStandalone && targetId != localPolicyTargetId) {
      throw const FormatException(
        'Only the local configuration can be simulated',
      );
    }
    final parts = targetId.split(':');
    if (parts.length != 2 ||
        !{'profile', 'integration'}.contains(parts.first)) {
      throw const FormatException('Invalid simulation target');
    }
    final integrated = parts.first == 'integration';
    final profileId = integrated ? null : int.tryParse(parts.last);
    if (!integrated && (profileId == null || profileId <= 0)) {
      throw const FormatException('Invalid simulation profile');
    }
    final targetDocument = LocalPolicyDocument.fromJson({
      ...document.toJson(),
      'moduleEnabled': true,
      'integrationEnabled': integrated,
      'activeIntegrationId': integrated
          ? parts.last
          : document.activeIntegrationId,
    });
    final source = sources
        .where((source) => source.id == '$profileId')
        .firstOrNull;
    final base = <String, Object?>{
      'mode': 'rule',
      'rules': ['MATCH,REJECT'],
      'proxies': source == null
          ? <Object?>[]
          : source.raw['flclash-inline-node-ids'] is List
          ? compiler
                .extractNodes(source)
                .where(
                  (node) => (source.raw['flclash-inline-node-ids'] as List)
                      .contains(node.id),
                )
                .map((node) => node.raw)
                .toList()
          : source.raw['proxies'] ?? <Object?>[],
      'proxy-groups': source?.raw['proxy-groups'] ?? <Object?>[],
      if (source?.raw['proxy-providers'] != null)
        'proxy-providers': source!.raw['proxy-providers'],
    };
    final compiled = compiler.compile(
      document: targetDocument,
      profileId: profileId,
      baseConfig: base,
      sources: sources,
      enforceCandidateReferences: false,
    );
    final config =
        compiled.config['flclash-local-policy'] ??
        {
          'schemaVersion': 1,
          'revision': document.revision,
          'enabled': false,
          'sources': <Object?>[],
          'nodes': <Object?>[],
          'policies': <Object?>[],
          'budgets': <Object?>[],
          'overrides': <Object?>[],
        };
    final response = await invoke({
      'config': config,
      'availableNodeIds': compiled.nodes.map((node) => node.id).toList(),
      'now': now.millisecondsSinceEpoch,
      'health': health,
      'localUsage': localUsage,
      'steps': steps,
    });
    final snapshot = policyObject(response['snapshot'], 'simulation snapshot');
    final timeline = policyItems(
      response,
      'steps',
      (json) => json,
      maximum: 33,
    );
    final results = policyItems(snapshot, 'policies', (json) {
      final nodes = policyItems(json, 'nodes', (node) => node, maximum: 5000);
      final selected = json['selectedNodeId'];
      return {
        'policyId': json['policyId'],
        'selectedNodeId': selected == '' ? null : selected,
        'fallback': selected == '' ? json['state'] : null,
        'reason': json['reason'],
        'candidates': nodes
            .map(
              (node) => {
                'nodeId': node['nodeId'],
                'eligible': node['eligible'],
                'reason': node['reason'],
              },
            )
            .toList(),
      };
    });
    return PolicySimulationResult(
      snapshot: snapshot,
      timeline: timeline,
      results: results,
    );
  }
}
