import 'dart:io';

import 'package:fl_clash/capabilities/file_access.dart';
import 'package:fl_clash/capabilities/gateway.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as paths;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'output selection returns a grant path without writing or truncating',
    () async {
      await AppLocalizations.load(const Locale('en'));
      final directory = await Directory.systemTemp.createTemp(
        'flclash-save-picker-',
      );
      final file = File(paths.join(directory.path, 'existing.txt'));
      await file.writeAsString('keep-this-content');
      const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'saveFile');
            expect((call.arguments as Map).containsKey('bytes'), false);
            return file.path;
          });
      try {
        expect(await selectLocalOutputPath('output.bin'), file.path);
        expect(await file.readAsString(), 'keep-this-content');
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'local grants refuse symlink traversal, overwrite and excessive input',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'flclash-capabilities-',
      );
      final root = await directory.resolveSymbolicLinks();
      try {
        final file = paths.join(root, 'output');
        SecureLocalFiles.write(file, Uint8List.fromList([1, 2, 3]));
        expect(SecureLocalFiles.read(file, maximumBytes: 3), [1, 2, 3]);
        expect(
          () => SecureLocalFiles.write(file, Uint8List.fromList([4])),
          throwsA(isA<FileSystemException>()),
        );
        expect(
          () => SecureLocalFiles.read(file, maximumBytes: 2),
          throwsA(isA<FileSystemException>()),
        );
        final link = Link(paths.join(root, 'link'));
        await link.create(file);
        expect(
          () => SecureLocalFiles.read(link.path, maximumBytes: 3),
          throwsA(isA<FileSystemException>()),
        );
        final folderLink = Link(paths.join(root, 'folder-link'));
        await folderLink.create(root);
        expect(
          () => SecureLocalFiles.read(
            paths.join(folderLink.path, 'output'),
            maximumBytes: 3,
          ),
          throwsA(isA<FileSystemException>()),
        );
        expect(await File(file).readAsBytes(), [1, 2, 3]);
      } finally {
        await directory.delete(recursive: true);
      }
    },
    skip: !Platform.isMacOS,
  );
}
