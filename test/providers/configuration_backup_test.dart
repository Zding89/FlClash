import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fl_clash/ai/credentials.dart';
import 'package:fl_clash/ai/settings.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/configuration/workbench_backup.dart';
import 'package:fl_clash/database/database.dart' as main_db;
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _BackupPaths extends PathProviderPlatform {
  _BackupPaths(this.path);

  final String path;

  @override
  Future<String> getApplicationSupportPath() async => path;
  @override
  Future<String> getTemporaryPath() async => path;
  @override
  Future<String> getApplicationCachePath() async => path;
}

class _BackupProfiles extends Profiles {
  @override
  List<Profile> build() => const [
    Profile(id: 7, label: 'Local', autoUpdateDuration: Duration(days: 1)),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late main_db.Database mainDatabase;
  late WorkbenchDatabase store;
  late ProviderContainer container;
  late PathProviderPlatform originalPaths;
  late bool originalDriftWarning;
  Map<String, dynamic>? writtenConfig;
  List<String>? writtenFiles;
  final readerArguments = <bool>[];
  MigrationData? migration;
  const connection = AgentConnection(
    id: 'primary',
    label: 'Primary',
    provider: 'openai',
    model: 'fixture-model',
  );
  const localProfile = Profile(
    id: 7,
    label: 'Local',
    autoUpdateDuration: Duration(days: 1),
  );
  const remoteProfile = Profile(
    id: 7,
    label: 'Restored',
    autoUpdateDuration: Duration(days: 1),
  );
  const localConfig = Config(
    themeProps: defaultThemeProps,
    currentProfileId: 7,
    davProps: DAVProps(uri: 'https://example.invalid/dav', user: 'local'),
  );
  const remoteAi = AgentSettings(
    enabled: true,
    selectedConnectionId: 'primary',
    connections: [connection],
  );
  const remotePolicy = LocalPolicyDocument(
    policies: [
      LocalPolicy(
        id: 'restored-policy',
        label: 'Restored policy',
        targetId: 'profile:7',
        candidateNodeIds: ['node-a'],
      ),
    ],
  );

  Future<Map<String, Object?>> portableSnapshot() async {
    final remote = WorkbenchDatabase(NativeDatabase.memory());
    try {
      await remote.writeSection('ai', remoteAi.toJson());
      await EncryptedConfigAgentCredentialStore(
        remote,
      ).write(connection.credentialId, 'restored-api-key');
      await remote.writeSection('policies', remotePolicy.toJson());
      await remote.saveChange(
        id: 'restored-change',
        category: 'configuration',
        summary: 'Restored history',
        highRisk: false,
        fingerprint: 'old-fingerprint',
        before: {'private': 'old-snapshot'},
        after: {'private': 'new-snapshot'},
        createdAt: 10,
        expiresAt: 9999999999999,
      );
      await remote.writeSection('aiConversations', {
        'version': 1,
        'conversations': [
          {
            'id': '0123456789abcdef0123456789abcdef',
            'updatedAt': 11,
            'messages': [
              {'role': 'user', 'content': 'Restored conversation'},
            ],
            'changeIds': ['restored-change'],
          },
        ],
      });
      return await exportWorkbenchBackup(remote, profileIds: {7});
    } finally {
      await remote.close();
    }
  }

  Map<String, Object?> restoreConfig({Object? workbench}) {
    final map = Map<String, Object?>.from(
      jsonDecode(
            jsonEncode(
              container.read(configProvider).copyWith(overrideDns: true),
            ),
          )
          as Map,
    );
    map['version'] = 1;
    if (workbench != null) map['workbench'] = workbench;
    return map;
  }

  Future<void> seedLocalWorkbench() async {
    await store.writeSection(
      'ai',
      const AgentSettings(connections: [connection]).toJson(),
    );
    await EncryptedConfigAgentCredentialStore(
      store,
    ).write(connection.credentialId, 'local-api-key');
    await store.writeSection('policies', const LocalPolicyDocument().toJson());
    await store.writeSection('localControl', {'enabled': false});
    await store.writeSection('permissions', {'approved': false});
  }

  Future<List<Object?>> localState() async => [
    await store.readSection('ai'),
    await store.readSection('aiCredentials'),
    await store.readSection('policies'),
    await store.readSection('aiConversations'),
    await store.readSection('localControl'),
    await store.readSection('permissions'),
  ];

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('flclash-backup-action-');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _BackupPaths(directory.path);
    originalDriftWarning = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    SharedPreferences.setMockInitialValues({});
    await preferences.sharedPreferencesCompleter.future;
    await AppLocalizations.load(const Locale('en'));
    final file = File(await appPath.getProfilePath('7'));
    await file.parent.create(recursive: true);
    await file.writeAsString('proxies: []\nproxy-groups: []\nrules: []\n');
  });

  tearDownAll(() async {
    PathProviderPlatform.instance = originalPaths;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = originalDriftWarning;
    await directory.delete(recursive: true);
  });

  setUp(() async {
    mainDatabase = main_db.Database(NativeDatabase.memory());
    store = WorkbenchDatabase(NativeDatabase.memory());
    await mainDatabase.profilesDao.setAll([localProfile]);
    await preferences.saveConfig(localConfig);
    await preferences.setVersion(1);
    writtenConfig = null;
    writtenFiles = null;
    migration = null;
    readerArguments.clear();
    container = ProviderContainer(
      overrides: [
        ...buildConfigOverrides(localConfig),
        configurationBackupDatabaseProvider.overrideWithValue(mainDatabase),
        workbenchDatabaseProvider.overrideWithValue(store),
        profilesProvider.overrideWith(_BackupProfiles.new),
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.disconnected),
        configurationBackupWriterProvider.overrideWithValue((
          config,
          files,
        ) async {
          writtenConfig = config;
          writtenFiles = files.toList();
          return 'synthetic-backup.zip';
        }),
        configurationBackupReaderProvider.overrideWithValue((
          includeWorkbench,
        ) async {
          readerArguments.add(includeWorkbench);
          await Directory(await appPath.restoreDirPath).create(recursive: true);
          return migration!;
        }),
      ],
    );
    container.listen(configProvider, (_, _) {});
    await seedLocalWorkbench();
  });

  tearDown(() async {
    container.dispose();
    await store.close();
    await mainDatabase.close();
  });

  test(
    'backup writer receives workbench encrypted credentials and profile files',
    () async {
      final result = await container
          .read(backupActionProvider.notifier)
          .backup();
      expect(result, 'synthetic-backup.zip');
      expect(writtenFiles, ['7.yaml']);
      expect(writtenConfig!['version'], 1);
      expect(writtenConfig, contains('workbench'));
      expect(jsonEncode(writtenConfig), isNot(contains('local-api-key')));
      final portable = await WorkbenchBackup.parse(
        writtenConfig!['workbench'],
        profileIds: {7},
      );
      final sections = portable.toJson()['sections'] as Map;
      final values = (sections['aiCredentials'] as Map)['values'] as Map;
      expect(values[connection.credentialId], startsWith('v1.'));
      expect(sections, isNot(contains('localControl')));
      expect(sections, isNot(contains('permissions')));
    },
  );

  test(
    'all restores workbench and main profiles and existing credential instance reads restored key',
    () async {
      final credentials = container
          .read(workbenchControllerProvider)
          .credentials;
      expect(await credentials.read(connection.credentialId), 'local-api-key');
      migration = MigrationData(
        profiles: [remoteProfile],
        configMap: restoreConfig(workbench: await portableSnapshot()),
      );
      await container
          .read(backupActionProvider.notifier)
          .restore(RestoreOption.all);
      expect(readerArguments, [true]);
      expect(
        (await mainDatabase.profilesDao.query().get()).single.label,
        'Restored',
      );
      expect(
        (await store.readPolicies()).toJson(),
        remotePolicy.asStandalone().toJson(),
      );
      expect(
        (await container.read(workbenchControllerProvider).readAgentSettings())
            .toJson(),
        remoteAi.toJson(),
      );
      expect(
        await credentials.read(connection.credentialId),
        'restored-api-key',
      );
      expect((await store.readChange('restored-change'))!.status, 'superseded');
      expect(
        (await store.readSection('aiConversations'))!['conversations'],
        hasLength(1),
      );
      expect(await store.readSection('localControl'), {'enabled': false});
      expect(await store.readSection('permissions'), {'approved': false});
      expect(container.read(configProvider).overrideDns, isTrue);
      expect((await preferences.getConfig())!.overrideDns, isTrue);
      expect(await Directory(await appPath.restoreDirPath).exists(), isFalse);
    },
  );

  test(
    'onlyProfiles excludes workbench and preserves configuration and credentials',
    () async {
      final before = await localState();
      migration = MigrationData(
        profiles: [remoteProfile],
        configMap: restoreConfig(workbench: {'version': 999}),
      );
      await container
          .read(backupActionProvider.notifier)
          .restore(RestoreOption.onlyProfiles);
      expect(readerArguments, [false]);
      expect(
        (await mainDatabase.profilesDao.query().get()).single.label,
        'Restored',
      );
      expect(await localState(), before);
      expect(container.read(configProvider), localConfig);
    },
  );

  test(
    'older all backup without workbench retains local workbench records and keys',
    () async {
      final before = await localState();
      migration = MigrationData(
        profiles: [remoteProfile],
        configMap: restoreConfig(),
      );
      await container
          .read(backupActionProvider.notifier)
          .restore(RestoreOption.all);
      expect(readerArguments, [true]);
      expect(
        (await mainDatabase.profilesDao.query().get()).single.label,
        'Restored',
      );
      expect(await localState(), before);
      expect(
        await container
            .read(workbenchControllerProvider)
            .credentials
            .read(connection.credentialId),
        'local-api-key',
      );
      expect(container.read(configProvider).overrideDns, isTrue);
    },
  );

  test(
    'corrupt all snapshot fails before main database restore and preserves local records',
    () async {
      final before = await localState();
      final bad = await portableSnapshot();
      ((bad['sections'] as Map)['aiCredentials']
              as Map)['values'][connection.credentialId] =
          'v1.corrupt';
      migration = MigrationData(
        profiles: [remoteProfile],
        configMap: restoreConfig(workbench: bad),
      );
      await expectLater(
        container
            .read(backupActionProvider.notifier)
            .restore(RestoreOption.all),
        throwsFormatException,
      );
      expect(readerArguments, [true]);
      expect(
        (await mainDatabase.profilesDao.query().get()).single.label,
        'Local',
      );
      expect(await localState(), before);
      expect(container.read(configProvider), localConfig);
      expect((await preferences.getConfig())!, localConfig);
      expect(await Directory(await appPath.restoreDirPath).exists(), isFalse);
    },
  );
}
