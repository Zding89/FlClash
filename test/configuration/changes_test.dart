import 'dart:convert';

import 'package:drift/native.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/configuration/settings.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:flutter_test/flutter_test.dart';

class _Backend
    implements
        ConfigurationBackend,
        ApprovedConfigurationValidator,
        ConfigurationRecoveryBackend {
  Map<String, Object?> state = {'value': 1, 'other': 1};
  int writes = 0;
  int activations = 0;
  int scriptRuns = 0;
  bool failActivation = false;
  bool partialWrite = false;
  bool scriptRequired = false;

  @override
  Future<Map<String, Object?>> readState() async =>
      policyObject(jsonDecode(jsonEncode(state)), 'state');
  @override
  Future<Map<String, Object?>> validate(Map<String, Object?> candidate) async =>
      {'requiresScriptExecutionApproval': scriptRequired};
  @override
  bool isHighRisk(Map<String, Object?> before, Map<String, Object?> after) =>
      true;
  @override
  Future<void> persist(Map<String, Object?> candidate) async {
    writes++;
    if (partialWrite) {
      state['value'] = candidate['value'];
      state['other'] = 7;
      partialWrite = false;
      throw StateError('partial');
    }
    state = Map.of(candidate);
  }

  @override
  Future<void> activate(Map<String, Object?> candidate) async {
    activations++;
    if (failActivation) {
      failActivation = false;
      throw StateError('apply');
    }
  }

  @override
  Future<void> restore(
    Map<String, Object?> before,
    Map<String, Object?> after,
  ) async {
    final restored = Map<String, Object?>.of(state);
    for (final key in before.keys) {
      if (before[key] == after[key]) continue;
      if (state[key] != before[key] && state[key] != after[key]) {
        throw const ConfigurationChangeException(
          'configuration_recovery_conflict',
        );
      }
      restored[key] = before[key];
    }
    await persist(restored);
    await activate(restored);
  }

  @override
  Future<Map<String, Object?>> validateApproved(
    Map<String, Object?> candidate,
  ) async {
    scriptRuns++;
    return {'finalConfigValidated': true};
  }
}

class _TransactionalBackend extends _Backend
    implements ConfigurationCommitBackend {
  final Map<String, String> artifacts = {};
  final Map<String, String> approved = {};
  String actual = 'before';
  bool failReadAfterActivation = false;
  bool _failNextRead = false;

  String key(Map<String, Object?> after, String digest) =>
      '${policyDigest(after)}:$digest';
  @override
  Future<Map<String, Object?>> readState() async {
    if (_failNextRead) {
      _failNextRead = false;
      throw StateError('read failed');
    }
    return super.readState();
  }

  @override
  Future<Map<String, Object?>> validateApproved(
    Map<String, Object?> candidate,
  ) async {
    scriptRuns++;
    final output = 'result-$scriptRuns';
    final digest = policyDigest(output);
    approved[key(candidate, digest)] = output;
    return {'finalConfigValidated': true, 'finalConfigDigest': digest};
  }

  @override
  Future<void> beginCommit(
    String id,
    Map<String, Object?> before,
    Map<String, Object?> after,
    Map<String, Object?> validation,
  ) async {
    final digest = validation['finalConfigDigest'] as String;
    if (!approved.containsKey(key(after, digest))) {
      throw const ConfigurationChangeException(
        'configuration_script_preview_missing',
      );
    }
    artifacts[id] = actual;
  }

  @override
  Future<void> activateCommit(
    String id,
    Map<String, Object?> after,
    Map<String, Object?> validation,
  ) async {
    actual = approved[key(after, validation['finalConfigDigest'] as String)]!;
    await activate(after);
    _failNextRead = failReadAfterActivation;
  }

  @override
  Future<void> restoreCommit(
    String id,
    Map<String, Object?> before,
    Map<String, Object?> after,
  ) async {
    await restore(before, after);
    actual = artifacts[id]!;
  }

  @override
  Future<void> endCommit(String id) async {
    artifacts.remove(id);
  }
}

class _CompletionBackend extends _Backend
    implements ConfigurationCompletionBackend {
  bool changeDuringRead = false;
  bool running = true;

  @override
  Future<ConfigurationCompletionReceipt> readCompletion(
    Map<String, Object?> before,
    Map<String, Object?> after, {
    required bool currentStateMatches,
  }) async {
    if (changeDuringRead) state['value'] = 3;
    return ConfigurationCompletionReceipt(
      persisted: true,
      currentStateMatches: currentStateMatches,
      scope: ConfigurationCompletionScope.localPolicy,
      activation: ConfigurationActivationReceipt(
        required: true,
        targetId: localPolicyTargetId,
        documentRevision: 1,
        loadedTargetId: localPolicyTargetId,
        loadedDocumentRevision: 1,
        loaded: true,
        running: running,
        reason: running ? 'active' : 'network_stopped',
      ),
    );
  }
}

class _ConcurrentValidationBackend extends _Backend {
  @override
  Future<Map<String, Object?>> validate(Map<String, Object?> candidate) async {
    state['other'] = 2;
    return super.validate(candidate);
  }
}

class _JournalFailureDatabase extends WorkbenchDatabase {
  _JournalFailureDatabase() : super(NativeDatabase.memory());
  @override
  Future<void> changeStatus(String id, String status, {String? error}) async {
    if (status == 'applied') throw StateError('journal unavailable');
    return super.changeStatus(id, status, error: error);
  }
}

void main() {
  late WorkbenchDatabase database;
  late _Backend backend;
  late ConfigurationChangeService service;
  setUp(() {
    database = WorkbenchDatabase(NativeDatabase.memory());
    backend = _Backend();
    service = ConfigurationChangeService(backend: backend, store: database);
  });
  tearDown(() async => database.close());
  Future<ConfigurationProposal> proposal() => service.propose(
    category: 'settings',
    summary: 'change',
    candidate: {'value': 2, 'other': 1},
  );
  test(
    'replayed commits re-read current runtime and saved state without writing',
    () async {
      final live = _CompletionBackend();
      final changes = ConfigurationChangeService(
        backend: live,
        store: database,
      );
      final draft = await changes.propose(
        category: 'policies',
        summary: 'local rules',
        candidate: {'value': 2, 'other': 1},
      );
      final first = await changes.commit(
        id: draft.id,
        approve: (_) async => true,
      );
      expect((first['completion'] as Map)['outcome'], 'effective');
      final writes = live.writes;
      live.running = false;
      final replay = await changes.commit(
        id: draft.id,
        approve: (_) async => true,
      );
      expect(replay['replayed'], isTrue);
      expect((replay['completion'] as Map)['outcome'], 'saved');
      expect(live.writes, writes);
      live.state['value'] = 4;
      final changed = await changes.completionStatus(draft.id);
      expect(changed['currentStateMatches'], isFalse);
      expect((changed['completion'] as Map)['currentStateMatches'], isFalse);
    },
  );

  test(
    'a concurrent saved-state change invalidates runtime completion evidence',
    () async {
      final live = _CompletionBackend();
      final changes = ConfigurationChangeService(
        backend: live,
        store: database,
      );
      final draft = await changes.propose(
        category: 'policies',
        summary: 'local rules',
        candidate: {'value': 2, 'other': 1},
      );
      await changes.commit(id: draft.id, approve: (_) async => true);
      live.changeDuringRead = true;
      final result = await changes.completionStatus(draft.id);
      expect(result['currentStateMatches'], isFalse);
      expect((result['completion'] as Map)['outcome'], 'saved');
      expect((result['completion'] as Map)['currentStateMatches'], isFalse);
    },
  );

  test('stale full state cannot produce a policy draft', () async {
    final expected = configurationDigest(await backend.readState());
    backend.state['other'] = 2;
    await expectLater(
      service.propose(
        category: 'policies',
        summary: 'stale snapshot',
        candidate: {'value': 2, 'other': 1},
        expectedStateDigest: expected,
      ),
      throwsA(
        isA<ConfigurationChangeException>().having(
          (error) => error.code,
          'code',
          'configuration_version_conflict',
        ),
      ),
    );
    expect(backend.writes, 0);
  });
  test('full state changes during draft validation are rejected', () async {
    final concurrent = _ConcurrentValidationBackend();
    service = ConfigurationChangeService(backend: concurrent, store: database);
    await expectLater(
      service.propose(
        category: 'policies',
        summary: 'concurrent validation',
        candidate: {'value': 2, 'other': 1},
        expectedStateDigest: configurationDigest(await concurrent.readState()),
      ),
      throwsA(
        isA<ConfigurationChangeException>().having(
          (error) => error.code,
          'code',
          'configuration_version_conflict',
        ),
      ),
    );
    expect(concurrent.writes, 0);
    expect(concurrent.state, {'value': 1, 'other': 2});
  });
  test(
    'all services sharing one store serialize overlapping approved writes',
    () async {
      final first = await proposal();
      final secondService = ConfigurationChangeService(
        backend: backend,
        store: database,
      );
      final second = await secondService.propose(
        category: 'resource:profile:1',
        summary: 'same state',
        candidate: {'value': 2, 'other': 1},
      );
      final outcomes = await Future.wait([
        service
            .commit(id: first.id, approve: (_) async => true)
            .then((r) => r['status'], onError: (Object e) => e),
        secondService
            .commit(id: second.id, approve: (_) async => true)
            .then((r) => r['status'], onError: (Object e) => e),
      ]);
      expect(outcomes.where((result) => result == 'applied').length, 1);
      expect(
        outcomes.whereType<ConfigurationChangeException>().single.code,
        'configuration_version_conflict',
      );
      expect(backend.writes, 1);
    },
  );
  test(
    'repeat prepare while final approval waits cannot replace script output',
    () async {
      final tx = _TransactionalBackend()..scriptRequired = true;
      service = ConfigurationChangeService(backend: tx, store: database);
      final draft = await service.propose(
        category: 'settings',
        summary: 'script',
        candidate: {'value': 2, 'other': 1},
      );
      final prepared = await service.prepareApprovedValidation(
        id: draft.id,
        approve: (_) async => true,
      );
      await service.commit(
        id: draft.id,
        approve: (shown) async {
          final repeat = await service.prepareApprovedValidation(
            id: draft.id,
            approve: (_) async => true,
          );
          expect(repeat.validation, prepared.validation);
          return true;
        },
      );
      expect(tx.scriptRuns, 1);
      expect(tx.actual, 'result-1');
      expect(tx.artifacts, isEmpty);
    },
  );
  test(
    'distinct drafts of an identical candidate retain the approved output',
    () async {
      final tx = _TransactionalBackend()..scriptRequired = true;
      service = ConfigurationChangeService(backend: tx, store: database);
      final one = await service.propose(
        category: 'settings',
        summary: 'one',
        candidate: {'value': 2, 'other': 1},
      );
      final two = await service.propose(
        category: 'settings',
        summary: 'two',
        candidate: {'value': 2, 'other': 1},
      );
      await service.prepareApprovedValidation(
        id: one.id,
        approve: (_) async => true,
      );
      await service.commit(
        id: one.id,
        approve: (_) async {
          await service.prepareApprovedValidation(
            id: two.id,
            approve: (_) async => true,
          );
          return true;
        },
      );
      expect(tx.scriptRuns, 2);
      expect(tx.actual, 'result-1');
    },
  );
  for (final fault in ['journal', 'readback']) {
    test(
      'successful activation followed by $fault failure restores original artifact',
      () async {
        if (fault == 'journal') {
          await database.close();
          database = _JournalFailureDatabase();
        }
        final tx = _TransactionalBackend()
          ..scriptRequired = true
          ..failReadAfterActivation = fault == 'readback';
        service = ConfigurationChangeService(backend: tx, store: database);
        final draft = await service.propose(
          category: 'settings',
          summary: 'script',
          candidate: {'value': 2, 'other': 1},
        );
        await service.prepareApprovedValidation(
          id: draft.id,
          approve: (_) async => true,
        );
        await expectLater(
          service.commit(id: draft.id, approve: (_) async => true),
          throwsA(isA<ConfigurationChangeException>()),
        );
        expect(tx.state, {'value': 1, 'other': 1});
        expect(tx.actual, 'before');
        expect((await database.readChange(draft.id))!.status, 'restored');
        expect(tx.artifacts, isEmpty);
      },
    );
  }
  test('preview and rejection never persist or activate', () async {
    final draft = await proposal();
    expect(backend.writes, 0);
    expect(backend.activations, 0);
    final result = await service.commit(
      id: draft.id,
      approve: (_) async => false,
    );
    expect(result['status'], 'rejected');
    expect(backend.state['value'], 1);
    expect(backend.writes, 0);
  });
  test('approval cannot overwrite a later user edit', () async {
    final draft = await proposal();
    await expectLater(
      service.commit(
        id: draft.id,
        approve: (_) async {
          backend.state['value'] = 3;
          return true;
        },
      ),
      throwsA(
        isA<ConfigurationChangeException>().having(
          (e) => e.code,
          'code',
          'configuration_version_conflict',
        ),
      ),
    );
    expect(backend.state['value'], 3);
    expect(backend.writes, 0);
  });
  test('cancelled generation cannot commit after approval', () async {
    final draft = await proposal();
    var current = true;
    await expectLater(
      service.commit(
        id: draft.id,
        isCurrent: () => current,
        approve: (_) async {
          current = false;
          return true;
        },
      ),
      throwsA(isA<ConfigurationChangeException>()),
    );
    expect(backend.writes, 0);
  });
  test('applied operation is idempotent and undo is version checked', () async {
    final draft = await proposal();
    await service.commit(id: draft.id, approve: (_) async => true);
    final replay = await service.commit(
      id: draft.id,
      approve: (_) async => throw StateError('unexpected approval'),
    );
    expect(replay['replayed'], true);
    expect(backend.writes, 1);
    backend.state['other'] = 9;
    await expectLater(
      service.proposeUndo(draft.id),
      throwsA(isA<ConfigurationChangeException>()),
    );
  });

  test('AI-only changes survive randomized WebDAV password encoding', () async {
    const config = Config(
      themeProps: defaultThemeProps,
      davProps: DAVProps(
        uri: 'https://example.invalid/dav',
        user: 'user',
        password: 'secret',
      ),
    );
    backend.state = {
      'config': configJson(config),
      'ai': {
        'schemaVersion': 1,
        'enabled': false,
        'selectedConnectionId': null,
        'connections': <Object?>[],
      },
    };
    final candidate = {
      'config': configJson(config),
      'ai': {
        'schemaVersion': 1,
        'enabled': true,
        'selectedConnectionId': 'ds',
        'connections': [
          {
            'id': 'ds',
            'label': 'DeepSeek',
            'provider': 'deepseek',
            'model': 'deepseek-chat',
            'baseUrl': '',
            'api': 'openai-completions',
            'useProxy': false,
            'timeoutSeconds': 90,
            'maxTokens': 4096,
          },
        ],
      },
    };
    final proposal = await service.propose(
      category: 'ai',
      summary: 'AI settings',
      candidate: candidate,
    );
    final result = await service.commit(
      id: proposal.id,
      approve: (_) async => true,
    );
    expect(result['status'], 'applied');
    expect((await backend.readState())['config'], isNotNull);
    expect(
      configurationDigest(await backend.readState()),
      configurationDigest(candidate),
    );
  });
  test(
    'activation failure restores persisted state and reports failure',
    () async {
      final draft = await proposal();
      backend.failActivation = true;
      await expectLater(
        service.commit(id: draft.id, approve: (_) async => true),
        throwsA(isA<ConfigurationChangeException>()),
      );
      expect(backend.state, {'value': 1, 'other': 1});
      expect((await database.readChange(draft.id))!.status, 'restored');
    },
  );
  test(
    'partial writes restore owned fields and preserve unrelated newer values',
    () async {
      final draft = await proposal();
      backend.partialWrite = true;
      await expectLater(
        service.commit(id: draft.id, approve: (_) async => true),
        throwsA(isA<ConfigurationChangeException>()),
      );
      expect(backend.state, {'value': 1, 'other': 7});
      expect((await database.readChange(draft.id))!.status, 'restored');
    },
  );
  test('startup recovery handles a mixed before and after snapshot', () async {
    final draft = await proposal();
    await database.changeStatus(draft.id, 'persisted');
    backend.state = {'value': 2, 'other': 8};
    await service.recoverInterrupted();
    expect(backend.state, {'value': 1, 'other': 8});
    expect((await database.readChange(draft.id))!.status, 'restored');
  });
  test(
    'script execution approval is distinct from final application approval',
    () async {
      backend.scriptRequired = true;
      final draft = await proposal();
      expect(backend.scriptRuns, 0);
      final prepared = await service.prepareApprovedValidation(
        id: draft.id,
        approve: (p) async {
          expect(p.validation['executionOnly'], true);
          return true;
        },
      );
      expect(prepared.validation['finalConfigValidated'], true);
      expect(backend.scriptRuns, 1);
      expect(backend.writes, 0);
      await service.commit(id: draft.id, approve: (_) async => false);
      expect(backend.writes, 0);
    },
  );
}
