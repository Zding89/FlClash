import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as paths;

Future<void> validateConfigurationBackupFiles({
  required String directory,
  required Iterable<int> profileIds,
  required Iterable<int> scriptIds,
  int? currentProfileId,
}) async {
  final profiles = profileIds.toSet();
  if (currentProfileId != null && !profiles.contains(currentProfileId)) {
    throw const FormatException('Backup refers to a missing profile');
  }
  for (final path in [
    ...profiles.map((id) => paths.join(directory, 'profiles', '$id.yaml')),
    ...scriptIds.map((id) => paths.join(directory, 'scripts', '$id.js')),
  ]) {
    if (await FileSystemEntity.type(path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const FormatException('Backup is missing a configuration file');
    }
  }
}

Future<void> extractConfigurationBackup(String source, String target) async {
  final input = InputFileStream(source);
  try {
    final archive = ZipDecoder().decodeStream(input);
    if (archive.files.length > 20000) {
      throw const FormatException('Invalid configuration backup');
    }
    final names = <String>{};
    var total = 0;
    for (final file in archive.files) {
      final name = paths.posix.normalize(file.name);
      total += file.size;
      if (file.isSymbolicLink ||
          file.mode & 0xf000 == 0xa000 ||
          file.name.contains('\\') ||
          name == '.' ||
          name == '..' ||
          name.startsWith('../') ||
          paths.posix.isAbsolute(name) ||
          RegExp(r'^[A-Za-z]:').hasMatch(name) ||
          !names.add(name) ||
          file.size < 0 ||
          total > 2 * 1024 * 1024 * 1024) {
        throw const FormatException('Invalid configuration backup');
      }
    }
    final directory = Directory(target);
    if (await directory.exists()) await directory.delete(recursive: true);
    await directory.create(recursive: true);
    for (final file in archive.files) {
      final outputPath = paths.join(target, paths.posix.normalize(file.name));
      if (!file.isFile) {
        await Directory(outputPath).create(recursive: true);
        continue;
      }
      await Directory(paths.dirname(outputPath)).create(recursive: true);
      final output = OutputFileStream(outputPath);
      try {
        file.writeContent(output);
      } finally {
        await output.close();
      }
    }
  } finally {
    await input.close();
  }
}
