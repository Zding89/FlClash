import 'dart:convert';
import 'package:drift/native.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/configuration/resources.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:flutter/material.dart';

class SourceEnvironment implements ResourceEnvironment {
  Map<String, Object?> state = {
    'scope': const ResourceScope(ResourceKind.profile, 7).toJson(),
    'profile': null,
    'protectedContent': null,
  };
  int writes = 0;
  int activations = 0;
  @override
  Future<Map<String, Object?>> read(ResourceScope scope) async =>
      policyObject(jsonDecode(jsonEncode(state)), 'state');
  @override
  Future<ResourceValidation> validate(
    ResourceScope scope,
    Map<String, Object?> candidate, {
    required bool approvedScript,
  }) async => const ResourceValidation({'validated': true});
  @override
  Future<void> persist(
    ResourceScope scope,
    Map<String, Object?> candidate,
  ) async {
    writes++;
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
  }
}

void main() {
  late WorkbenchDatabase store;
  late SourceEnvironment environment;
  late ResourceChangeService service;
  var valid = true;
  const content =
      'proxies: [{name: fixture, type: http, server: example.invalid, port: 443}]';
  setUp(() async {
    await AppLocalizations.load(const Locale('en'));
    store = WorkbenchDatabase(NativeDatabase.memory());
    environment = SourceEnvironment();
    valid = true;
    service = ResourceChangeService(
      store: store,
      environment: environment,
      validateRecoveryContent: (_) async => valid ? '' : 'invalid',
    );
    const document = LocalPolicyDocument(
      integrations: [
        SubscriptionIntegration(
          id: 'target',
          label: 'target',
          sourceProfileIds: [7],
        ),
      ],
    );
    await store.writeSection('policies', document.toJson());
    await store.saveChange(
      id: 'failed',
      category: 'policies',
      summary: 'failure',
      highRisk: true,
      fingerprint: 'fixture',
      before: {'policies': document.toJson()},
      after: {'policies': document.toJson()},
      createdAt: 1,
      expiresAt: 9999999999999,
    );
    await store.changeStatus(
      'failed',
      'recovery_required',
      error: 'preserved_failure',
    );
  });
  tearDown(() => store.close());
  test(
    'prepared source preserves blocked recovery and never activates Core',
    () async {
      final proposal = await service.proposeRepairSource(
        'failed',
        7,
        content: content,
      );
      expect(proposal.highRisk, isTrue);
      expect(proposal.toJson().toString(), isNot(contains(content)));
      final result = await service.commit(
        proposal.id,
        approve: (_) async => true,
      );
      expect(result['status'], 'applied');
      expect(result['recoveryPending'], isTrue);
      expect(environment.writes, 1);
      expect(environment.activations, 0);
      expect((environment.state['profile'] as Map)['id'], 7);
      expect(environment.state['protectedContent'], content);
      expect((await store.readChange('failed'))!.status, 'recovery_required');
      expect((await store.readChange('failed'))!.error, 'preserved_failure');
    },
  );
  test(
    'unrelated source, existing resource and invalid native config are rejected before write',
    () async {
      await expectLater(
        service.proposeRepairSource('failed', 8, content: content),
        throwsA(isA<ConfigurationChangeException>()),
      );
      environment.state['profile'] = {'id': 7};
      await expectLater(
        service.proposeRepairSource('failed', 7, content: content),
        throwsA(isA<ConfigurationChangeException>()),
      );
      environment.state['profile'] = null;
      valid = false;
      await expectLater(
        service.proposeRepairSource('failed', 7, content: content),
        throwsA(isA<ConfigurationChangeException>()),
      );
      expect(environment.writes, 0);
    },
  );
  test(
    'rejected repair and stale approval keep original missing source',
    () async {
      final proposal = await service.proposeRepairSource(
        'failed',
        7,
        content: content,
      );
      expect(
        (await service.commit(
          proposal.id,
          approve: (_) async => false,
        ))['status'],
        'rejected',
      );
      final next = await service.proposeRepairSource(
        'failed',
        7,
        content: content,
      );
      await store.changeStatus('failed', 'resolved');
      await expectLater(
        service.commit(next.id, approve: (_) async => true),
        throwsA(isA<ConfigurationChangeException>()),
      );
      expect(environment.writes, 0);
      expect(environment.state['profile'], isNull);
    },
  );
}
