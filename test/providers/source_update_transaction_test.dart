import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _SourcePaths extends PathProviderPlatform {
  _SourcePaths(this.path);
  final String path;

  @override
  Future<String> getApplicationSupportPath() async => path;
  @override
  Future<String> getTemporaryPath() async => path;
  @override
  Future<String> getApplicationCachePath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late File source;
  const profile = Profile(id: 71, autoUpdateDuration: Duration(days: 1));
  final bytes = Uint8List.fromList('new-source'.codeUnits);

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('source-transaction-');
    PathProviderPlatform.instance = _SourcePaths(directory.path);
    source = File(await appPath.getProfilePath('${profile.id}'));
    await source.parent.create(recursive: true);
  });
  tearDownAll(() => directory.delete(recursive: true));
  setUp(() => source.writeAsString('old-source'));

  Future<Profile> publish({
    required Future<void> Function(Profile profile) apply,
    Future<void> Function()? rollback,
    bool Function()? isCurrent,
  }) => profile.saveFile(
    bytes,
    validateConfig: (_) async => '',
    onPublished: apply,
    onRollback: rollback,
    isCurrent: isCurrent,
  );

  test('source success waits for actual application completion', () async {
    final started = Completer<void>();
    final applied = Completer<void>();
    var completed = false;
    final pending =
        publish(
          apply: (_) async {
            expect(await source.readAsString(), 'new-source');
            started.complete();
            await applied.future;
          },
        ).then((value) {
          completed = true;
          return value;
        });
    await started.future;
    expect(completed, isFalse);
    applied.complete();
    expect((await pending).lastUpdateDate, isNotNull);
    expect(await source.readAsString(), 'new-source');
  });

  test(
    'application failure restores source before waiting for recovery',
    () async {
      final recovering = Completer<void>();
      final recovered = Completer<void>();
      final pending = publish(
        apply: (_) async => throw StateError('apply failed'),
        rollback: () async {
          expect(await source.readAsString(), 'old-source');
          recovering.complete();
          await recovered.future;
        },
      );
      final failure = expectLater(pending, throwsStateError);
      await recovering.future;
      recovered.complete();
      await failure;
      expect(await source.readAsString(), 'old-source');
    },
  );

  test(
    'superseded publication rolls back before next source task begins',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final action = container.read(setupActionProvider.notifier);
      final started = Completer<void>();
      final applied = Completer<void>();
      var current = true;
      final first = action.runSourceUpdate(
        (_) => publish(
          isCurrent: () => current,
          apply: (_) async {
            started.complete();
            await applied.future;
          },
          rollback: () async {
            expect(await source.readAsString(), 'old-source');
          },
        ),
      );
      final rejected = expectLater(first, throwsStateError);
      await started.future;
      current = false;
      final second = action.runSourceUpdate((_) async {
        expect(await source.readAsString(), 'old-source');
        await source.writeAsString('latest-source');
      });
      applied.complete();
      await rejected;
      await second;
      expect(await source.readAsString(), 'latest-source');
    },
  );

  test(
    'interrupted application restores source and reports failed recovery',
    () async {
      await expectLater(
        publish(
          apply: (_) async => throw StateError('interrupted'),
          rollback: () async => throw StateError('core unavailable'),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('profile_update_rollback_failed'),
          ),
        ),
      );
      expect(await source.readAsString(), 'old-source');
      expect(directory.listSync().whereType<File>(), isEmpty);
    },
  );
}
