import 'dart:convert';

import 'package:drift/native.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:flutter_test/flutter_test.dart';

class RecoveryBackend
    implements ConfigurationBackend, ConfigurationRecoveryValidator {
  Map<String, Object?> state = {'value': 2, 'external': 9};
  int checked = 0;
  int writes = 0;
  int activations = 0;
  void Function()? onPersist;
  void Function()? onRead;
  @override
  Future<Map<String, Object?>> readState() async {
    onRead?.call();
    return policyObject(jsonDecode(jsonEncode(state)), 'state');
  }

  @override
  Future<Map<String, Object?>> validate(Map<String, Object?> candidate) async =>
      {'validated': true};
  @override
  Future<Map<String, Object?>> validateRecovery(
    Map<String, Object?> candidate,
  ) async {
    checked++;
    return {'validated': true, 'forceActivation': true};
  }

  @override
  Future<Map<String, Object?>> validateRecoveryApproved(
    Map<String, Object?> candidate,
  ) => validateRecovery(candidate);
  @override
  bool isHighRisk(Map<String, Object?> before, Map<String, Object?> after) =>
      false;
  @override
  Future<void> persist(Map<String, Object?> candidate) async {
    writes++;
    onPersist?.call();
    state = Map.of(candidate);
  }

  @override
  Future<void> activate(Map<String, Object?> candidate) async {
    activations++;
  }
}

void main() {
  late WorkbenchDatabase store;
  late RecoveryBackend backend;
  late ConfigurationChangeService changes;
  setUp(() async {
    store = WorkbenchDatabase(NativeDatabase.memory());
    backend = RecoveryBackend();
    changes = ConfigurationChangeService(backend: backend, store: store);
    await store.saveChange(
      id: 'failed',
      category: 'policies',
      summary: 'test failure',
      highRisk: true,
      fingerprint: 'before',
      before: {'value': 1, 'external': 1},
      after: {'value': 2, 'external': 1},
      createdAt: 1,
      expiresAt: 9999999999999,
    );
    await store.changeStatus(
      'failed',
      'recovery_required',
      error: 'failure_evidence',
    );
  });
  tearDown(() async {
    await store.close();
  });
  test(
    'recovery blocks ordinary changes and safely merges unrelated live edits',
    () async {
      await expectLater(
        changes.propose(
          category: 'settings',
          summary: 'ordinary',
          candidate: {'value': 3, 'external': 9},
        ),
        throwsA(
          isA<ConfigurationChangeException>().having(
            (e) => e.code,
            'code',
            'configuration_recovery_required',
          ),
        ),
      );
      final proposal = await changes.proposeRecovery('failed');
      expect(proposal.highRisk, isTrue);
      await changes.commitRecovery(proposal, approve: (_) async => true);
      expect(backend.state, {'value': 1, 'external': 9});
      expect(backend.checked, greaterThanOrEqualTo(2));
      final original = await store.readChange('failed');
      expect(original!.status, 'resolved');
      expect(original.error, 'failure_evidence');
      expect(
        (await store.readChange(proposal.id))!.category,
        'recovery:failed',
      );
    },
  );
  test(
    'cancelled recovery approval never persists or resolves the original',
    () async {
      final proposal = await changes.proposeRecovery('failed');
      var current = true;
      await expectLater(
        changes.commitRecovery(
          proposal,
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
      expect(backend.writes, 0);
      expect(backend.activations, 0);
      expect((await store.readChange('failed'))!.status, 'recovery_required');
      expect((await store.readChange(proposal.id))!.status, 'draft');
    },
  );

  test(
    'recovery rechecks cancellation after its final asynchronous read',
    () async {
      final proposal = await changes.proposeRecovery('failed');
      var current = true;
      var readsAfterApproval = 0;
      await expectLater(
        changes.commitRecovery(
          proposal,
          approve: (_) async {
            backend.onRead = () {
              readsAfterApproval++;
              if (readsAfterApproval == 3) current = false;
            };
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
      expect(readsAfterApproval, 3);
      expect(backend.writes, 0);
      expect(backend.activations, 0);
      expect((await store.readChange('failed'))!.status, 'recovery_required');
    },
  );

  test(
    'recovery finishes and resolves after persistence has started',
    () async {
      final proposal = await changes.proposeRecovery('failed');
      var current = true;
      backend.onPersist = () => current = false;
      final result = await changes.commitRecovery(
        proposal,
        approve: (_) async => true,
        isCurrent: () => current,
      );
      expect(result['status'], 'applied');
      expect(backend.writes, 1);
      expect(backend.activations, 1);
      expect((await store.readChange('failed'))!.status, 'resolved');
    },
  );

  test(
    'keep current must check and activate even when settings have no differences',
    () async {
      final proposal = await changes.proposeRecovery(
        'failed',
        keepCurrent: true,
      );
      expect(proposal.differences, isEmpty);
      await changes.commitRecovery(proposal, approve: (_) async => true);
      expect(backend.checked, greaterThanOrEqualTo(2));
      expect(backend.activations, 1);
      expect(backend.state['value'], 2);
    },
  );
  test(
    'recovery rejection and stale confirmation do not clear failure or overwrite',
    () async {
      final rejected = await changes.proposeRecovery(
        'failed',
        keepCurrent: true,
      );
      expect(
        (await changes.commitRecovery(
          rejected,
          approve: (_) async => false,
        ))['status'],
        'rejected',
      );
      expect((await store.readChange('failed'))!.status, 'recovery_required');
      expect(backend.writes, 0);
      final draft = await changes.proposeRecovery('failed');
      backend.state['value'] = 7;
      await expectLater(
        changes.commitRecovery(draft, approve: (_) async => true),
        throwsA(
          isA<ConfigurationChangeException>().having(
            (e) => e.code,
            'code',
            'configuration_version_conflict',
          ),
        ),
      );
      expect(backend.state['value'], 7);
      expect((await store.readChange('failed'))!.status, 'recovery_required');
    },
  );
  test(
    'conflicting original field cannot be reverted and protected content is redacted',
    () async {
      backend.state['value'] = 8;
      await expectLater(
        changes.proposeRecovery('failed'),
        throwsA(
          isA<ConfigurationChangeException>().having(
            (e) => e.code,
            'code',
            'configuration_recovery_conflict',
          ),
        ),
      );
      final differences = configurationDifferences(
        {
          'resource': {'protectedContent': 'secret-a'},
        },
        {
          'resource': {'protectedContent': 'secret-b'},
        },
      );
      expect(differences.single.before, isNull);
      expect(differences.single.after, isNull);
    },
  );
}
