import 'package:fl_clash/capabilities/runtime_events.dart';
import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/configuration/barrier.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/providers/usage.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoreManager extends ConsumerStatefulWidget {
  final Widget child;
  final CoreController controller;

  CoreManager({super.key, required this.child, CoreController? controller})
    : controller = controller ?? coreController;

  @override
  ConsumerState<CoreManager> createState() => _CoreContainerState();
}

class _CoreContainerState extends ConsumerState<CoreManager>
    with CoreEventListener, WidgetsBindingObserver {
  UsageRuntime? _usageRuntime;

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    coreEventManager.addListener(this);
    final usageSupported = ref.read(usagePlatformSupportedProvider);
    if (usageSupported) {
      _usageRuntime = ref.read(usageRuntimeProvider.notifier);
      ref.read(usageRuntimeProvider);
    }
    ref.listenManual(currentProfileIdProvider, (prev, next) {
      if (prev != next && !configurationWriteBarrier.active) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(setupActionProvider.notifier).fullSetup();
        });
      }
    });
    if (usageSupported) {
      ref.listenManual(currentProfileProvider, (prev, next) {
        if (prev?.id == next?.id && prev?.label != next?.label) {
          ref.read(usageRuntimeProvider.notifier).syncCore();
        }
      });
      ref.listenManual(coreStatusProvider, (prev, next) {
        if (next == CoreStatus.connected && prev != next) {
          ref.read(usageRuntimeProvider.notifier).syncCore();
        }
      });
    }
    ref.listenManual(updateParamsProvider, (prev, next) {
      if (prev != next && !configurationWriteBarrier.active) {
        ref.read(setupActionProvider.notifier).updateConfigDebounce();
      }
    });
    ref.listenManual(appSettingProvider.select((state) => state.openLogs), (
      prev,
      next,
    ) {
      if (next) {
        widget.controller.startLog();
      } else {
        widget.controller.stopLog();
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    coreEventManager.removeListener(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final usageRuntime = _usageRuntime;
    if (usageRuntime == null) {
      return;
    }
    if (state == AppLifecycleState.resumed) {
      ref.read(usageClockProvider.notifier).refresh();
      unawaited(usageRuntime.syncLocalCalendar());
      return;
    }
    if ({
      AppLifecycleState.inactive,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
      AppLifecycleState.hidden,
    }.contains(state)) {
      unawaited(usageRuntime.flush());
    }
  }

  @override
  Future<void> onDelay(Delay delay) async {
    super.onDelay(delay);
    final proxiesAction = ref.read(proxiesActionProvider.notifier);
    proxiesAction.setDelay(delay);
    debouncer.call(FunctionTag.updateDelay, () async {
      proxiesAction.updateGroupsDebounce();
    }, duration: const Duration(milliseconds: 5000));
  }

  @override
  void onLog(Log log) {
    ref.read(logsProvider.notifier).add(log);
    if (log.logLevel == LogLevel.error) {
      globalState.showNotifier(log.payload);
    }
    super.onLog(log);
  }

  @override
  void onRequest(TrackerInfo trackerInfo) async {
    ref.read(requestsProvider.notifier).addRequest(trackerInfo);
    super.onRequest(trackerInfo);
  }

  @override
  Future<void> onLoaded(String providerName) async {
    final ref = globalState.container;
    ref
        .read(providersProvider.notifier)
        .setProvider(await widget.controller.getExternalProvider(providerName));
    debouncer.call(FunctionTag.loadedProvider, () async {
      ref.read(proxiesActionProvider.notifier).updateGroupsDebounce();
    }, duration: const Duration(milliseconds: 5000));
    super.onLoaded(providerName);
  }

  @override
  Future<void> onCrash(String message) async {
    if (ref.read(coreStatusProvider) != CoreStatus.connected) {
      return;
    }
    ref.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      context.showNotifier(message);
    }
    super.onCrash(message);
  }

  @override
  void onGeoUpdate(String geoType, bool updating, bool skipped, String? error) {
    capabilityRuntimeEvents.reportGeo(geoType, updating, skipped, error);
    final geoResource = GeoResource.fromJson(geoType.toLowerCase());
    final key = geoResource.updatingKey;
    final l10n = currentAppLocalizations;
    if (updating) {
      globalState.showNotifier(l10n.geoUpdating(geoResource.name));
    } else if (skipped) {
      globalState.showNotifier(l10n.geoSkipped(geoResource.name));
    } else {
      globalState.showNotifier(l10n.geoUpdated(geoResource.name));
    }
    ref.read(isUpdatingProvider(key).notifier).value = updating;
    if (!updating && error != null && error.isNotEmpty) {
      globalState.showNotifier(error);
    }
    super.onGeoUpdate(geoType, updating, skipped, error);
  }
}
