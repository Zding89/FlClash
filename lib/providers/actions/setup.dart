part of '../action.dart';

enum _SetupTaskResult { completed, handoffToCoreRestart }

class _RunRequest {
  final bool running;
  final bool initialize;

  const _RunRequest({required this.running, required this.initialize});
}

@Riverpod(keepAlive: true)
class SetupAction extends _$SetupAction {
  Timer? _runtimeTimer;
  final _setupScheduler = SerialTaskScheduler();
  final _listenerScheduler = SerialTaskScheduler();
  _RunRequest? _latestRunRequest;
  DateTime? _startTime;
  String? _approvedProfileYaml;
  String? _approvedProfileSignature;
  Map<String, String> _selectionAliases = {};
  Set<String> _policyGroups = {};
  bool _integratedSelection = false;

  bool get _isRunning => _startTime != null && _startTime!.isBeforeNow;

  @override
  void build() {}

  SetupParams get _setupParams {
    final selectedMap = ref.read(selectedMapProvider);
    final testUrl = ref.read(
      appSettingProvider.select((state) => state.testUrl),
    );
    return SetupParams(
      selectedMap: {
        if (!_integratedSelection)
          for (final entry in selectedMap.entries)
            if (!_policyGroups.contains(entry.key))
              entry.key: _selectionAliases[entry.value] ?? entry.value,
      },
      testUrl: testUrl,
    );
  }

  String? originalSelection(String groupName, String proxyName) {
    if (_integratedSelection || _policyGroups.contains(groupName)) return null;
    for (final entry in _selectionAliases.entries) {
      if (entry.value == proxyName) return entry.key;
    }
    return proxyName;
  }

  void _readSelectionAliases(String yaml, LocalPolicyDocument document) {
    final raw = normalizePolicyYaml(loadYaml(yaml)) as Map;
    final extension = raw['flclash-local-policy'];
    _selectionAliases = extension is Map && extension['enabled'] == true
        ? Map<String, String>.from(
            raw['flclash-selection-aliases'] as Map? ?? {},
          )
        : {};
    _policyGroups = extension is Map
        ? (extension['policies'] as List? ?? [])
              .map((entry) => (entry as Map)['groupName'])
              .whereType<String>()
              .toSet()
        : {};
    _integratedSelection = document.integrationEnabled;
  }

  void fullSetup() {
    if (!ref.read(initProvider)) return;
    ref.read(delayDataSourceProvider.notifier).value = {};
    unawaited(_runSetup(force: true));
    ref.read(logsProvider.notifier).value = FixedList(500);
    ref.read(requestsProvider.notifier).value = FixedList(500);
  }

  void _setLocalRunning(bool running) {
    _runtimeTimer?.cancel();
    _runtimeTimer = null;
    if (!running) {
      _startTime = null;
      debouncer.cancel(FunctionTag.applyProfile);
      _updateRunTime();
      return;
    }

    _startTime ??= DateTime.now();
    _refreshRunningState();
    _runtimeTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshRunningState(),
    );
  }

  void _refreshRunningState() {
    _updateRunTime();
    unawaited(ref.read(commonActionProvider.notifier).updateTraffic());
  }

  void _updateRunTime() {
    final startTime = _startTime;
    ref.read(runTimeProvider.notifier).value = startTime == null
        ? null
        : DateTime.now().millisecondsSinceEpoch -
              startTime.millisecondsSinceEpoch;
  }

  Future<void> _updateStartTime() async {
    _startTime = await service?.getRunTime();
  }

  Future<void> initStatus() async {
    if (!globalState.needInitStatus) {
      commonPrint.log('init status cancel');
      return;
    }
    commonPrint.log('init status');
    if (system.isAndroid) {
      await _updateStartTime();
    }
    final shouldRun = _isRunning || ref.read(appSettingProvider).autoRun;
    if (shouldRun) {
      await setRunning(true, initialize: true);
    } else {
      await applyProfile(force: true);
    }
  }

  Future<void> setRunning(bool running, {bool initialize = false}) {
    if (running && !initialize && !ref.read(initProvider)) {
      return Future.value();
    }

    final request = _RunRequest(
      running: running,
      initialize: running && initialize,
    );
    _latestRunRequest = request;
    _setLocalRunning(running);
    if (request.initialize) {
      globalState.needInitStatus = false;
    }
    return running ? _start(request) : _stop(request);
  }

  Future<void> _start(_RunRequest request) async {
    if (request.initialize) {
      try {
        await applyProfile(
          force: true,
          preloadInvoke: () => _setCoreRunning(request),
        );
      } catch (_) {
        if (_isCurrent(request)) {
          await setRunning(false);
        }
      }
      return;
    }

    await _setCoreRunning(request);
    if (_isCurrent(request)) {
      applyProfileDebounce(force: true, silence: true);
    }
  }

  Future<void> _stop(_RunRequest request) async {
    await _setCoreRunning(request);
    if (!_isCurrent(request)) {
      return;
    }
    resetCoreTraffic();
    ref.read(trafficsProvider.notifier).clear();
    ref.read(totalTrafficProvider.notifier).value = const Traffic();
    ref.read(checkIpNumProvider.notifier).add();
  }

  Future<void> _setCoreRunning(_RunRequest request) {
    return _listenerScheduler.run(() async {
      if (!_isCurrent(request)) {
        return;
      }
      if (request.running && ref.read(suspendProvider)) {
        return;
      }
      await setCoreRunning(request.running);
    });
  }

  bool _isCurrent(_RunRequest request) => identical(_latestRunRequest, request);

  Future<void> updateConfigDebounce() async {
    debouncer.call(FunctionTag.updateConfig, updateConfig);
  }

  @protected
  Future<bool> setCoreRunning(bool running) {
    return running
        ? coreController.startListener()
        : coreController.stopListener();
  }

  @protected
  void resetCoreTraffic() {
    coreController.resetTraffic();
  }

  @visibleForTesting
  Future<void> updateConfig() async {
    await globalState.safeRun(() async {
      final updateParams = ref.read(updateParamsProvider);
      final shouldContinueSetup = await requestAdmin(updateParams.tun.enable);
      if (!shouldContinueSetup) {
        await _restartCoreAfterAuthorization();
        return;
      }
      final message = await coreController.updateConfig(
        updateParams.copyWith.tun(
          enable: _getEffectiveTunEnable(updateParams.tun.enable),
        ),
      );
      ref.read(checkIpNumProvider.notifier).add();
      if (message.isNotEmpty) throw message;
    });
  }

  void tryCheckIp() {
    final isTimeout = ref.read(
      networkDetectionProvider.select(
        (state) => state.ipInfo == null && state.isLoading == false,
      ),
    );
    if (!isTimeout) return;
    ref.read(checkIpNumProvider.notifier).add();
  }

  void applyProfileDebounce({bool silence = false, bool force = false}) {
    debouncer.call(FunctionTag.applyProfile, (silence, force) {
      applyProfile(silence: silence, force: force);
    }, args: [silence, force]);
  }

  void changeMode(Mode mode) {
    ref
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith(mode: mode));
    if (mode == Mode.global) {
      ref
          .read(proxiesActionProvider.notifier)
          .updateCurrentGroupName(GroupName.GLOBAL.name);
    }
  }

  void autoApplyProfile() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      applyProfile();
    });
  }

  Future<void> applyProfile({
    bool silence = false,
    bool force = false,
    Future<void> Function()? preloadInvoke,
    String? approvedProfileYaml,
    bool requireTunAuthorization = false,
  }) async {
    if (approvedProfileYaml != null) {
      final document = await ref.read(workbenchDatabaseProvider).readPolicies();
      _approvedProfileYaml = approvedProfileYaml;
      _approvedProfileSignature = _profileSignature(document);
    }
    try {
      await _runSetup(
        force: force,
        silence: silence,
        preloadInvoke: preloadInvoke,
        requireTunAuthorization: requireTunAuthorization,
      );
    } finally {
      if (approvedProfileYaml != null &&
          _approvedProfileYaml == approvedProfileYaml) {
        _approvedProfileYaml = null;
        _approvedProfileSignature = null;
      }
    }
  }

  Future<void> _runSetup({
    bool requireTunAuthorization = false,
    bool silence = false,
    bool force = false,
    Future<void> Function()? preloadInvoke,
  }) async {
    final result = await _setupScheduler.run(() {
      return _setupConfig(
        force: force,
        silence: silence,
        preloadInvoke: preloadInvoke,
        requireTunAuthorization: requireTunAuthorization,
        onUpdated: () async {
          await ref.read(proxiesActionProvider.notifier).updateGroups();
          await ref.read(providersProvider.notifier).syncProviders();
        },
      );
    });
    if (result != _SetupTaskResult.handoffToCoreRestart) {
      return;
    }
    // Release the current serial task before restartCore reapplies the profile.
    await _restartCoreAfterAuthorization();
  }

  Future<void> _restartCoreAfterAuthorization() async {
    try {
      await ref.read(coreActionProvider.notifier).restartCore();
    } catch (_) {
      ref.read(authorizedTunEnableProvider.notifier).value =
          TunAuthorizationState.none;
      rethrow;
    }
  }

  Future<VM2<String, String>> getProfile({
    required SetupState setupState,
    required PatchClashConfig patchConfig,
    LocalPolicyDocument? policyDocument,
    NetworkProps? networkProps,
    bool? dnsOverride,
    bool preview = false,
    bool allowScriptExecution = false,
  }) async {
    final profileId = setupState.profileId;
    final document = system.isMacOS
        ? policyDocument ??
              await ref.read(workbenchDatabaseProvider).readPolicies()
        : const LocalPolicyDocument();
    final integrated = document.integrationEnabled;
    if (profileId == null && !integrated) return const VM2('', '');
    final defaultUA = globalState.packageInfo.ua;
    final networkVM2 = ref.read(
      networkSettingProvider.select(
        (state) => VM2(state.appendSystemDns, state.routeMode),
      ),
    );
    final overrideDns = ref.read(overrideDnsProvider);
    final appendSystemDns = networkProps?.appendSystemDns ?? networkVM2.a;
    final routeMode = networkProps?.routeMode ?? networkVM2.b;
    final configMap = integrated
        ? <String, dynamic>{
            'rules': <String>['MATCH,REJECT'],
            'dns': patchConfig.dns.toJson(),
          }
        : await coreController.getConfig(profileId!);
    String? scriptContent;
    final List<Rule> addedRules = [];
    final List<ProxyGroup> proxyGroups = [];
    final List<Rule> rules = [];
    if (!integrated && setupState.overwriteType == OverwriteType.script) {
      if (preview && setupState.script != null && !allowScriptExecution) {
        throw StateError('script_preview_requires_authorization');
      }
      scriptContent = await setupState.script?.content;
    } else if (!integrated &&
        setupState.overwriteType == OverwriteType.standard) {
      addedRules.addAll(setupState.addedRules);
    } else if (!integrated) {
      proxyGroups.addAll(setupState.proxyGroups);
      rules.addAll(setupState.rules);
    }
    final realPatchConfig = patchConfig.copyWith(
      tun: patchConfig.tun.getRealTun(routeMode),
    );
    Map<String, dynamic> rawConfig = configMap;
    if (scriptContent?.isNotEmpty == true) {
      rawConfig = await handleEvaluate(scriptContent!, rawConfig);
    }
    final directory = await appPath.profilesPath;
    final res = await makeRealProfileTask(
      MakeRealProfileState(
        rules: rules,
        proxyGroups: proxyGroups,
        profilesPath: directory,
        profileId: profileId ?? 0,
        rawConfig: rawConfig,
        realPatchConfig: realPatchConfig,
        overrideDns: dnsOverride ?? overrideDns,
        appendSystemDns: appendSystemDns,
        addedRules: addedRules,
        defaultUA: defaultUA,
      ),
    );
    if (!system.isMacOS ||
        (!integrated &&
            !document.policiesEnabled &&
            !document.budgetsEnabled)) {
      return res;
    }
    final raw = policyObject(
      normalizePolicyYaml(loadYaml(res.a)),
      'generatedConfig',
    );
    final compiled = await ref
        .read(workbenchControllerProvider)
        .profiles
        .compile(
          document: document,
          profiles: ref.read(profilesProvider),
          profileId: profileId,
          baseConfig: raw,
          persistCache: !preview,
          enforceCandidateReferences: preview,
        );
    final output = await encodeYamlTask(compiled.config);
    return VM2(output, await encodeMD5Task(output));
  }

  String _profileSignature(LocalPolicyDocument document) => policyDigest({
    'config': configJson(ref.read(configProvider)),
    'policies': document.toJson(),
    'profiles': ref
        .read(profilesProvider)
        .map((profile) => profile.toJson())
        .toList(),
  });

  Future<String> getProfileWithId(int profileId) async {
    try {
      final setupState = await ref.read(setupStateProvider(profileId).future);
      final patchClashConfig = ref.read(patchClashConfigProvider);
      final res = await getProfile(
        setupState: setupState,
        patchConfig: patchClashConfig,
      );
      return res.a;
    } catch (e) {
      globalState.showNotifier(e.toString());
    }
    return '';
  }

  bool _getEffectiveTunEnable(bool enableTun) {
    final authorizationState = ref.read(authorizedTunEnableProvider);
    return enableTun && authorizationState == TunAuthorizationState.authorized;
  }

  @protected
  Future<AuthorizeCode> authorizeCore() {
    return system.authorizeCore();
  }

  @visibleForTesting
  Future<bool> requestAdmin(bool enableTun) async {
    if (!enableTun) {
      return true;
    }
    final authorizationState = ref.read(authorizedTunEnableProvider);
    if (authorizationState != TunAuthorizationState.none) {
      return true;
    }

    final authorizationNotifier = ref.read(
      authorizedTunEnableProvider.notifier,
    );
    authorizationNotifier.value = TunAuthorizationState.unauthorized;

    final code = await authorizeCore();

    switch (code) {
      case AuthorizeCode.success:
        authorizationNotifier.value = TunAuthorizationState.authorized;
        return false;
      case AuthorizeCode.none:
        authorizationNotifier.value = TunAuthorizationState.authorized;
        return true;
      case AuthorizeCode.error:
        return true;
    }
  }

  Future<_SetupTaskResult> _setupConfig({
    bool requireTunAuthorization = false,
    bool force = false,
    bool silence = false,
    Future<void> Function()? preloadInvoke,
    FutureOr Function()? onUpdated,
  }) async {
    await configurationWriteBarrier.wait();
    var profile = ref.read(currentProfileProvider);
    final nextProfile = await profile?.checkAndUpdateAndCopy();
    if (nextProfile != null) {
      profile = nextProfile;
      ref.read(profilesProvider.notifier).put(nextProfile);
    }
    commonPrint.log('setup ===> ${profile?.realLabel}');
    final patchConfig = ref.read(patchClashConfigProvider);
    final shouldContinueSetup = await requestAdmin(patchConfig.tun.enable);
    if (!shouldContinueSetup) {
      return _SetupTaskResult.handoffToCoreRestart;
    }
    final effectiveTunEnable = _getEffectiveTunEnable(patchConfig.tun.enable);
    if (requireTunAuthorization &&
        patchConfig.tun.enable &&
        !effectiveTunEnable) {
      throw StateError('configuration_tun_authorization_failed');
    }
    final realPatchConfig = patchConfig.copyWith.tun(
      enable: effectiveTunEnable,
    );
    final setupState = await ref.read(setupStateProvider(profile?.id).future);
    final document = system.isMacOS
        ? await ref.read(workbenchDatabaseProvider).readPolicies()
        : const LocalPolicyDocument();
    final initialSignature = system.isMacOS
        ? policyDigest(
            await ref.read(workbenchControllerProvider).backend.readState(),
          )
        : null;
    final String? approved = _approvedProfileYaml;
    final VM2<String, String> vm2;
    if (approved != null) {
      if (_approvedProfileSignature != _profileSignature(document)) {
        throw StateError('configuration_version_conflict');
      }
      if (patchConfig.tun.enable && !effectiveTunEnable) {
        throw StateError('configuration_tun_authorization_failed');
      }
      vm2 = VM2(approved, await encodeMD5Task(approved));
    } else {
      vm2 = await getProfile(
        setupState: setupState,
        patchConfig: realPatchConfig,
        policyDocument: document,
      );
    }
    final yamlString = vm2.a;
    final yamlMd5 = vm2.b;
    if (yamlMd5 == globalState.lastConfigMd5 && force == false) {
      await _syncUsageProfile(profile);
      return _SetupTaskResult.completed;
    }
    if (system.isAndroid) {
      globalState.lastVpnState = ref.read(vpnStateProvider);
      final sharedState = ref.read(sharedStateProvider);
      await preferences.saveShareState(sharedState);
    }
    final applied = await globalState.loadingRun<bool>(
      () async {
        final configFilePath = await appPath.configFilePath;
        final configFile = File(configFilePath);
        final previous = await configFile.exists()
            ? await configFile.readAsString()
            : null;
        final output = await _activationYaml(
          yamlString,
          documentRevision: document.revision,
        );
        final validation = await coreController.validateConfigWithData(output);
        if (validation.isNotEmpty) throw validation;
        if (initialSignature != null &&
            initialSignature !=
                policyDigest(
                  await ref
                      .read(workbenchControllerProvider)
                      .backend
                      .readState(),
                )) {
          throw StateError('configuration_version_conflict');
        }
        final staging = File('$configFilePath.pending');
        await staging.writeAsString(output, flush: true);
        await staging.rename(configFilePath);
        final previousAliases = _selectionAliases;
        final previousGroups = _policyGroups;
        final previousIntegrated = _integratedSelection;
        _readSelectionAliases(output, document);
        try {
          final message = await coreController.setupConfig(
            params: _setupParams,
            preloadInvoke: preloadInvoke,
          );
          if (message.isNotEmpty && !message.endsWith('is empty')) {
            throw message;
          }
        } catch (_) {
          _selectionAliases = previousAliases;
          _policyGroups = previousGroups;
          _integratedSelection = previousIntegrated;
          if (previous != null) {
            await staging.writeAsString(
              await _activationYaml(previous),
              flush: true,
            );
            await staging.rename(configFilePath);
            final rollbackMessage = await coreController.setupConfig(
              params: _setupParams,
            );
            if (rollbackMessage.isNotEmpty &&
                !rollbackMessage.endsWith('is empty')) {
              commonPrint.log(
                'Configuration rollback failed',
                logLevel: LogLevel.error,
              );
            }
          } else if (await configFile.exists()) {
            await configFile.delete();
          }
          rethrow;
        } finally {
          if (await staging.exists()) await staging.delete();
        }
        await _syncUsageProfile(profile);
        globalState.lastConfigMd5 = yamlMd5;
        if (system.isMacOS) {
          await ref
              .read(workbenchControllerProvider)
              .backend
              .synchronizeActivatedState();
        }
        ref.read(checkIpNumProvider.notifier).add();
        await onUpdated?.call();
        return true;
      },
      silence: true,
      tag: !silence ? LoadingTag.proxies : null,
    );
    if (applied != true) {
      throw StateError('configuration_apply_failed');
    }
    return _SetupTaskResult.completed;
  }

  Future<String> _activationYaml(String value, {int? documentRevision}) async {
    if (!system.isMacOS || !value.contains('flclash-local-policy')) {
      return value;
    }
    final parsed = policyObject(
      normalizePolicyYaml(loadYaml(value)),
      'compiledConfig',
    );
    final local = policyObject(parsed['flclash-local-policy'], 'localPolicy');
    final status = await coreController.getLocalPolicyStatus();
    final lastRevision = status['revision'] is num
        ? (status['revision'] as num).toInt()
        : 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    local['documentRevision'] =
        documentRevision ?? local['documentRevision'] ?? local['revision'];
    local['revision'] = now > lastRevision ? now : lastRevision + 1;
    parsed['flclash-local-policy'] = local;
    return encodeYamlTask(parsed);
  }

  Future<void> _syncUsageProfile(Profile? profile) async {
    if (!ref.read(usagePlatformSupportedProvider)) {
      return;
    }
    try {
      await ref
          .read(usageRuntimeProvider.notifier)
          .syncProfile(
            profileId: profile?.id,
            profileLabel: profile?.label ?? '',
          );
    } catch (error) {
      commonPrint.log(
        'Failed to sync the applied usage profile: $error',
        logLevel: LogLevel.warning,
      );
    }
  }
}
