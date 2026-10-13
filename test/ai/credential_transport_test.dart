import 'package:ai_security/ai_security.dart';
import 'package:fl_clash/ai/credentials.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  const store = KeychainAgentCredentialStore();
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AiSecurity.channel, (call) async {
          calls.add(call);
          return call.method == 'get' ? 'test-secret' : null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AiSecurity.channel, null);
  });
  test(
    'typed credential operations use the private Keychain channel',
    () async {
      await store.write('credential-1', 'test-secret');
      expect(await store.read('credential-1'), 'test-secret');
      await store.delete('credential-1');
      expect(calls.map((call) => call.method), ['set', 'get', 'delete']);
      expect(calls.first.arguments, {
        'id': 'credential-1',
        'secret': 'test-secret',
      });
    },
  );
  test('invalid ids and empty secrets never reach the platform', () async {
    expect(() => store.read('../invalid'), throwsArgumentError);
    expect(() => store.read('credential\n'), throwsArgumentError);
    await expectLater(store.write('valid', ''), throwsArgumentError);
    expect(calls, isEmpty);
  });
}
