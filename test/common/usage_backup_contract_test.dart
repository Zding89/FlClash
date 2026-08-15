import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('configuration backup never reads the usage database', () async {
    final source = await File('lib/common/task.dart').readAsString();

    expect(source, contains('appPath.databasePath'));
    expect(source, isNot(contains('appPath.usageDatabasePath')));
    expect(source, isNot(contains('usage.sqlite')));
  });

  test('path-based streaming save remains desktop-only', () async {
    final source = await File('lib/common/picker.dart').readAsString();

    expect(source, contains('if (system.isDesktop)'));
    expect(source, isNot(contains('if (!system.isAndroid)')));
  });
}
