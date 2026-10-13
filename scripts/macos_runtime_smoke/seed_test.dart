import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/models/config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prepare empty CI application fixture through the real schema', () async {
    expect(Platform.isMacOS, isTrue);
    expect(Platform.environment['GITHUB_ACTIONS'], 'true');
    expect(Platform.environment['RUNNER_OS'], 'macOS');
    const path = String.fromEnvironment('SMOKE_DATA_DIR');
    const configPath = String.fromEnvironment('SMOKE_CONFIG_PATH');
    final expected =
        '${Platform.environment['HOME']}/Library/Application Support/com.zding.flclash.usage';
    expect(path, expected);
    expect(configPath.startsWith('/private/tmp/flclash-macos-smoke-'), isTrue);
    final dir = Directory(path);
    expect(await dir.exists(), isFalse);
    await dir.create(recursive: true);
    final database = WorkbenchDatabase(
      NativeDatabase(File('$path/workbench.sqlite')),
    );
    try {
      await database.writeSection('localControl', {'enabled': true});
    } finally {
      await database.close();
    }
    const config = Config(
      themeProps: defaultThemeProps,
      appSettingProps: AppSettingProps(
        locale: 'zh_CN',
        disclaimerAccepted: true,
        autoCheckUpdate: false,
      ),
      networkProps: NetworkProps(systemProxy: false, autoSetSystemDns: false),
    );
    await File(configPath).writeAsString(jsonEncode(config));
  });
}
