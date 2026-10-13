import 'package:fl_clash/providers/control.dart';
import 'package:fl_clash/views/control/settings.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/usage.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CloseConnectionsItem extends ConsumerWidget {
  const CloseConnectionsItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final closeConnections = ref.watch(
      appSettingProvider.select((state) => state.closeConnections),
    );
    return ListItem.toggle(
      title: Text(appLocalizations.autoCloseConnections),
      subtitle: Text(appLocalizations.autoCloseConnectionsDesc),
      value: closeConnections,
      onChanged: (value) async {
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(closeConnections: value));
      },
    );
  }
}

class UsageItem extends ConsumerWidget {
  const UsageItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final onlyStatisticsProxy = ref.watch(
      appSettingProvider.select((state) => state.onlyStatisticsProxy),
    );
    return ListItem.toggle(
      title: Text(appLocalizations.onlyStatisticsProxy),
      subtitle: Text(appLocalizations.onlyStatisticsProxyDesc),
      value: onlyStatisticsProxy,
      onChanged: (bool value) async {
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(onlyStatisticsProxy: value));
      },
    );
  }
}

class UsageRecordingItem extends ConsumerWidget {
  const UsageRecordingItem({super.key});

  Future<bool> _confirmEnable(BuildContext context) async {
    final appLocalizations = context.appLocalizations;
    return await showDialog<bool>(
          context: context,
          builder: (context) => CommonDialog(
            title: appLocalizations.usagePrivacyTitle,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(appLocalizations.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(appLocalizations.enableUsageRecording),
              ),
            ],
            child: Text(appLocalizations.usagePrivacyDesc),
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final enabledState = ref.watch(usageEnabledProvider);
    final runtimeState = ref.watch(usageRuntimeProvider);
    final issues = ref.watch(usageIssuesProvider);
    final hasDegradedData =
        ref.watch(usageHasAnyDegradedDataProvider).value ?? false;
    final enabled = enabledState.value ?? false;
    final loading = enabledState.isLoading || runtimeState.isLoading;
    final subtitle = issues.contains(UsageIssue.persistence)
        ? appLocalizations.usagePersistenceIssue
        : hasDegradedData
        ? appLocalizations.usageDegradedIssue
        : appLocalizations.usageRecordingDesc;
    return ListItem.toggle(
      title: Text(appLocalizations.usageRecording),
      subtitle: Text(subtitle),
      value: enabled,
      onChanged: loading
          ? null
          : (value) async {
              if (value) {
                final hasConsent = await ref
                    .read(usageStoreProvider)
                    .hasConsent();
                if (!context.mounted) {
                  return;
                }
                if (!hasConsent && !await _confirmEnable(context)) {
                  return;
                }
              }
              if (!context.mounted) {
                return;
              }
              try {
                await ref.read(usageRuntimeProvider.notifier).setEnabled(value);
              } catch (error) {
                if (context.mounted) {
                  context.showNotifier(error.toString());
                }
              }
            },
    );
  }
}

class ClearUsageDataItem extends ConsumerWidget {
  const ClearUsageDataItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final loading = ref.watch(usageRuntimeProvider).isLoading;
    return ListItem(
      leading: const Icon(Icons.delete_outline),
      title: Text(appLocalizations.clearUsageData),
      subtitle: Text(appLocalizations.clearUsageDataDesc),
      trailing: TextButton(
        onPressed: loading
            ? null
            : () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => CommonDialog(
                    title: appLocalizations.clearUsageData,
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(appLocalizations.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(appLocalizations.confirm),
                      ),
                    ],
                    child: Text(appLocalizations.clearUsageDataConfirm),
                  ),
                );
                if (confirmed == true) {
                  try {
                    await ref.read(usageRuntimeProvider.notifier).clear();
                  } catch (error) {
                    if (context.mounted) {
                      context.showNotifier(error.toString());
                    }
                  }
                }
              },
        child: Text(appLocalizations.clearUsageData),
      ),
    );
  }
}

class MinimizeItem extends ConsumerWidget {
  const MinimizeItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final minimizeOnExit = ref.watch(
      appSettingProvider.select((state) => state.minimizeOnExit),
    );
    return ListItem.toggle(
      title: Text(appLocalizations.minimizeOnExit),
      subtitle: Text(appLocalizations.minimizeOnExitDesc),
      value: minimizeOnExit,
      onChanged: (bool value) {
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(minimizeOnExit: value));
      },
    );
  }
}

class AutoLaunchItem extends ConsumerWidget {
  const AutoLaunchItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final autoLaunch = ref.watch(
      appSettingProvider.select((state) => state.autoLaunch),
    );
    return ListItem.toggle(
      title: Text(appLocalizations.autoLaunch),
      subtitle: Text(appLocalizations.autoLaunchDesc),
      value: autoLaunch,
      onChanged: (bool value) {
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(autoLaunch: value));
      },
    );
  }
}

class SilentLaunchItem extends ConsumerWidget {
  const SilentLaunchItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final silentLaunch = ref.watch(
      appSettingProvider.select((state) => state.silentLaunch),
    );
    return ListItem.toggle(
      title: Text(appLocalizations.silentLaunch),
      subtitle: Text(appLocalizations.silentLaunchDesc),
      value: silentLaunch,
      onChanged: (bool value) {
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(silentLaunch: value));
      },
    );
  }
}

class AutoRunItem extends ConsumerWidget {
  const AutoRunItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final autoRun = ref.watch(
      appSettingProvider.select((state) => state.autoRun),
    );
    return ListItem.toggle(
      title: Text(appLocalizations.autoRun),
      subtitle: Text(appLocalizations.autoRunDesc),
      value: autoRun,
      onChanged: (bool value) {
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(autoRun: value));
      },
    );
  }
}

class HiddenItem extends ConsumerWidget {
  const HiddenItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final hidden = ref.watch(
      appSettingProvider.select((state) => state.hidden),
    );
    return ListItem.toggle(
      title: Text(appLocalizations.exclude),
      subtitle: Text(appLocalizations.excludeDesc),
      value: hidden,
      onChanged: (value) {
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(hidden: value));
      },
    );
  }
}

class AnimateTabItem extends ConsumerWidget {
  const AnimateTabItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final isAnimateToPage = ref.watch(
      appSettingProvider.select((state) => state.isAnimateToPage),
    );
    return ListItem.toggle(
      title: Text(appLocalizations.tabAnimation),
      subtitle: Text(appLocalizations.tabAnimationDesc),
      value: isAnimateToPage,
      onChanged: (value) {
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(isAnimateToPage: value));
      },
    );
  }
}

class OpenLogsItem extends ConsumerWidget {
  const OpenLogsItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final openLogs = ref.watch(
      appSettingProvider.select((state) => state.openLogs),
    );
    return ListItem.toggle(
      title: Text(appLocalizations.logcat),
      subtitle: Text(appLocalizations.logcatDesc),
      value: openLogs,
      onChanged: (bool value) {
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(openLogs: value));
      },
    );
  }
}

class CrashlyticsItem extends ConsumerWidget {
  const CrashlyticsItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final crashlytics = ref.watch(
      appSettingProvider.select((state) => state.crashlytics),
    );
    return ListItem.toggle(
      title: Text(appLocalizations.crashlytics),
      subtitle: Text(appLocalizations.crashlyticsTip),
      value: crashlytics,
      onChanged: (bool value) {
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(crashlytics: value));
      },
    );
  }
}

class AutoCheckUpdateItem extends ConsumerWidget {
  const AutoCheckUpdateItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final autoCheckUpdate = ref.watch(
      appSettingProvider.select((state) => state.autoCheckUpdate),
    );
    return ListItem.toggle(
      title: Text(appLocalizations.autoCheckUpdate),
      subtitle: Text(appLocalizations.autoCheckUpdateDesc),
      value: autoCheckUpdate,
      onChanged: (bool value) {
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(autoCheckUpdate: value));
      },
    );
  }
}

class ApplicationSettingView extends ConsumerWidget {
  const ApplicationSettingView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Widget> items = [
      const MinimizeItem(),
      if (system.isDesktop) ...[
        const AutoLaunchItem(),
        const SilentLaunchItem(),
      ],
      const AutoRunItem(),
      if (system.isAndroid) ...[const HiddenItem()],
      const AnimateTabItem(),
      const OpenLogsItem(),
      const CloseConnectionsItem(),
      const UsageItem(),
      if (system.isMacOS) ...[
        const UsageRecordingItem(),
        const ClearUsageDataItem(),
      ],
      if (system.isAndroid) const CrashlyticsItem(),
      const AutoCheckUpdateItem(),
      if (system.isMacOS)
        ListTile(
          leading: const Icon(Icons.terminal_outlined),
          title: Text(context.appLocalizations.localControlTitle),
          subtitle: Text(context.appLocalizations.localControlDescription),
          onTap: () => showExtend(
            context,
            builder: (_) => AdaptiveSheetScaffold(
              title: context.appLocalizations.localControlTitle,
              body: LocalControlSettings(
                service: ref.read(localControlServiceProvider),
              ),
            ),
          ),
        ),
    ];
    return BaseScaffold(
      title: context.appLocalizations.application,
      body: ListView.separated(
        itemBuilder: (_, index) {
          final item = items[index];
          return item;
        },
        separatorBuilder: (_, _) {
          return const Divider(height: 0);
        },
        itemCount: items.length,
      ),
    );
  }
}
