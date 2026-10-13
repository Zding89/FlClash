import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/configuration/barrier.dart';
import 'package:fl_clash/capabilities/runtime_events.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

class HotKeyManager extends ConsumerStatefulWidget {
  final Widget child;

  const HotKeyManager({super.key, required this.child});

  @override
  ConsumerState<HotKeyManager> createState() => _HotKeyManagerState();
}

class _HotKeyManagerState extends ConsumerState<HotKeyManager> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(hotKeyActionsProvider, (prev, next) {
      if (!configurationWriteBarrier.active &&
          !hotKeyActionListEquality.equals(prev, next)) {
        applyHotKeyActions(next);
      }
    }, fireImmediately: true);
  }

  Shortcuts _buildCloseShortcuts(Widget child) {
    return Shortcuts(
      shortcuts: {
        utils.controlSingleActivator(LogicalKeyboardKey.keyW):
            const CloseWindowIntent(),
        const SingleActivator(LogicalKeyboardKey.escape):
            const EscapeBackIntent(),
      },
      child: Actions(
        actions: {
          CloseWindowIntent: CallbackAction<CloseWindowIntent>(
            onInvoke: (_) => globalState.container
                .read(systemActionProvider.notifier)
                .handleClose(false),
          ),
          EscapeBackIntent: CallbackAction<EscapeBackIntent>(
            onInvoke: (_) => globalState.navigatorKey.currentState?.maybePop(),
          ),
          DoNothingIntent: CallbackAction<DoNothingIntent>(
            onInvoke: (_) => null,
          ),
        },
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildCloseShortcuts(widget.child);
  }
}

Future<void> _handleHotKeyAction(HotAction action) async {
  final ref = globalState.container;
  final commonAction = ref.read(commonActionProvider.notifier);
  final systemAction = ref.read(systemActionProvider.notifier);
  switch (action) {
    case HotAction.mode:
      commonAction.updateMode();
    case HotAction.start:
      commonAction.toggleRunning();
    case HotAction.view:
      systemAction.updateVisible();
    case HotAction.proxy:
      systemAction.updateSystemProxy();
    case HotAction.tun:
      systemAction.updateTun();
  }
}

Future<void> applyHotKeyActions(List<HotKeyAction> hotKeyActions) async {
  try {
    await hotKeyManager.unregisterAll();
  } catch (_) {
    capabilityRuntimeEvents.reportHotkeys(applied: false, count: null);
    rethrow;
  }
  final hotkeyActionHandles = hotKeyActions
      .where((hotKeyAction) {
        return hotKeyAction.key != null && hotKeyAction.modifiers.isNotEmpty;
      })
      .map<Future>((hotKeyAction) async {
        final modifiers = hotKeyAction.modifiers
            .map((item) => item.toHotKeyModifier())
            .toList();
        final hotKey = HotKey(
          key: PhysicalKeyboardKey(hotKeyAction.key!),
          modifiers: modifiers,
        );
        return hotKeyManager.register(
          hotKey,
          keyDownHandler: (_) {
            _handleHotKeyAction(hotKeyAction.action);
          },
        );
      });
  try {
    await Future.wait(hotkeyActionHandles);
    capabilityRuntimeEvents.reportHotkeys(
      applied: true,
      count: hotKeyActions
          .where((action) => action.key != null && action.modifiers.isNotEmpty)
          .length,
    );
  } catch (_) {
    capabilityRuntimeEvents.reportHotkeys(applied: false, count: null);
    rethrow;
  }
}
