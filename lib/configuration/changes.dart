import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/configuration/settings.dart';
import 'package:fl_clash/policy/models.dart';

abstract interface class ConfigurationBackend {
  Future<Map<String, Object?>> readState();
  Future<Map<String, Object?>> validate(Map<String, Object?> candidate);
  bool isHighRisk(Map<String, Object?> before, Map<String, Object?> after);
  Future<void> persist(Map<String, Object?> candidate);
  Future<void> activate(Map<String, Object?> candidate);
}

enum ConfigurationCompletionScope { configuration, localPolicy }

final class ConfigurationActivationBasis {
  final String stateFingerprint;
  final String targetId;
  final int documentRevision;

  const ConfigurationActivationBasis({
    required this.stateFingerprint,
    required this.targetId,
    required this.documentRevision,
  });

  factory ConfigurationActivationBasis.fromJson(Map<String, Object?> json) {
    policyKeys(json, {
      'version',
      'stateFingerprint',
      'targetId',
      'documentRevision',
    });
    final fingerprint = policyString(json, 'stateFingerprint', maximum: 64);
    final target = policyString(json, 'targetId', maximum: 128);
    if (json['version'] != 1 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(fingerprint) ||
        target != localPolicyTargetId) {
      throw const FormatException('Invalid activation basis');
    }
    return ConfigurationActivationBasis(
      stateFingerprint: fingerprint,
      targetId: target,
      documentRevision: policyInt(json, 'documentRevision'),
    );
  }

  Map<String, Object?> toJson() => {
    'version': 1,
    'stateFingerprint': stateFingerprint,
    'targetId': targetId,
    'documentRevision': documentRevision,
  };
}

final class ConfigurationActivationReceipt {
  final bool required;
  final String? targetId;
  final int? documentRevision;
  final String? loadedTargetId;
  final int? loadedDocumentRevision;
  final bool loaded;
  final bool running;
  final String reason;

  const ConfigurationActivationReceipt({
    required this.required,
    this.targetId,
    this.documentRevision,
    this.loadedTargetId,
    this.loadedDocumentRevision,
    required this.loaded,
    required this.running,
    required this.reason,
  });

  bool get effective =>
      required &&
      loaded &&
      running &&
      targetId != null &&
      targetId == loadedTargetId &&
      documentRevision != null &&
      documentRevision == loadedDocumentRevision;

  Map<String, Object?> toJson() => {
    'required': required,
    'targetId': targetId,
    'documentRevision': documentRevision,
    'loadedTargetId': loadedTargetId,
    'loadedDocumentRevision': loadedDocumentRevision,
    'loaded': loaded,
    'running': running,
    'effective': effective,
    'reason': reason,
  };
}

final class ConfigurationCompletionReceipt {
  final bool persisted;
  final bool currentStateMatches;
  final ConfigurationCompletionScope scope;
  final ConfigurationActivationReceipt? activation;

  const ConfigurationCompletionReceipt({
    required this.persisted,
    required this.currentStateMatches,
    required this.scope,
    this.activation,
  });

  bool get effective =>
      persisted && currentStateMatches && activation?.effective == true;

  Map<String, Object?> toJson() => {
    'version': 1,
    'persisted': persisted,
    'currentStateMatches': currentStateMatches,
    'scope': scope == ConfigurationCompletionScope.localPolicy
        ? 'local_policy'
        : 'configuration',
    'outcome': effective ? 'effective' : 'saved',
    if (activation != null) 'activation': activation!.toJson(),
  };
}

abstract interface class ConfigurationCompletionBackend {
  Future<ConfigurationCompletionReceipt> readCompletion(
    Map<String, Object?> before,
    Map<String, Object?> after, {
    required bool currentStateMatches,
  });
}

abstract interface class ApprovedConfigurationValidator {
  Future<Map<String, Object?>> validateApproved(Map<String, Object?> candidate);
}

abstract interface class ConfigurationRecoveryBackend {
  Future<void> restore(Map<String, Object?> before, Map<String, Object?> after);
}

abstract interface class ConfigurationCommitBackend {
  Future<void> beginCommit(
    String id,
    Map<String, Object?> before,
    Map<String, Object?> after,
    Map<String, Object?> validation,
  );
  Future<void> activateCommit(
    String id,
    Map<String, Object?> after,
    Map<String, Object?> validation,
  );
  Future<void> restoreCommit(
    String id,
    Map<String, Object?> before,
    Map<String, Object?> after,
  );
  Future<void> endCommit(String id);
}

abstract interface class ConfigurationRecoveryValidator {
  Future<Map<String, Object?>> validateRecovery(Map<String, Object?> candidate);
  Future<Map<String, Object?>> validateRecoveryApproved(
    Map<String, Object?> candidate,
  );
}

Map<String, Object?> configurationRecoveryState(
  Map<String, Object?> before,
  Map<String, Object?> after,
  Map<String, Object?> current,
) {
  Object? restore(
    Object? original,
    Object? changed,
    Object? live,
    String path,
  ) {
    if (configurationDigest(original, path) ==
        configurationDigest(changed, path)) {
      return live;
    }
    if (original is Map && changed is Map && live is Map) {
      final result = Map<String, Object?>.from(live);
      for (final key in {...original.keys, ...changed.keys}) {
        final childPath = path.isEmpty ? '$key' : '$path.$key';
        result['$key'] = restore(
          original[key],
          changed[key],
          live[key],
          childPath,
        );
      }
      return result;
    }
    if (configurationDigest(live, path) == configurationDigest(changed, path) ||
        configurationDigest(live, path) ==
            configurationDigest(original, path)) {
      return original;
    }
    throw const ConfigurationChangeException('configuration_recovery_conflict');
  }

  return policyObject(restore(before, after, current, ''), 'recovery');
}

bool configurationRestoredMatches(
  Object? before,
  Object? after,
  Object? current, [
  String path = '',
]) {
  if (configurationDigest(before, path) == configurationDigest(after, path)) {
    return true;
  }
  if (before is Map && after is Map && current is Map) {
    return {...before.keys, ...after.keys}.every(
      (key) => configurationRestoredMatches(
        before[key],
        after[key],
        current[key],
        path.isEmpty ? '$key' : '$path.$key',
      ),
    );
  }
  return configurationDigest(before, path) ==
      configurationDigest(current, path);
}

final class ConfigurationChangeException implements Exception {
  final String code;

  const ConfigurationChangeException(this.code);

  @override
  String toString() => code;
}

final class ConfigurationDifference {
  final String path;
  final Object? before;
  final Object? after;

  const ConfigurationDifference({
    required this.path,
    required this.before,
    required this.after,
  });

  Map<String, Object?> toJson() => {
    'path': path,
    'before': before,
    'after': after,
  };
}

List<ConfigurationDifference> configurationDifferences(
  Object? before,
  Object? after, [
  String path = '',
]) {
  final differences = <ConfigurationDifference>[];
  if (before is Map && after is Map) {
    final keys = {...before.keys, ...after.keys};
    for (final key in keys) {
      differences.addAll(
        configurationDifferences(
          before[key],
          after[key],
          path.isEmpty ? '$key' : '$path.$key',
        ),
      );
    }
  } else if (configurationDigest(before, path) !=
      configurationDigest(after, path)) {
    final sensitive = RegExp(
      r'(password|secret|token|credential|api.?key|authorization|protectedContent)',
      caseSensitive: false,
    ).hasMatch(path);
    differences.add(
      ConfigurationDifference(
        path: path,
        before: sensitive ? null : before,
        after: sensitive ? null : after,
      ),
    );
  }
  return differences;
}

final class ConfigurationProposal {
  final String id;
  final String summary;
  final bool highRisk;
  final int expiresAt;
  final List<ConfigurationDifference> differences;
  final Map<String, Object?> validation;

  const ConfigurationProposal({
    required this.id,
    required this.summary,
    required this.highRisk,
    required this.expiresAt,
    required this.differences,
    required this.validation,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'summary': summary,
    'highRisk': highRisk,
    'expiresAt': expiresAt,
    'differences': differences.map((entry) => entry.toJson()).toList(),
    'validation': validation,
  };
}

typedef ConfigurationApproval =
    Future<bool> Function(ConfigurationProposal proposal);

final class ConfigurationChangeQueue {
  Future<void> _tail = Future<void>.value();
  int _pending = 0;

  Future<T> run<T>(Future<T> Function() action) {
    if (_pending >= 16) {
      return Future.error(
        const ConfigurationChangeException('configuration_queue_full'),
      );
    }
    _pending++;
    final result = _tail.then((_) => action());
    _tail = result
        .then<void>((_) {}, onError: (Object _, StackTrace _) {})
        .whenComplete(() => _pending--);
    return result;
  }
}

final _configurationQueues = Expando<ConfigurationChangeQueue>();

final class ConfigurationChangeService {
  final ConfigurationBackend backend;
  final WorkbenchDatabase store;
  final DateTime Function() clock;
  final Duration proposalLifetime;
  final ConfigurationChangeQueue _queue;
  final Map<String, Map<String, Object?>> _prepared = {};

  ConfigurationChangeService({
    required this.backend,
    required this.store,
    DateTime Function()? clock,
    this.proposalLifetime = const Duration(minutes: 10),
    ConfigurationChangeQueue? queue,
  }) : clock = clock ?? DateTime.now,
       _queue =
           queue ??
           (_configurationQueues[store] ??= ConfigurationChangeQueue());

  String _id() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<T> _serial<T>(Future<T> Function() action) => _queue.run(action);

  Future<ConfigurationProposal> propose({
    required String category,
    required String summary,
    required Map<String, Object?> candidate,
    String? baseDraftId,
    String? expectedPolicyDigest,
    String? expectedStateDigest,
  }) => _serial(() async {
    if (!category.startsWith('recovery:') &&
        !category.startsWith('repair:') &&
        (await store.recoveryChanges()).isNotEmpty) {
      throw const ConfigurationChangeException(
        'configuration_recovery_required',
      );
    }
    final before = await backend.readState();
    if (expectedStateDigest != null &&
            configurationDigest(before) != expectedStateDigest ||
        expectedPolicyDigest != null &&
            policyDigest(
                  LocalPolicyDocument.fromJson(
                    policyObject(before['policies'], 'policies'),
                  ).asStandalone().toJson(),
                ) !=
                expectedPolicyDigest) {
      throw const ConfigurationChangeException(
        'configuration_version_conflict',
      );
    }
    if (baseDraftId != null) {
      await _pendingDraft(baseDraftId, category, before);
    }
    final snapshot = policyObject(
      jsonDecode(jsonEncode(candidate)),
      'candidate',
    );
    final validation =
        category.startsWith('recovery:') &&
            backend is ConfigurationRecoveryValidator
        ? await (backend as ConfigurationRecoveryValidator).validateRecovery(
            snapshot,
          )
        : await backend.validate(snapshot);
    final afterValidation =
        expectedStateDigest != null || expectedPolicyDigest != null
        ? await backend.readState()
        : null;
    if (expectedStateDigest != null &&
            configurationDigest(afterValidation) != expectedStateDigest ||
        expectedPolicyDigest != null &&
            policyDigest(
                  LocalPolicyDocument.fromJson(
                    policyObject(afterValidation!['policies'], 'policies'),
                  ).asStandalone().toJson(),
                ) !=
                expectedPolicyDigest) {
      throw const ConfigurationChangeException(
        'configuration_version_conflict',
      );
    }
    final differences = configurationDifferences(before, snapshot);
    if (differences.isEmpty && !category.startsWith('recovery:')) {
      throw const ConfigurationChangeException('configuration_unchanged');
    }
    final highRisk =
        category.startsWith('recovery:') ||
        backend.isHighRisk(before, snapshot);
    final now = clock();
    final id = _id();
    final expiresAt = now.add(proposalLifetime).millisecondsSinceEpoch;
    if (baseDraftId != null) {
      await _pendingDraft(baseDraftId, category, await backend.readState());
    }
    await store.transaction(() async {
      await store.saveChange(
        id: id,
        category: category,
        summary: summary,
        highRisk: highRisk,
        fingerprint: configurationDigest(before),
        before: before,
        after: snapshot,
        createdAt: now.millisecondsSinceEpoch,
        expiresAt: expiresAt,
      );
      if (baseDraftId != null) {
        await store.changeStatus(baseDraftId, 'superseded');
        _prepared.remove(baseDraftId);
      }
    });
    return ConfigurationProposal(
      id: id,
      summary: summary,
      highRisk: highRisk,
      expiresAt: expiresAt,
      differences: differences,
      validation: validation,
    );
  });

  Future<WorkbenchChange> _pendingDraft(
    String id,
    String category,
    Map<String, Object?> current,
  ) async {
    final row = await store.readChange(id);
    if (row == null) {
      throw const ConfigurationChangeException(
        'configuration_proposal_missing',
      );
    }
    if (row.category != category || row.status != 'draft') {
      throw const ConfigurationChangeException(
        'configuration_proposal_not_pending',
      );
    }
    if (clock().millisecondsSinceEpoch >= row.expiresAt) {
      throw const ConfigurationChangeException(
        'configuration_proposal_expired',
      );
    }
    if (configurationDigest(current) != row.fingerprint) {
      throw const ConfigurationChangeException(
        'configuration_version_conflict',
      );
    }
    return row;
  }

  Future<LocalPolicyDocument> readPolicyDraft(String id) => _serial(() async {
    final row = await _pendingDraft(id, 'policies', await backend.readState());
    final candidate = policyObject(jsonDecode(row.afterPayload), 'after');
    return LocalPolicyDocument.fromJson(
      policyObject(candidate['policies'], 'policies'),
    ).asStandalone();
  });

  Future<Map<String, Object?>> completionStatus(String id) async {
    final row = await store.readChange(id);
    if (row == null || row.status != 'applied') return {};
    final before = policyObject(jsonDecode(row.beforePayload), 'before');
    final after = policyObject(jsonDecode(row.afterPayload), 'after');
    final matches =
        configurationDigest(await backend.readState()) ==
        configurationDigest(after);
    if (backend is! ConfigurationCompletionBackend) {
      return {'currentStateMatches': matches};
    }
    final receipt = await (backend as ConfigurationCompletionBackend)
        .readCompletion(before, after, currentStateMatches: matches);
    final stillMatches =
        matches &&
        configurationDigest(await backend.readState()) ==
            configurationDigest(after);
    return {
      'currentStateMatches': stillMatches,
      'completion': ConfigurationCompletionReceipt(
        persisted: receipt.persisted,
        currentStateMatches: stillMatches,
        scope: receipt.scope,
        activation: receipt.activation,
      ).toJson(),
    };
  }

  Future<ConfigurationProposal> readProposal(String id) async {
    final row = await store.readChange(id);
    if (row == null) {
      throw const ConfigurationChangeException(
        'configuration_proposal_missing',
      );
    }
    final before = policyObject(jsonDecode(row.beforePayload), 'before');
    final after = policyObject(jsonDecode(row.afterPayload), 'after');
    return ConfigurationProposal(
      id: id,
      summary: row.summary,
      highRisk: row.highRisk,
      expiresAt: row.expiresAt,
      differences: configurationDifferences(before, after),
      validation: policyObject(
        _prepared[id]?['validation'] ??
            (row.status == 'draft'
                ? row.category.startsWith('recovery:') &&
                          backend is ConfigurationRecoveryValidator
                      ? await (backend as ConfigurationRecoveryValidator)
                            .validateRecovery(after)
                      : await backend.validate(after)
                : <String, Object?>{}),
        'validation',
      ),
    );
  }

  Future<ConfigurationProposal> prepareApprovedValidation({
    required String id,
    required ConfigurationApproval approve,
    bool Function()? isCurrent,
  }) async {
    final row = await store.readChange(id);
    if (row == null) {
      throw const ConfigurationChangeException(
        'configuration_proposal_missing',
      );
    }
    if (row.status == 'applied') return readProposal(id);
    if (row.status != 'draft') {
      throw const ConfigurationChangeException(
        'configuration_proposal_not_pending',
      );
    }
    if (clock().millisecondsSinceEpoch >= row.expiresAt) {
      throw const ConfigurationChangeException(
        'configuration_proposal_expired',
      );
    }
    final candidate = policyObject(jsonDecode(row.afterPayload), 'after');
    final cached = _prepared[id];
    if (cached != null &&
        cached['fingerprint'] == row.fingerprint &&
        cached['afterDigest'] == configurationDigest(candidate)) {
      if (configurationDigest(await backend.readState()) != row.fingerprint) {
        throw const ConfigurationChangeException(
          'configuration_version_conflict',
        );
      }
      return readProposal(id);
    }
    final validation =
        row.category.startsWith('recovery:') &&
            backend is ConfigurationRecoveryValidator
        ? await (backend as ConfigurationRecoveryValidator).validateRecovery(
            candidate,
          )
        : await backend.validate(candidate);
    if (validation['requiresScriptExecutionApproval'] != true) {
      return readProposal(id);
    }
    if (isCurrent?.call() == false) {
      throw const ConfigurationChangeException('configuration_cancelled');
    }
    if (configurationDigest(await backend.readState()) != row.fingerprint) {
      throw const ConfigurationChangeException(
        'configuration_version_conflict',
      );
    }
    final proposal = await readProposal(id);
    final execution = ConfigurationProposal(
      id: proposal.id,
      summary: proposal.summary,
      highRisk: true,
      expiresAt: proposal.expiresAt,
      differences: proposal.differences,
      validation: {
        'executionOnly': true,
        'requiresScriptExecutionApproval': true,
      },
    );
    if (!await approve(execution)) {
      throw const ConfigurationChangeException(
        'configuration_script_execution_rejected',
      );
    }
    if (isCurrent?.call() == false) {
      throw const ConfigurationChangeException('configuration_cancelled');
    }
    if (configurationDigest(await backend.readState()) != row.fingerprint) {
      throw const ConfigurationChangeException(
        'configuration_version_conflict',
      );
    }
    return _serial(() async {
      final latest = await store.readChange(id);
      if (latest == null || latest.status != 'draft') {
        throw const ConfigurationChangeException(
          'configuration_proposal_not_pending',
        );
      }
      if (clock().millisecondsSinceEpoch >= latest.expiresAt) {
        throw const ConfigurationChangeException(
          'configuration_proposal_expired',
        );
      }
      if (isCurrent?.call() == false) {
        throw const ConfigurationChangeException('configuration_cancelled');
      }
      if (configurationDigest(await backend.readState()) != row.fingerprint) {
        throw const ConfigurationChangeException(
          'configuration_version_conflict',
        );
      }
      final cached = _prepared[id];
      if (cached != null &&
          cached['fingerprint'] == row.fingerprint &&
          cached['afterDigest'] == configurationDigest(candidate)) {
        return readProposal(id);
      }
      final validator = backend;
      if (validator is! ApprovedConfigurationValidator) {
        throw const ConfigurationChangeException(
          'configuration_script_preview_unavailable',
        );
      }
      final prepared =
          row.category.startsWith('recovery:') &&
              validator is ConfigurationRecoveryValidator
          ? await (validator as ConfigurationRecoveryValidator)
                .validateRecoveryApproved(candidate)
          : await (validator as ApprovedConfigurationValidator)
                .validateApproved(candidate);
      if (isCurrent?.call() == false) {
        throw const ConfigurationChangeException('configuration_cancelled');
      }
      if (configurationDigest(await backend.readState()) != row.fingerprint) {
        throw const ConfigurationChangeException(
          'configuration_version_conflict',
        );
      }
      if (_prepared.length >= 4) _prepared.remove(_prepared.keys.first);
      _prepared[id] = {
        'fingerprint': row.fingerprint,
        'afterDigest': configurationDigest(candidate),
        'validation': prepared,
      };
      return readProposal(id);
    });
  }

  Future<Map<String, Object?>> commit({
    required String id,
    required ConfigurationApproval approve,
    bool Function()? isCurrent,
  }) async {
    final initial = await store.readChange(id);
    if (initial == null) {
      throw const ConfigurationChangeException(
        'configuration_proposal_missing',
      );
    }
    if (initial.status == 'applied') {
      return {
        'id': id,
        'status': 'applied',
        'replayed': true,
        ...await completionStatus(id),
      };
    }
    if (initial.status != 'draft') {
      throw const ConfigurationChangeException(
        'configuration_proposal_not_pending',
      );
    }
    if (clock().millisecondsSinceEpoch >= initial.expiresAt) {
      throw const ConfigurationChangeException(
        'configuration_proposal_expired',
      );
    }
    if (isCurrent?.call() == false) {
      throw const ConfigurationChangeException('configuration_cancelled');
    }
    final approvalProposal = await readProposal(id);
    final approvalDigest = policyDigest(approvalProposal.validation);
    if (initial.highRisk && !await approve(approvalProposal)) {
      await store.changeStatus(id, 'rejected');
      _prepared.remove(id);
      return {'id': id, 'status': 'rejected'};
    }
    if (isCurrent?.call() == false) {
      throw const ConfigurationChangeException('configuration_cancelled');
    }
    return _serial(() async {
      final row = await store.readChange(id);
      if (row == null) {
        throw const ConfigurationChangeException(
          'configuration_proposal_missing',
        );
      }
      if (row.status == 'applied') {
        return {
          'id': id,
          'status': 'applied',
          'replayed': true,
          ...await completionStatus(id),
        };
      }
      if (row.status != 'draft') {
        throw const ConfigurationChangeException(
          'configuration_proposal_not_pending',
        );
      }
      if (clock().millisecondsSinceEpoch >= row.expiresAt) {
        throw const ConfigurationChangeException(
          'configuration_proposal_expired',
        );
      }
      final before = policyObject(jsonDecode(row.beforePayload), 'before');
      final after = policyObject(jsonDecode(row.afterPayload), 'after');
      if (configurationDigest(await backend.readState()) != row.fingerprint) {
        await store.changeStatus(id, 'superseded');
        throw const ConfigurationChangeException(
          'configuration_version_conflict',
        );
      }
      final validation =
          row.category.startsWith('recovery:') &&
              backend is ConfigurationRecoveryValidator
          ? await (backend as ConfigurationRecoveryValidator).validateRecovery(
              after,
            )
          : await backend.validate(after);
      final prepared = _prepared[id];
      final matchesPrepared =
          prepared != null &&
          prepared['fingerprint'] == row.fingerprint &&
          prepared['afterDigest'] == configurationDigest(after);
      if (validation['requiresScriptExecutionApproval'] == true &&
          !matchesPrepared) {
        throw const ConfigurationChangeException(
          'configuration_script_authorization_required',
        );
      }
      final commitValidation = matchesPrepared
          ? policyObject(prepared['validation'], 'prepared validation')
          : validation;
      if (policyDigest(commitValidation) != approvalDigest) {
        throw const ConfigurationChangeException(
          'configuration_approval_changed',
        );
      }
      if (isCurrent?.call() == false) {
        throw const ConfigurationChangeException('configuration_cancelled');
      }
      if (configurationDigest(await backend.readState()) != row.fingerprint) {
        await store.changeStatus(id, 'superseded');
        throw const ConfigurationChangeException(
          'configuration_version_conflict',
        );
      }
      final transaction = backend is ConfigurationCommitBackend
          ? backend as ConfigurationCommitBackend
          : null;
      await transaction?.beginCommit(id, before, after, commitValidation);
      try {
        if (isCurrent?.call() == false) {
          throw const ConfigurationChangeException('configuration_cancelled');
        }
        if (configurationDigest(await backend.readState()) != row.fingerprint) {
          await store.changeStatus(id, 'superseded');
          throw const ConfigurationChangeException(
            'configuration_version_conflict',
          );
        }
        if (isCurrent?.call() == false) {
          throw const ConfigurationChangeException('configuration_cancelled');
        }
        await store.changeStatus(id, 'committing');
        try {
          await backend.persist(after);
          await store.changeStatus(id, 'persisted');
          if (transaction != null) {
            await transaction.activateCommit(id, after, commitValidation);
          } else {
            await backend.activate(after);
          }
          if (configurationDigest(await backend.readState()) !=
              configurationDigest(after)) {
            await store.changeStatus(id, 'superseded');
            throw const ConfigurationChangeException(
              'configuration_version_conflict',
            );
          }
          await store.changeStatus(id, 'applied');
          return {'id': id, 'status': 'applied', ...await completionStatus(id)};
        } catch (error) {
          if (error is ConfigurationChangeException &&
              error.code == 'configuration_version_conflict') {
            rethrow;
          }
          try {
            await store.changeStatus(id, 'restoring');
            if (transaction != null) {
              await transaction.restoreCommit(id, before, after);
            } else if (backend is ConfigurationRecoveryBackend) {
              await (backend as ConfigurationRecoveryBackend).restore(
                before,
                after,
              );
            } else {
              final current = await backend.readState();
              if (configurationDigest(current) != configurationDigest(after) &&
                  configurationDigest(current) != configurationDigest(before)) {
                await store.changeStatus(
                  id,
                  'superseded',
                  error: 'configuration_changed_during_failure',
                );
                throw const ConfigurationChangeException(
                  'configuration_changed_during_failure',
                );
              }
              await backend.persist(before);
              await backend.activate(before);
            }
            if (!configurationRestoredMatches(
              before,
              after,
              await backend.readState(),
            )) {
              throw const ConfigurationChangeException(
                'configuration_restore_verification_failed',
              );
            }
            await store.changeStatus(id, 'restored', error: _safeError(error));
          } catch (restoreError) {
            final latest = await store.readChange(id);
            if (latest?.status != 'superseded') {
              await store.changeStatus(
                id,
                'recovery_required',
                error: _safeError(restoreError),
              );
            }
          }
          throw ConfigurationChangeException(_safeError(error));
        }
      } finally {
        _prepared.remove(id);
        await transaction?.endCommit(id);
      }
    });
  }

  String _safeError(Object error) => error is ConfigurationChangeException
      ? error.code
      : 'configuration_apply_failed';

  Future<ConfigurationProposal> proposeUndo(String id) async {
    final row = await store.readChange(id);
    if (row == null || row.status != 'applied') {
      throw const ConfigurationChangeException('configuration_not_undoable');
    }
    final after = policyObject(jsonDecode(row.afterPayload), 'after');
    if (configurationDigest(await backend.readState()) !=
        configurationDigest(after)) {
      throw const ConfigurationChangeException('configuration_undo_conflict');
    }
    return propose(
      category: 'undo',
      summary: row.summary,
      candidate: policyObject(jsonDecode(row.beforePayload), 'before'),
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
        row.category.startsWith('resource:')) {
      throw const ConfigurationChangeException(
        'configuration_recovery_missing',
      );
    }
    final current = await backend.readState();
    final candidate =
        replacement ??
        (keepCurrent
            ? current
            : configurationRecoveryState(
                policyObject(jsonDecode(row.beforePayload), 'before'),
                policyObject(jsonDecode(row.afterPayload), 'after'),
                current,
              ));
    return propose(
      category: 'recovery:$id',
      summary: row.summary,
      candidate: candidate,
    );
  }

  Future<Map<String, Object?>> commitRecovery(
    ConfigurationProposal proposal, {
    required ConfigurationApproval approve,
    bool Function()? isCurrent,
  }) async {
    final row = await store.readChange(proposal.id);
    if (row == null || !row.category.startsWith('recovery:')) {
      throw const ConfigurationChangeException(
        'configuration_recovery_missing',
      );
    }
    final originalId = row.category.substring('recovery:'.length);
    final original = await store.readChange(originalId);
    if (original?.status != 'recovery_required') {
      throw const ConfigurationChangeException(
        'configuration_recovery_conflict',
      );
    }
    final prepared = await prepareApprovedValidation(
      id: proposal.id,
      approve: approve,
      isCurrent: isCurrent,
    );
    final result = await commit(
      id: prepared.id,
      approve: approve,
      isCurrent: isCurrent,
    );
    if (result['status'] == 'applied') {
      await store.changeStatus(originalId, 'resolved', error: original!.error);
    }
    return {...result, 'recoveryOf': originalId};
  }

  Future<void> recoverInterrupted() => _serial(() async {
    for (final row in await store.interruptedChanges()) {
      if (row.category.startsWith('resource:') ||
          row.category.startsWith('repair:')) {
        continue;
      }
      if (row.category.startsWith('recovery:')) {
        final original = await store.readChange(
          row.category.substring('recovery:'.length),
        );
        if (original?.category.startsWith('resource:') == true) continue;
      }
      try {
        final before = policyObject(jsonDecode(row.beforePayload), 'before');
        final after = policyObject(jsonDecode(row.afterPayload), 'after');
        final current = await backend.readState();
        if (backend is! ConfigurationRecoveryBackend &&
            configurationDigest(current) != configurationDigest(before) &&
            configurationDigest(current) != configurationDigest(after)) {
          await store.changeStatus(
            row.id,
            'superseded',
            error: 'configuration_recovery_conflict',
          );
          continue;
        }
        await store.changeStatus(row.id, 'restoring');
        final recovery = backend;
        if (recovery is ConfigurationRecoveryBackend) {
          await (recovery as ConfigurationRecoveryBackend).restore(
            before,
            after,
          );
        } else {
          await backend.persist(before);
          await backend.activate(before);
        }
        await store.changeStatus(row.id, 'restored');
      } catch (_) {
        await store.changeStatus(
          row.id,
          'recovery_required',
          error: 'configuration_recovery_failed',
        );
      }
    }
  });
}
