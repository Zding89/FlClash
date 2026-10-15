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

  Future<void> persistCurrentSelectedMap(
    String groupName,
    String proxyName,
  ) async {
    final originalName = ref
        .read(setupActionProvider.notifier)
        .originalSelection(groupName, proxyName);
    if (originalName == null) return;
    final profile = ref.read(currentProfileProvider);
    if (profile == null) throw StateError('proxy_profile_missing');
    final selectedMap = Map<String, String>.from(profile.selectedMap)
      ..[groupName] = originalName;
    await ref
        .read(profilesProvider.notifier)
        .putAndWait(profile.copyWith(selectedMap: selectedMap));
  }

  Future<void> deleteProfile(int id) async {
    final document = system.isMacOS
        ? (await ref.read(workbenchDatabaseProvider).readPolicies())
              .asStandalone()
        : const LocalPolicyDocument();
    if (document.referencesProfile(id)) {
      throw const ConfigurationChangeException('resource_source_referenced');
    }
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
        if (!(document.moduleEnabled && document.integrationEnabled)) {
          ref.read(setupActionProvider.notifier).setRunning(false);
        }
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
    final epoch = (_updateEpochs[profile.id] ?? 0) + 1;
    _updateEpochs[profile.id] = epoch;
    bool isCurrent() =>
        _updateEpochs[profile.id] == epoch &&
        ref.read(profilesProvider).getProfile(profile.id)?.url == profile.url;
    try {
      if (showLoading) {
        ref.read(isUpdatingProvider(profile.updatingKey).notifier).value = true;
      }
      await ref.read(profilesProvider.notifier).putAndWait(profile);
      final fetch = system.isMacOS
          ? ref.read(workbenchControllerProvider).fetchSourceResponse
          : request.getBoundedFileResponse;
      await ref.read(setupActionProvider.notifier).runSourceUpdate((
        apply,
      ) async {
        if (!isCurrent()) throw StateError('profile_update_superseded');
        final previous = ref.read(profilesProvider).getProfile(profile.id)!;
        Profile? published;
        PreparedSourceUpdate? candidate;
        await profile.update(
          fetch: fetch,
          isCurrent: isCurrent,
          validateSource: system.isMacOS
              ? (bytes) async {
                  candidate = await ref
                      .read(workbenchControllerProvider)
                      .validateSourceUpdate(
                        profile,
                        bytes,
                        isCurrent: isCurrent,
                      );
                }
              : null,
          onMetadata: (metadata) async {
            if (!isCurrent()) return;
            final latest = ref.read(profilesProvider).getProfile(profile.id)!;
            await ref
                .read(profilesProvider.notifier)
                .putAndWait(
                  latest.copyWith(subscriptionInfo: metadata.subscriptionInfo),
                );
            if (system.isMacOS) {
              await ref
                  .read(workbenchControllerProvider)
                  .refreshSourceMetadata(metadata, isCurrent: isCurrent);
            }
          },
          onPublished: (updated) async {
            if (!isCurrent()) throw StateError('profile_update_superseded');
            await candidate?.publish();
            final latest = ref.read(profilesProvider).getProfile(profile.id)!;
            published = latest.copyWith(
              label: latest.label.isEmpty ? updated.label : latest.label,
              subscriptionInfo: updated.subscriptionInfo,
              lastUpdateDate: updated.lastUpdateDate,
            );
            await ref.read(profilesProvider.notifier).putAndWait(published!);
            if (await _affectsCurrentProfile(profile.id)) await apply();
          },
          onRollback: () async {
            await candidate?.rollback();
            final latest = ref.read(profilesProvider).getProfile(profile.id);
            if (published != null &&
                latest != null &&
                latest.lastUpdateDate == published!.lastUpdateDate) {
              await ref
                  .read(profilesProvider.notifier)
                  .putAndWait(
                    latest.copyWith(
                      label: latest.label == published!.label
                          ? previous.label
                          : latest.label,
                      lastUpdateDate: previous.lastUpdateDate,
                    ),
                  );
            }
            if (await _affectsCurrentProfile(profile.id)) await apply();
          },
        );
      });
    } finally {
      if (_updateEpochs[profile.id] == epoch) {
        ref.read(isUpdatingProvider(profile.updatingKey).notifier).value =
            false;
      }
    }
  }

  Future<bool> _affectsCurrentProfile(int id) async {
    if (system.isMacOS) {
      final document =
          (await ref.read(workbenchDatabaseProvider).readPolicies())
              .asStandalone();
      if (document.moduleEnabled && document.integrationEnabled) {
        return document.localProfile.sourceProfileIds.contains(id);
      }
    }
    return id == ref.read(currentProfileIdProvider);
  }

  Future<Profile?> addProfileFormFile({bool navigateToProfiles = true}) async {
    final platformFile = await globalState.safeRun(picker.pickerFile);
    if (platformFile == null) return null;
    final bytes = await platformFile.readBytes();
    if (navigateToProfiles) {
      globalState.navigatorKey.currentState?.popUntil((route) => route.isFirst);
      ref.read(currentPageLabelProvider.notifier).toProfiles();
    }
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
    return profile;
  }

  Future<Profile?> addProfileFormURL(
    String url, {
    bool navigateToProfiles = true,
  }) async {
    if (navigateToProfiles &&
        (globalState.navigatorKey.currentState?.canPop() ?? false)) {
      globalState.navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
    if (navigateToProfiles) {
      ref.read(currentPageLabelProvider.notifier).value = PageLabel.profiles;
    }
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
    return profile;
  }

  Future<void> setProfileAndAutoApply(Profile profile) async {
    ref.read(profilesProvider.notifier).put(profile);
    try {
      if (await _affectsCurrentProfile(profile.id)) {
        ref.read(setupActionProvider.notifier).applyProfileDebounce();
      }
    } catch (_) {
      commonPrint.log(
        'Profile activation check failed (${profile.id})',
        logLevel: LogLevel.warning,
      );
    }
  }

  Future<Profile?> addProfileFormQrCode({
    bool navigateToProfiles = true,
  }) async {
    final url = await globalState.safeRun(picker.pickerConfigQRCode);
    if (url == null) return null;
    return addProfileFormURL(url, navigateToProfiles: navigateToProfiles);
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
