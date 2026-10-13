import 'dart:convert';

import 'package:fl_clash/common/app_localizations.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/policy/compiler.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/policy/sources.dart';
import 'package:yaml/yaml.dart';

import 'changes.dart';
import 'resources.dart';

class RecoverySourceBackend
    implements ConfigurationBackend, ConfigurationRecoveryBackend {
  final ResourceScope scope;
  final String recoveryId;
  final WorkbenchDatabase store;
  final ResourceEnvironment environment;
  final Future<String> Function(String) validateContent;
  RecoverySourceBackend({
    required this.scope,
    required this.recoveryId,
    required this.store,
    required this.environment,
    Future<String> Function(String)? validateContent,
  }) : validateContent =
           validateContent ?? coreController.validateConfigWithData;
  Future<WorkbenchChange> _recovery() async {
    final row = await store.readChange(recoveryId);
    if (row == null || row.status != 'recovery_required') {
      throw const ConfigurationChangeException(
        'configuration_recovery_missing',
      );
    }
    final documents = [await store.readPolicies()];
    for (final payload in [row.beforePayload, row.afterPayload]) {
      final state = policyObject(jsonDecode(payload), 'state');
      if (state['policies'] is Map) {
        documents.add(
          LocalPolicyDocument.fromJson(
            policyObject(state['policies'], 'policies'),
          ),
        );
      }
    }
    final referred =
        documents.any(
          (d) =>
              d.integrations.any(
                (i) => i.sourceProfileIds.contains(scope.id),
              ) ||
              d.policies.any(
                (p) =>
                    p.targetId == 'profile:${scope.id}' ||
                    p.candidateNodeIds.any((n) => n.startsWith('${scope.id}:')),
              ) ||
              d.budgets.any((b) => b.sourceId == '${scope.id}'),
        ) ||
        row.category == 'resource:profile:${scope.id}';
    if (!referred) {
      throw const ConfigurationChangeException(
        'recovery_source_not_referenced',
      );
    }
    return row;
  }

  @override
  Future<Map<String, Object?>> readState() async {
    final row = await _recovery();
    return {
      'resource': await environment.read(scope),
      'recoveryStatus': row.status,
      'policyFingerprint': policyDigest((await store.readPolicies()).toJson()),
    };
  }

  @override
  Future<Map<String, Object?>> validate(Map<String, Object?> candidate) async {
    policyKeys(candidate, {'resource', 'recoveryStatus', 'policyFingerprint'});
    await _recovery();
    final live = await environment.read(scope);
    if (live['profile'] != null) {
      throw const ConfigurationChangeException(
        'recovery_source_already_exists',
      );
    }
    final resource = policyObject(candidate['resource'], 'resource');
    if (policyDigest(resource['scope']) != policyDigest(scope.toJson())) {
      throw const ConfigurationChangeException('resource_scope_invalid');
    }
    if (environment is ResourceInputValidator) {
      await (environment as ResourceInputValidator).checkInputs(
        scope,
        resource,
      );
    }
    final content = resource['protectedContent'];
    if (content is! String || utf8.encode(content).length > 8 * 1024 * 1024) {
      throw const FormatException('Invalid source content');
    }
    final raw = policyObject(normalizePolicyYaml(loadYaml(content)), 'source');
    if (raw.containsKey('flclash-local-policy')) {
      throw const FormatException('Recursive source');
    }
    final nodes = const LocalPolicyCompiler().extractNodes(
      PolicySource(
        id: '${scope.id}',
        label: currentAppLocalizations.policySources,
        raw: raw,
      ),
    );
    if (nodes.length > 5000) throw const FormatException('Node limit exceeded');
    if ((await validateContent(content)).isNotEmpty) {
      throw const ConfigurationChangeException(
        'configuration_core_validation_failed',
      );
    }
    return {
      'validated': true,
      'preparationOnly': true,
      'recoveryPending': true,
      'sourceId': '${scope.id}',
      'nodeCount': nodes.length,
    };
  }

  @override
  bool isHighRisk(Map<String, Object?> before, Map<String, Object?> after) =>
      true;
  @override
  Future<void> persist(Map<String, Object?> candidate) => environment.persist(
    scope,
    policyObject(candidate['resource'], 'resource'),
  );
  @override
  Future<void> activate(Map<String, Object?> candidate) async {}
  @override
  Future<void> restore(
    Map<String, Object?> before,
    Map<String, Object?> after,
  ) async {
    final current = await environment.read(scope);
    final previous = policyObject(before['resource'], 'resource');
    final changed = policyObject(after['resource'], 'resource');
    if (!resourcePartialRecoveryMatches(previous, changed, current)) {
      throw const ConfigurationChangeException(
        'configuration_recovery_conflict',
      );
    }
    await environment.persist(scope, previous);
  }
}
