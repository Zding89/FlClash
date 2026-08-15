import 'dart:async';

import 'package:fl_clash/providers/actions/system_exit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('coalesces repeated exit requests and runs cleanup once', () async {
    final closeCoreCompleter = Completer<void>();
    final calls = <String>[];
    final coordinator = SystemExitCoordinator(
      watchdogDuration: const Duration(hours: 1),
      closeWindow: () async => calls.add('window'),
      closeCore: () async {
        calls.add('core');
        await closeCoreCompleter.future;
      },
      exitApplication: () async => calls.add('exit'),
    );

    final first = coordinator.exit(
      cleanup: () async => calls.add('cleanup'),
      prepareForClose: () async => calls.add('prepare'),
    );
    final second = coordinator.exit(
      cleanup: () async => calls.add('unexpected cleanup'),
      prepareForClose: () async => calls.add('unexpected prepare'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(identical(first, second), isTrue);
    expect(calls, ['prepare', 'cleanup', 'window', 'core']);

    closeCoreCompleter.complete();
    await Future.wait([first, second]);

    expect(calls, ['prepare', 'cleanup', 'window', 'core', 'exit']);
  });

  test('watchdog and normal completion share one application exit', () async {
    final closeCoreCompleter = Completer<void>();
    var exitCount = 0;
    final coordinator = SystemExitCoordinator(
      watchdogDuration: const Duration(milliseconds: 1),
      closeWindow: () async {},
      closeCore: () => closeCoreCompleter.future,
      exitApplication: () async => exitCount++,
    );

    final operation = coordinator.exit(
      cleanup: () async {},
      prepareForClose: () async {},
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(exitCount, 1);
    closeCoreCompleter.complete();
    await operation;
    expect(exitCount, 1);
  });

  test('cleanup failure does not skip window or Core shutdown', () async {
    final calls = <String>[];
    final coordinator = SystemExitCoordinator(
      watchdogDuration: const Duration(hours: 1),
      closeWindow: () async => calls.add('window'),
      closeCore: () async => calls.add('core'),
      exitApplication: () async => calls.add('exit'),
    );

    await expectLater(
      coordinator.exit(
        cleanup: () async {
          calls.add('cleanup');
          throw StateError('cleanup failed');
        },
        prepareForClose: () async => calls.add('prepare'),
      ),
      throwsStateError,
    );

    expect(calls, ['prepare', 'cleanup', 'window', 'core', 'exit']);
  });

  test('prepare step finishes before window and Core shutdown', () async {
    final prepareCompleter = Completer<void>();
    final calls = <String>[];
    final coordinator = SystemExitCoordinator(
      watchdogDuration: const Duration(hours: 1),
      closeWindow: () async => calls.add('window'),
      closeCore: () async => calls.add('core'),
      exitApplication: () async => calls.add('exit'),
    );

    final operation = coordinator.exit(
      cleanup: () async => calls.add('cleanup'),
      prepareForClose: () async {
        calls.add('prepare');
        await prepareCompleter.future;
      },
    );
    await Future<void>.delayed(Duration.zero);

    expect(calls, ['prepare']);
    prepareCompleter.complete();
    await operation;
    expect(calls, ['prepare', 'cleanup', 'window', 'core', 'exit']);
  });

  test('prepare failure reports the error without vetoing shutdown', () async {
    final calls = <String>[];
    final coordinator = SystemExitCoordinator(
      watchdogDuration: const Duration(hours: 1),
      closeWindow: () async => calls.add('window'),
      closeCore: () async => calls.add('core'),
      exitApplication: () async => calls.add('exit'),
    );

    Future<void> prepare() async {
      calls.add('prepare');
      throw StateError('usage flush failed');
    }

    await expectLater(
      coordinator.exit(
        cleanup: () async => calls.add('cleanup'),
        prepareForClose: prepare,
      ),
      throwsStateError,
    );
    expect(calls, ['prepare', 'cleanup', 'window', 'core', 'exit']);
  });

  test('watchdog covers a preparation step that does not finish', () async {
    final prepareCompleter = Completer<void>();
    final calls = <String>[];
    final coordinator = SystemExitCoordinator(
      watchdogDuration: const Duration(milliseconds: 1),
      closeWindow: () async => calls.add('window'),
      closeCore: () async => calls.add('core'),
      exitApplication: () async => calls.add('exit'),
    );

    final operation = coordinator.exit(
      cleanup: () async => calls.add('cleanup'),
      prepareForClose: () async {
        calls.add('prepare');
        await prepareCompleter.future;
      },
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(calls, ['prepare', 'exit']);

    prepareCompleter.complete();
    await operation;
    expect(calls, ['prepare', 'exit', 'cleanup', 'window', 'core']);
  });
}
