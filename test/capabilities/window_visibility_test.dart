import 'dart:async';

import 'package:fl_clash/capabilities/gateway.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Controller extends Mock implements WorkbenchController {}

class _Core extends Mock implements CoreController {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('window_manager');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late ProviderContainer container;
  late FlutterApplicationCapabilityGateway gateway;

  setUp(() {
    container = ProviderContainer();
    gateway = container.read(
      Provider(
        (ref) => FlutterApplicationCapabilityGateway(
          ref: ref,
          controller: _Controller(),
          core: _Core(),
        ),
      ),
    );
  });

  tearDown(() {
    render?.resume();
    messenger.setMockMethodCallHandler(channel, null);
    container.dispose();
  });

  for (final visible in [false, true]) {
    final command = visible ? 'app_show' : 'app_hide';
    test(
      '$command completes only after the native state changes',
      () async {
        var actual = !visible;
        var completed = false;
        var requests = 0;
        final firstObservation = Completer<void>();
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'isMinimized') return false;
          if (call.method == (visible ? 'show' : 'hide')) requests++;
          if (call.method == 'isVisible') {
            if (!firstObservation.isCompleted) firstObservation.complete();
            return actual;
          }
          return null;
        });

        final operation = gateway.execute(command, {}, origin: 'cli').then((
          value,
        ) {
          completed = true;
          return value;
        });
        await firstObservation.future;
        await pumpEventQueue();
        expect(completed, false);
        actual = visible;
        expect(await operation, {'status': 'completed', 'visible': visible});
        expect(requests, 1);
      },
      skip: !system.isDesktop,
    );

    test('$command accepts an already matching native state', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'isMinimized') return false;
        return call.method == 'isVisible' ? visible : null;
      });
      expect(await gateway.execute(command, {}, origin: 'cli'), {
        'status': 'completed',
        'visible': visible,
      });
    }, skip: !system.isDesktop);
  }

  test(
    'a missing native transition fails without repeating hide',
    () async {
      var requests = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'hide') requests++;
        return call.method == 'isVisible' ? true : null;
      });
      await expectLater(
        gateway.execute('app_hide', {}, origin: 'cli'),
        throwsA(
          isA<ConfigurationChangeException>().having(
            (error) => error.code,
            'code',
            'window_visibility_timeout',
          ),
        ),
      );
      expect(requests, 1);
    },
    skip: !system.isDesktop,
  );

  test(
    'a native read that never replies respects the total deadline',
    () async {
      final nativeRead = Completer<bool>();
      var observations = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'isVisible') {
          observations++;
          return nativeRead.future;
        }
        return null;
      });
      try {
        expect(
          await Window().waitForVisibility(
            false,
            timeout: const Duration(milliseconds: 100),
          ),
          false,
        );
        nativeRead.complete(false);
        await pumpEventQueue();
        expect(observations, 1);
      } finally {
        if (!nativeRead.isCompleted) nativeRead.complete(false);
      }
    },
  );

  test('a native read failure is not reported as completed', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isMinimized') return false;
      if (call.method == 'isVisible') {
        throw PlatformException(code: 'native_window_failure');
      }
      return null;
    });
    await expectLater(
      gateway.execute('app_show', {}, origin: 'cli'),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'native_window_failure',
        ),
      ),
    );
  }, skip: !system.isDesktop);
}
