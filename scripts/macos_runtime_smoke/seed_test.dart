import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/models/config.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'prepare standalone CI application fixture without ordinary profiles',
    () async {
      expect(Platform.isMacOS, isTrue);
      expect(Platform.environment['GITHUB_ACTIONS'], 'true');
      expect(Platform.environment['RUNNER_OS'], 'macOS');
      const path = String.fromEnvironment('SMOKE_DATA_DIR');
      const configPath = String.fromEnvironment('SMOKE_CONFIG_PATH');
      final expected =
          '${Platform.environment['HOME']}/Library/Application Support/com.zding.flclash.usage';
      expect(path, expected);
      expect(
        configPath.startsWith('/private/tmp/flclash-macos-smoke-'),
        isTrue,
      );
      final dir = Directory(path);
      expect(await dir.exists(), isFalse);
      await dir.create(recursive: true);
      final database = WorkbenchDatabase(
        NativeDatabase(File('$path/workbench.sqlite')),
      );
      try {
        await database.writeSection('localControl', {'enabled': true});
        final document = LocalPolicyDocument.fromJson({
          ...const LocalPolicyDocument(
            integrations: [
              SubscriptionIntegration(
                id: localPolicyProfileId,
                label: 'Local',
                sourceProfileIds: [],
              ),
            ],
            moduleEnabled: true,
            integrationEnabled: true,
            policiesEnabled: true,
            policies: [
              LocalPolicy(
                id: 'smoke-local-direct',
                label: 'Smoke local direct',
                targetId: localPolicyTargetId,
                action: PolicyAction.direct,
                scope: PolicyMatch(
                  type: PolicyMatchType.domainSuffix,
                  values: ['smoke.invalid'],
                ),
              ),
            ],
          ).toJson(),
          'schemaVersion': 4,
          'activeIntegrationId': localPolicyProfileId,
        }).asStandalone();
        await database.writeSection('policies', document.toJson());
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
    },
  );
}
