import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fl_clash/ai/credentials.dart';
import 'package:fl_clash/ai/history.dart';
import 'package:fl_clash/ai/settings.dart';
import 'package:fl_clash/configuration/workbench_backup.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late WorkbenchDatabase source;
  late WorkbenchDatabase target;
  late bool warnAboutMultipleDatabases;
  const connection = AgentConnection(
    id: 'primary',
    label: 'Test',
    provider: 'openai',
    model: 'gpt-test',
  );
  const policy = LocalPolicyDocument(
    policies: [
      LocalPolicy(
        id: 'route',
        label: 'Route',
        targetId: 'profile:7',
        candidateNodeIds: ['node-a'],
      ),
    ],
    integrations: [
      SubscriptionIntegration(
        id: 'joined',
        label: 'Joined',
        sourceProfileIds: [7],
      ),
    ],
    budgets: [SourceBudget(sourceId: '7', limitBytes: 500)],
  );

  Future<void> seed() async {
    await source.writeSection('policies', policy.toJson());
    await source.writeSection(
      'ai',
      const AgentSettings(connections: [connection]).toJson(),
    );
    await EncryptedConfigAgentCredentialStore(
      source,
    ).write(connection.credentialId, 'private-api-key');
    await source.saveChange(
      id: 'pending',
      category: 'resource:profile:7',
      summary: 'Pending change',
      highRisk: true,
      fingerprint: 'old-fingerprint',
      before: {'secret': 'old-secret'},
      after: {'secret': 'new-secret'},
      createdAt: 50,
      expiresAt: 9999999999999,
    );
    await source.saveChange(
      id: 'applied',
      category: 'configuration',
      summary: 'Applied change',
      highRisk: false,
      fingerprint: 'applied-fingerprint',
      before: {'permissions': true},
      after: {'localControl': true},
      createdAt: 20,
      expiresAt: 9999999999999,
    );
    await source.changeStatus('applied', 'applied');
    await source.writeSection('aiConversations', {
      'version': 1,
      'conversations': [
        {
          'id': '0123456789abcdef0123456789abcdef',
          'updatedAt': 60,
          'messages': [
            {'role': 'user', 'content': '保留对话'},
          ],
          'changeIds': ['pending', 'applied'],
        },
      ],
    });
    await source.writeSection('localBudgetHistory', {
      '7': {
        'sourceId': '7',
        'usedBytes': 10,
        'limitBytes': 500,
        'periodStart': 1,
        'sampleAt': 2,
        'trusted': true,
      },
    });
    await source.writeSection('localControl', {'enabled': true, 'port': 1234});
    await source.writeSection('permissions', {'approved': true});
    await source.saveSourceCache(7, {'secret': 'subscription-url'});
    await target.writeSection('localControl', {'enabled': false});
    await target.writeSection('permissions', {'approved': false});
    await target.saveSourceCache(7, {'local': 'cache'});
    await target.writeSection('policies', const LocalPolicyDocument().toJson());
  }

  setUpAll(() {
    warnAboutMultipleDatabases =
        driftRuntimeOptions.dontWarnAboutMultipleDatabases;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  tearDownAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases =
        warnAboutMultipleDatabases;
  });

  setUp(() {
    source = WorkbenchDatabase(NativeDatabase.memory());
    target = WorkbenchDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  test(
    'portable backup retains tool context and interrupted task state',
    () async {
      await seed();
      await AiHistoryStore(source).save(
        const AiConversation(
          id: 'abcdef0123456789abcdef0123456789',
          updatedAt: 100,
          messages: [
            {'role': 'user', 'content': 'continue draft'},
          ],
          context: [
            {'role': 'user', 'content': 'continue draft'},
            {
              'role': 'assistant',
              'content': [
                {
                  'type': 'toolCall',
                  'id': 'call-1',
                  'name': 'policies_read',
                  'arguments': {},
                },
              ],
            },
            {
              'role': 'toolResult',
              'toolCallId': 'call-1',
              'toolName': 'policies_read',
              'isError': false,
              'content': [
                {'type': 'text', 'text': '{"document":{"policies":[]}}'},
              ],
            },
          ],
          recoveryRequired: true,
          diagnostics: [
            {'kind': 'run', 'status': 'cancelled', 'at': 100},
          ],
        ),
      );
      final exported = await exportWorkbenchBackup(source, profileIds: {7});
      await restoreWorkbenchBackup(
        target,
        await WorkbenchBackup.parse(exported, profileIds: {7}),
      );
      final restored = (await AiHistoryStore(target).list()).first;
      expect(restored.context, hasLength(3));
      expect(restored.context.last['toolCallId'], 'call-1');
      expect(restored.recoveryRequired, true);
      expect(restored.diagnostics.single['status'], 'cancelled');
    },
  );

  test(
    'round trip preserves portable config and encrypted keys without device state or executable history',
    () async {
      await seed();
      final exported = await exportWorkbenchBackup(source, profileIds: {7});
      final encoded = jsonEncode(exported);
      expect(encoded, isNot(contains('private-api-key')));
      expect(encoded, isNot(contains('old-secret')));
      expect(encoded, isNot(contains('subscription-url')));
      expect(encoded, isNot(contains('localControl')));
      final parsed = await WorkbenchBackup.parse(
        jsonDecode(encoded),
        profileIds: {7},
      );
      await restoreWorkbenchBackup(target, parsed);

      expect(
        (await target.readPolicies()).toJson(),
        policy.asStandalone().toJson(),
      );
      expect(
        await EncryptedConfigAgentCredentialStore(
          target,
        ).read(connection.credentialId),
        'private-api-key',
      );
      expect(
        await target.readSection('aiConversations'),
        await source.readSection('aiConversations'),
      );
      expect(
        await target.readSection('localBudgetHistory'),
        await source.readSection('localBudgetHistory'),
      );
      expect(await target.readSection('localControl'), {'enabled': false});
      expect(await target.readSection('permissions'), {'approved': false});
      expect(await target.readSourceCache(7), {'local': 'cache'});
      expect(await target.interruptedChanges(), isEmpty);
      expect(await target.recoveryChanges(), isEmpty);
      for (final id in ['pending', 'applied']) {
        final row = (await target.readChange(id))!;
        expect(row.status, 'superseded');
        expect(row.expiresAt, 0);
        expect(row.beforePayload, '{}');
        expect(row.afterPayload, '{}');
        expect(row.fingerprint, isEmpty);
      }
    },
  );

  test(
    'restoring replaces synchronized sections and history rather than merging',
    () async {
      await seed();
      await target.saveChange(
        id: 'old',
        category: 'x',
        summary: 'Old',
        highRisk: false,
        fingerprint: '',
        before: {},
        after: {},
        createdAt: 1,
        expiresAt: 9,
      );
      final emptyStore = WorkbenchDatabase(NativeDatabase.memory());
      addTearDown(emptyStore.close);
      final empty = await exportWorkbenchBackup(emptyStore, profileIds: {});
      await restoreWorkbenchBackup(
        target,
        await WorkbenchBackup.parse(empty, profileIds: {}),
      );
      expect((await target.readPolicies()).policies, isEmpty);
      expect(await target.readChange('old'), isNull);
      expect(await target.readSection('localControl'), {'enabled': false});
    },
  );

  test('rejects missing profile references before any writes', () async {
    await seed();
    final exported = await exportWorkbenchBackup(source, profileIds: {7});
    await expectLater(
      WorkbenchBackup.parse(exported, profileIds: {}),
      throwsFormatException,
    );
    expect((await target.readPolicies()).policies, isEmpty);
    expect(await target.readSection('ai'), isNull);
  });

  test(
    'schema three cross-airport groups retain ranking and schedules in backups',
    () async {
      final document = LocalPolicyDocument.fromJson({
        ...policy.toJson(),
        'nodeSets': [
          const PolicyNodeSet(
            id: 'cross',
            label: 'Cross',
            targetId: 'profile:7',
            sourceIds: ['8'],
            preferences: [
              NodePreference(
                type: NodePreferenceType.expiry,
                direction: SortDirection.ascending,
              ),
            ],
            selectionMode: NodeSelectionMode.loadBalance,
            schedule: PolicySchedule(
              windows: [
                PolicyWindow(weekdays: [1], startMinute: 1320, endMinute: 60),
              ],
            ),
          ).toJson(),
        ],
      });
      await source.writeSection('policies', document.toJson());
      final exported = await exportWorkbenchBackup(source, profileIds: {7, 8});
      await restoreWorkbenchBackup(
        target,
        await WorkbenchBackup.parse(exported, profileIds: {7, 8}),
      );
      expect(
        (await target.readPolicies()).toJson(),
        document.asStandalone().toJson(),
      );
      await expectLater(
        WorkbenchBackup.parse(exported, profileIds: {7}),
        throwsFormatException,
      );
    },
  );

  test(
    'standalone backups preserve unchecked source filters and archived integrations',
    () async {
      final document = LocalPolicyDocument.fromJson({
        ...const LocalPolicyDocument(
          integrations: [
            SubscriptionIntegration(
              id: 'archive',
              label: 'Archive',
              sourceProfileIds: [999],
            ),
            SubscriptionIntegration(
              id: localPolicyProfileId,
              label: 'Local',
              sourceProfileIds: [],
            ),
          ],
          nodeSets: [
            PolicyNodeSet(
              id: 'saved',
              label: 'Saved',
              targetId: localPolicyTargetId,
              sourceIds: ['7'],
            ),
          ],
        ).toJson(),
        'schemaVersion': 4,
        'activeIntegrationId': localPolicyProfileId,
      }).asStandalone();
      await source.writeSection('policies', document.toJson());
      final exported = await exportWorkbenchBackup(source, profileIds: {7});
      await restoreWorkbenchBackup(
        target,
        await WorkbenchBackup.parse(exported, profileIds: {7}),
      );
      expect((await target.readPolicies()).toJson(), document.toJson());
      await expectLater(
        WorkbenchBackup.parse(exported, profileIds: {}),
        throwsFormatException,
      );
    },
  );

  test(
    'rejects unknown sections versions credentials and conversation references',
    () async {
      await seed();
      final exported = await exportWorkbenchBackup(source, profileIds: {7});
      Map<String, dynamic> copy() =>
          jsonDecode(jsonEncode(exported)) as Map<String, dynamic>;
      final credentials = (exported['sections'] as Map)['aiCredentials'] as Map;
      final ciphertext =
          (credentials['values'] as Map)[connection.credentialId] as String;
      final bytes = base64Url.decode(ciphertext.substring(3));
      bytes[bytes.length - 1] ^= 1;
      final corruptions = [
        copy()..['version'] = 2,
        copy()..['sections']['localControl'] = {'enabled': true},
        copy()..['sections']['policies']['schemaVersion'] = 99,
        copy()..['sections']['aiCredentials']['values'] = {},
        copy()
          ..['sections']['policies']['integrations'][0]['sourceProfileIds'] = [
            '8',
          ],
        copy()
          ..['sections']['policies']['policies'][0]['candidateNodeIds'] = [
            '8:missing-node',
          ],
        copy()..['sections']['policies']['budgets'][0]['sourceId'] = '8',
        copy()
          ..['sections']['policies']['nodeSets'] = [
            {
              'id': 'set',
              'label': 'Set',
              'targetId': 'profile:7',
              'sourceIds': ['8'],
            },
          ],
        copy()
          ..['sections']['aiCredentials']['values'][connection.credentialId] =
              'v1.broken',
        copy()
          ..['sections']['aiCredentials']['values'][connection.credentialId] =
              'v1.${base64Url.encode(bytes)}',
        copy()
          ..['sections']['aiConversations']['conversations'][0]['changeIds'] = [
            'missing',
          ],
        copy()..['sections']['aiConversations']['version'] = 2,
        copy()..['sections']['localBudgetHistory']['7']['sourceId'] = '8',
        copy()..['sections']['ai']['selectedConnectionId'] = 'missing',
      ];
      for (final json in corruptions) {
        await expectLater(
          WorkbenchBackup.parse(json, profileIds: {7}),
          throwsFormatException,
        );
      }
      expect((await target.readPolicies()).policies, isEmpty);
      expect(await target.readSection('ai'), isNull);
    },
  );

  test('bounds nested values strings and history counts', () async {
    final exported = await exportWorkbenchBackup(source, profileIds: {});
    Map<String, dynamic> copy() =>
        jsonDecode(jsonEncode(exported)) as Map<String, dynamic>;
    final oversized = copy()
      ..['sections']['aiConversations']['conversations'] = List.filled(21, {});
    final largeString = copy()
      ..['sections']['ai']['selectedConnectionId'] = 'a' * (256 * 1024 + 1);
    final nested = copy();
    Object? value;
    for (var i = 0; i < 40; i++) {
      value = [value];
    }
    nested['sections']['ai'] = value;
    for (final json in [oversized, largeString, nested]) {
      await expectLater(
        WorkbenchBackup.parse(json, profileIds: {}),
        throwsFormatException,
      );
    }
  });

  test('validation freezes snapshot and import marks keys attempted', () async {
    await source.writeSection(
      'ai',
      const AgentSettings(connections: [connection]).toJson(),
    );
    await EncryptedConfigAgentCredentialStore(
      source,
    ).write(connection.credentialId, 'private-api-key');
    final exported = await exportWorkbenchBackup(source, profileIds: {});
    final parsing = WorkbenchBackup.parse(exported, profileIds: {});
    ((exported['sections'] as Map)['aiCredentials']
            as Map)['values'][connection.credentialId] =
        'plaintext-mutation';
    final parsed = await parsing;
    (exported['sections'] as Map)['localControl'] = {'enabled': true};
    final copy = parsed.toJson();
    (copy['sections'] as Map)['localControl'] = {'enabled': true};
    await restoreWorkbenchBackup(target, parsed);
    expect(await target.readSection('localControl'), isNull);
    expect(
      await EncryptedConfigAgentCredentialStore(
        target,
      ).read(connection.credentialId),
      'private-api-key',
    );
    expect((await target.readSection('aiCredentials'))!['legacyAttempted'], [
      connection.credentialId,
    ]);
  });

  test('restores transactionally when a database write fails', () async {
    await seed();
    final parsed = await WorkbenchBackup.parse(
      await exportWorkbenchBackup(source, profileIds: {7}),
      profileIds: {7},
    );
    await target.customStatement(
      "CREATE TRIGGER fail_history BEFORE INSERT ON workbench_changes BEGIN SELECT RAISE(ABORT, 'test failure'); END",
    );
    await expectLater(
      restoreWorkbenchBackup(target, parsed),
      throwsA(anything),
    );
    expect((await target.readPolicies()).policies, isEmpty);
    expect(await target.readSection('ai'), isNull);
    expect(await target.readSection('localControl'), {'enabled': false});
  });
}
