part of '../action.dart';

final configurationBackupDatabaseProvider = Provider<Database>(
  (ref) => database,
);

final configurationBackupWriterProvider =
    Provider<Future<String> Function(Map<String, dynamic>, Iterable<String>)>(
      (ref) => backupTask,
    );

final configurationBackupReaderProvider =
    Provider<Future<MigrationData> Function(bool)>(
      (ref) =>
          (includeWorkbench) => restoreTask(includeWorkbench: includeWorkbench),
    );

@Riverpod(keepAlive: true)
class BackupAction extends _$BackupAction {
  @override
  void build() {}

  Future<String> backup() async {
    final database = ref.read(configurationBackupDatabaseProvider);
    final res = await Future.wait([
      database.profilesDao.fileNames().get(),
      database.scriptsDao.fileNames().get(),
    ]);
    final profileFileNames = res[0];
    final scriptFileNames = res[1];
    final controller = ref.read(workbenchControllerProvider);
    final agent = await controller.readAgentSettings();
    final credentials = controller.credentials;
    if (credentials is EncryptedConfigAgentCredentialStore) {
      try {
        await credentials.ensurePortable(
          agent.connections.map((connection) => connection.credentialId),
        );
      } on FormatException {
        throw currentAppLocalizations.aiBackupKeyRequired;
      }
    }
    final profiles = await database.profilesDao.query().get();
    final configMap = ref.read(configProvider).toJson();
    configMap['version'] = await preferences.getVersion();
    configMap['workbench'] = await exportWorkbenchBackup(
      ref.read(workbenchDatabaseProvider),
      profileIds: profiles.map((profile) => profile.id).toSet(),
    );
    return ref.read(configurationBackupWriterProvider)(configMap, [
      ...profileFileNames,
      ...scriptFileNames,
    ]);
  }

  Future<void> restore(RestoreOption option) async {
    final database = ref.read(configurationBackupDatabaseProvider);
    final restoreDirPath = await appPath.restoreDirPath;
    final restoreDir = Directory(restoreDirPath);
    final restoreStrategy = ref.read(
      appSettingProvider.select((state) => state.restoreStrategy),
    );
    final isOverride = restoreStrategy == RestoreStrategy.override;
    try {
      final migrationData = await ref.read(configurationBackupReaderProvider)(
        option == RestoreOption.all,
      );
      if (!await restoreDir.exists()) {
        throw currentAppLocalizations.restoreException;
      }
      final configMap = migrationData.configMap;
      final config = option == RestoreOption.all && configMap != null
          ? Config.fromJson(configMap)
          : null;
      final portable =
          option == RestoreOption.all &&
              configMap?.containsKey('workbench') == true
          ? await WorkbenchBackup.parse(
              configMap!['workbench'],
              profileIds: migrationData.profiles
                  .map((profile) => profile.id)
                  .toSet(),
            )
          : null;
      if (config != null) {
        await ref.read(workbenchControllerProvider).closeAgent();
      }
      await database.restore(
        migrationData.profiles,
        migrationData.scripts,
        migrationData.rules,
        migrationData.links,
        migrationData.proxyGroups,
        isOverride: isOverride,
      );
      if (config == null) return;
      if (portable != null) {
        await restoreWorkbenchBackup(
          ref.read(workbenchDatabaseProvider),
          portable,
        );
      }
      ref.read(davSettingProvider.notifier).update((_) => config.davProps);
      ref.read(patchClashConfigProvider.notifier).value =
          config.patchClashConfig;
      ref.read(appSettingProvider.notifier).value = config.appSettingProps;
      ref.read(currentProfileIdProvider.notifier).value =
          config.currentProfileId;
      ref.read(themeSettingProvider.notifier).value = config.themeProps;
      ref.read(windowSettingProvider.notifier).value = config.windowProps;
      ref.read(vpnSettingProvider.notifier).value = config.vpnProps;
      ref.read(proxiesStyleSettingProvider.notifier).value =
          config.proxiesStyleProps;
      ref.read(overrideDnsProvider.notifier).value = config.overrideDns;
      ref.read(networkSettingProvider.notifier).value = config.networkProps;
      ref.read(hotKeyActionsProvider.notifier).value = config.hotKeyActions;
      ref.read(excludeSSIDsProvider.notifier).value = config.excludeSSIDs;
      if (!await preferences.saveConfig(ref.read(configProvider))) {
        throw currentAppLocalizations.restoreException;
      }
      if (portable != null &&
          ref.read(coreStatusProvider) == CoreStatus.connected) {
        await ref.read(setupActionProvider.notifier).applyProfile(force: true);
      }
      return;
    } finally {
      await restoreDir.safeDelete(recursive: true);
    }
  }
}
