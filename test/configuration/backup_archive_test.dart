import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:fl_clash/configuration/backup_archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as paths;

void main() {
  late Directory directory;
  late String source;
  late String target;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('flclash-backup-');
    source = paths.join(directory.path, 'backup.zip');
    target = paths.join(directory.path, 'restore');
  });

  tearDown(() async => directory.delete(recursive: true));

  Future<void> writeArchive(List<ArchiveFile> files) async {
    final archive = Archive();
    for (final file in files) {
      archive.addFile(file);
    }
    await File(source).writeAsBytes(ZipEncoder().encode(archive));
  }

  test(
    'extracts portable configuration and profile files into a fresh stage',
    () async {
      await Directory(target).create();
      await File(paths.join(target, 'stale.json')).writeAsString('stale');
      await writeArchive([
        ArchiveFile.string('config.json', '{"workbench":{"version":1}}'),
        ArchiveFile.string('profiles/7.yaml', 'proxies: []'),
        ArchiveFile.string('scripts/8.js', 'function main(c) { return c; }'),
      ]);

      await extractConfigurationBackup(source, target);

      expect(
        await File(paths.join(target, 'config.json')).readAsString(),
        contains('workbench'),
      );
      expect(
        await File(paths.join(target, 'profiles/7.yaml')).readAsString(),
        'proxies: []',
      );
      expect(await File(paths.join(target, 'scripts/8.js')).exists(), isTrue);
      expect(await File(paths.join(target, 'stale.json')).exists(), isFalse);
    },
  );

  for (final name in [
    '../outside',
    '/outside',
    'profiles/../../outside',
    r'profiles\..\outside',
    'C:/outside',
  ]) {
    test(
      'rejects unsafe archive path $name before replacing the stage',
      () async {
        await Directory(target).create();
        final sentinel = File(paths.join(target, 'sentinel'));
        await sentinel.writeAsString('retained');
        await writeArchive([ArchiveFile.string(name, 'unsafe')]);

        await expectLater(
          extractConfigurationBackup(source, target),
          throwsFormatException,
        );

        expect(await sentinel.readAsString(), 'retained');
        expect(
          await File(paths.join(directory.path, 'outside')).exists(),
          isFalse,
        );
      },
    );
  }

  test('rejects symlink entries before writing files', () async {
    await writeArchive([
      ArchiveFile.string('profiles/link', '../../outside')..mode = 0xa1ff,
    ]);

    await expectLater(
      extractConfigurationBackup(source, target),
      throwsFormatException,
    );

    expect(await Directory(target).exists(), isFalse);
  });

  test(
    'preflight rejects missing profiles, scripts and selected profile references',
    () async {
      await writeArchive([
        ArchiveFile.string('profiles/7.yaml', 'proxies: []'),
      ]);
      await extractConfigurationBackup(source, target);

      await validateConfigurationBackupFiles(
        directory: target,
        profileIds: [7],
        scriptIds: const [],
        currentProfileId: 7,
      );
      for (final missing in ['profile', 'script', 'selection']) {
        await expectLater(
          validateConfigurationBackupFiles(
            directory: target,
            profileIds: missing == 'profile' ? [7, 8] : [7],
            scriptIds: missing == 'script' ? [9] : const [],
            currentProfileId: missing == 'selection' ? 99 : 7,
          ),
          throwsFormatException,
        );
      }
      expect(
        await File(paths.join(target, 'profiles/7.yaml')).readAsString(),
        'proxies: []',
      );
    },
  );
}
