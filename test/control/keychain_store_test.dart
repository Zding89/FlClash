import 'package:ai_security/ai_security.dart';
import 'package:fl_clash/control/password.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AiSecurity.channel, (call) async {
          calls.add(call);
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AiSecurity.channel, null),
  );
  test(
    'control password namespace is isolated from provider credentials',
    () async {
      const store = KeychainControlPasswordStore();
      expect(await store.read(), null);
      await store.write('test-password-only-123');
      await const AiSecurity().get('provider');
      expect(calls[0].arguments, {'namespace': 'control', 'id': 'password'});
      expect(calls[1].arguments, {
        'namespace': 'control',
        'id': 'password',
        'secret': 'test-password-only-123',
      });
    expect(calls[2].arguments, {'id': 'provider'});
    },
  );
  test('Keychain unavailable is not interpreted as a missing record', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          AiSecurity.channel,
          (call) async => throw PlatformException(code: 'keychainFailure'),
        );
    await expectLater(
      const KeychainControlPasswordStore().read(),
      throwsA(isA<PlatformException>()),
    );
  });
}
