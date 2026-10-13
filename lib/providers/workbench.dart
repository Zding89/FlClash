import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart' show Response;

import 'package:fl_clash/ai/credentials.dart';
import 'package:fl_clash/ai/runtime.dart';
import 'package:fl_clash/ai/settings.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/configuration/barrier.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/configuration/settings.dart';
import 'package:fl_clash/configuration/resources.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/material.dart' show Offset;
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/policy/profile_service.dart';
import 'package:fl_clash/policy/sources.dart';
import 'package:fl_clash/policy/simulation.dart';
import 'package:fl_clash/policy/compiler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yaml/yaml.dart' show loadYaml;

import 'action.dart';
import 'app.dart';
import 'config.dart';
import 'database.dart';
import 'state.dart';

final workbenchDatabaseProvider = Provider<WorkbenchDatabase>(
  (ref) => workbenchDatabase,
);

var _sourceRefreshSequence = 0;

int _nextSourceRefreshSequence() {
  final now = DateTime.now().microsecondsSinceEpoch;
  _sourceRefreshSequence = now > _sourceRefreshSequence
      ? now
      : _sourceRefreshSequence + 1;
  return _sourceRefreshSequence;
}

final localPoliciesProvider = StreamProvider<LocalPolicyDocument>(
  (ref) => ref.watch(workbenchDatabaseProvider).watchPolicies(),
);

final agentSettingsProvider = StreamProvider<AgentSettings>(
  (ref) => ref
      .watch(workbenchDatabaseProvider)
      .watchSection('ai')
      .map((json) => AgentSettings.fromJson(json ?? const {})),
);

final workbenchChangesProvider = StreamProvider<List<WorkbenchChange>>(
  (ref) => ref.watch(workbenchDatabaseProvider).watchChanges(),
);

final workbenchControllerProvider = Provider<WorkbenchController>((ref) {
  final controller = WorkbenchController(ref);
  ref.onDispose(() => unawaited(controller.closeAgent()));
  return controller;
});

final localPolicyNodesProvider = FutureProvider.family<List<LocalNode>, String>(
  (ref, targetId) async {
    final document = await ref.watch(localPoliciesProvider.future);
    final profiles = ref.watch(profilesProvider);
    return ref
        .read(workbenchControllerProvider)
        .profiles
        .nodesForTarget(
          document: document,
          profiles: profiles,
          targetId: targetId,
        );
  },
);

final localPolicyStatusProvider = StreamProvider<Map<String, Object?>>((
  ref,
) async* {
  final connected = ref.watch(coreStatusProvider) == CoreStatus.connected;
  if (!connected) {
    yield {
      'enabled': false,
      'state': 'core_disconnected',
      'policies': <Object?>[],
    };
    return;
  }
  var disposed = false;
  ref.onDispose(() => disposed = true);
  while (!disposed) {
    try {
      yield await coreController.getLocalPolicyStatus();
    } catch (_) {
      yield {
        'enabled': false,
        'state': 'status_unavailable',
        'policies': <Object?>[],
      };
    }
    if (!disposed) await Future<void>.delayed(const Duration(seconds: 3));
  }
});

class WorkbenchController {
  final Ref ref;
  final WorkbenchDatabase store;
  final AgentCredentialStore credentials;
  late final PolicyProfileService profiles;
  late final FlutterConfigurationBackend backend;
  late final ConfigurationChangeService changes;
  late final ResourceChangeService resources;
  AgentRuntime? _runtime;

  WorkbenchController(
    this.ref, {
    WorkbenchDatabase? store,
    AgentCredentialStore? credentials,
  }) : store = store ?? ref.read(workbenchDatabaseProvider),
       credentials = credentials ?? const KeychainAgentCredentialStore() {
    profiles = PolicyProfileService(
      loader: PolicySourceLoader(
        store: this.store,
        fetchFile: (url) async =>
            utf8.decode((await fetchSourceResponse(url)).data!),
      ),
    );
    backend = FlutterConfigurationBackend(
      ref: ref,
      store: this.store,
      profiles: profiles,
    );
    changes = ConfigurationChangeService(backend: backend, store: this.store);
    resources = ResourceChangeService(
      store: this.store,
      environment: FlutterResourceEnvironment(ref: ref, store: this.store),
    );
  }

  AgentRuntime get runtime => _runtime ??= AgentRuntime();

  Future<void> closeAgent() async {
    final runtime = _runtime;
    _runtime = null;
    await runtime?.close();
  }

  Future<AgentSettings> readAgentSettings() async =>
      AgentSettings.fromJson(await store.readSection('ai') ?? const {});

  Future<LocalPolicyDocument> readPolicies() => store.readPolicies();

  Future<Response<Uint8List>> fetchSourceResponse(String url) async {
    final document = await readPolicies();
    final managed =
        document.integrationEnabled ||
        document.policiesEnabled ||
        document.budgetsEnabled;
    String? route;
    if (managed) {
      if (document.sourceUpdateRoute == SourceUpdateRoute.direct) {
        route = 'DIRECT';
      } else {
        if (!ref.read(isStartProvider) ||
            ref.read(suspendProvider) ||
            ref.read(coreStatusProvider) != CoreStatus.connected) {
          throw const ConfigurationChangeException(
            'source_update_proxy_unavailable',
          );
        }
        final port = ref.read(patchClashConfigProvider).mixedPort;
        if (port < 1 || port > 65535) {
          throw const ConfigurationChangeException(
            'source_update_proxy_unavailable',
          );
        }
        route = 'PROXY 127.0.0.1:$port';
      }
    }
    return request.getBoundedFileResponse(url, proxyDirective: route);
  }

  Future<void> validateSourceUpdate(
    Profile profile,
    Uint8List bytes, {
    required bool Function() isCurrent,
  }) async {
    final document = await readPolicies();
    if (!document.integrationEnabled &&
        !document.policiesEnabled &&
        !document.budgetsEnabled) {
      return;
    }
    final content = utf8.decode(bytes);
    final raw = policyObject(normalizePolicyYaml(loadYaml(content)), 'source');
    for (final value in raw['proxy-groups'] as List? ?? []) {
      final group = policyObject(value, 'group');
      for (final key in ['filter', 'exclude-filter', 'exclude-type']) {
        if (group[key] != null && group[key] != '') {
          throw PolicySourceException('proxy-groups.$key');
        }
      }
    }
    final loader = profiles.loader;
    final sourcePath = await loader.profilePath(profile.id);
    final candidateLoader = PolicySourceLoader(
      store: store,
      readFile: (path) async =>
          path == sourcePath ? content : await loader.readFile(path),
      fetchFile: loader.fetchFile,
      writeFile: loader.writeFile,
      commitFile: loader.commitFile,
      profilePath: loader.profilePath,
      providerCachePath: loader.providerCachePath,
      homePath: loader.homePath,
    );
    final source = (await candidateLoader.load(
      [profile],
      allowNetwork: true,
      isCurrent: isCurrent,
    )).single;
    final nodes = profiles.compiler.extractNodes(source);
    final identities = <String, String>{};
    for (final node in nodes) {
      final prior = identities[node.label];
      if (prior != null && prior != node.id) {
        throw const PolicySourceException('duplicate-node-name');
      }
      identities[node.label] = node.id;
    }
  }

  Future<void> refreshSourceMetadata(
    Profile profile, {
    required bool Function() isCurrent,
  }) async {
    if (!isCurrent() || ref.read(coreStatusProvider) != CoreStatus.connected) {
      return;
    }
    final info = profile.subscriptionInfo;
    final remainingKnown =
        info != null &&
        info.total > 0 &&
        info.knownFields.containsAll({'total', 'upload', 'download'});
    final sequence = _nextSourceRefreshSequence();
    for (var attempt = 0; attempt < 2; attempt++) {
      final status = await coreController.getLocalPolicyStatus();
      if (!isCurrent() || status['enabled'] != true) return;
      final error = await coreController.refreshLocalPolicySource({
        'revision': status['revision'],
        'sequence': sequence,
        'source': {
          'id': '${profile.id}',
          'expiresAt': info != null && info.expire > 0
              ? info.expire * 1000
              : null,
          'remainingBytes': remainingKnown
              ? (info.total - info.upload - info.download).clamp(
                  0,
                  9007199254740991,
                )
              : null,
          'observedAt': info?.observedAt?.millisecondsSinceEpoch,
        },
      });
      if (error.isEmpty ||
          error == 'local_policy_source_missing' ||
          error == 'local_policy_source_inactive') {
        return;
      }
      if (error != 'local_policy_source_revision_conflict' || attempt == 1) {
        throw ConfigurationChangeException(error);
      }
      if (!isCurrent()) return;
    }
  }

  Future<ConfigurationProposal> proposeAgentSettings(
    AgentSettings settings,
  ) async {
    AgentSettings.fromJson(settings.toJson());
    final snapshot = await backend.readState();
    snapshot['ai'] = settings.toJson();
    return changes.propose(
      category: 'ai',
      summary: currentAppLocalizations.aiSettingsTitle,
      candidate: snapshot,
    );
  }

  Future<ConfigurationProposal> proposeSettingsPatch(
    Map<String, Object?> patch,
  ) async {
    final snapshot = await backend.readState();
    snapshot['config'] = backend.catalog.applyPatch(
      policyObject(snapshot['config'], 'config'),
      patch,
    );
    return changes.propose(
      category: 'settings',
      summary: currentAppLocalizations.settings,
      candidate: snapshot,
    );
  }

  Future<ConfigurationProposal> proposePolicies(
    LocalPolicyDocument document,
  ) async {
    LocalPolicyDocument.fromJson(document.toJson());
    final snapshot = await backend.readState();
    final current = LocalPolicyDocument.fromJson(
      policyObject(snapshot['policies'], 'policies'),
    );
    snapshot['policies'] = document.withRevision(current.revision + 1).toJson();
    return changes.propose(
      category: 'policies',
      summary: currentAppLocalizations.localPolicies,
      candidate: snapshot,
    );
  }

  Future<Map<String, Object?>> commit(
    ConfigurationProposal proposal, {
    required ConfigurationApproval approve,
    bool Function()? isCurrent,
  }) async {
    final prepared = await changes.prepareApprovedValidation(
      id: proposal.id,
      approve: approve,
      isCurrent: isCurrent,
    );
    return changes.commit(
      id: prepared.id,
      approve: approve,
      isCurrent: isCurrent,
    );
  }

  Future<Map<String, Object?>> undo(
    String id, {
    required ConfigurationApproval approve,
    bool Function()? isCurrent,
  }) async {
    final row = await store.readChange(id);
    if (row == null) {
      throw const ConfigurationChangeException(
        'configuration_proposal_missing',
      );
    }
    if (row.category.startsWith('resource:')) {
      final proposal = await resources.undo(id);
      return resources.commit(
        proposal.id,
        approve: approve,
        isCurrent: isCurrent,
      );
    }
    final proposal = await changes.proposeUndo(id);
    return commit(proposal, approve: approve, isCurrent: isCurrent);
  }

  Future<PolicySimulationResult> simulatePolicies({
    required LocalPolicyDocument document,
    required String targetId,
    required List<PolicySource> sources,
    required Map<String, bool?> health,
    required DateTime now,
    Map<String, int> localUsage = const {},
    List<Map<String, Object?>> steps = const [],
  }) {
    if (ref.read(coreStatusProvider) != CoreStatus.connected) {
      throw const ConfigurationChangeException(
        'configuration_core_required_for_simulation',
      );
    }
    return LocalPolicySimulation().run(
      document: document,
      targetId: targetId,
      sources: sources,
      health: health,
      localUsage: localUsage,
      now: now,
      steps: steps,
    );
  }

  Future<List<LocalNode>> loadNodes(
    String targetId, {
    bool refresh = false,
  }) async => profiles.nodesForTarget(
    document: await store.readPolicies(),
    profiles: ref.read(profilesProvider),
    targetId: targetId,
    refresh: refresh,
  );
}

class FlutterConfigurationBackend
    implements
        ConfigurationBackend,
        ApprovedConfigurationValidator,
        ConfigurationRecoveryBackend,
        ConfigurationCommitBackend {
  final Ref ref;
  final WorkbenchDatabase store;
  final PolicyProfileService profiles;
  final SettingsCatalog catalog;
  Map<String, Object?>? _lastActivated;
  final Map<String, String?> _commitArtifacts = {};
  String? _providedYaml;
  bool _activating = false;
  final Map<String, String> _approvedProfiles = {};

  FlutterConfigurationBackend({
    required this.ref,
    required this.store,
    required this.profiles,
    SettingsCatalog? catalog,
  }) : catalog = catalog ?? SettingsCatalog();

  Future<void> synchronizeActivatedState() async {
    if (_activating) return;
    _lastActivated = await readState();
  }

  @override
  Future<Map<String, Object?>> readState() async {
    final document = await store.readPolicies();
    final ai = AgentSettings.fromJson(
      await store.readSection('ai') ?? const {},
    );
    final snapshot = <String, Object?>{
      'config': configJson(ref.read(configProvider)),
      'policies': document.toJson(),
      'ai': ai.toJson(),
      'profilesSignature': policyDigest({
        'profiles': ref
            .read(profilesProvider)
            .map((profile) => profile.toJson())
            .toList(),
        'sources': {
          for (final profile in ref.read(profilesProvider))
            '${profile.id}': await profiles.loader.fingerprint(profile),
        },
      }),
    };
    _lastActivated ??= policyObject(
      jsonDecode(jsonEncode(snapshot)),
      'activated',
    );
    return snapshot;
  }

  @override
  Future<Map<String, Object?>> validate(Map<String, Object?> candidate) async {
    policyKeys(candidate, {'config', 'policies', 'ai', 'profilesSignature'});
    final config = catalog.validate(
      policyObject(candidate['config'], 'config'),
    );
    final document = LocalPolicyDocument.fromJson(
      policyObject(candidate['policies'], 'policies'),
    );
    AgentSettings.fromJson(policyObject(candidate['ai'], 'ai'));
    final allProfiles = ref.read(profilesProvider);
    final ids = allProfiles.map((profile) => profile.id).toSet();
    if (config.currentProfileId != null &&
        !ids.contains(config.currentProfileId)) {
      throw const ConfigurationChangeException('configuration_profile_missing');
    }
    for (final integration in document.integrations) {
      if (!ids.containsAll(integration.sourceProfileIds)) {
        throw const ConfigurationChangeException(
          'configuration_source_missing',
        );
      }
    }
    for (final policy in document.policies) {
      if (policy.targetId.startsWith('profile:') &&
          !ids.contains(int.tryParse(policy.targetId.split(':').last))) {
        throw const ConfigurationChangeException(
          'configuration_policy_target_missing',
        );
      }
      if (policy.scope.type == PolicyMatchType.group &&
          policy.scope.values.single == 'GLOBAL') {
        throw const ConfigurationChangeException(
          'configuration_global_group_unsupported',
        );
      }
    }
    final current = await readState();
    final currentConfig = policyObject(current['config'], 'config');
    final candidateConfig = policyObject(candidate['config'], 'config');
    final needsCore =
        policyDigest(current['policies']) !=
            policyDigest(candidate['policies']) ||
        [
          'patchClashConfig',
          'networkProps',
          'overrideDns',
          'currentProfileId',
        ].any(
          (key) =>
              policyDigest(currentConfig[key]) !=
              policyDigest(candidateConfig[key]),
        );
    if (!needsCore) return {'validated': true, 'networkChanged': false};
    final setupState = await ref.read(
      setupStateProvider(config.currentProfileId).future,
    );
    if (setupState.overwriteType == OverwriteType.script &&
        setupState.script != null &&
        !document.integrationEnabled) {
      return {
        'validated': true,
        'finalConfigValidated': false,
        'requiresScriptExecutionApproval': true,
      };
    }
    final result = await ref
        .read(setupActionProvider.notifier)
        .getProfile(
          setupState: setupState,
          patchConfig: config.patchClashConfig,
          policyDocument: document,
          networkProps: config.networkProps,
          dnsOverride: config.overrideDns,
          preview: true,
        );
    if (result.a.isNotEmpty) {
      final error = await coreController.validateConfigWithData(result.a);
      if (error.isNotEmpty) {
        throw const ConfigurationChangeException(
          'configuration_core_validation_failed',
        );
      }
    }
    final active = document.integrationEnabled
        ? document.activeIntegration?.targetId
        : 'profile:${config.currentProfileId}';
    final activePolicies = document.policies
        .where((policy) => policy.enabled && policy.targetId == active)
        .toList();
    if (document.policiesEnabled &&
        activePolicies.isNotEmpty &&
        config.patchClashConfig.mode != Mode.rule) {
      throw const ConfigurationChangeException(
        'configuration_policies_require_rule_mode',
      );
    }
    for (final policy in document.policies.where((policy) => policy.enabled)) {
      final available = await profiles.nodesForTarget(
        document: document,
        profiles: allProfiles,
        targetId: policy.targetId,
      );
      final availableIds = available.map((node) => node.id).toSet();
      if (!availableIds.containsAll(policy.candidateNodeIds)) {
        throw const ConfigurationChangeException(
          'configuration_policy_node_missing',
        );
      }
    }
    return {
      'validated': true,
      'networkChanged': true,
      'finalConfigValidated': true,
      'policyCount': activePolicies.length,
    };
  }

  @override
  bool isHighRisk(Map<String, Object?> before, Map<String, Object?> after) {
    if (catalog.highRisk(
      policyObject(before['config'], 'config'),
      policyObject(after['config'], 'config'),
    )) {
      return true;
    }
    if (policyDigest(before['policies']) != policyDigest(after['policies'])) {
      return true;
    }
    final oldAi = AgentSettings.fromJson(policyObject(before['ai'], 'ai'));
    final newAi = AgentSettings.fromJson(policyObject(after['ai'], 'ai'));
    for (final old in oldAi.connections) {
      final replacements = newAi.connections.where(
        (connection) => connection.id == old.id,
      );
      if (replacements.isEmpty) return true;
      final updated = replacements.single;
      if (old.provider != updated.provider ||
          old.baseUrl != updated.baseUrl ||
          old.api != updated.api) {
        return true;
      }
    }
    return false;
  }

  @override
  Future<Map<String, Object?>> validateApproved(
    Map<String, Object?> candidate,
  ) async {
    final config = catalog.validate(
      policyObject(candidate['config'], 'config'),
    );
    final document = LocalPolicyDocument.fromJson(
      policyObject(candidate['policies'], 'policies'),
    );
    final setupState = await ref.read(
      setupStateProvider(config.currentProfileId).future,
    );
    final result = await ref
        .read(setupActionProvider.notifier)
        .getProfile(
          setupState: setupState,
          patchConfig: config.patchClashConfig,
          policyDocument: document,
          networkProps: config.networkProps,
          dnsOverride: config.overrideDns,
          preview: true,
          allowScriptExecution: true,
        );
    final error = await coreController.validateConfigWithData(result.a);
    if (error.isNotEmpty) {
      throw const ConfigurationChangeException(
        'configuration_core_validation_failed',
      );
    }
    final previousFile = File(await appPath.configFilePath);
    final previous = await previousFile.exists()
        ? normalizePolicyYaml(loadYaml(await previousFile.readAsString()))
        : <String, Object?>{};
    final next = normalizePolicyYaml(loadYaml(result.a));
    if (_approvedProfiles.length >= 2) {
      _approvedProfiles.remove(_approvedProfiles.keys.first);
    }
    _approvedProfiles[_approvedArtifactKey(candidate, policyDigest(next))] =
        result.a;
    return {
      'finalConfigValidated': true,
      'finalConfigDigest': policyDigest(next),
      'finalConfigDifferences': configurationDifferences(
        _safeCoreConfig(previous),
        _safeCoreConfig(next),
      ).map((entry) => entry.toJson()).toList(),
    };
  }

  Object? _safeCoreConfig(Object? value) {
    if (value is Map) {
      return value.map(
        (key, entry) => MapEntry(
          '$key',
          RegExp(
                r'(password|secret|token|uuid|private.?key|authorization)',
                caseSensitive: false,
              ).hasMatch('$key')
              ? null
              : _safeCoreConfig(entry),
        ),
      );
    }
    if (value is List) return value.map(_safeCoreConfig).toList();
    if (value is String) {
      final uri = Uri.tryParse(value);
      if (uri != null && {'http', 'https'}.contains(uri.scheme)) {
        return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
      }
    }
    return value;
  }

  String _approvedArtifactKey(Map<String, Object?> candidate, String digest) =>
      '${policyDigest(candidate)}:$digest';

  @override
  Future<void> beginCommit(
    String id,
    Map<String, Object?> before,
    Map<String, Object?> after,
    Map<String, Object?> validation,
  ) async {
    final digest = validation['finalConfigDigest'];
    if (digest is String &&
        !_approvedProfiles.containsKey(_approvedArtifactKey(after, digest))) {
      throw const ConfigurationChangeException(
        'configuration_script_preview_missing',
      );
    }
    final file = File(await appPath.configFilePath);
    if (await file.exists()) {
      if (await file.length() > 8 * 1024 * 1024) {
        throw const ConfigurationChangeException(
          'configuration_artifact_too_large',
        );
      }
      _commitArtifacts[id] = await file.readAsString();
    } else {
      _commitArtifacts[id] = null;
    }
  }

  @override
  Future<void> activateCommit(
    String id,
    Map<String, Object?> after,
    Map<String, Object?> validation,
  ) async {
    final digest = validation['finalConfigDigest'];
    if (digest is String) {
      final yaml = _approvedProfiles.remove(
        _approvedArtifactKey(after, digest),
      );
      if (yaml == null ||
          policyDigest(normalizePolicyYaml(loadYaml(yaml))) != digest) {
        throw const ConfigurationChangeException(
          'configuration_approval_changed',
        );
      }
      _providedYaml = yaml;
    }
    try {
      await activate(after);
    } finally {
      _providedYaml = null;
    }
  }

  @override
  Future<void> restoreCommit(
    String id,
    Map<String, Object?> before,
    Map<String, Object?> after,
  ) => _restore(before, after, artifact: _commitArtifacts[id]);

  @override
  Future<void> endCommit(String id) async {
    _commitArtifacts.remove(id);
  }

  @override
  Future<void> restore(
    Map<String, Object?> before,
    Map<String, Object?> after,
  ) => _restore(before, after);

  Future<void> _restore(
    Map<String, Object?> before,
    Map<String, Object?> after, {
    String? artifact,
  }) async {
    final current = await readState();
    Object? restoreField(Object? original, Object? changed, Object? live) {
      if (policyDigest(original) == policyDigest(changed)) return live;
      if (original is Map && changed is Map && live is Map) {
        final result = Map<String, Object?>.from(live);
        for (final key in {...original.keys, ...changed.keys}) {
          result['$key'] = restoreField(original[key], changed[key], live[key]);
        }
        return result;
      }
      if (policyDigest(live) == policyDigest(changed) ||
          policyDigest(live) == policyDigest(original)) {
        return original;
      }
      throw const ConfigurationChangeException(
        'configuration_recovery_conflict',
      );
    }

    final restored = policyObject(
      restoreField(before, after, current),
      'restored',
    );
    await persist(restored);
    if (ref.read(coreStatusProvider) != CoreStatus.connected) {
      _lastActivated = restored;
      return;
    }
    final restoredConfig = catalog.validate(
      policyObject(restored['config'], 'config'),
    );
    final setup = await ref.read(
      setupStateProvider(restoredConfig.currentProfileId).future,
    );
    if (setup.overwriteType == OverwriteType.script &&
        !LocalPolicyDocument.fromJson(
          policyObject(restored['policies'], 'policies'),
        ).integrationEnabled) {
      Map<String, Object?> networkState(Map<String, Object?> state) {
        final config = policyObject(state['config'], 'config');
        return {
          'patchClashConfig': config['patchClashConfig'],
          'networkProps': config['networkProps'],
          'overrideDns': config['overrideDns'],
          'currentProfileId': config['currentProfileId'],
          'policies': state['policies'],
          'profilesSignature': state['profilesSignature'],
        };
      }

      if (artifact == null ||
          policyDigest(networkState(before)) !=
              policyDigest(networkState(restored))) {
        throw const ConfigurationChangeException(
          'configuration_recovery_requires_review',
        );
      }
      _providedYaml = artifact;
    }
    _lastActivated = after;
    try {
      await activate(restored);
    } finally {
      _providedYaml = null;
    }
  }

  @override
  Future<void> persist(Map<String, Object?> candidate) =>
      configurationWriteBarrier.run(() async {
        final config = catalog.validate(
          policyObject(candidate['config'], 'config'),
        );
        final document = LocalPolicyDocument.fromJson(
          policyObject(candidate['policies'], 'policies'),
        );
        final ai = AgentSettings.fromJson(policyObject(candidate['ai'], 'ai'));
        debouncer.cancel(FunctionTag.savePreferences);
        debouncer.cancel(FunctionTag.applyProfile);
        await store.transaction(() async {
          await store.writeSection('policies', document.toJson());
          await store.writeSection('ai', ai.toJson());
          if (!await preferences.saveConfig(config)) {
            throw const ConfigurationChangeException(
              'configuration_preferences_failed',
            );
          }
        });
        _setConfig(config);
      });

  void _setConfig(Config config) {
    ref.read(appSettingProvider.notifier).value = config.appSettingProps;
    ref.read(windowSettingProvider.notifier).value = config.windowProps;
    ref.read(vpnSettingProvider.notifier).value = config.vpnProps;
    ref.read(networkSettingProvider.notifier).value = config.networkProps;
    ref.read(themeSettingProvider.notifier).value = config.themeProps;
    ref.read(currentProfileIdProvider.notifier).value = config.currentProfileId;
    ref.read(davSettingProvider.notifier).value = config.davProps;
    ref.read(overrideDnsProvider.notifier).value = config.overrideDns;
    ref.read(hotKeyActionsProvider.notifier).value = config.hotKeyActions;
    ref.read(proxiesStyleSettingProvider.notifier).value =
        config.proxiesStyleProps;
    ref.read(patchClashConfigProvider.notifier).value = config.patchClashConfig;
    ref.read(excludeSSIDsProvider.notifier).value = config.excludeSSIDs;
  }

  @override
  Future<void> activate(Map<String, Object?> candidate) async {
    _activating = true;
    try {
      await _activate(candidate);
    } finally {
      _activating = false;
    }
  }

  Future<void> _activate(Map<String, Object?> candidate) async {
    if (policyDigest(await readState()) != policyDigest(candidate)) {
      throw const ConfigurationChangeException(
        'configuration_version_conflict',
      );
    }
    final current = policyObject(candidate['config'], 'config');
    final old = _lastActivated == null
        ? null
        : policyObject(_lastActivated!['config'], 'config');
    final networkChanged =
        old == null ||
        policyDigest(_lastActivated!['policies']) !=
            policyDigest(candidate['policies']) ||
        [
          'patchClashConfig',
          'networkProps',
          'overrideDns',
          'currentProfileId',
        ].any((key) => policyDigest(old[key]) != policyDigest(current[key]));
    if (networkChanged &&
        ref.read(coreStatusProvider) == CoreStatus.connected) {
      final config = catalog.validate(current);
      final setup = await ref.read(
        setupStateProvider(config.currentProfileId).future,
      );
      final approvedYaml = _providedYaml;
      if (setup.overwriteType == OverwriteType.script &&
          !LocalPolicyDocument.fromJson(
            policyObject(candidate['policies'], 'policies'),
          ).integrationEnabled &&
          approvedYaml == null) {
        throw const ConfigurationChangeException(
          'configuration_script_preview_missing',
        );
      }
      await ref
          .read(setupActionProvider.notifier)
          .applyProfile(
            force: true,
            silence: true,
            approvedProfileYaml: approvedYaml,
            requireTunAuthorization: true,
          );
      final state = ref.read(proxyStateProvider);
      final result = state.isStart && state.systemProxy
          ? await proxy?.startProxy(state.port, state.bassDomain)
          : await proxy?.stopProxy();
      if (result == false) {
        throw const ConfigurationChangeException(
          'configuration_system_proxy_failed',
        );
      }
      if (system.isMacOS) {
        final state = ref.read(autoSetSystemDnsStateProvider);
        await macOS?.updateDns(!(state.a && state.b));
      }
    }
    if (system.isMacOS && old != null) {
      final config = catalog.validate(current);
      final previous = catalog.validate(old);
      await configurationWriteBarrier.run(() async {
        if (config.appSettingProps.autoLaunch !=
            previous.appSettingProps.autoLaunch) {
          await autoLaunch?.updateStatus(config.appSettingProps.autoLaunch);
        }
        if (!hotKeyActionListEquality.equals(
          config.hotKeyActions,
          previous.hotKeyActions,
        )) {
          await applyHotKeyActions(config.hotKeyActions);
        }
        if (config.windowProps.width != previous.windowProps.width ||
            config.windowProps.height != previous.windowProps.height) {
          await windowManager.setSize(config.windowProps.size);
        }
        if (config.windowProps.left != previous.windowProps.left ||
            config.windowProps.top != previous.windowProps.top) {
          await windowManager.setPosition(
            Offset(config.windowProps.left ?? 0, config.windowProps.top ?? 0),
          );
        }
      });
    }
    final settings = AgentSettings.fromJson(
      policyObject(candidate['ai'], 'ai'),
    );
    if (!settings.enabled ||
        (_lastActivated != null &&
            policyDigest(_lastActivated!['ai']) !=
                policyDigest(candidate['ai']))) {
      await ref.read(workbenchControllerProvider).closeAgent();
    }
    _lastActivated = policyObject(
      jsonDecode(jsonEncode(candidate)),
      'activated',
    );
  }
}
