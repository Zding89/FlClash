import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:fl_clash/common/javascript.dart';
import 'package:fl_clash/common/request.dart';
import 'package:fl_clash/common/snowflake.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/configuration/resources.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/database/database.dart' as db;
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test/test.dart' as test_package;

class _Environment implements ResourceEnvironment, ResourceActivationArtifacts {
  final scope = const ResourceScope(ResourceKind.profile, 7);
  late Map<String, Object?> state = {
    'scope': scope.toJson(),
    'file': 'old',
    'row': 'old',
  };
  int writes = 0;
  int activations = 0;
  int executions = 0;
  bool script = false;
  bool partialWrite = false;
  bool failActivation = false;
  String? appliedYaml;
  String artifact = 'previous effective yaml';
  String generated = 'approved effective yaml';
  Map<String, Object?>? activationPrevious;

  @override
  Future<Map<String, Object?>> read(ResourceScope scope) async =>
      policyObject(jsonDecode(jsonEncode(state)), 'state');

  @override
  Future<String?> readActivationArtifact() async => artifact;

  @override
  Future<ResourceValidation> validate(
    ResourceScope scope,
    Map<String, Object?> candidate, {
    required bool approvedScript,
  }) async {
    if (script && !approvedScript) {
      return const ResourceValidation({
        'requiresScriptExecutionApproval': true,
      });
    }
    if (script) executions++;
    return ResourceValidation({
      'validated': true,
      'finalConfigValidated': true,
    }, generatedYaml: generated);
  }

  @override
  Future<void> persist(
    ResourceScope scope,
    Map<String, Object?> candidate,
  ) async {
    writes++;
    if (partialWrite) {
      state['file'] = candidate['file'];
      partialWrite = false;
      throw StateError('partial write');
    }
    state = Map.of(candidate);
  }

  @override
  Future<void> activate(
    ResourceScope scope,
    Map<String, Object?> candidate, {
    String? generatedYaml,
    Map<String, Object?>? previousSnapshot,
  }) async {
    activations++;
    appliedYaml = generatedYaml;
    if (generatedYaml != null) artifact = generatedYaml;
    activationPrevious = previousSnapshot;
    if (failActivation) {
      failActivation = false;
      throw StateError('partially applied');
    }
  }
}

class _AppliedJournalFailure extends WorkbenchDatabase {
  bool failApplied = true;
  _AppliedJournalFailure() : super(NativeDatabase.memory());
  @override
  Future<void> changeStatus(String id, String status, {String? error}) {
    if (status == 'applied' && failApplied) {
      failApplied = false;
      throw StateError('journal write fixture failure');
    }
    return super.changeStatus(id, status, error: error);
  }
}

class _DownloadAdapter implements HttpClientAdapter {
  final Stream<Uint8List> stream;
  bool cancelled = false;
  _DownloadAdapter(this.stream);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    unawaited(cancelFuture?.then((_) => cancelled = true));
    return ResponseBody(
      stream,
      200,
      headers: {
        'subscription-userinfo': [
          'upload=1; download=2; total=100; expire=1893456000',
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late WorkbenchDatabase database;
  late _Environment environment;
  late ResourceChangeService service;
  setUp(() {
    database = WorkbenchDatabase(NativeDatabase.memory());
    environment = _Environment();
    service = ResourceChangeService(store: database, environment: environment);
  });
  tearDown(() async => database.close());
  Future<ConfigurationProposal> propose() => service.propose(
    environment.scope,
    {...environment.state, 'file': 'new', 'row': 'new'},
    summary: 'fixture',
  );

  test('resource previews and rejected approval never write', () async {
    final draft = await propose();
    expect(draft.highRisk, true);
    expect(environment.writes, 0);
    await service.commit(draft.id, approve: (_) async => false);
    expect(environment.writes, 0);
    expect((await database.readChange(draft.id))!.status, 'rejected');
  });

  test('cancellation during approval never writes', () async {
    var current = true;
    final draft = await propose();
    await expectLater(
      service.commit(
        draft.id,
        approve: (_) async {
          current = false;
          return true;
        },
        isCurrent: () => current,
      ),
      throwsA(isA<ConfigurationChangeException>()),
    );
    expect(environment.writes, 0);
  });

  test(
    'resource recovery cancellation after approval never persists',
    () async {
      final failed = await propose();
      environment.state = {...environment.state, 'file': 'new', 'row': 'new'};
      await database.changeStatus(failed.id, 'recovery_required');
      final recovery = await service.proposeRecovery(failed.id);
      var current = true;
      await expectLater(
        service.commit(
          recovery.id,
          approve: (_) async {
            current = false;
            return true;
          },
          isCurrent: () => current,
        ),
        throwsA(
          isA<ConfigurationChangeException>().having(
            (error) => error.code,
            'code',
            'configuration_cancelled',
          ),
        ),
      );
      expect(environment.writes, 0);
      expect(environment.activations, 0);
      expect(
        (await database.readChange(failed.id))!.status,
        'recovery_required',
      );
      expect((await database.readChange(recovery.id))!.status, 'draft');
    },
  );

  test('commit awaits persistence and applies the approved artifact', () async {
    final draft = await propose();
    await service.commit(draft.id, approve: (_) async => true);
    expect(environment.state['row'], 'new');
    expect(environment.appliedYaml, 'approved effective yaml');
    expect(environment.activationPrevious!['row'], 'old');
    expect((await database.readChange(draft.id))!.status, 'applied');
    final undo = await service.undo(draft.id);
    expect(
      (await database.readChange(undo.id))!.category,
      environment.scope.category,
    );
    await service.commit(undo.id, approve: (_) async => true);
    expect(environment.state['row'], 'old');
  });

  test(
    'partial writes restore file and row using the prior runtime artifact',
    () async {
      final draft = await propose();
      environment.partialWrite = true;
      await expectLater(
        service.commit(draft.id, approve: (_) async => true),
        throwsA(isA<ConfigurationChangeException>()),
      );
      expect(environment.state['file'], 'old');
      expect(environment.state['row'], 'old');
      expect(environment.appliedYaml, 'previous effective yaml');
      expect(environment.activationPrevious!['row'], 'new');
      expect((await database.readChange(draft.id))!.status, 'restored');
    },
  );

  test('partial activation rollback is applied from after state', () async {
    final draft = await propose();
    environment.failActivation = true;
    await expectLater(
      service.commit(draft.id, approve: (_) async => true),
      throwsA(isA<ConfigurationChangeException>()),
    );
    expect(environment.activations, 2);
    expect(environment.appliedYaml, 'previous effective yaml');
    expect(environment.activationPrevious!['file'], 'new');
  });

  test(
    'startup restores mixed snapshots without executing or activating',
    () async {
      final draft = await propose();
      await database.changeStatus(draft.id, 'persisted');
      environment.state['file'] = 'new';
      await service.recoverInterrupted();
      expect(environment.state['file'], 'old');
      expect(environment.activations, 0);
      expect(environment.executions, 0);
      expect((await database.readChange(draft.id))!.status, 'restored');
    },
  );

  test('startup preserves a third party resource value', () async {
    final draft = await propose();
    await database.changeStatus(draft.id, 'persisted');
    environment.state['file'] = 'third party';
    await service.recoverInterrupted();
    expect(environment.state['file'], 'third party');
    expect(environment.writes, 0);
    expect((await database.readChange(draft.id))!.status, 'superseded');
  });

  test(
    'script execution and application have separate approvals and run once',
    () async {
      environment.script = true;
      final draft = await propose();
      expect(environment.executions, 0);
      var approvals = 0;
      await service.commit(
        draft.id,
        approve: (proposal) async {
          approvals++;
          expect(proposal.validation['executionOnly'] == true, approvals == 1);
          return true;
        },
      );
      expect(approvals, 2);
      expect(environment.executions, 1);
      expect(environment.writes, 1);
      expect(environment.appliedYaml, 'approved effective yaml');
    },
  );

  test('rejecting execution approval never executes a script', () async {
    environment.script = true;
    final draft = await propose();
    await expectLater(
      service.commit(draft.id, approve: (_) async => false),
      throwsA(isA<ConfigurationChangeException>()),
    );
    expect(environment.executions, 0);
    expect(environment.writes, 0);
  });

  test(
    'final script review includes effective changes without credentials',
    () async {
      environment.script = true;
      environment.artifact =
          'proxies: [{name: original, password: before-secret, uuid: before-id}]';
      environment.generated =
          'proxies: [{name: next, password: after-secret, uuid: after-id, url: "https://example.invalid/key?token=after-key"}]';
      final draft = await propose();
      var approvals = 0;
      await service.commit(
        draft.id,
        approve: (proposal) async {
          approvals++;
          if (approvals == 1) return true;
          final differences = jsonEncode(
            proposal.validation['finalConfigDifferences'],
          );
          expect(differences, contains('original'));
          expect(differences, contains('next'));
          expect(differences, isNot(contains('before-secret')));
          expect(differences, isNot(contains('after-secret')));
          expect(differences, isNot(contains('after-id')));
          expect(differences, isNot(contains('after-key')));
          return false;
        },
      );
      expect(approvals, 2);
      expect(environment.executions, 1);
      expect(environment.writes, 0);
    },
  );

  test('repeated prepare reuses the exact approved script artifact', () async {
    environment.script = true;
    final draft = await propose();
    final scoped = service.service(environment.scope);
    final first = await scoped.prepareApprovedValidation(
      id: draft.id,
      approve: (_) async => true,
    );
    environment.generated = 'different unapproved yaml';
    var repeatedApprovals = 0;
    final repeated = await scoped.prepareApprovedValidation(
      id: draft.id,
      approve: (_) async {
        repeatedApprovals++;
        return true;
      },
    );
    expect(
      repeated.validation['finalConfigDigest'],
      first.validation['finalConfigDigest'],
    );
    expect(environment.executions, 1);
    expect(repeatedApprovals, 0);
    await service.commit(draft.id, approve: (_) async => true);
    expect(environment.appliedYaml, 'approved effective yaml');
  });

  test(
    'applied journal failure restores the pinned before artifact after activation',
    () async {
      await database.close();
      database = _AppliedJournalFailure();
      service = ResourceChangeService(
        store: database,
        environment: environment,
      );
      final draft = await propose();
      await expectLater(
        service.commit(draft.id, approve: (_) async => true),
        throwsA(isA<ConfigurationChangeException>()),
      );
      expect(environment.activations, 2);
      expect(environment.artifact, 'previous effective yaml');
      expect(environment.state['row'], 'old');
      expect((await database.readChange(draft.id))!.status, 'restored');
    },
  );

  test('commit rejects mismatched final digest before persistence', () async {
    final backend = ResourceConfigurationBackend(
      scope: environment.scope,
      environment: environment,
    );
    final before = await backend.readState();
    final after = {...before, 'row': 'new'};
    final validation = await backend.validate(after);
    await backend.beginCommit('fixture', before, after, validation);
    await expectLater(
      backend.activateCommit('fixture', after, {
        ...validation,
        'finalConfigDigest': 'wrong',
      }),
      throwsA(isA<ConfigurationChangeException>()),
    );
    expect(environment.activations, 0);
    await backend.endCommit('fixture');
  });

  test(
    'different final digests never overwrite a pinned resource artifact',
    () async {
      final backend = ResourceConfigurationBackend(
        scope: environment.scope,
        environment: environment,
      );
      final before = await backend.readState();
      final after = {...before, 'row': 'new'};
      environment.generated = 'approved X';
      final approvedX = await backend.validateApproved(after);
      environment.generated = 'approved Y';
      await backend.validateApproved(after);
      await backend.beginCommit('fixture-X', before, after, approvedX);
      await backend.persist(after);
      await backend.activateCommit('fixture-X', after, approvedX);
      expect(environment.appliedYaml, 'approved X');
      await backend.endCommit('fixture-X');
    },
  );

  test('resource category never accepts arbitrary paths', () {
    for (final category in [
      'resource:profile:/tmp/a',
      'resource:script:0',
      'resource:rules:0:custom',
      'resource:groups:1:added',
    ]) {
      expect(
        () => ResourceScope.fromCategory(category),
        throwsA(isA<ConfigurationChangeException>()),
      );
    }
  });

  group('real scoped persistence fixtures', () {
    late db.Database resourcesDb;
    late ProviderContainer container;
    late Directory directory;
    late FlutterResourceEnvironment real;
    setUp(() async {
      resourcesDb = db.Database(NativeDatabase.memory());
      container = ProviderContainer();
      directory = await Directory.systemTemp.createTemp(
        'flclash-resource-fixture-',
      );
      final reference = Provider<Ref>((ref) => ref);
      real = FlutterResourceEnvironment(
        ref: container.read(reference),
        store: database,
        database: resourcesDb,
        profilePath: (id) async => '${directory.path}/profile-$id.yaml',
        scriptPath: (id) async => '${directory.path}/script-$id.js',
        providerCacheDirectory: (id) async => '${directory.path}/providers-$id',
      );
      await resourcesDb
          .into(resourcesDb.profiles)
          .insertOnConflictUpdate(
            const Profile(
              id: 7,
              label: 'fixture',
              autoUpdateDuration: Duration(hours: 1),
            ).toCompanion(),
          );
      await File(
        '${directory.path}/profile-7.yaml',
      ).writeAsString('rules: [MATCH,REJECT]');
    });
    tearDown(() async {
      container.dispose();
      await resourcesDb.close();
      await directory.delete(recursive: true);
    });

    test(
      'provider cache changes invalidate approval without binding owned raw input',
      () async {
        final cache = File('${directory.path}/providers-7/provider');
        await cache.parent.create(recursive: true);
        await cache.writeAsString('proxies: [{name: old, type: direct}]');
        const scope = ResourceScope(ResourceKind.profile, 7);
        final before = await real.read(scope);
        await File(
          '${directory.path}/profile-7.yaml',
        ).writeAsString('rules: [MATCH,DIRECT]');
        await real.checkInputs(scope, before);
        await cache.writeAsString('proxies: [{name: refreshed, type: direct}]');
        await expectLater(
          real.checkInputs(scope, before),
          throwsA(isA<ConfigurationChangeException>()),
        );
      },
    );

    test(
      'other source resolved snapshot changes invalidate scoped approval',
      () async {
        await resourcesDb
            .into(resourcesDb.profiles)
            .insertOnConflictUpdate(
              const Profile(
                id: 8,
                label: 'other',
                autoUpdateDuration: Duration(hours: 1),
              ).toCompanion(),
            );
        await database.saveSourceCache(8, {
          'proxies': [
            {'name': 'old', 'type': 'direct'},
          ],
        });
        const scope = ResourceScope(ResourceKind.profile, 7);
        final before = await real.read(scope);
        await database.saveSourceCache(8, {
          'proxies': [
            {'name': 'refreshed', 'type': 'direct'},
          ],
        });
        await expectLater(
          real.checkInputs(scope, before),
          throwsA(isA<ConfigurationChangeException>()),
        );
      },
    );

    test(
      'source deletion is blocked while referenced by a saved integration',
      () async {
        await database.writeSection(
          'policies',
          const LocalPolicyDocument(
            integrations: [
              SubscriptionIntegration(
                id: 'main',
                label: 'fixture',
                sourceProfileIds: [7],
              ),
            ],
          ).toJson(),
        );
        const scope = ResourceScope(ResourceKind.profile, 7);
        final candidate = await real.read(scope);
        candidate['profile'] = null;
        candidate['protectedContent'] = null;
        await expectLater(
          real.validate(scope, candidate, approvedScript: false),
          throwsA(
            isA<ConfigurationChangeException>().having(
              (e) => e.code,
              'code',
              'resource_source_referenced',
            ),
          ),
        );
        expect(
          (await resourcesDb.select(resourcesDb.profiles).get()).length,
          1,
        );
        expect(await File('${directory.path}/profile-7.yaml').exists(), true);
      },
    );

    test(
      'rules cannot mutate the private source through a forged candidate',
      () async {
        const scope = ResourceScope(
          ResourceKind.rules,
          7,
          scene: RuleScene.added,
        );
        final candidate = await real.read(scope);
        candidate['protectedContent'] = 'forged source';
        await expectLater(
          real.validate(scope, candidate, approvedScript: false),
          throwsA(
            isA<ConfigurationChangeException>().having(
              (e) => e.code,
              'code',
              'resource_scope_invalid',
            ),
          ),
        );
        expect(
          await File('${directory.path}/profile-7.yaml').readAsString(),
          'rules: [MATCH,REJECT]',
        );
      },
    );

    test(
      'awaited scoped rule persistence restores through the same database',
      () async {
        const scope = ResourceScope(
          ResourceKind.rules,
          7,
          scene: RuleScene.added,
        );
        final before = await real.read(scope);
        final after = {
          ...before,
          'addedRules': [
            const Rule(
              id: 12,
              content: 'example.invalid',
              ruleTarget: 'REJECT',
            ).toJson(),
          ],
        };
        await real.persist(scope, after);
        expect((await real.read(scope))['addedRules'], after['addedRules']);
        await real.persist(scope, before);
        expect((await real.read(scope))['addedRules'], isEmpty);
      },
    );

    test(
      'real Snowflake profile and rule identifiers survive scoped SQL persistence',
      () async {
        final profileId = snowflake.id;
        final ruleId = snowflake.id;
        expect(profileId, greaterThan(9007199254740991));
        final profile = Profile(
          id: profileId,
          label: 'large-id',
          autoUpdateDuration: const Duration(hours: 1),
        );
        await resourcesDb
            .into(resourcesDb.profiles)
            .insertOnConflictUpdate(profile.toCompanion());
        await File(
          '${directory.path}/profile-$profileId.yaml',
        ).writeAsString('rules: [MATCH,REJECT]');
        final scope = ResourceScope(
          ResourceKind.rules,
          profileId,
          scene: RuleScene.added,
        );
        expect(ResourceScope.fromCategory(scope.category).id, profileId);
        final before = await real.read(scope);
        final after = {
          ...before,
          'addedRules': [
            Rule(
              id: ruleId,
              content: 'example.invalid',
              ruleTarget: 'REJECT',
            ).toJson(),
          ],
        };
        await real.persist(scope, after);
        expect(
          ((await real.read(scope))['addedRules'] as List).first,
          (after['addedRules'] as List).first,
        );
        await real.persist(scope, before);
        expect((await real.read(scope))['addedRules'], isEmpty);
      },
    );
  });

  group('bounded subscription response fixtures', () {
    test(
      'response wrapper preserves bytes and subscription metadata',
      () async {
        final adapter = _DownloadAdapter(
          Stream.fromIterable([Uint8List.fromList(utf8.encode('fixture'))]),
        );
        final client = Dio()..httpClientAdapter = adapter;
        try {
          final response = await Request(
            profileClient: client,
          ).getBoundedFileResponse('https://example.invalid/source');
          expect(utf8.decode(response.data!), 'fixture');
          expect(
            response.headers.value('subscription-userinfo'),
            contains('total=100'),
          );
          expect(response.statusCode, 200);
          expect(adapter.cancelled, true);
        } finally {
          client.close(force: true);
        }
      },
    );

    test(
      'oversized source cancels the stream before any resource write',
      () async {
        var closed = false;
        final stream = StreamController<Uint8List>(
          onCancel: () => closed = true,
        );
        final adapter = _DownloadAdapter(stream.stream);
        final client = Dio()..httpClientAdapter = adapter;
        try {
          final pending = Request(profileClient: client).getBoundedFileResponse(
            'https://example.invalid/source',
            maximumBytes: 4,
          );
          stream.add(Uint8List.fromList([1, 2, 3, 4, 5]));
          await expectLater(pending, throwsA(isA<FormatException>()));
          expect(closed, true);
          expect(adapter.cancelled, true);
        } finally {
          await stream.close();
          client.close(force: true);
        }
      },
    );

    test('silent source times out and cancels its stream', () async {
      var closed = false;
      final stream = StreamController<Uint8List>(onCancel: () => closed = true);
      final adapter = _DownloadAdapter(stream.stream);
      final client = Dio()..httpClientAdapter = adapter;
      try {
        await expectLater(
          Request(profileClient: client).getBoundedFileResponse(
            'https://example.invalid/source',
            timeout: const Duration(milliseconds: 20),
          ),
          throwsA(isA<TimeoutException>()),
        );
        expect(closed, true);
        expect(adapter.cancelled, true);
      } finally {
        await stream.close();
        client.close(force: true);
      }
    });
  });

  test_package.group(
    'isolated macOS script worker',
    () {
      late Process worker;
      Future<Process> launch() async {
        worker = await launchScriptProcess(
          executablePath:
              Platform.environment['FLCLASH_TEST_NODE'] ??
              '/private/tmp/flclash-ai-host-node22-arm64/Resources/ai/node',
          runnerPath: '${Directory.current.path}/scripts/script_runner.mjs',
        );
        return worker;
      }

      test('plain context works and exposes no host capabilities', () async {
        final result = await handleEvaluate(
          'function main(config) { config.host = [typeof process, typeof require, typeof Buffer, typeof fetch, typeof setTimeout, typeof ArrayBuffer]; return config; }',
          {'name': 'fixture'},
          launcher: launch,
        );
        expect(result['name'], 'fixture');
        expect(result['host'], List.filled(6, 'undefined'));
        expect(await worker.exitCode, 0);
      });

      test(
        'infinite scripts terminate the owned child and next call succeeds',
        () async {
          await expectLater(
            handleEvaluate(
              'function main(config) { while (true) {} }',
              {},
              timeout: const Duration(milliseconds: 100),
              launcher: launch,
            ),
            throwsA(
              isA<ScriptExecutionException>().having(
                (e) => e.code,
                'code',
                'script_timeout',
              ),
            ),
          );
          expect(await worker.exitCode, isNotNull);
          final result = await handleEvaluate(
            'function main(config) { return {ok: true}; }',
            {},
            launcher: launch,
          );
          expect(result, {'ok': true});
          expect(await worker.exitCode, 0);
        },
      );

      test(
        'parent deadline terminates hostile error getters outside vm timeout',
        () async {
          await expectLater(
            handleEvaluate(
              'function main(config) { throw {get code(){while(true){}}}; }',
              {},
              timeout: const Duration(milliseconds: 100),
              launcher: launch,
            ),
            throwsA(
              isA<ScriptExecutionException>().having(
                (e) => e.code,
                'code',
                'script_timeout',
              ),
            ),
          );
          expect(await worker.exitCode, isNot(0));
        },
      );

      test('UTF-8 input bound rejects before starting a worker', () async {
        var launched = false;
        await expectLater(
          handleEvaluate(
            '汉' * 200000,
            {},
            launcher: () async {
              launched = true;
              return launch();
            },
          ),
          throwsA(
            isA<ScriptExecutionException>().having(
              (e) => e.code,
              'code',
              'script_input_limit',
            ),
          ),
        );
        expect(launched, false);
      });

      test('heap exhaustion exits only the worker', () async {
        await expectLater(
          handleEvaluate(
            'function main(config) { const retained = []; while (true) { retained.push(new Array(100000).fill("fixture")); } }',
            {},
            launcher: launch,
          ),
          throwsA(isA<ScriptExecutionException>()),
        );
        expect(await worker.exitCode, isNot(0));
        expect(
          await handleEvaluate(
            'function main(config) { return {ok:true}; }',
            {},
            launcher: launch,
          ),
          {'ok': true},
        );
      });

      test('large output is rejected with bounded output collection', () async {
        await expectLater(
          handleEvaluate(
            'function main(config) { return {value:"x".repeat(9*1024*1024)}; }',
            {},
            launcher: launch,
          ),
          throwsA(isA<ScriptExecutionException>()),
        );
        expect(await worker.exitCode, isNot(0));
      });

      test('host escape and dynamic import attempts fail closed', () async {
        for (final script in [
          'function main(config) { return {value: process.env.API_KEY}; }',
          'function main(config) { return require("node:fs").readFileSync("/etc/hosts"); }',
          'function main(config) { return config.constructor.constructor("return process")(); }',
          'function main(config) { import("node:fs"); return config; }',
        ]) {
          await expectLater(
            handleEvaluate(script, {}, launcher: launch),
            throwsA(isA<ScriptExecutionException>()),
          );
          expect(await worker.exitCode, isNot(0));
        }
      });

      test(
        'OS sandbox denies file reads, writes, and socket access even to host Node',
        () async {
          final directory = await Directory.systemTemp.createTemp(
            'flclash-script-boundary-',
          );
          Process? sandboxed;
          try {
            final secret = File('${directory.path}/api-key-fixture');
            await secret.writeAsString('fixture-private-key');
            final output = File('${directory.path}/must-not-exist');
            final runner = File('${directory.path}/boundary.mjs');
            await runner.writeAsString('''
import fs from 'node:fs';
import net from 'node:net';
let readCode, writeCode;
try { fs.readFileSync(${jsonEncode(secret.path)}); readCode = 'ALLOWED'; } catch (error) { readCode = error.code; }
try { fs.writeFileSync(${jsonEncode(output.path)}, 'fixture'); writeCode = 'ALLOWED'; } catch (error) { writeCode = error.code; }
const networkCode = await new Promise((resolve) => {
  const socket = net.createConnection({host:'127.0.0.1', port:1});
  socket.on('error', (error) => { socket.destroy(); resolve(error.code); });
  socket.on('connect', () => { socket.destroy(); resolve('ALLOWED'); });
});
process.stdout.write(JSON.stringify({readCode,writeCode,networkCode, inheritedSecret:process.env.FLCLASH_TEST_SECRET ?? null}));
''');
            sandboxed = await launchScriptProcess(
              executablePath:
                  Platform.environment['FLCLASH_TEST_NODE'] ??
                  '/private/tmp/flclash-ai-host-node22-arm64/Resources/ai/node',
              runnerPath: runner.path,
            );
            final diagnostics = sandboxed.stderr.drain<void>();
            final response = await utf8.decoder
                .bind(sandboxed.stdout)
                .join()
                .timeout(const Duration(seconds: 3));
            expect(await sandboxed.exitCode, 0);
            await diagnostics;
            final value = jsonDecode(response) as Map;
            expect(value['readCode'], anyOf('EPERM', 'EACCES'));
            expect(value['writeCode'], anyOf('EPERM', 'EACCES'));
            expect(value['networkCode'], anyOf('EPERM', 'EACCES'));
            expect(value['inheritedSecret'], null);
            expect(await output.exists(), false);
          } finally {
            sandboxed?.kill(ProcessSignal.sigkill);
            await sandboxed?.exitCode;
            await directory.delete(recursive: true);
          }
        },
      );
    },
    tags: ['native-script-worker'],
    skip: !Platform.isMacOS,
  );
}
