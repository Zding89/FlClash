import 'dart:async';

import 'package:ai_security/ai_security.dart';
import 'package:fl_clash/ai/credentials.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  late KeychainAgentCredentialStore store;
  String? secret;
  Object? getError;
  Object? setError;
  Object? deleteError;
  Completer<String?>? pendingRead;
  setUp(() {
    store = KeychainAgentCredentialStore();
    secret = 'test-secret';
    getError = null;
    setError = null;
    deleteError = null;
    pendingRead = null;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AiSecurity.channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'get':
              if (getError != null) throw getError!;
              return pendingRead == null ? secret : pendingRead!.future;
            case 'set':
              if (setError != null) throw setError!;
              secret = (call.arguments as Map)['secret'] as String;
            case 'delete':
              if (deleteError != null) throw deleteError!;
              secret = null;
          }
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AiSecurity.channel, null);
  });
  test(
    'typed credential operations use the private Keychain channel',
    () async {
      expect(await store.read('credential-1'), 'test-secret');
      await store.write('credential-1', 'test-secret');
      expect(await store.read('credential-1'), 'test-secret');
      await store.delete('credential-1');
      expect(calls.map((call) => call.method), ['get', 'set', 'delete']);
      expect(calls[1].arguments, {
        'id': 'credential-1',
        'secret': 'test-secret',
      });
    },
  );
  test('invalid ids and empty secrets never reach the platform', () async {
    await expectLater(store.read('../invalid'), throwsArgumentError);
    await expectLater(store.read('credential\n'), throwsArgumentError);
    await expectLater(store.write('valid', ''), throwsArgumentError);
    expect(calls, isEmpty);
  });

  test('three sequential prompts read the Keychain only once', () async {
    for (var turn = 0; turn < 3; turn++) {
      expect(await store.read('credential-1'), 'test-secret');
    }
    expect(calls.map((call) => call.method), ['get']);
  });

  test('concurrent reads share the successful Keychain lookup', () async {
    pendingRead = Completer<String?>();
    final first = store.read('credential-1');
    final second = store.read('credential-1');
    await Future<void>.delayed(Duration.zero);
    expect(calls.length, 1);
    pendingRead!.complete('test-secret');
    expect(await Future.wait([first, second]), ['test-secret', 'test-secret']);
    expect(calls.length, 1);
  });

  test(
    'missing secrets are retried and connection caches are isolated',
    () async {
      secret = null;
      expect(await store.read('credential-1'), isNull);
      secret = 'first-secret';
      expect(await store.read('credential-1'), 'first-secret');
      secret = 'second-secret';
      expect(await store.read('credential-2'), 'second-secret');
      expect(await store.read('credential-1'), 'first-secret');
      expect(calls.length, 3);
    },
  );

  test('a declined Keychain read can be retried', () async {
    getError = PlatformException(code: 'keychainFailure');
    await expectLater(
      store.read('credential-1'),
      throwsA(isA<PlatformException>()),
    );
    getError = null;
    expect(await store.read('credential-1'), 'test-secret');
    expect(calls.length, 2);
  });

  test(
    'successful writes replace cached values without reading again',
    () async {
      expect(await store.read('credential-1'), 'test-secret');
      await store.write('credential-1', 'new-secret');
      expect(await store.read('credential-1'), 'new-secret');
      expect(calls.map((call) => call.method), ['get', 'set']);
    },
  );

  test('deleting a credential prevents reuse of its old cache', () async {
    expect(await store.read('credential-1'), 'test-secret');
    await store.delete('credential-1');
    expect(await store.read('credential-1'), isNull);
    expect(calls.map((call) => call.method), ['get', 'delete', 'get']);
  });

  test('failed writes and deletes discard cached values and recover', () async {
    expect(await store.read('credential-1'), 'test-secret');
    setError = PlatformException(code: 'keychainFailure');
    await expectLater(
      store.write('credential-1', 'new-secret'),
      throwsA(isA<PlatformException>()),
    );
    expect(await store.read('credential-1'), 'test-secret');
    deleteError = PlatformException(code: 'keychainFailure');
    await expectLater(
      store.delete('credential-1'),
      throwsA(isA<PlatformException>()),
    );
    expect(await store.read('credential-1'), 'test-secret');
    expect(calls.map((call) => call.method), [
      'get',
      'set',
      'get',
      'delete',
      'get',
    ]);
  });

  test(
    'writes queued behind a pending read cannot leave a stale cache',
    () async {
      pendingRead = Completer<String?>();
      final oldRead = store.read('credential-1');
      final write = store.write('credential-1', 'new-secret');
      final nextRead = store.read('credential-1');
      await Future<void>.delayed(Duration.zero);
      expect(calls.map((call) => call.method), ['get']);
      pendingRead!.complete('old-secret');
      expect(await oldRead, 'old-secret');
      await write;
      expect(await nextRead, 'new-secret');
      expect(calls.map((call) => call.method), ['get', 'set']);
    },
  );

  test('a new app store does not reuse a previous store secret', () async {
    expect(await store.read('credential-1'), 'test-secret');
    secret = 'changed-secret';
    expect(
      await KeychainAgentCredentialStore().read('credential-1'),
      'changed-secret',
    );
    expect(calls.length, 2);
  });

  test('credential retention is bounded to 32 successful reads', () async {
    for (var index = 0; index < 33; index++) {
      await store.read('credential-$index');
    }
    await store.read('credential-32');
    expect(calls.length, 33);
    await store.read('credential-0');
    expect(calls.length, 34);
  });
}
