import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/database/database.dart' as db;
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/policy/compiler.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/policy/sources.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yaml/yaml.dart';

import 'barrier.dart';
import 'changes.dart';
import 'settings.dart';
import 'recovery_source.dart';

enum ResourceKind { profile, rules, groups, script }

int resourceId(
  Map<String, Object?> value,
  String key, {
  bool allowZero = false,
}) {
  final raw = value[key];
  final parsed =
      raw is String && RegExp(r'^(0|[1-9][0-9]{0,18})$').hasMatch(raw)
      ? int.tryParse(raw)
      : raw is int && raw <= 9007199254740991
      ? raw
      : null;
  if (parsed == null ||
      parsed < (allowZero ? 0 : 1) ||
      parsed > 9223372036854775807) {
    throw const FormatException('Invalid resource identifier');
  }
  return parsed;
}

final class ResourceScope {
  final ResourceKind kind;
  final int id;
  final RuleScene? scene;

  const ResourceScope(this.kind, this.id, {this.scene});

  String get category =>
      'resource:${kind.name}:$id${scene == null ? '' : ':${scene!.name}'}';

  factory ResourceScope.fromCategory(String category) {
    final parts = category.split(':');
    if (parts.length < 3 || parts.length > 4 || parts.first != 'resource') {
      throw const ConfigurationChangeException('resource_scope_invalid');
    }
    final kind = ResourceKind.values
        .where((item) => item.name == parts[1])
        .firstOrNull;
    final id = int.tryParse(parts[2]);
    final scene = parts.length == 4
        ? RuleScene.values.where((item) => item.name == parts[3]).firstOrNull
        : null;
    if (kind == null ||
        id == null ||
        id < 0 ||
        id > 9223372036854775807 ||
        (kind == ResourceKind.rules
            ? scene == null || id == 0 && scene != RuleScene.added
            : id == 0 || scene != null)) {
      throw const ConfigurationChangeException('resource_scope_invalid');
    }
    return ResourceScope(kind, id, scene: scene);
  }

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'id': id,
    if (scene != null) 'scene': scene!.name,
  };
}

final class ResourceValidation {
  final Map<String, Object?> summary;
  final String? generatedYaml;

  const ResourceValidation(this.summary, {this.generatedYaml});
}

abstract interface class ResourceInputValidator {
  Future<void> checkInputs(ResourceScope scope, Map<String, Object?> candidate);
}

abstract interface class ResourceActivationArtifacts {
  Future<String?> readActivationArtifact();
}

abstract interface class ResourceEnvironment {
  Future<Map<String, Object?>> read(ResourceScope scope);
  Future<ResourceValidation> validate(
    ResourceScope scope,
    Map<String, Object?> candidate, {
    required bool approvedScript,
  });
  Future<void> persist(ResourceScope scope, Map<String, Object?> candidate);
  Future<void> activate(
    ResourceScope scope,
    Map<String, Object?> candidate, {
    String? generatedYaml,
    Map<String, Object?>? previousSnapshot,
  });
}

final class _ResourceArtifactCache {
  final Map<String, ({String? yaml, int bytes})> _entries = {};
  int _bytes = 0;

  bool contains(String key) => _entries.containsKey(key);
  String? read(String key) => _entries[key]?.yaml;
  void save(String key, String? yaml) {
    final length = yaml == null ? 0 : utf8.encode(yaml).length;
    if (length > 8 * 1024 * 1024) {
      throw const ConfigurationChangeException('resource_artifact_limit');
    }
    final replaced = _entries.remove(key);
    _bytes -= replaced?.bytes ?? 0;
    while (_entries.isNotEmpty &&
        (_entries.length >= 8 || _bytes + length > 16 * 1024 * 1024)) {
      _bytes -= _entries.remove(_entries.keys.first)!.bytes;
    }
    _entries[key] = (yaml: yaml, bytes: length);
    _bytes += length;
  }
}

final class _ResourceCommit {
  final String beforeDigest;
  final String afterDigest;
  final String validationDigest;
  final String? beforeYaml;
  final String? afterYaml;
  final Map<String, Object?> before;
  const _ResourceCommit({
    required this.beforeDigest,
    required this.afterDigest,
    required this.validationDigest,
    required this.beforeYaml,
    required this.afterYaml,
    required this.before,
  });
}

final class ResourceConfigurationBackend
    implements
        ConfigurationBackend,
        ApprovedConfigurationValidator,
        ConfigurationRecoveryBackend,
        ConfigurationCommitBackend,
        ConfigurationRecoveryValidator {
  final ResourceScope scope;
  final ResourceEnvironment environment;
  String? _validatedFingerprint;
  ResourceValidation? _validation;
  bool _executionBound = false;
  Map<String, Object?>? _beforeActivation;
  final _ResourceArtifactCache _artifacts;
  final Map<String, _ResourceCommit> _commits = {};

  ResourceConfigurationBackend({required this.scope, required this.environment})
    : _artifacts = _ResourceArtifactCache();

  ResourceConfigurationBackend._shared({
    required this.scope,
    required this.environment,
    required _ResourceArtifactCache artifacts,
  }) : _artifacts = artifacts;

  @override
  Future<Map<String, Object?>> readState() async {
    final state = await environment.read(scope);
    final digest = policyDigest(state);
    if (!_artifacts.contains('before:$digest')) {
      if (environment case final ResourceActivationArtifacts artifacts) {
        _artifacts.save(
          'before:$digest',
          await artifacts.readActivationArtifact(),
        );
      }
    }
    return state;
  }

  void _checkScope(Map<String, Object?> candidate) {
    if (policyDigest(candidate['scope']) != policyDigest(scope.toJson())) {
      throw const ConfigurationChangeException('resource_scope_invalid');
    }
  }

  ResourceValidation _remember(
    Map<String, Object?> candidate,
    ResourceValidation result, {
    bool executionBound = false,
  }) {
    final yaml = result.generatedYaml;
    final summary = {...result.summary};
    if (yaml != null) {
      final digest = policyDigest(normalizePolicyYaml(loadYaml(yaml)));
      summary['finalConfigDigest'] = digest;
      _artifacts.save('approved:${policyDigest(candidate)}:$digest', yaml);
    }
    _validatedFingerprint = policyDigest(candidate);
    _executionBound = executionBound;
    _validation = ResourceValidation(
      {...summary}..remove('finalConfigDifferences'),
    );
    return ResourceValidation(summary);
  }

  String? _approvedYaml(
    Map<String, Object?> candidate,
    Map<String, Object?> validation,
  ) {
    final digest = validation['finalConfigDigest'];
    if (digest is! String) {
      if (validation['networkChanged'] == false ||
          scope.kind == ResourceKind.profile && candidate['profile'] == null) {
        return null;
      }
      throw const ConfigurationChangeException(
        'resource_activation_artifact_missing',
      );
    }
    final yaml = _artifacts.read('approved:${policyDigest(candidate)}:$digest');
    if (yaml == null ||
        policyDigest(normalizePolicyYaml(loadYaml(yaml))) != digest) {
      throw const ConfigurationChangeException(
        'resource_activation_artifact_missing',
      );
    }
    return yaml;
  }

  @override
  Future<Map<String, Object?>> validate(Map<String, Object?> candidate) async {
    _checkScope(candidate);
    if (environment case final ResourceInputValidator validator) {
      await validator.checkInputs(scope, candidate);
    }
    if (_validatedFingerprint == policyDigest(candidate) &&
        _validation != null) {
      return {
        ..._validation!.summary,
        if (_executionBound) 'requiresScriptExecutionApproval': true,
      };
    }
    final result = await environment.validate(
      scope,
      candidate,
      approvedScript: false,
    );
    if (result.summary['requiresScriptExecutionApproval'] != true) {
      return _remember(candidate, result).summary;
    }
    return result.summary;
  }

  @override
  Future<Map<String, Object?>> validateRecovery(
    Map<String, Object?> candidate,
  ) async {
    _validatedFingerprint = null;
    _validation = null;
    return validate(candidate);
  }

  @override
  Future<Map<String, Object?>> validateRecoveryApproved(
    Map<String, Object?> candidate,
  ) => validateApproved(candidate);

  @override
  Future<Map<String, Object?>> validateApproved(
    Map<String, Object?> candidate,
  ) async {
    _checkScope(candidate);
    final result = await environment.validate(
      scope,
      candidate,
      approvedScript: true,
    );
    if (result.summary['requiresScriptExecutionApproval'] == true) {
      throw const ConfigurationChangeException(
        'resource_script_validation_incomplete',
      );
    }
    var summary = result.summary;
    if (result.generatedYaml != null) {
      if (environment case final ResourceActivationArtifacts artifacts) {
        final previous = await artifacts.readActivationArtifact();
        final before = previous == null
            ? <String, Object?>{}
            : normalizePolicyYaml(loadYaml(previous));
        final after = normalizePolicyYaml(loadYaml(result.generatedYaml!));
        summary = {
          ...summary,
          'finalConfigDigest': policyDigest(after),
          'finalConfigDifferences': configurationDifferences(
            redactResource({'config': before})['config'],
            redactResource({'config': after})['config'],
          ).map((entry) => entry.toJson()).toList(),
        };
      }
    }
    return _remember(
      candidate,
      ResourceValidation(summary, generatedYaml: result.generatedYaml),
      executionBound: result.generatedYaml != null,
    ).summary;
  }

  @override
  bool isHighRisk(Map<String, Object?> before, Map<String, Object?> after) =>
      true;

  @override
  Future<void> restore(
    Map<String, Object?> before,
    Map<String, Object?> after,
  ) async {
    final current = await environment.read(scope);
    if (!resourcePartialRecoveryMatches(before, after, current)) {
      throw const ConfigurationChangeException(
        'configuration_changed_during_failure',
      );
    }
    await environment.persist(scope, before);
    final artifact = _artifacts.read('before:${policyDigest(before)}');
    await environment.activate(
      scope,
      before,
      generatedYaml: artifact,
      previousSnapshot: after,
    );
  }

  @override
  Future<void> persist(Map<String, Object?> candidate) async {
    _beforeActivation = await environment.read(scope);
    await environment.persist(scope, candidate);
  }

  @override
  Future<void> activate(Map<String, Object?> candidate) async {
    if (_validatedFingerprint != policyDigest(candidate)) {
      final validation = await environment.validate(
        scope,
        candidate,
        approvedScript: false,
      );
      if (validation.summary['requiresScriptExecutionApproval'] == true) {
        throw const ConfigurationChangeException(
          'resource_script_reapproval_required',
        );
      }
      _remember(candidate, validation);
    }
    await environment.activate(
      scope,
      candidate,
      generatedYaml: _approvedYaml(candidate, _validation?.summary ?? const {}),
      previousSnapshot: _beforeActivation,
    );
  }

  @override
  Future<void> beginCommit(
    String id,
    Map<String, Object?> before,
    Map<String, Object?> after,
    Map<String, Object?> validation,
  ) async {
    if (_commits.containsKey(id) || _commits.length >= 16) {
      throw const ConfigurationChangeException('resource_commit_conflict');
    }
    final yaml = _approvedYaml(after, validation);
    final artifacts = environment;
    final previous = artifacts is ResourceActivationArtifacts
        ? await (artifacts as ResourceActivationArtifacts)
              .readActivationArtifact()
        : null;
    _commits[id] = _ResourceCommit(
      beforeDigest: policyDigest(before),
      afterDigest: policyDigest(after),
      validationDigest: policyDigest(validation),
      beforeYaml: previous,
      afterYaml: yaml,
      before: before,
    );
  }

  @override
  Future<void> activateCommit(
    String id,
    Map<String, Object?> after,
    Map<String, Object?> validation,
  ) async {
    final operation = _commits[id];
    if (operation == null ||
        operation.afterDigest != policyDigest(after) ||
        operation.validationDigest != policyDigest(validation)) {
      throw const ConfigurationChangeException('resource_commit_conflict');
    }
    await environment.activate(
      scope,
      after,
      generatedYaml: operation.afterYaml,
      previousSnapshot: operation.before,
    );
  }

  @override
  Future<void> restoreCommit(
    String id,
    Map<String, Object?> before,
    Map<String, Object?> after,
  ) async {
    final operation = _commits[id];
    if (operation == null ||
        operation.beforeDigest != policyDigest(before) ||
        operation.afterDigest != policyDigest(after)) {
      throw const ConfigurationChangeException('resource_commit_conflict');
    }
    if (!resourcePartialRecoveryMatches(
      before,
      after,
      await environment.read(scope),
    )) {
      throw const ConfigurationChangeException(
        'configuration_changed_during_failure',
      );
    }
    await environment.persist(scope, before);
    await environment.activate(
      scope,
      before,
      generatedYaml: operation.beforeYaml,
      previousSnapshot: after,
    );
  }

  @override
  Future<void> endCommit(String id) async {
    _commits.remove(id);
  }
}

final class ResourceChangeService {
  final WorkbenchDatabase store;
  final ResourceEnvironment environment;
  final Future<String> Function(String)? validateRecoveryContent;
  final Map<String, ConfigurationChangeService> _services = {};
  final _ResourceArtifactCache _artifacts = _ResourceArtifactCache();
  final Map<String, ConfigurationChangeService> _repairServices = {};

  ResourceChangeService({
    required this.store,
    required this.environment,
    this.validateRecoveryContent,
  });

  ConfigurationChangeService service(ResourceScope scope) =>
      _services.putIfAbsent(
        scope.category,
        () => ConfigurationChangeService(
          store: store,
          backend: ResourceConfigurationBackend._shared(
            scope: scope,
            environment: environment,
            artifacts: _artifacts,
          ),
        ),
      );

  Future<ConfigurationProposal> propose(
    ResourceScope scope,
    Map<String, Object?> candidate, {
    required String summary,
  }) => service(
    scope,
  ).propose(category: scope.category, summary: summary, candidate: candidate);

  ConfigurationChangeService _repairService(String recoveryId, int profileId) =>
      _repairServices.putIfAbsent(
        '$recoveryId:$profileId',
        () => ConfigurationChangeService(
          store: store,
          backend: RecoverySourceBackend(
            scope: ResourceScope(ResourceKind.profile, profileId),
            recoveryId: recoveryId,
            store: store,
            environment: environment,
            validateContent: validateRecoveryContent,
          ),
        ),
      );

  Future<ConfigurationProposal> proposeRepairSource(
    String recoveryId,
    int profileId, {
    required String content,
    String? label,
  }) async {
    final scoped = _repairService(recoveryId, profileId);
    final before = await scoped.backend.readState();
    final resource = policyObject(before['resource'], 'resource');
    resource['profile'] = Profile(
      id: profileId,
      autoUpdateDuration: const Duration(days: 1),
      label: label ?? currentAppLocalizations.policySources,
      overwriteType: OverwriteType.standard,
    ).toJson();
    resource['protectedContent'] = content;
    return scoped.propose(
      category: 'repair:$recoveryId:$profileId',
      summary: currentAppLocalizations.policySources,
      candidate: {...before, 'resource': resource},
    );
  }

  Future<ConfigurationProposal> proposeRecovery(
    String id, {
    bool keepCurrent = false,
    Map<String, Object?>? replacement,
  }) async {
    final row = await store.readChange(id);
    if (row == null ||
        row.status != 'recovery_required' ||
        !row.category.startsWith('resource:')) {
      throw const ConfigurationChangeException(
        'configuration_recovery_missing',
      );
    }
    final scope = ResourceScope.fromCategory(row.category);
    final current = await environment.read(scope);
    final before = policyObject(jsonDecode(row.beforePayload), 'before');
    final after = policyObject(jsonDecode(row.afterPayload), 'after');
    if (!keepCurrent &&
        replacement == null &&
        !resourcePartialRecoveryMatches(before, after, current)) {
      throw const ConfigurationChangeException(
        'configuration_recovery_conflict',
      );
    }
    return service(scope).propose(
      category: 'recovery:$id',
      summary: row.summary,
      candidate: replacement ?? (keepCurrent ? current : before),
    );
  }

  Future<void> recoverInterrupted({bool activate = false}) async {
    for (final row in await store.interruptedChanges()) {
      if (row.category.startsWith('repair:')) {
        final parts = row.category.split(':');
        final service = _repairService(parts[1], int.parse(parts[2]));
        try {
          await (service.backend as ConfigurationRecoveryBackend).restore(
            policyObject(jsonDecode(row.beforePayload), 'before'),
            policyObject(jsonDecode(row.afterPayload), 'after'),
          );
          await store.changeStatus(row.id, 'restored');
        } catch (_) {
          await store.changeStatus(
            row.id,
            'recovery_required',
            error: 'resource_recovery_failed',
          );
        }
        continue;
      }
      var category = row.category;
      if (category.startsWith('recovery:')) {
        final original = await store.readChange(
          category.substring('recovery:'.length),
        );
        category = original?.category ?? '';
      }
      if (!category.startsWith('resource:')) continue;
      final scope = ResourceScope.fromCategory(category);
      final before = policyObject(jsonDecode(row.beforePayload), 'before');
      final after = policyObject(jsonDecode(row.afterPayload), 'after');
      final current = await environment.read(scope);
      if (!resourcePartialRecoveryMatches(before, after, current)) {
        await store.changeStatus(
          row.id,
          'superseded',
          error: 'configuration_recovery_conflict',
        );
        continue;
      }
      try {
        await store.changeStatus(row.id, 'restoring');
        await environment.persist(scope, before);
        if (activate) {
          await environment.activate(scope, before, previousSnapshot: after);
        }
        await store.changeStatus(row.id, 'restored');
      } catch (_) {
        await store.changeStatus(
          row.id,
          'recovery_required',
          error: 'resource_recovery_failed',
        );
      }
    }
  }

  Future<Map<String, Object?>> commit(
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
    if (row.category.startsWith('repair:')) {
      final parts = row.category.split(':');
      final scoped = _repairService(parts[1], int.parse(parts[2]));
      final prepared = await scoped.prepareApprovedValidation(
        id: id,
        approve: approve,
        isCurrent: isCurrent,
      );
      return {
        ...await scoped.commit(
          id: prepared.id,
          approve: approve,
          isCurrent: isCurrent,
        ),
        'preparationOnly': true,
        'recoveryPending': true,
      };
    }
    if (row.category.startsWith('recovery:')) {
      final original = await store.readChange(
        row.category.substring('recovery:'.length),
      );
      if (original == null || !original.category.startsWith('resource:')) {
        throw const ConfigurationChangeException(
          'configuration_recovery_missing',
        );
      }
      final scoped = service(ResourceScope.fromCategory(original.category));
      return scoped.commitRecovery(
        await scoped.readProposal(id),
        approve: approve,
        isCurrent: isCurrent,
      );
    }
    final scoped = service(ResourceScope.fromCategory(row.category));
    final proposal = await scoped.readProposal(id);
    final before = policyObject(
      jsonDecode(row.beforePayload),
      'resourceBefore',
    );
    final after = policyObject(jsonDecode(row.afterPayload), 'resourceAfter');
    final validation = await scoped.backend.validate(after);
    if (validation['requiresScriptExecutionApproval'] == true) {
      await scoped.prepareApprovedValidation(
        id: id,
        approve: approve,
        isCurrent: isCurrent,
      );
    }
    if (isCurrent?.call() == false) {
      throw const ConfigurationChangeException('configuration_cancelled');
    }
    if (proposal.highRisk != scoped.backend.isHighRisk(before, after)) {
      throw const ConfigurationChangeException('resource_risk_mismatch');
    }
    return scoped.commit(id: id, approve: approve, isCurrent: isCurrent);
  }

  Future<ConfigurationProposal> undo(String id) async {
    final row = await store.readChange(id);
    if (row == null) {
      throw const ConfigurationChangeException(
        'configuration_proposal_missing',
      );
    }
    if (row.status != 'applied') {
      throw const ConfigurationChangeException('configuration_not_undoable');
    }
    final scope = ResourceScope.fromCategory(row.category);
    final current = await environment.read(scope);
    if (policyDigest(current) !=
        policyDigest(policyObject(jsonDecode(row.afterPayload), 'after'))) {
      throw const ConfigurationChangeException('configuration_undo_conflict');
    }
    return propose(
      scope,
      policyObject(jsonDecode(row.beforePayload), 'before'),
      summary: row.summary,
    );
  }
}

Map<String, Object?> redactResource(Object? value) {
  Object? redact(Object? value, [String key = '']) {
    if (RegExp(
      r'(protected|secret|password|token|credential|authorization|api.?key|uuid|private.?key)',
      caseSensitive: false,
    ).hasMatch(key)) {
      return value == null
          ? null
          : {'redacted': true, 'digest': policyDigest(value)};
    }
    if (value is Map) {
      return value.map(
        (key, value) => MapEntry(key.toString(), redact(value, key.toString())),
      );
    }
    if (value is List) return value.map((value) => redact(value, key)).toList();
    if (value is int &&
        (value > 9007199254740991 ||
            value < -9007199254740991 ||
            RegExp(r'(^id$|Id$|Ids$)').hasMatch(key))) {
      return '$value';
    }
    if (value is String &&
        (RegExp(r'(url|uri)$', caseSensitive: false).hasMatch(key) ||
            {'http', 'https'}.contains(Uri.tryParse(value)?.scheme))) {
      final uri = Uri.tryParse(value);
      return uri == null || uri.host.isEmpty
          ? null
          : '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    }
    return value;
  }

  return policyObject(redact(value), 'redactedResource');
}

final class FlutterResourceEnvironment
    implements
        ResourceEnvironment,
        ResourceInputValidator,
        ResourceActivationArtifacts {
  final Ref ref;
  final WorkbenchDatabase store;
  final db.Database database;
  final Future<String> Function(int) profilePath;
  final Future<String> Function(int) scriptPath;
  final Future<String> Function(int) providerCacheDirectory;
  late final PolicySourceLoader _contextLoader = PolicySourceLoader(
    store: store,
    profilePath: profilePath,
    readFile: _readFile,
  );

  FlutterResourceEnvironment({
    required this.ref,
    required this.store,
    db.Database? database,
    Future<String> Function(int)? profilePath,
    Future<String> Function(int)? scriptPath,
    Future<String> Function(int)? providerCacheDirectory,
  }) : database = database ?? db.database,
       profilePath = profilePath ?? ((id) => appPath.getProfilePath('$id')),
       scriptPath = scriptPath ?? ((id) => appPath.getScriptPath('$id')),
       providerCacheDirectory =
           providerCacheDirectory ??
           ((id) async =>
               '${await appPath.getProvidersDirPath('$id')}/proxies');

  @override
  Future<String?> readActivationArtifact() async =>
      _readFile(await appPath.configFilePath);

  Future<String?> _readFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    if (await file.length() > 8 * 1024 * 1024) {
      throw const ConfigurationChangeException('resource_file_limit');
    }
    return file.readAsString();
  }

  Future<List<Profile>> readProfiles() => database.profilesDao.query().get();

  Future<Profile?> _profile(int id) async =>
      (await readProfiles()).where((profile) => profile.id == id).firstOrNull;

  Future<List<Rule>> _rules(int id, RuleScene scene) =>
      (id == 0
              ? database.rulesDao.queryGlobalAddedRules()
              : switch (scene) {
                  RuleScene.added => database.rulesDao.queryProfileAddedRules(
                    id,
                  ),
                  RuleScene.custom => database.rulesDao.queryProfileCustomRules(
                    id,
                  ),
                  RuleScene.disabled =>
                    database.rulesDao.queryProfileDisabledRules(id),
                })
          .get();

  String _settingsSignature() {
    final config = configJson(ref.read(configProvider))
      ..remove('currentProfileId');
    return configurationDigest(config);
  }

  Future<String> _otherContextSignature(ResourceScope scope) async {
    final profiles = await readProfiles();
    final selected = profiles.where(
      (profile) => scope.kind == ResourceKind.script || profile.id != scope.id,
    );
    final values = <Object?>[];
    for (final profile in selected) {
      values.add({
        'profile': profile.toJson(),
        'sourceDigest': await _contextLoader.fingerprint(profile),
      });
    }
    if (scope.id != 0 && scope.kind != ResourceKind.script) {
      final directory = Directory(await providerCacheDirectory(scope.id));
      final files = <File>[];
      if (await directory.exists()) {
        await for (final entry in directory.list(followLinks: false)) {
          if (entry is! File || files.length >= 1000) {
            throw const ConfigurationChangeException('resource_file_limit');
          }
          files.add(entry);
        }
      }
      files.sort((a, b) => a.path.compareTo(b.path));
      var bytes = 0;
      final cache = <String, String>{};
      for (final file in files) {
        bytes += await file.length();
        if (bytes > 32 * 1024 * 1024) {
          throw const ConfigurationChangeException('resource_file_limit');
        }
        cache[file.uri.pathSegments.last] = policyDigest(
          await _readFile(file.path),
        );
      }
      values.add({'providerCache': cache});
      final content = await _readFile(await profilePath(scope.id));
      if (content != null) {
        final raw = policyObject(
          normalizePolicyYaml(loadYaml(content)),
          'source',
        );
        values.add({
          'fileProviders': await _contextLoader.fileProviderDependencies(raw),
        });
      }
    }
    if (scope.id != 0) {
      values.add({
        'globalRules': (await database.rulesDao.queryGlobalAddedRules().get())
            .map((rule) => rule.toJson())
            .toList(),
      });
    }
    return policyDigest(values);
  }

  @override
  Future<void> checkInputs(
    ResourceScope scope,
    Map<String, Object?> candidate,
  ) async {
    if (candidate['policyRevision'] != (await store.readPolicies()).revision ||
        candidate['settingsSignature'] != _settingsSignature() ||
        candidate['otherContextSignature'] !=
            await _otherContextSignature(scope)) {
      throw const ConfigurationChangeException(
        'configuration_version_conflict',
      );
    }
  }

  @override
  Future<Map<String, Object?>> read(ResourceScope scope) async {
    final document = (await store.readPolicies()).asStandalone();
    final result = <String, Object?>{
      'scope': scope.toJson(),
      'policyRevision': document.revision,
      'settingsSignature': _settingsSignature(),
      'otherContextSignature': await _otherContextSignature(scope),
    };
    if (scope.kind == ResourceKind.script) {
      final script = await database.scriptsDao.get(scope.id).getSingleOrNull();
      result['script'] = script?.toJson();
      result['protectedContent'] = await _readFile(await scriptPath(scope.id));
      result['references'] = (await readProfiles())
          .where((profile) => profile.scriptId == scope.id)
          .map((profile) => profile.id)
          .toList();
      result['selectedProfileId'] = ref.read(currentProfileIdProvider);
      return policyObject(jsonDecode(jsonEncode(result)), 'resource');
    }
    final profile = scope.id == 0 ? null : await _profile(scope.id);
    result['profile'] = profile?.toJson();
    result['protectedContent'] = scope.id == 0
        ? null
        : await _readFile(await profilePath(scope.id));
    result['selectedProfileId'] = ref.read(currentProfileIdProvider);
    result['protectedScriptContent'] = profile?.scriptId == null
        ? null
        : await _readFile(await scriptPath(profile!.scriptId!));
    result['addedRules'] = (await _rules(
      scope.id,
      RuleScene.added,
    )).map((rule) => rule.toJson()).toList();
    result['customRules'] = scope.id == 0
        ? <Object?>[]
        : (await _rules(
            scope.id,
            RuleScene.custom,
          )).map((rule) => rule.toJson()).toList();
    result['disabledRules'] = scope.id == 0
        ? <Object?>[]
        : (await _rules(
            scope.id,
            RuleScene.disabled,
          )).map((rule) => rule.toJson()).toList();
    result['groups'] = scope.id == 0
        ? <Object?>[]
        : (await database.proxyGroupsDao.query(scope.id).get())
              .map((group) => group.toJson())
              .toList();
    return policyObject(jsonDecode(jsonEncode(result)), 'resource');
  }

  void _validateSnapshot(ResourceScope scope, Map<String, Object?> candidate) {
    policyKeys(
      candidate,
      scope.kind == ResourceKind.script
          ? {
              'scope',
              'policyRevision',
              'settingsSignature',
              'otherContextSignature',
              'script',
              'protectedContent',
              'references',
              'selectedProfileId',
            }
          : {
              'scope',
              'policyRevision',
              'settingsSignature',
              'otherContextSignature',
              'profile',
              'protectedContent',
              'protectedScriptContent',
              'selectedProfileId',
              'addedRules',
              'customRules',
              'disabledRules',
              'groups',
            },
    );
    if (policyDigest(candidate['scope']) != policyDigest(scope.toJson())) {
      throw const ConfigurationChangeException('resource_scope_invalid');
    }
    final content = candidate['protectedContent'];
    if (content != null &&
        (content is! String ||
            content.length >
                (scope.kind == ResourceKind.script
                    ? 512 * 1024
                    : 8 * 1024 * 1024))) {
      throw const ConfigurationChangeException('resource_file_limit');
    }
    if (scope.kind == ResourceKind.script) {
      if (candidate['script'] != null) {
        final script = Script.fromJson(
          policyObject(candidate['script'], 'script'),
        );
        if (script.id != scope.id ||
            script.label.length > 256 ||
            content == null) {
          throw const ConfigurationChangeException('resource_script_invalid');
        }
      }
      return;
    }
    if (candidate['profile'] != null) {
      final profile = Profile.fromJson(
        policyObject(candidate['profile'], 'profile'),
      );
      if (profile.id != scope.id ||
          profile.label.length > 256 ||
          profile.autoUpdateDuration < const Duration(minutes: 1) ||
          profile.autoUpdateDuration > const Duration(days: 30)) {
        throw const ConfigurationChangeException('resource_profile_invalid');
      }
      if (profile.url.isNotEmpty) {
        final uri = Uri.tryParse(profile.url);
        if (uri == null ||
            !{'http', 'https'}.contains(uri.scheme) ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty ||
            profile.url.length > 4096) {
          throw const ConfigurationChangeException('resource_url_invalid');
        }
      }
    } else if (scope.kind != ResourceKind.profile && scope.id != 0) {
      throw const ConfigurationChangeException('resource_profile_missing');
    }
    for (final scene in RuleScene.values) {
      final rules = policyItems(
        candidate,
        '${scene.name}Rules',
        (json) => Rule.fromJson(json),
        maximum: 5000,
      );
      if (rules.map((rule) => rule.id).toSet().length != rules.length ||
          rules.any(
            (rule) =>
                rule.id < 1 ||
                rule.id > 9223372036854775807 ||
                (rule.content?.length ?? 0) > 4096 ||
                (rule.ruleTarget?.length ?? 0) > 256,
          )) {
        throw const ConfigurationChangeException('resource_rule_invalid');
      }
    }
    final groups = policyItems(
      candidate,
      'groups',
      ProxyGroup.fromJson,
      maximum: 1000,
    );
    if (groups.map((group) => group.id).toSet().length != groups.length ||
        groups.map((group) => group.name).toSet().length != groups.length ||
        groups.any(
          (group) =>
              group.id < 1 ||
              group.id > 9223372036854775807 ||
              group.name.isEmpty ||
              group.name.length > 256 ||
              group.profileId != null && group.profileId != scope.id,
        )) {
      throw const ConfigurationChangeException('resource_group_invalid');
    }
  }

  @override
  Future<ResourceValidation> validate(
    ResourceScope scope,
    Map<String, Object?> candidate, {
    required bool approvedScript,
  }) async {
    _validateSnapshot(scope, candidate);
    final existing = await read(scope);
    final allowed = switch (scope.kind) {
      ResourceKind.script => {'script', 'protectedContent'},
      ResourceKind.rules => {'${scope.scene!.name}Rules'},
      ResourceKind.groups => {'groups', 'customRules'},
      ResourceKind.profile => {
        'profile',
        'protectedContent',
        'protectedScriptContent',
        if (candidate['profile'] == null) ...{
          'selectedProfileId',
          'addedRules',
          'customRules',
          'disabledRules',
          'groups',
        },
      },
    };
    for (final key in existing.keys) {
      if (!allowed.contains(key) &&
          policyDigest(existing[key]) != policyDigest(candidate[key])) {
        throw const ConfigurationChangeException('resource_scope_invalid');
      }
    }
    final document = (await store.readPolicies()).asStandalone();
    await checkInputs(scope, candidate);
    if (scope.kind == ResourceKind.profile && candidate['profile'] == null) {
      if (document.referencesProfile(scope.id)) {
        throw const ConfigurationChangeException('resource_source_referenced');
      }
      return const ResourceValidation({
        'validated': true,
        'reversible': true,
        'networkChanged': true,
      });
    }
    if (scope.kind == ResourceKind.script) {
      final references = (await readProfiles())
          .where((profile) => profile.scriptId == scope.id)
          .toList();
      if (candidate['script'] == null && references.isNotEmpty) {
        throw const ConfigurationChangeException('resource_script_referenced');
      }
      if (document.moduleEnabled && document.integrationEnabled) {
        return const ResourceValidation({
          'validated': true,
          'reversible': true,
          'networkChanged': false,
        });
      }
      final active = references
          .where(
            (profile) =>
                profile.id == ref.read(currentProfileIdProvider) &&
                profile.overwriteType == OverwriteType.script,
          )
          .firstOrNull;
      if (active == null) {
        return const ResourceValidation({
          'validated': true,
          'reversible': true,
          'networkChanged': false,
        });
      }
      final profileScope = ResourceScope(ResourceKind.profile, active.id);
      final profileCandidate = await read(profileScope);
      profileCandidate['protectedScriptContent'] =
          candidate['protectedContent'];
      return _validateProfile(
        profileScope,
        profileCandidate,
        document,
        approvedScript: approvedScript,
      );
    }
    await _validateIds(scope, candidate);
    return _validateProfile(
      scope,
      candidate,
      document,
      approvedScript: approvedScript,
    );
  }

  Future<void> _validateIds(
    ResourceScope scope,
    Map<String, Object?> candidate,
  ) async {
    final current = await read(scope);
    for (final scene in RuleScene.values) {
      final old = policyItems(
        current,
        '${scene.name}Rules',
        Rule.fromJson,
      ).map((rule) => rule.id).toSet();
      final proposed = policyItems(
        candidate,
        '${scene.name}Rules',
        Rule.fromJson,
        maximum: 5000,
      );
      for (final rule in proposed.where(
        (rule) => scene == RuleScene.disabled || !old.contains(rule.id),
      )) {
        final existing = await (database.select(
          database.rules,
        )..where((row) => row.id.equals(rule.id))).getSingleOrNull();
        final links = await (database.select(
          database.profileRuleLinks,
        )..where((row) => row.ruleId.equals(rule.id))).get();
        if (scene == RuleScene.disabled &&
            (existing == null ||
                !links.any(
                  (link) =>
                      (link.profileId == null || link.profileId == scope.id) &&
                      (link.scene == null || link.scene == RuleScene.added),
                ))) {
          throw const ConfigurationChangeException('resource_rule_missing');
        }
        if (existing != null && links.isNotEmpty) {
          final oldJson = existing.toRule().toJson()..remove('order');
          final newJson = rule.toJson()..remove('order');
          if (scene != RuleScene.disabled ||
              policyDigest(oldJson) != policyDigest(newJson)) {
            throw const ConfigurationChangeException(
              'resource_rule_id_conflict',
            );
          }
        }
      }
    }
    final oldGroups = policyItems(
      current,
      'groups',
      ProxyGroup.fromJson,
    ).map((group) => group.id).toSet();
    for (final group in policyItems(
      candidate,
      'groups',
      ProxyGroup.fromJson,
      maximum: 1000,
    ).where((group) => !oldGroups.contains(group.id))) {
      if ((await (database.select(
            database.proxyGroups,
          )..where((row) => row.id.equals(group.id))).getSingleOrNull()) !=
          null) {
        throw const ConfigurationChangeException('resource_group_id_conflict');
      }
    }
  }

  Future<ResourceValidation> _validateProfile(
    ResourceScope scope,
    Map<String, Object?> candidate,
    LocalPolicyDocument document, {
    required bool approvedScript,
  }) async {
    document = document.asStandalone();
    final activeProfileId = ref.read(currentProfileIdProvider);
    final localSelected = document.moduleEnabled && document.integrationEnabled;
    if (localSelected && scope.kind != ResourceKind.profile) {
      return const ResourceValidation({
        'validated': true,
        'reversible': true,
        'networkChanged': false,
      });
    }
    final integrated =
        localSelected &&
        document.localProfile.sourceProfileIds.contains(scope.id);
    final targetId = scope.id == 0 ? activeProfileId : scope.id;
    if (targetId == null) {
      return const ResourceValidation({
        'validated': true,
        'networkChanged': false,
      });
    }
    final data = scope.id == 0
        ? await read(ResourceScope(ResourceKind.profile, targetId))
        : candidate;
    final profile = Profile.fromJson(policyObject(data['profile'], 'profile'));
    final content = data['protectedContent'];
    if (content is! String) {
      throw const ConfigurationChangeException('resource_source_file_missing');
    }
    var raw = policyObject(normalizePolicyYaml(loadYaml(content)), 'source');
    if (scope.id != 0) {
      final currentContent = await _readFile(await profilePath(scope.id));
      if (currentContent != null) {
        final currentRaw = policyObject(
          normalizePolicyYaml(loadYaml(currentContent)),
          'source',
        );
        Map<String, Object?> fileProviders(Map<String, Object?> source) =>
            policyObject(source['proxy-providers'] ?? {}, 'providers').map(
              (key, value) => MapEntry(key, policyObject(value, 'provider')),
            )..removeWhere((key, value) => (value as Map)['type'] != 'file');
        final editedRaw = raw;
        if (policyDigest(fileProviders(currentRaw)) !=
            policyDigest(fileProviders(editedRaw))) {
          throw const PolicySourceException('file-provider-definition-change');
        }
      }
    }
    if (profile.overwriteType == OverwriteType.script && !integrated) {
      if (profile.scriptId == null ||
          data['protectedScriptContent'] is! String) {
        throw const ConfigurationChangeException('resource_script_missing');
      }
      if (!approvedScript) {
        return const ResourceValidation({
          'validated': true,
          'finalConfigValidated': false,
          'requiresScriptExecutionApproval': true,
        });
      }
      raw = await handleEvaluate(
        data['protectedScriptContent'] as String,
        Map<String, dynamic>.from(raw),
      );
    }
    final disabledIds = policyItems(
      data,
      'disabledRules',
      Rule.fromJson,
      maximum: 5000,
    ).map((rule) => rule.id).toSet();
    final added = profile.overwriteType == OverwriteType.standard
        ? [
            ...policyItems(
              scope.id == 0 ? candidate : data,
              'addedRules',
              Rule.fromJson,
              maximum: 5000,
            ),
            if (scope.id != 0)
              ...await database.rulesDao.queryGlobalAddedRules().get(),
          ].where((rule) => !disabledIds.contains(rule.id)).toList()
        : <Rule>[];
    final groups = profile.overwriteType == OverwriteType.custom
        ? policyItems(data, 'groups', ProxyGroup.fromJson, maximum: 1000)
        : <ProxyGroup>[];
    final rules = profile.overwriteType == OverwriteType.custom
        ? policyItems(data, 'customRules', Rule.fromJson, maximum: 5000)
        : <Rule>[];
    final network = ref.read(networkSettingProvider);
    final patch = ref.read(patchClashConfigProvider);
    final generated = await makeRealProfileTask(
      MakeRealProfileState(
        profilesPath: await appPath.profilesPath,
        profileId: integrated ? 0 : targetId,
        rawConfig: integrated
            ? {
                'proxies': <Object?>[],
                'proxy-groups': <Object?>[],
                'rules': <String>['MATCH,REJECT'],
                'dns': patch.dns.toJson(),
              }
            : Map<String, dynamic>.from(raw),
        realPatchConfig: patch.copyWith(
          tun: patch.tun.getRealTun(network.routeMode),
        ),
        overrideDns: ref.read(overrideDnsProvider),
        appendSystemDns: network.appendSystemDns,
        proxyGroups: integrated ? [] : groups,
        rules: integrated ? [] : rules,
        addedRules: integrated ? [] : added,
        defaultUA: globalState.packageInfo.ua,
      ),
    );
    var yaml = generated.a;
    if (integrated) {
      final controller = ref.read(workbenchControllerProvider);
      final currentProfiles = await readProfiles();
      final editedProfile = profile;
      final replacements =
          currentProfiles.where((item) => item.id != editedProfile.id).toList()
            ..add(editedProfile);
      final loader = PolicySourceLoader(
        store: store,
        readFile: (path) async => path == await profilePath(editedProfile.id)
            ? content
            : _readFile(path),
      );
      final selected = controller.profiles.requiredProfiles(
        document: document,
        profiles: replacements,
        profileId: targetId,
      );
      final sources = await loader.load(selected);
      final compiled = const LocalPolicyCompiler().compile(
        document: document,
        profileId: targetId,
        baseConfig: policyObject(
          normalizePolicyYaml(loadYaml(yaml)),
          'generated',
        ),
        sources: sources,
        enforceCandidateReferences: false,
      );
      yaml = await encodeYamlTask(compiled.config);
    }
    if ((await coreController.validateConfigWithData(yaml)).isNotEmpty) {
      throw const ConfigurationChangeException(
        'configuration_core_validation_failed',
      );
    }
    return ResourceValidation({
      'validated': true,
      'finalConfigValidated': true,
      'reversible': true,
      'networkChanged': localSelected
          ? integrated
          : _resourceUsesProfile(scope, profile, false) &&
                (targetId == ref.read(currentProfileIdProvider) ||
                    integrated &&
                        (document.activeIntegration?.sourceProfileIds.contains(
                              targetId,
                            ) ??
                            false)),
      'generatedDigest': policyDigest(yaml),
    }, generatedYaml: yaml);
  }

  Future<void> _writeFile(String path, Object? content) async {
    final file = File(path);
    if (content == null) {
      if (await file.exists()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    final temporary = File('$path.workbench');
    try {
      await temporary.writeAsString(content as String, flush: true);
      await temporary.rename(path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<void> _putRules(int id, RuleScene scene, List<Rule> rules) async {
    await (database.delete(database.profileRuleLinks)..where(
          (row) =>
              (id == 0 ? row.profileId.isNull() : row.profileId.equals(id)) &
              (id == 0 ? const Constant(true) : row.scene.equalsValue(scene)),
        ))
        .go();
    for (final rule in rules) {
      if (scene != RuleScene.disabled) {
        await database
            .into(database.rules)
            .insertOnConflictUpdate(rule.toCompanion());
      }
      await database
          .into(database.profileRuleLinks)
          .insertOnConflictUpdate(
            ProfileRuleLink(
              profileId: id == 0 ? null : id,
              ruleId: rule.id,
              scene: id == 0 ? null : scene,
              order: rule.order,
            ).toCompanion(),
          );
    }
  }

  @override
  Future<void> persist(ResourceScope scope, Map<String, Object?> candidate) =>
      configurationWriteBarrier.run(() async {
        _validateSnapshot(scope, candidate);
        if (scope.kind == ResourceKind.script) {
          await _writeFile(
            await scriptPath(scope.id),
            candidate['protectedContent'],
          );
          await database.transaction(() async {
            if (candidate['script'] == null) {
              await (database.delete(
                database.scripts,
              )..where((row) => row.id.equals(scope.id))).go();
            } else {
              await database
                  .into(database.scripts)
                  .insertOnConflictUpdate(
                    Script.fromJson(
                      policyObject(candidate['script'], 'script'),
                    ).toCompanion(),
                  );
            }
          });
          return;
        }
        if (scope.kind == ResourceKind.profile) {
          await _writeFile(
            await profilePath(scope.id),
            candidate['protectedContent'],
          );
        }
        await database.transaction(() async {
          if (scope.id > 0) {
            if (candidate['profile'] == null) {
              await (database.delete(
                database.profiles,
              )..where((row) => row.id.equals(scope.id))).go();
            } else {
              await database
                  .into(database.profiles)
                  .insertOnConflictUpdate(
                    Profile.fromJson(
                      policyObject(candidate['profile'], 'profile'),
                    ).toCompanion(),
                  );
            }
          }
          for (final scene in RuleScene.values) {
            if (scope.id == 0 && scene != RuleScene.added) continue;
            await _putRules(
              scope.id,
              scene,
              policyItems(
                candidate,
                '${scene.name}Rules',
                Rule.fromJson,
                maximum: 5000,
              ),
            );
          }
          if (scope.id > 0) {
            await (database.delete(
              database.proxyGroups,
            )..where((row) => row.profileId.equals(scope.id))).go();
            for (final group in policyItems(
              candidate,
              'groups',
              ProxyGroup.fromJson,
              maximum: 1000,
            )) {
              await database
                  .into(database.proxyGroups)
                  .insertOnConflictUpdate(group.toCompanion(scope.id));
            }
          }
        });
        final selected = candidate['selectedProfileId'];
        if (selected != ref.read(currentProfileIdProvider)) {
          ref.read(currentProfileIdProvider.notifier).value = selected as int?;
          if (!await preferences.saveConfig(ref.read(configProvider))) {
            throw const ConfigurationChangeException(
              'configuration_preferences_failed',
            );
          }
        }
      });

  @override
  Future<void> activate(
    ResourceScope scope,
    Map<String, Object?> candidate, {
    String? generatedYaml,
    Map<String, Object?>? previousSnapshot,
  }) async {
    if (policyDigest(await read(scope)) != policyDigest(candidate)) {
      throw const ConfigurationChangeException(
        'configuration_version_conflict',
      );
    }
    ref.invalidate(profilesStreamProvider);
    await ref.read(profilesStreamProvider.future);
    ref.invalidate(profilesProvider);
    ref.invalidate(setupStateProvider);
    final document = (await store.readPolicies()).asStandalone();
    final selectedId = ref.read(currentProfileIdProvider);
    final targetProfile = scope.kind == ResourceKind.script || scope.id == 0
        ? selectedId == null
              ? null
              : await _profile(selectedId)
        : candidate['profile'] == null
        ? null
        : Profile.fromJson(policyObject(candidate['profile'], 'profile'));
    final activeScript =
        scope.kind == ResourceKind.script &&
        !(document.moduleEnabled && document.integrationEnabled) &&
        (await readProfiles()).any(
          (profile) =>
              profile.id == ref.read(currentProfileIdProvider) &&
              profile.scriptId == scope.id &&
              profile.overwriteType == OverwriteType.script,
        );
    final localSelected = document.moduleEnabled && document.integrationEnabled;
    final activeSource =
        localSelected &&
        scope.kind == ResourceKind.profile &&
        document.localProfile.sourceProfileIds.contains(scope.id);
    final affectsCurrent = localSelected
        ? activeSource
        : _resourceUsesProfile(
                scope,
                targetProfile,
                (document.moduleEnabled && document.integrationEnabled),
              ) &&
              (scope.id == 0 ||
                  scope.id == ref.read(currentProfileIdProvider) ||
                  previousSnapshot?['selectedProfileId'] == scope.id ||
                  activeScript ||
                  activeSource ||
                  (document.moduleEnabled && document.integrationEnabled) &&
                      (document.activeIntegration?.sourceProfileIds.contains(
                            scope.id,
                          ) ??
                          false));
    if (affectsCurrent &&
        ref.read(coreStatusProvider) == CoreStatus.connected) {
      if (scope.kind == ResourceKind.profile && candidate['profile'] == null) {
        await ref.read(setupActionProvider.notifier).setRunning(false);
      } else {
        if (generatedYaml == null) {
          throw const ConfigurationChangeException(
            'resource_activation_artifact_missing',
          );
        }
        await ref
            .read(setupActionProvider.notifier)
            .applyProfile(
              force: true,
              silence: true,
              approvedProfileYaml: generatedYaml,
              requireTunAuthorization: true,
            );
      }
    }
  }
}

bool _resourceUsesProfile(
  ResourceScope scope,
  Profile? profile,
  bool integrated,
) =>
    scope.kind == ResourceKind.profile ||
    !integrated &&
        switch (scope.kind) {
          ResourceKind.script =>
            profile?.scriptId == scope.id &&
                profile?.overwriteType == OverwriteType.script,
          ResourceKind.groups => profile?.overwriteType == OverwriteType.custom,
          ResourceKind.rules =>
            scope.scene == RuleScene.custom
                ? profile?.overwriteType == OverwriteType.custom
                : profile?.overwriteType == OverwriteType.standard,
          ResourceKind.profile => true,
        };

bool resourcePartialRecoveryMatches(
  Map<String, Object?> before,
  Map<String, Object?> after,
  Map<String, Object?> current,
) {
  if (current.keys.toSet().difference(before.keys.toSet()).isNotEmpty ||
      before.keys.toSet().difference(current.keys.toSet()).isNotEmpty) {
    return false;
  }
  for (final key in before.keys) {
    final observed = policyDigest(current[key]);
    if (observed != policyDigest(before[key]) &&
        observed != policyDigest(after[key])) {
      return false;
    }
  }
  return true;
}
