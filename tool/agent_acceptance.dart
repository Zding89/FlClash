import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:fl_clash/ai/credentials.dart';
import 'package:fl_clash/ai/settings.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/proxy.dart' as desktop_proxy;
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/main.dart' as application;
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/ai/assistant.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:proxy/proxy.dart' as platform_proxy;
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

const _fullFlow = bool.fromEnvironment('FLCLASH_AGENT_FULL_FLOW');
const _root = _fullFlow
    ? '/private/tmp/flclash-agent-full-flow'
    : '/private/tmp/flclash-agent-acceptance';
const _connection = AgentConnection(
  id: 'acceptance-loopback',
  label: '本机受控验收模型',
  provider: 'custom',
  model: 'flclash-agent-acceptance',
  baseUrl: 'http://127.0.0.1:49385/v1',
  timeoutSeconds: 90,
);

const _flowPrompts = [
  (
    '从零生成方案',
    '请从零创建本地规则草稿，不要应用，不选用本地配置。AI 流量优先迷之屋美区；迷之屋没有可用美国节点时，继续下一条同范围规则，使用其他机场的美国节点，尽量低倍率，不设倍率硬上限。国内用 GeoIP CN 直连，其余国外流量走香港，香港优先非迷之屋的机场。AI 范围在本次验收明确为 openai.com、chatgpt.com、anthropic.com、claude.ai、gemini.google.com 及各自子域。请创建所需动态节点组，保存筛选条件，不增加其他规则，不修改订阅附加规则。隔离验收的节点检查地址是 http://127.0.0.1:49390/health，GET，期望 204；自动检查每 5 秒，超时 1 秒，失败和成功阈值均为 1，重试 5 秒，有效期 10 秒，恢复观察和冷却均为 0 秒。',
  ),
  ('第一次连续修改', '继续修改刚才未应用的同一草稿：只把第一条规则改名为“AI 优先迷之屋美国”，其他字段、规则顺序和节点组全部保留，不要应用。'),
  (
    '第二次连续修改',
    '继续修改同一草稿：给前两条 AI 规则都补充 oaistatic.com 及其子域，保留第一次改名、原有域名、节点组和规则顺序，其他内容不变，不要应用。',
  ),
  (
    '重开后恢复检查',
    '我重新打开了这段聊天。请重新读取刚才最新的真实草稿，确认第一条已改名、两条 AI 规则均包含 oaistatic.com，并保留原节点组和顺序；不要重建、不要提交或切换网络。',
  ),
  (
    '仅保存且不选用',
    '现在提交保存这份方案，交给我本地审阅批准；先不要选用本地配置，不要启动连接。完成后核对保存结果，明确说明本地规则是否已经处理当前流量。',
  ),
  (
    '选择并开启连接',
    '现在明确选择使用本地配置并开启连接，让刚才保存的规则处理流量。我会在本地批准必要操作。请核对实际目标、规则版本和运行状态；不要把保存成功当成网络已生效，也不要声称已经验证网站访问。',
  ),
  ('读取实际生效状态', '请重新核对刚才选择本地配置和开启连接的操作，以及当前本地规则目标、文档版本和运行状态；只读查询，不重复执行写入。'),
  (
    '修正隔离检查参数',
    '最新草稿保留了默认检查参数，请继续修改同一草稿：逐一修改全部节点组以及 action 为 proxy 的规则，将 probe.url 设为 http://127.0.0.1:49390/health ，probe.method 为 GET，probe.expectedStatus 为 204，probe.automatic 为 true，probe.intervalSeconds 为 5，probe.timeoutSeconds 为 1，probe.failureThreshold 和 successThreshold 都为 1，probe.retrySeconds 为 5，probe.validitySeconds 为 10；字段 recoverySeconds 和 cooldownSeconds 均为 0。请按真实 schema 修改这些现有资源并逐一核对，保留规则名、顺序、全部域名、来源和地区条件，不新增或删除规则和节点组，不应用。',
  ),
];

Future<void> _installFlowControls() async {
  await WidgetsBinding.instance.endOfFrame;
  final navigator = globalState.navigatorKey.currentState;
  if (navigator == null) throw StateError('Acceptance navigator is missing');
  final input = TextEditingController();
  unawaited(
    navigator.push<void>(
      MaterialPageRoute(
        builder: (_) => AiAssistantView(inputController: input),
      ),
    ),
  );
  navigator.overlay!.insert(
    OverlayEntry(
      builder: (_) => Positioned(
        right: 18,
        bottom: 145,
        child: Material(
          child: PopupMenuButton<int>(
            tooltip: '载入中文验收指令',
            onSelected: (index) {
              final text = _flowPrompts[index].$2;
              input.value = TextEditingValue(
                text: text,
                selection: TextSelection.collapsed(offset: text.length),
              );
            },
            itemBuilder: (_) => [
              for (var index = 0; index < _flowPrompts.length; index++)
                PopupMenuItem(
                  value: index,
                  child: Text(_flowPrompts[index].$1),
                ),
            ],
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text('载入中文验收指令'),
            ),
          ),
        ),
      ),
    ),
  );
}

List<Profile> acceptanceFixtureProfiles() => [
  for (final id in [71001, 71002])
    Profile(
      id: id,
      label: _fullFlow
          ? id == 71001
                ? '迷之屋（隔离验收）'
                : '其他机场（隔离验收）'
          : id == 71001
          ? '验收机场 A'
          : '验收机场 B',
      autoUpdateDuration: const Duration(days: 365),
      autoUpdate: false,
      lastUpdateDate: DateTime.utc(2026, 10, 15),
    ),
];

Map<String, Object?> acceptanceFixtureSource(int id) {
  if (_fullFlow) {
    return {
      'proxies': [
        for (final entry
            in id == 71001
                ? [
                    ('美国 0.1x TCP', 'US', 0.1, 49387, false, 'mz-us-tcp'),
                    ('美国 1x UDP', 'US', 1.0, 49388, true, 'mz-us-udp'),
                    ('香港 1x', 'HK', 1.0, 49388, true, 'mz-hk'),
                  ]
                : [
                    ('美国 0.1x', 'US', 0.1, 49389, true, 'other-us-01'),
                    ('美国 0.5x', 'US', 0.5, 49389, true, 'other-us-05'),
                    ('香港 0.1x', 'HK', 0.1, 49389, true, 'other-hk'),
                  ])
          {
            'name': '${id == 71001 ? '迷之屋' : '其他机场'} ${entry.$1}',
            'type': entry.$5 ? 'socks5' : 'http',
            'server': '127.0.0.1',
            'port': entry.$4,
            'username': entry.$6,
            'password': 'acceptance-only',
            if (entry.$5) 'udp': true,
            'flclash-region': entry.$2,
            'flclash-multiplier': entry.$3,
          },
      ],
      'proxy-groups': <Object?>[],
      'rules': ['MATCH,DIRECT'],
    };
  }
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
  if (_fullFlow) {
    await _installFlowControls();
    var pending = false;
    Timer.periodic(const Duration(seconds: 1), (_) async {
      if (pending) return;
      pending = true;
      try {
        final status = await coreController.getLocalPolicyStatus().timeout(
          const Duration(seconds: 2),
        );
        await File(
          '$_root/runtime-status.json',
        ).writeAsString(jsonEncode(status), flush: true);
        final connections = await coreController.getConnections().timeout(
          const Duration(seconds: 2),
        );
        await File(
          '$_root/runtime-connections.json',
        ).writeAsString(jsonEncode(connections), flush: true);
      } catch (_) {
      } finally {
        pending = false;
      }
    });
  }
}
