import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:fl_clash/ai/history.dart';
import 'package:fl_clash/ai/context.dart';
import 'package:fl_clash/ai/policy_contract.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:flutter_test/flutter_test.dart';

String _id(int value) => value.toRadixString(16).padLeft(32, '0');

AiConversation _conversation(
  int number, {
  int? updatedAt,
  List<Map<String, String>>? messages,
}) => AiConversation(
  id: _id(number),
  updatedAt: updatedAt ?? number,
  messages:
      messages ??
      [
        {'role': 'user', 'content': 'question $number'},
      ],
  targetLabel: 'source $number',
  changeIds: ['change-$number'],
);

class _DelayedDatabase extends WorkbenchDatabase {
  _DelayedDatabase() : super(NativeDatabase.memory());

  Completer<void>? readStarted;
  Completer<void>? readRelease;
  Object? readFailure;
  Object? writeFailure;

  @override
  Future<Map<String, Object?>?> readSection(String section) async {
    final failure = readFailure;
    if (failure != null) {
      readFailure = null;
      throw failure;
    }
    if (section == 'aiConversations' && readStarted != null) {
      final started = readStarted!;
      final release = readRelease!;
      readStarted = null;
      started.complete();
      await release.future;
    }
    return super.readSection(section);
  }

  @override
  Future<void> writeSection(
    String section,
    Map<String, Object?> payload,
  ) async {
    final failure = writeFailure;
    if (section == 'aiConversations' && failure != null) {
      writeFailure = null;
      throw failure;
    }
    await super.writeSection(section, payload);
  }
}

void main() {
  late Directory directory;
  late File file;
  late WorkbenchDatabase database;
  late AiHistoryStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('flclash-ai-history-');
    file = File('${directory.path}/workbench.sqlite');
    database = WorkbenchDatabase(NativeDatabase(file));
    store = AiHistoryStore(database);
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test(
    'restored conversations can be updated after an earlier local deletion',
    () async {
      await store.save(_conversation(1));
      final snapshot = await database.readSection('aiConversations');
      await store.delete(_id(1));
      expect(await store.list(), isEmpty);
      final generations = <int>[];
      final subscription = store.restores.listen(generations.add);
      addTearDown(subscription.cancel);

      await AiHistoryStore.replaceForRestore(database, () async {
        await database.writeSection('aiConversations', snapshot!);
      });
      await Future<void>.delayed(Duration.zero);
      await store.save(
        _conversation(
          1,
          messages: const [
            {'role': 'user', 'content': 'continued after restore'},
          ],
        ),
      );

      expect((await store.list()).single.title, 'continued after restore');
      expect(generations, [1]);
      expect(store.generation, 1);
    },
  );

  test(
    'restoration excludes saves during replacement and resets all store instances',
    () async {
      await store.save(_conversation(1));
      final snapshot = await database.readSection('aiConversations');
      final another = AiHistoryStore(database);
      await another.delete(_id(1));
      final entered = Completer<void>();
      final release = Completer<void>();
      final restoration = AiHistoryStore.replaceForRestore(database, () async {
        entered.complete();
        await release.future;
        await database.writeSection('aiConversations', snapshot!);
      });
      await entered.future;
      await store.save(_conversation(2));
      release.complete();
      await restoration;
      await another.save(_conversation(1, updatedAt: 10));

      expect((await store.list()).map((entry) => entry.id), [_id(1)]);
      expect((await store.list()).single.updatedAt, 10);
      expect(another.generation, store.generation);
    },
  );

  Future<void> reopen() async {
    await database.close();
    database = WorkbenchDatabase(NativeDatabase(file));
    store = AiHistoryStore(database);
  }

  test('reopening database restores the latest twenty conversations', () async {
    for (var index = 1; index <= 25; index++) {
      await store.save(_conversation(index));
    }
    await reopen();

    final restored = await store.list();
    expect(restored.map((entry) => entry.id), [
      for (var index = 25; index >= 6; index--) _id(index),
    ]);
    expect(restored.first.title, 'question 25');
    expect(restored.first.targetLabel, 'source 25');
    expect(restored.first.changeIds, ['change-25']);
    await store.delete(_id(25));
    await reopen();
    final afterDeletion = await store.list();
    expect(afterDeletion, hasLength(19));
    expect(afterDeletion.map((entry) => entry.id), isNot(contains(_id(25))));
  });

  test('message retention restores the latest eighty text messages', () async {
    await store.save(
      _conversation(
        1,
        messages: [
          for (var index = 0; index < 95; index++)
            {
              'role': index.isEven ? 'user' : 'assistant',
              'content': 'message $index',
            },
        ],
      ),
    );
    await reopen();

    final messages = (await store.list()).single.messages;
    expect(messages, hasLength(80));
    expect(messages.first['content'], 'message 15');
    expect(messages.last['content'], 'message 94');
  });

  test(
    'UTF-8 message bytes include the 256 KiB boundary and omit older text',
    () async {
      final chinese = List.filled(87381, '汉').join();
      expect(utf8.encode(chinese).length, 256 * 1024 - 1);
      await store.save(
        _conversation(
          1,
          messages: [
            {'role': 'user', 'content': 'older text'},
            {'role': 'user', 'content': chinese},
            {'role': 'assistant', 'content': 'a'},
          ],
        ),
      );
      await reopen();

      final messages = (await store.list()).single.messages;
      expect(messages, hasLength(2));
      expect(messages.first['content'], chinese);
      expect(messages.last['content'], 'a');
      expect(
        messages.fold<int>(
          0,
          (total, message) => total + utf8.encode(message['content']!).length,
        ),
        256 * 1024,
      );
    },
  );

  test(
    'tools, proposals, transport details and known secrets are not stored',
    () async {
      const key = 'provider-key-private-value';
      const sourcePassword = 'source-password-private-value';
      final safeText = aiHistoryText(
        'Use $key and $sourcePassword; sk-example123456; '
        'Bearer bearer-private-value; '
        'https://user:password@example.com/subscription/private?token=private#key',
        [key, sourcePassword],
      );
      await store.save(
        _conversation(
          1,
          messages: [
            {'role': 'system', 'content': 'system-private-value'},
            {'role': 'tool', 'content': 'tool-private-value'},
            {
              'role': 'user',
              'content': safeText,
              'proposal': 'proposal-private-value',
            },
            {
              'role': 'assistant',
              'content': 'text reply',
              'toolCallId': 'tool-id-private-value',
              'arguments': 'arguments-private-value',
            },
          ],
        ),
      );
      await reopen();

      final raw = jsonEncode(await database.readSection('aiConversations'));
      for (final secret in [
        key,
        sourcePassword,
        'sk-example123456',
        'bearer-private-value',
        'subscription/private',
        'token=private',
        'user:password',
        'system-private-value',
        'tool-private-value',
        'proposal-private-value',
        'tool-id-private-value',
        'arguments-private-value',
      ]) {
        expect(raw, isNot(contains(secret)), reason: secret);
      }
      final restored = (await store.list()).single;
      expect(restored.messages.map((message) => message['role']), [
        'user',
        'assistant',
      ]);
      expect(restored.messages.last, {
        'role': 'assistant',
        'content': 'text reply',
      });
      expect(restored.messages.first['content'], contains('[redacted]'));
      expect(restored.changeIds, ['change-1']);
    },
  );

  test(
    'deletion wins over queued saves and preserves policies and changes',
    () async {
      final delayed = _DelayedDatabase();
      addTearDown(delayed.close);
      final history = AiHistoryStore(delayed);
      const policies = {
        'revision': 7,
        'rules': ['existing-policy'],
      };
      await delayed.writeSection('policies', policies);
      await delayed.saveChange(
        id: 'change-1',
        category: 'policies',
        summary: 'existing draft',
        highRisk: true,
        fingerprint: 'original-fingerprint',
        before: {'revision': 6},
        after: {'revision': 7},
        createdAt: 1,
        expiresAt: 9999999999999,
      );
      final before = (await delayed.readChange('change-1'))!.toJson();
      await history.save(_conversation(1));
      final started = Completer<void>();
      final release = Completer<void>();
      delayed.readStarted = started;
      delayed.readRelease = release;
      final writing = history.save(_conversation(1, updatedAt: 2));
      await started.future;
      final queued = history.save(_conversation(1, updatedAt: 3));
      final deletion = history.delete(_id(1));
      final late = history.save(_conversation(1, updatedAt: 4));
      release.complete();
      await Future.wait([writing, queued, deletion, late]);

      expect(await history.list(), isEmpty);
      expect(await delayed.readSection('policies'), policies);
      expect((await delayed.readChange('change-1'))!.toJson(), before);
      final freshStore = AiHistoryStore(delayed);
      expect(await freshStore.list(), isEmpty);
    },
  );

  test(
    'overlapping saves serialize, update one row and keep eviction final',
    () async {
      await Future.wait([
        for (var index = 1; index <= 25; index++)
          store.save(_conversation(index)),
      ]);
      await Future.wait([
        store.save(_conversation(10, updatedAt: 99)),
        store.save(
          _conversation(
            10,
            updatedAt: 100,
            messages: [
              {'role': 'user', 'content': 'latest update'},
            ],
          ),
        ),
        store.save(_conversation(1, updatedAt: 101)),
      ]);

      final entries = await store.list();
      expect(entries, hasLength(20));
      expect(entries.map((entry) => entry.id).toSet(), hasLength(20));
      expect(entries.first.id, _id(10));
      expect(entries.first.title, 'latest update');
      expect(entries.map((entry) => entry.id), isNot(contains(_id(1))));
      await reopen();
      expect((await store.list()).first.title, 'latest update');
    },
  );

  test(
    'malformed conversation entries are skipped and metadata is bounded',
    () async {
      await database.writeSection('aiConversations', {
        'conversations': [
          null,
          42,
          {'id': 'invalid', 'updatedAt': 1, 'messages': []},
          {'id': _id(2), 'updatedAt': 'wrong', 'messages': []},
          {'id': _id(3), 'updatedAt': 3, 'messages': 'wrong'},
          {
            'id': _id(4),
            'updatedAt': 4,
            'messages': [
              null,
              {'role': 'tool', 'content': 'excluded'},
              {'role': 'user', 'content': 9},
              {
                'role': 'assistant',
                'content': 'valid text',
                'secret': 'discard',
              },
            ],
            'targetLabel': 'x' * 200,
            'changeIds': [
              'duplicate',
              'duplicate',
              8,
              'x' * 161,
              for (var i = 0; i < 120; i++) 'id-$i',
            ],
          },
        ],
      });

      final valid = (await store.list()).single;
      expect(valid.id, _id(4));
      expect(valid.messages, [
        {'role': 'assistant', 'content': 'valid text'},
      ]);
      expect(valid.targetLabel, hasLength(160));
      expect(valid.changeIds, hasLength(96));
      expect(valid.changeIds.toSet(), hasLength(96));
      await store.save(_conversation(5));
      expect((await store.list()).map((entry) => entry.id), [_id(5), _id(4)]);
    },
  );

  test(
    'oversized latest text cannot create an unbounded saved conversation',
    () async {
      await store.save(
        _conversation(
          1,
          messages: [
            {'role': 'user', 'content': 'older message'},
            {'role': 'assistant', 'content': 'x' * (256 * 1024 + 1)},
          ],
        ),
      );
      expect(await store.list(), isEmpty);
    },
  );

  test(
    'storage errors remain visible and do not poison the serial queue',
    () async {
      final failing = _DelayedDatabase();
      addTearDown(failing.close);
      final history = AiHistoryStore(failing);
      failing.readFailure = StateError('storage read failed');
      await expectLater(history.list(), throwsStateError);
      await history.save(_conversation(1));
      expect((await history.list()).single.id, _id(1));
    },
  );

  test(
    'failed deletion allows the same conversation to be saved again',
    () async {
      final failing = _DelayedDatabase();
      addTearDown(failing.close);
      final history = AiHistoryStore(failing);
      await history.save(_conversation(1));
      failing.writeFailure = StateError('delete write failed');
      await expectLater(history.delete(_id(1)), throwsStateError);
      expect((await history.list()).single.title, 'question 1');

      await history.save(
        _conversation(
          1,
          updatedAt: 100,
          messages: [
            {'role': 'user', 'content': 'updated after failed deletion'},
          ],
        ),
      );
      final updated = (await history.list()).single;
      expect(updated.id, _id(1));
      expect(updated.updatedAt, 100);
      expect(updated.title, 'updated after failed deletion');
      expect(
        (await AiHistoryStore(failing).list()).single.title,
        updated.title,
      );
    },
  );

  test('failed eviction does not permanently suppress its candidate', () async {
    final failing = _DelayedDatabase();
    addTearDown(failing.close);
    final history = AiHistoryStore(failing);
    for (var index = 1; index <= 20; index++) {
      await history.save(_conversation(index));
    }
    failing.writeFailure = StateError('eviction write failed');
    await expectLater(history.save(_conversation(21)), throwsStateError);
    final unchanged = await history.list();
    expect(unchanged, hasLength(20));
    expect(unchanged.map((entry) => entry.id), contains(_id(1)));
    expect(unchanged.map((entry) => entry.id), isNot(contains(_id(21))));

    await history.save(
      _conversation(
        1,
        updatedAt: 100,
        messages: [
          {'role': 'user', 'content': 'updated after failed eviction'},
        ],
      ),
    );
    final updated = await history.list();
    expect(updated, hasLength(20));
    expect(updated.first.id, _id(1));
    expect(updated.first.updatedAt, 100);
    expect(updated.first.title, 'updated after failed eviction');
    expect(
      (await AiHistoryStore(failing).list()).first.title,
      updated.first.title,
    );
  });

  test(
    'corrupt JSON or non-object sections do not prevent later saves',
    () async {
      for (final payload in ['{invalid-json', '[]', 'null', '42']) {
        await database.customStatement(
          'INSERT OR REPLACE INTO workbench_records (section, payload, revision) '
          'VALUES (?, ?, ?)',
          ['aiConversations', payload, 0],
        );
        expect(await store.list(), isEmpty);
        await store.save(_conversation(1));
        expect((await store.list()).single.id, _id(1));
      }
    },
  );
  test('structured context and safe diagnostics survive reopening', () async {
    await store.save(
      AiConversation(
        id: _id(1),
        updatedAt: 1,
        messages: const [
          {'role': 'user', 'content': 'make draft'},
        ],
        context: const [
          {'role': 'user', 'content': 'make draft'},
          {
            'role': 'assistant',
            'content': [
              {
                'type': 'toolCall',
                'id': 'call-1',
                'name': 'policies_propose',
                'arguments': {'patch': {}},
              },
            ],
          },
          {
            'role': 'toolResult',
            'toolCallId': 'call-1',
            'toolName': 'policies_propose',
            'isError': false,
            'content': [
              {'type': 'text', 'text': '{"proposal":{"id":"draft-1"}}'},
            ],
          },
        ],
        diagnostics: const [
          {
            'kind': 'tool',
            'name': 'policies_propose',
            'status': 'draft',
            'at': 1,
            'payload': 'must-not-persist',
          },
        ],
      ),
    );
    await reopen();
    final entry = (await store.list()).single;
    expect(entry.context, hasLength(3));
    expect(entry.context.last['toolCallId'], 'call-1');
    expect(entry.diagnostics.single['status'], 'draft');
    expect(jsonEncode(entry.toJson()), isNot(contains('must-not-persist')));
  });
  test(
    'actual local rule capabilities and latest draft snapshots survive app history roundtrip',
    () async {
      final contract = AgentPolicyContract.describe(
        const LocalPolicyDocument().asStandalone(),
      );
      final context = aiContextMessages([
        {'role': 'user', 'content': '继续调整本地规则'},
        {
          'role': 'assistant',
          'content': [
            {
              'type': 'toolCall',
              'id': 'pinned-catalog',
              'name': 'policies_catalog',
              'arguments': <String, Object?>{},
            },
          ],
        },
        {
          'role': 'toolResult',
          'toolCallId': 'pinned-catalog',
          'toolName': 'policies_catalog',
          'isError': false,
          'content': [
            {
              'type': 'text',
              'text': jsonEncode({
                'patchSchema': AgentPolicyContract.patchSchema,
                'contract': contract,
              }),
            },
          ],
        },
        {
          'role': 'assistant',
          'content': [
            {
              'type': 'toolCall',
              'id': 'pinned-draft',
              'name': 'policies_draft_read',
              'arguments': {'id': 'actual-latest-draft'},
            },
          ],
        },
        {
          'role': 'toolResult',
          'toolCallId': 'pinned-draft',
          'toolName': 'policies_draft_read',
          'isError': false,
          'content': [
            {
              'type': 'text',
              'text': jsonEncode({
                'id': 'actual-latest-draft',
                'status': 'draft',
                'businessSummary': {
                  'ruleCount': 4,
                  'targetId': localPolicyTargetId,
                },
                'validation': {'valid': true},
              }),
            },
          ],
        },
        {
          'role': 'assistant',
          'content': [
            {'type': 'text', 'text': '已读取最新草稿'},
          ],
        },
      ], sanitize: (value) => aiHistoryText(value, const []));
      await store.save(
        AiConversation(
          id: _id(9),
          updatedAt: 9,
          messages: const [
            {'role': 'user', 'content': '继续调整本地规则'},
            {'role': 'assistant', 'content': '已读取最新草稿'},
          ],
          context: context,
        ),
      );
      final restored = (await store.list()).single;
      expect(restored.context, hasLength(6));
      final encoded = jsonEncode(restored.context);
      expect(encoded, contains('GEOIP,CN'));
      expect(encoded, contains('destinationRegion'));
      expect(encoded, contains('actual-latest-draft'));
      expect(encoded, contains('ruleCount'));
      expect(restored.context.first['role'], 'user');
    },
  );
}
