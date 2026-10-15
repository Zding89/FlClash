import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:fl_clash/ai/credentials.dart';
import 'package:fl_clash/ai/settings.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/proxy.dart' as desktop_proxy;
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/main.dart' as application;
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:proxy/proxy.dart' as platform_proxy;
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

const _root = '/private/tmp/flclash-agent-acceptance';
const _connection = AgentConnection(
  id: 'acceptance-loopback',
  label: '本机受控验收模型',
  provider: 'custom',
  model: 'flclash-agent-acceptance',
  baseUrl: 'http://127.0.0.1:49385/v1',
  timeoutSeconds: 90,
);

List<Profile> acceptanceFixtureProfiles() => [
  for (final id in [71001, 71002])
    Profile(
      id: id,
      label: id == 71001 ? '验收机场 A' : '验收机场 B',
      autoUpdateDuration: const Duration(days: 365),
      autoUpdate: false,
      lastUpdateDate: DateTime.utc(2026, 10, 15),
    ),
];

Map<String, Object?> acceptanceFixtureSource(int id) {
  final prefix = id == 71001 ? 'A' : 'B';
  return {
    'proxies': [
      for (final name in [
        '$prefix 美国 0.1x',
        '$prefix 香港 1x',
        '$prefix 美国 未知倍率',
      ])
        {
          'name': name,
          'type': 'ss',
          'server': '127.0.0.1',
          'port': 9,
          'cipher': 'aes-128-gcm',
          'password': 'synthetic-fixture-$name',
          'flclash-region': name.contains('美国') ? 'US' : 'HK',
          if (!name.contains('未知倍率'))
            'flclash-multiplier': name.contains('0.1x') ? 0.1 : 1,
        },
    ],
    'proxy-groups': <Object?>[],
    'rules': ['MATCH,DIRECT'],
  };
}

LocalPolicyDocument acceptanceFixtureDocument() {
  const document = LocalPolicyDocument(
    schemaVersion: 4,
    activeIntegrationId: localPolicyProfileId,
    sourceUpdateRoute: SourceUpdateRoute.direct,
    integrations: [
      SubscriptionIntegration(
        id: localPolicyProfileId,
        label: '验收本地配置',
        sourceProfileIds: [71001, 71002],
      ),
    ],
  );
  document.validate();
  return document;
}

class _PreferencesFile extends InMemorySharedPreferencesStore {
  _PreferencesFile(this.file, Map<String, Object> data) : super.withData(data);
  final File file;
  Future<void> _pending = Future.value();

  Future<bool> _persist() async {
    final snapshot = await getAllWithParameters(
      GetAllParameters(filter: PreferencesFilter(prefix: '')),
    );
    final write = _pending.then((_) async {
      final temporary = File('${file.path}.pending');
      await temporary.writeAsString(jsonEncode(snapshot), flush: true);
      await temporary.rename(file.path);
    });
    _pending = write.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    await write;
    return true;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    await super.setValue(valueType, key, value);
    return _persist();
  }

  @override
  Future<bool> remove(String key) async {
    await super.remove(key);
    return _persist();
  }

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) async {
    await super.clearWithParameters(parameters);
    return _persist();
  }
}

Future<Directory> _directory(String name) async {
  final directory = Directory('$_root/$name');
  if (await FileSystemEntity.type(directory.path, followLinks: false) ==
      FileSystemEntityType.link) {
    throw StateError('Acceptance directories must not be symbolic links');
  }
  await directory.create(recursive: true);
  if (await directory.resolveSymbolicLinks() != directory.path) {
    throw StateError('Acceptance directory escaped its fixed temporary root');
  }
  return directory;
}

Future<void> _seed(Directory data) async {
  final marker = File('${data.path}/fixture-v1.json');
  final workbench = WorkbenchDatabase(
    NativeDatabase(File('${data.path}/workbench.sqlite')),
  );
  final profileDatabase = Database(
    NativeDatabase(File('${data.path}/database.sqlite')),
  );
  try {
    if (!await marker.exists()) {
      final fixtureProfiles = acceptanceFixtureProfiles();
      await profileDatabase.profilesDao.setAll(fixtureProfiles);
      await Directory('${data.path}/profiles').create(recursive: true);
      for (final profile in fixtureProfiles) {
        final content = acceptanceFixtureSource(profile.id);
        await File(
          '${data.path}/profiles/${profile.fileName}',
        ).writeAsString(jsonEncode(content), flush: true);
      }
      final document = acceptanceFixtureDocument();
      await workbench.writeSection('policies', document.toJson());
      await workbench.writeSection('localControl', {'enabled': false});
      await marker.writeAsString(
        jsonEncode({
          'version': 1,
          'synthetic': true,
          'network': 'loopback-only',
        }),
        flush: true,
      );
    }
    if (const bool.fromEnvironment('FLCLASH_AGENT_LIVE_MODEL')) {
      final file = File('$_root/live-model.json');
      final value = jsonDecode(await file.readAsString()) as Map;
      final settings = AgentSettings.fromJson(
        Map<String, Object?>.from(value['ai'] as Map),
      );
      final connection = settings.selected;
      if (connection == null ||
          connection.id == _connection.id ||
          settings.connections.length != 1) {
        throw StateError('Acceptance requires one existing live connection');
      }
      final credentials =
          await EncryptedConfigAgentCredentialStore.validateSection(
            Map<String, Object?>.from(value['aiCredentials'] as Map),
          );
      if (!(credentials['values'] as Map).containsKey(
        connection.credentialId,
      )) {
        throw StateError('Live acceptance credential is missing');
      }
      await workbench.writeSection('ai', settings.toJson());
      await workbench.writeSection('aiCredentials', credentials);
    } else {
      await workbench.writeSection(
        'ai',
        const AgentSettings(
          enabled: true,
          selectedConnectionId: 'acceptance-loopback',
          connections: [_connection],
        ).toJson(),
      );
      await EncryptedConfigAgentCredentialStore(workbench).write(
        _connection.credentialId,
        'acceptance-fixture-key-not-a-real-secret',
      );
    }
  } finally {
    await profileDatabase.close();
    await workbench.close();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final package = await PackageInfo.fromPlatform();
  if (!const bool.fromEnvironment('FLCLASH_AGENT_ACCEPTANCE') ||
      !Platform.isMacOS ||
      package.packageName != 'com.zding.flclash.usage.acceptance') {
    throw StateError(
      'Acceptance requires FLCLASH_AGENT_ACCEPTANCE=true and the isolated macOS acceptance bundle',
    );
  }
  if (await FileSystemEntity.type(_root, followLinks: false) ==
      FileSystemEntityType.link) {
    throw StateError('Acceptance root must not be a symbolic link');
  }
  final data = await _directory('data');
  final temporary = await _directory('temp');
  final cache = await _directory('cache');
  await Future.wait([
    appPath.dataDir.future,
    appPath.tempDir.future,
    appPath.cacheDir.future,
  ]);
  appPath.dataDir = Completer<Directory>()..complete(data);
  appPath.tempDir = Completer<Directory>()..complete(temporary);
  appPath.cacheDir = Completer<Directory>()..complete(cache);
  final preferenceFile = File('${data.path}/acceptance-preferences.json');
  final stored = await preferenceFile.exists()
      ? Map<String, Object>.from(
          jsonDecode(await preferenceFile.readAsString()) as Map,
        )
      : <String, Object>{};
  SharedPreferencesStorePlatform.instance = _PreferencesFile(
    preferenceFile,
    stored,
  );
  final existing = await preferences.getConfig();
  final config = existing ?? Config.realFromJson(null);
  await preferences.saveConfig(
    config.copyWith(
      appSettingProps: config.appSettingProps.copyWith(
        locale: 'zh_CN',
        autoRun: false,
        autoLaunch: false,
        autoCheckUpdate: false,
        disclaimerAccepted: true,
        crashlyticsTip: true,
        crashlytics: false,
      ),
      networkProps: config.networkProps.copyWith(
        systemProxy: false,
        autoSetSystemDns: false,
      ),
      patchClashConfig: config.patchClashConfig.copyWith(
        mixedPort: 49386,
        tun: const Tun(enable: false),
      ),
    ),
  );
  await preferences.setVersion(1);
  desktop_proxy.proxy = platform_proxy.Proxy(
    processRunner: (executable, arguments, {runInShell = false}) async {
      if (executable != '/usr/sbin/networksetup') {
        throw StateError('Unexpected system proxy executable in acceptance');
      }
      await File('${data.path}/suppressed-system-proxy.jsonl').writeAsString(
        '${jsonEncode({'executable': executable, 'arguments': arguments})}\n',
        mode: FileMode.append,
      );
      return ProcessResult(
        0,
        0,
        arguments.contains('-listallnetworkservices')
            ? 'Acceptance Loopback\n'
            : '',
        '',
      );
    },
  );
  await _seed(data);
  await application.main();
}
