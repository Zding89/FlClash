part of '../action.dart';

@Riverpod(keepAlive: true)
class ProfilesAction extends _$ProfilesAction {
  final Map<int, int> _updateEpochs = {};
  @override
  void build() {}

  void updateCurrentSelectedMap(String groupName, String proxyName) {
    final originalName = ref
        .read(setupActionProvider.notifier)
        .originalSelection(groupName, proxyName);
    if (originalName == null) return;
    final currentProfile = ref.read(currentProfileProvider);
    if (currentProfile != null &&
        currentProfile.selectedMap[groupName] != originalName) {
      final selectedMap = Map<String, String>.from(currentProfile.selectedMap)
        ..[groupName] = originalName;
      ref
          .read(profilesProvider.notifier)
          .put(currentProfile.copyWith(selectedMap: selectedMap));
    }
  }

  Future<void> deleteProfile(int id) async {
    await ref.read(profilesProvider.notifier).del(id);
    await clearEffect(id);
    final currentProfileId = ref.read(currentProfileIdProvider);
    if (currentProfileId == id) {
      final profiles = ref.read(profilesProvider);
      if (profiles.isNotEmpty) {
        final updateId = profiles.first.id;
        ref.read(currentProfileIdProvider.notifier).value = updateId;
      } else {
        ref.read(currentProfileIdProvider.notifier).value = null;
        ref.read(setupActionProvider.notifier).setRunning(false);
      }
    }
  }

  Future<void> autoUpdateProfiles() async {
    for (final profile in ref.read(profilesProvider)) {
      if (!profile.autoUpdate) continue;
      final isNotNeedUpdate = profile.lastUpdateDate
          ?.add(profile.autoUpdateDuration)
          .isBeforeNow;
      if (isNotNeedUpdate == false || profile.type == ProfileType.file) {
        continue;
      }
      try {
        await updateProfile(profile);
      } catch (_) {
        commonPrint.log(
          'Subscription update failed (${profile.id})',
          logLevel: LogLevel.warning,
        );
      }
    }
  }

  void putProfile(Profile profile) {
    ref.read(profilesProvider.notifier).put(profile);
    if (ref.read(currentProfileIdProvider) != null) return;
    ref.read(currentProfileIdProvider.notifier).value = profile.id;
  }

  Future<void> updateProfiles() async {
    for (final profile in ref.read(profilesProvider)) {
      if (profile.type == ProfileType.file) continue;
      await updateProfile(profile);
    }
  }

  Future<void> updateProfile(
    Profile profile, {
    bool showLoading = false,
  }) async {
    var metadataChanged = false;
    bool Function()? stillCurrent;
    try {
      if (showLoading) {
        ref.read(isUpdatingProvider(profile.updatingKey).notifier).value = true;
      }
      ref.read(profilesProvider.notifier).put(profile);
      final epoch = (_updateEpochs[profile.id] ?? 0) + 1;
      _updateEpochs[profile.id] = epoch;
      bool isCurrent() =>
          _updateEpochs[profile.id] == epoch &&
          ref.read(profilesProvider).getProfile(profile.id)?.url == profile.url;
      stillCurrent = isCurrent;
      final fetch = system.isMacOS
          ? ref.read(workbenchControllerProvider).fetchSourceResponse
          : request.getBoundedFileResponse;
      final newProfile = await profile.update(
        fetch: fetch,
        isCurrent: isCurrent,
        validateSource: system.isMacOS
            ? (bytes) => ref
                  .read(workbenchControllerProvider)
                  .validateSourceUpdate(profile, bytes, isCurrent: isCurrent)
            : null,
        onMetadata: (metadata) async {
          if (!isCurrent()) return;
          final latest = ref.read(profilesProvider).getProfile(profile.id)!;
          metadataChanged =
              latest.subscriptionInfo != metadata.subscriptionInfo;
          ref
              .read(profilesProvider.notifier)
              .put(
                latest.copyWith(subscriptionInfo: metadata.subscriptionInfo),
              );
          if (system.isMacOS) {
            await ref
                .read(workbenchControllerProvider)
                .refreshSourceMetadata(metadata, isCurrent: isCurrent);
          }
        },
      );
      if (!isCurrent()) return;
      final latest = ref.read(profilesProvider).getProfile(profile.id)!;
      ref
          .read(profilesProvider.notifier)
          .put(
            latest.copyWith(
              label: latest.label.isEmpty ? newProfile.label : latest.label,
              subscriptionInfo: newProfile.subscriptionInfo,
              lastUpdateDate: newProfile.lastUpdateDate,
            ),
          );
      if (await _affectsCurrentProfile(profile.id)) {
        ref
            .read(setupActionProvider.notifier)
            .applyProfileDebounce(silence: true);
      }
    } catch (_) {
      if (metadataChanged &&
          stillCurrent?.call() == true &&
          await _affectsCurrentProfile(profile.id)) {
        try {
          await ref
              .read(setupActionProvider.notifier)
              .applyProfile(force: true, silence: true);
        } catch (_) {}
      }
      rethrow;
    } finally {
      ref.read(isUpdatingProvider(profile.updatingKey).notifier).value = false;
    }
  }

  Future<bool> _affectsCurrentProfile(int id) async {
    if (id == ref.read(currentProfileIdProvider)) return true;
    if (!system.isMacOS) return false;
    final document = await ref.read(workbenchDatabaseProvider).readPolicies();
    return document.integrationEnabled &&
        document.activeIntegration?.sourceProfileIds.contains(id) == true;
  }

  Future<void> addProfileFormFile() async {
    final platformFile = await globalState.safeRun(picker.pickerFile);
    if (platformFile == null) return;
    final bytes = await platformFile.readBytes();
    globalState.navigatorKey.currentState?.popUntil((route) => route.isFirst);
    ref.read(currentPageLabelProvider.notifier).toProfiles();
    final profile = await globalState.loadingRun(
      tag: LoadingTag.profiles,
      () async {
        return Profile.normal(label: platformFile.name).saveFile(bytes);
      },
      title: currentAppLocalizations.addProfile,
    );
    if (profile != null) {
      putProfile(profile);
    }
  }

  Future<void> addProfileFormURL(String url) async {
    if (globalState.navigatorKey.currentState?.canPop() ?? false) {
      globalState.navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
    ref.read(currentPageLabelProvider.notifier).value = PageLabel.profiles;
    final profile = await globalState.loadingRun(
      tag: LoadingTag.profiles,
      () async {
        return Profile.normal(url: url).update(
          fetch: system.isMacOS
              ? ref.read(workbenchControllerProvider).fetchSourceResponse
              : request.getBoundedFileResponse,
        );
      },
      title: currentAppLocalizations.addProfile,
    );
    if (profile != null) {
      putProfile(profile);
    }
  }

  void setProfileAndAutoApply(Profile profile) {
    ref.read(profilesProvider.notifier).put(profile);
    if (profile.id == ref.read(currentProfileIdProvider)) {
      ref.read(setupActionProvider.notifier).applyProfileDebounce();
    }
  }

  Future<void> addProfileFormQrCode() async {
    final url = await globalState.safeRun(picker.pickerConfigQRCode);
    if (url == null) return;
    addProfileFormURL(url);
  }

  Future<void> reorder(List<Profile> profiles) =>
      ref.read(profilesProvider.notifier).reorder(profiles);

  Future<void> clearEffect(int profileId) async {
    final profilePath = await appPath.getProfilePath(profileId.toString());
    final profileFile = File(profilePath);
    final isExists = await profileFile.exists();
    if (isExists) {
      await profileFile.safeDelete(recursive: true);
    }
    final error = await coreController.clearEffect(profileId);
    if (error.isNotEmpty) {
      commonPrint.log(error, logLevel: LogLevel.warning);
    }
  }
}
