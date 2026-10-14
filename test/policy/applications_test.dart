import 'dart:io';

import 'package:fl_clash/policy/applications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as paths;

void main() {
  late Directory directory;
  setUp(
    () async => directory = await Directory.systemTemp.createTemp(
      'flclash-app-catalog-',
    ),
  );
  tearDown(() => directory.delete(recursive: true));
  Future<String> application(String name) async {
    final root = paths.join(directory.path, name);
    await File(
      paths.join(root, 'Contents', 'MacOS', 'main'),
    ).create(recursive: true);
    return root;
  }

  test(
    'enumerates bounded app bundles and maps only executables inside the app',
    () async {
      final first = await application('A (work),test.app');
      await application('Tools/Z.app');
      final catalog = PolicyApplicationCatalog(
        roots: [directory.path],
        supported: true,
        readPlist: (path) async => {
          'CFBundleExecutable': 'main',
          'CFBundleName': paths.basename(paths.dirname(paths.dirname(path))),
        },
      );
      final apps = await catalog.load();
      expect(apps, hasLength(2));
      final app = apps.first;
      expect(app.path, first);
      expect(policyApplicationLabel(app.processPathPattern), 'A (work),test');
      final pattern = RegExp(app.processPathPattern);
      expect(app.processPathPattern, isNot(contains('(')));
      expect(app.processPathPattern, isNot(contains(',')));
      expect(pattern.hasMatch('$first/Contents/MacOS/main'), isTrue);
      expect(
        pattern.hasMatch(
          '$first/Contents/Frameworks/Helper.app/Contents/MacOS/Helper',
        ),
        isTrue,
      );
      expect(pattern.hasMatch('${first}Other/Contents/MacOS/main'), isFalse);
      expect(
        pattern.hasMatch('/Applications/Other.app/Contents/MacOS/Helper'),
        isFalse,
      );
    },
  );
  test('rejects traversal executables and skips missing metadata', () async {
    await application('Bad.app');
    var catalog = PolicyApplicationCatalog(
      roots: [directory.path],
      supported: true,
      readPlist: (_) async => {'CFBundleExecutable': '../outside'},
    );
    expect(await catalog.load(), isEmpty);
    catalog = PolicyApplicationCatalog(
      roots: [directory.path],
      supported: true,
      readPlist: (_) async => null,
    );
    expect(await catalog.load(), isEmpty);
  });
  test(
    'does not traverse symbolic links or emit a silently truncated list',
    () async {
      await application('One.app');
      await application('Two.app');
      await Link(paths.join(directory.path, 'linked')).create(directory.path);
      final catalog = PolicyApplicationCatalog(
        roots: [directory.path],
        supported: true,
        maximumApplications: 1,
        readPlist: (_) async => {'CFBundleExecutable': 'main'},
      );
      await expectLater(catalog.load(), throwsStateError);
    },
  );
  test(
    'unsupported platforms fail explicitly without invoking plist reader',
    () async {
      var reads = 0;
      final catalog = PolicyApplicationCatalog(
        supported: false,
        readPlist: (_) async {
          reads++;
          return null;
        },
      );
      await expectLater(catalog.load(), throwsUnsupportedError);
      expect(reads, 0);
    },
  );
  test(
    'native plist decoding reads only the supplied bundle metadata',
    () async {
      final app = await application('Native.app');
      await File(paths.join(app, 'Contents', 'Info.plist')).writeAsString(
        '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>CFBundleExecutable</key><string>main</string><key>CFBundleDisplayName</key><string>Native Fixture</string></dict></plist>',
      );
      final result = await PolicyApplicationCatalog(
        roots: [directory.path],
        supported: true,
      ).load();
      expect(result.single.label, 'Native Fixture');
      expect(
        result.single.executable,
        paths.join(app, 'Contents', 'MacOS', 'main'),
      );
    },
    skip: !Platform.isMacOS,
  );
}
