import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:fl_clash/ai/credential_cipher.dart';
import 'package:fl_clash/ai/credentials.dart';
import 'package:fl_clash/ai/settings.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:flutter_test/flutter_test.dart';

class _LegacyStore implements AgentCredentialStore {
  final reads = <String>[];
  String? secret = 'legacy-secret';
  Object? failure;
  Completer<String?>? pending;

  @override
  Future<String?> read(String credentialId) async {
    reads.add(credentialId);
    if (failure != null) throw failure!;
    return pending == null ? secret : pending!.future;
  }

  @override
  Future<void> write(String credentialId, String secret) async =>
      throw StateError('Legacy writes are forbidden');

  @override
  Future<void> delete(String credentialId) async =>
      throw StateError('Legacy deletes are forbidden');
}

class _FailingDatabase extends WorkbenchDatabase {
  _FailingDatabase() : super(NativeDatabase.memory());

  int? failAfterWrites;
  bool failAfterPersist = false;

  @override
  Future<void> writeSection(
    String section,
    Map<String, Object?> payload,
  ) async {
    if (section == EncryptedConfigAgentCredentialStore.section &&
        failAfterWrites != null &&
        failAfterWrites! <= 0) {
      failAfterWrites = null;
      if (failAfterPersist) {
        failAfterPersist = false;
        await super.writeSection(section, payload);
      }
      throw StateError('Storage unavailable');
    }
    if (failAfterWrites != null) failAfterWrites = failAfterWrites! - 1;
    await super.writeSection(section, payload);
  }
}

void main() {
  late _FailingDatabase database;
  late _LegacyStore legacy;
  late EncryptedConfigAgentCredentialStore store;
  const connection = AgentConnection(
    id: 'existing',
    label: 'Existing',
    provider: 'openai',
    model: 'test-model',
  );

  setUp(() {
    database = _FailingDatabase();
    legacy = _LegacyStore();
    store = EncryptedConfigAgentCredentialStore(database, legacy: legacy);
  });

  tearDown(() => database.close());

  Future<Map<String, Object?>> payload() async =>
      (await database.readSection('aiCredentials'))!;

  Future<void> saveConnection() => database.writeSection(
    'ai',
    const AgentSettings(connections: [connection]).toJson(),
  );

  test(
    'ciphertext is authenticated, versioned, and contains no plaintext',
    () async {
      await store.write('credential-1', 'sk-sensitive-api-key');
      final document = await payload();
      expect(document['version'], 1);
      final value = (document['values'] as Map)['credential-1'] as String;
      expect(value, startsWith('v1.'));
      expect(jsonEncode(document), isNot(contains('sk-sensitive-api-key')));
      expect(base64Url.decode(value.substring(3)).length, 12 + 20 + 16);
      expect(await store.read('credential-1'), 'sk-sensitive-api-key');
      expect(legacy.reads, isEmpty);
      await EncryptedConfigAgentCredentialStore.validateSection(document);
    },
  );

  test(
    'repeated writes use different nonces and independent instances can read',
    () async {
      await store.write('credential-1', 'same-secret');
      final first = await payload();
      await store.write('credential-1', 'same-secret');
      final second = await payload();
      expect(first['values'], isNot(equals(second['values'])));
      expect(
        await EncryptedConfigAgentCredentialStore(
          database,
        ).read('credential-1'),
        'same-secret',
      );
      final restored = WorkbenchDatabase(NativeDatabase.memory());
      try {
        await restored.writeSection('aiCredentials', first);
        expect(
          await EncryptedConfigAgentCredentialStore(
            restored,
          ).read('credential-1'),
          'same-secret',
        );
      } finally {
        await restored.close();
      }
    },
  );

  test('restoring storage cannot leave a stale plaintext cache', () async {
    await store.write('credential-1', 'old-secret');
    final old = await payload();
    await store.write('credential-1', 'new-secret');
    expect(await store.read('credential-1'), 'new-secret');
    await database.writeSection('aiCredentials', old);
    expect(await store.read('credential-1'), 'old-secret');
  });

  test(
    'ciphertext tampering and credential substitution fail closed',
    () async {
      await store.write('first', 'secret');
      final document = await payload();
      final value = (document['values'] as Map)['first'] as String;
      final bytes = base64Url.decode(value.substring(3));
      bytes[12] ^= 1;
      (document['values'] as Map)['first'] = 'v1.${base64Url.encode(bytes)}';
      await database.writeSection('aiCredentials', document);
      await expectLater(store.read('first'), throwsFormatException);
      await expectLater(
        EncryptedConfigAgentCredentialStore.validateSection(document),
        throwsFormatException,
      );
      await expectLater(
        AgentCredentialCipher().decrypt('second', value),
        throwsFormatException,
      );
      expect(legacy.reads, isEmpty);
    },
  );

  test('unsupported versions and malformed encodings are rejected', () async {
    for (final value in ['v2.AAAA', 'v1.AAAA', 'v1.@@@', 'v1.AAAA\n']) {
      await expectLater(
        AgentCredentialCipher().decrypt('valid', value),
        throwsFormatException,
      );
    }
    for (final document in <Map<String, Object?>>[
      {'version': 2, 'values': {}, 'legacyAttempted': []},
      {'version': 1.0, 'values': {}, 'legacyAttempted': []},
      {
        'version': 1,
        'values': {},
        'legacyAttempted': ['a', 'a'],
      },
      {
        'version': 1,
        'values': {},
        'legacyAttempted': ['../bad'],
      },
      {'version': 1, 'values': {}, 'legacyAttempted': [], 'extra': true},
    ]) {
      await expectLater(
        EncryptedConfigAgentCredentialStore.validateSection(document),
        throwsFormatException,
      );
    }
  });

  test(
    'IDs and secret bounds match AiSecurity without storage effects',
    () async {
      for (final id in ['', '../bad', 'id\n', 'a' * 97]) {
        await expectLater(store.read(id), throwsArgumentError);
        await expectLater(store.write(id, 'secret'), throwsArgumentError);
        await expectLater(store.delete(id), throwsArgumentError);
      }
      await expectLater(store.write('valid', ''), throwsArgumentError);
      await expectLater(store.write('valid', 's' * 16385), throwsArgumentError);
      expect(await database.readSection('aiCredentials'), isNull);
      await store.write('valid', '中' * 16384);
      expect(await store.read('valid'), '中' * 16384);
      expect(legacy.reads, isEmpty);
    },
  );

  test(
    'concurrent stores serialize writes without losing other credentials',
    () async {
      final other = EncryptedConfigAgentCredentialStore(database);
      await Future.wait([
        for (var index = 0; index < 20; index++)
          (index.isEven ? store : other).write('key-$index', 'secret-$index'),
      ]);
      for (var index = 0; index < 20; index++) {
        expect(await other.read('key-$index'), 'secret-$index');
      }
      expect((await payload())['legacyAttempted'], hasLength(20));
    },
  );

  test(
    'failed mutations roll back and do not poison the serial queue',
    () async {
      await store.write('key', 'original');
      database.failAfterWrites = 0;
      database.failAfterPersist = true;
      await expectLater(store.write('key', 'replacement'), throwsStateError);
      expect(await store.read('key'), 'original');
      database.failAfterWrites = 0;
      database.failAfterPersist = true;
      await expectLater(store.delete('key'), throwsStateError);
      expect(await store.read('key'), 'original');
      await store.write('key', 'recovered');
      expect(await store.read('key'), 'recovered');
    },
  );

  test(
    'construction and new draft reads never access the legacy platform',
    () async {
      expect(legacy.reads, isEmpty);
      expect(await database.readSection('aiCredentials'), isNull);
      expect(await store.read(connection.credentialId), isNull);
      await saveConnection();
      expect(await store.read(connection.credentialId), isNull);
      expect(legacy.reads, isEmpty);
    },
  );

  test(
    'existing keys migrate once with durable marker and no legacy deletion',
    () async {
      await saveConnection();
      legacy.pending = Completer<String?>();
      final migration = store.read(connection.credentialId);
      while (legacy.reads.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      expect((await payload())['legacyAttempted'], [connection.credentialId]);
      legacy.pending!.complete('migrated-key');
      expect(await migration, 'migrated-key');
      expect(await store.read(connection.credentialId), 'migrated-key');
      expect(legacy.reads, [connection.credentialId]);
      expect(jsonEncode(await payload()), isNot(contains('migrated-key')));
    },
  );

  test(
    'legacy failure is attempted once across stores and allows manual repair',
    () async {
      await saveConnection();
      legacy.failure = StateError('platform refused');
      await expectLater(
        store.read(connection.credentialId),
        throwsA(isA<LegacyCredentialMigrationException>()),
      );
      legacy.failure = null;
      final reopened = EncryptedConfigAgentCredentialStore(
        database,
        legacy: legacy,
      );
      expect(await reopened.read(connection.credentialId), isNull);
      await expectLater(
        reopened.ensurePortable([connection.credentialId]),
        throwsA(isA<MissingAgentCredentialException>()),
      );
      expect(legacy.reads, [connection.credentialId]);
      await reopened.write(connection.credentialId, 'replacement');
      await reopened.ensurePortable([connection.credentialId]);
    },
  );

  test(
    'a missing legacy key is not repeatedly queried or silently backed up',
    () async {
      await saveConnection();
      legacy.secret = null;
      expect(await store.read(connection.credentialId), isNull);
      expect(await store.read(connection.credentialId), isNull);
      await expectLater(
        store.ensurePortable([connection.credentialId]),
        throwsA(isA<MissingAgentCredentialException>()),
      );
      expect(legacy.reads, [connection.credentialId]);
    },
  );

  test(
    'marker persistence failure prevents platform access and can recover',
    () async {
      await saveConnection();
      database.failAfterWrites = 0;
      await expectLater(store.read(connection.credentialId), throwsStateError);
      expect(legacy.reads, isEmpty);
      expect(await store.read(connection.credentialId), 'legacy-secret');
    },
  );

  test(
    'migration ciphertext write failure retains one-time attempt marker',
    () async {
      await saveConnection();
      database.failAfterWrites = 1;
      await expectLater(store.read(connection.credentialId), throwsStateError);
      expect(await store.read(connection.credentialId), isNull);
      expect(legacy.reads, [connection.credentialId]);
      await store.write(connection.credentialId, 'repaired');
      expect(await store.read(connection.credentialId), 'repaired');
    },
  );

  test(
    'deletion and explicit writes prevent resurrection of legacy keys',
    () async {
      await saveConnection();
      await store.delete(connection.credentialId);
      expect(await store.read(connection.credentialId), isNull);
      await store.write(connection.credentialId, 'new-key');
      expect(await store.read(connection.credentialId), 'new-key');
      await store.delete(connection.credentialId);
      expect(await store.read(connection.credentialId), isNull);
      expect(legacy.reads, isEmpty);
    },
  );

  test(
    'queued writes and deletes supersede a pending migration in order',
    () async {
      await saveConnection();
      legacy.pending = Completer<String?>();
      final read = store.read(connection.credentialId);
      final write = store.write(connection.credentialId, 'new-key');
      final delete = store.delete(connection.credentialId);
      final finalRead = store.read(connection.credentialId);
      while (legacy.reads.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      legacy.pending!.complete('old-key');
      expect(await read, 'old-key');
      await write;
      await delete;
      expect(await finalRead, isNull);
      expect(legacy.reads, [connection.credentialId]);
    },
  );

  test('backup preparation migrates all persisted keys exactly once', () async {
    await saveConnection();
    await store.ensurePortable([
      connection.credentialId,
      connection.credentialId,
    ]);
    await store.ensurePortable([connection.credentialId]);
    expect(await store.read(connection.credentialId), 'legacy-secret');
    expect(legacy.reads, [connection.credentialId]);
  });

  test(
    'restoring a key during platform authorization wins over the old key',
    () async {
      await saveConnection();
      legacy.pending = Completer<String?>();
      final read = store.read(connection.credentialId);
      while (legacy.reads.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      EncryptedConfigAgentCredentialStore.invalidatePendingMigrations(database);
      final restored = await AgentCredentialCipher().encrypt(
        connection.credentialId,
        'restored-key',
      );
      await database.writeSection('aiCredentials', {
        'version': 1,
        'values': {connection.credentialId: restored},
        'legacyAttempted': [connection.credentialId],
      });
      legacy.pending!.complete('old-platform-key');
      expect(await read, 'restored-key');
      expect(await store.read(connection.credentialId), 'restored-key');
    },
  );

  test(
    'changing AI settings during platform authorization cancels migration',
    () async {
      await saveConnection();
      legacy.pending = Completer<String?>();
      final read = store.read(connection.credentialId);
      while (legacy.reads.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      await database.writeSection('ai', const AgentSettings().toJson());
      legacy.pending!.complete('old-platform-key');
      expect(await read, isNull);
      expect((await payload())['values'], isEmpty);
    },
  );

  test(
    'restoring identical tombstones cancels pending platform results',
    () async {
      await saveConnection();
      legacy.pending = Completer<String?>();
      final read = store.read(connection.credentialId);
      while (legacy.reads.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      final tombstones = await payload();
      EncryptedConfigAgentCredentialStore.invalidatePendingMigrations(database);
      await database.writeSection('aiCredentials', tombstones);
      legacy.pending!.complete('old-platform-key');
      expect(await read, isNull);
      expect(await store.read(connection.credentialId), isNull);
      expect(legacy.reads, [connection.credentialId]);
    },
  );
}
