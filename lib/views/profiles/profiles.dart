import 'package:fl_clash/views/policy/policy.dart';
import 'package:fl_clash/views/ai/approval.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/profiles/overwrite/overwrite.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'add.dart';
import 'edit.dart';
import 'preview.dart';

class ProfilesView extends StatefulWidget {
  const ProfilesView({super.key});

  @override
  State<ProfilesView> createState() => _ProfilesViewState();
}

class _ProfilesViewState extends State<ProfilesView> {
  Function? applyConfigDebounce;
  bool _isUpdating = false;
  bool _selecting = false;
  int _selectionEpoch = 0;

  // final GlobalKey _targetKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   final context = _targetKey.currentContext;
    //   if (context == null) {
    //     return;
    //   }
    //   Scrollable.ensureVisible(
    //     context,
    //     duration: commonDuration,
    //     alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    //   );
    // });
  }

  void _handleShowAddExtendPage() {
    showExtend(
      globalState.navigatorKey.currentState!.context,
      builder: (_) {
        return AdaptiveSheetScaffold(
          body: AddProfileView(
            context: globalState.navigatorKey.currentState!.context,
          ),
          title: context.appLocalizations.addProfile,
        );
      },
    );
  }

  Future<void> _updateProfiles(List<Profile> profiles) async {
    if (_isUpdating == true) {
      return;
    }
    _isUpdating = true;
    final List<UpdatingMessage> messages = [];
    final updateProfiles = profiles.map<Future>((profile) async {
      if (profile.type == ProfileType.file) return;
      try {
        await globalState.container
            .read(profilesActionProvider.notifier)
            .updateProfile(profile, showLoading: true);
      } catch (e) {
        messages.add(
          UpdatingMessage(label: profile.realLabel, message: e.toString()),
        );
      }
    });
    await Future.wait(updateProfiles);
    if (messages.isNotEmpty) {
      globalState.showAllUpdatingMessagesDialog(messages);
    }
    _isUpdating = false;
  }

  Future<void> _select(
    WidgetRef ref, {
    int? profileId,
    String? integrationId,
    bool? moduleEnabled,
  }) async {
    final epoch = ++_selectionEpoch;
    setState(() => _selecting = true);
    try {
      await ref
          .read(workbenchControllerProvider)
          .selectPolicyTarget(
            profileId: profileId,
            integrationId: integrationId,
            moduleEnabled: moduleEnabled,
            approve: (proposal) => mounted
                ? showAiConfigurationApproval(context, proposal)
                : Future.value(false),
          );
    } catch (_) {
      if (mounted && epoch == _selectionEpoch) {
        globalState.showNotifier(
          context.appLocalizations.policyOperationFailed,
        );
      }
    } finally {
      if (mounted && epoch == _selectionEpoch) {
        setState(() => _selecting = false);
      }
    }
  }

  void _editCollection() =>
      showExtend(context, builder: (_) => const LocalPolicyWorkbenchView());

  List<Widget> _buildActions(List<Profile> profiles, bool desktop) => [
    if (profiles.isNotEmpty) ...[
      if (desktop)
        OutlinedButton.icon(
          onPressed: () => _updateProfiles(profiles),
          icon: const Icon(Icons.sync),
          label: Text(context.appLocalizations.profilesUpdateAll),
        )
      else
        IconButton(
          onPressed: () => _updateProfiles(profiles),
          tooltip: context.appLocalizations.profilesUpdateAll,
          icon: const Icon(Icons.sync),
        ),
      IconButton(
        onPressed: () => showSheet(
          context: context,
          builder: (_) => ReorderableProfilesSheet(profiles: profiles),
        ),
        tooltip: context.appLocalizations.profilesSort,
        icon: const Icon(Icons.sort),
        iconSize: 26,
      ),
    ],
    if (desktop)
      Padding(
        padding: const EdgeInsets.only(right: 16),
        child: FilledButton.icon(
          onPressed: _handleShowAddExtendPage,
          icon: const Icon(Icons.add),
          label: Text(context.appLocalizations.addProfile),
        ),
      ),
  ];

  Widget _buildFAB() {
    return CommonFloatingActionButton(
      onPressed: _handleShowAddExtendPage,
      icon: const Icon(Icons.add),
      label: context.appLocalizations.addProfile,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (_, ref, _) {
        final appLocalizations = context.appLocalizations;
        final isLoading = ref.watch(loadingProvider(LoadingTag.profiles));
        final state = ref.watch(profilesStateProvider);

        final document = system.isMacOS
            ? ref.watch(localPoliciesProvider).value
            : null;
        final runtime = system.isMacOS
            ? ref.watch(localPolicyStatusProvider).value
            : null;
        final integrated =
            document?.moduleEnabled == true &&
            document?.integrationEnabled == true;
        final collectionInUse =
            runtime?['targetId'] == document?.activeIntegration?.targetId &&
            runtime?['documentRevision'] == document?.revision;
        final desktop = MediaQuery.sizeOf(context).width >= 800;
        return CommonScaffold(
          isLoading: isLoading,
          title: appLocalizations.profiles,
          floatingActionButton: desktop ? null : _buildFAB(),
          actions: _buildActions(state.profiles, desktop),
          body: LayoutBuilder(
            builder: (_, constraints) {
              final wide = constraints.maxWidth >= 800;
              const horizontalPadding = 16.0;
              return Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  key: profilesStoreKey,
                  padding: const EdgeInsets.only(
                    left: horizontalPadding,
                    right: horizontalPadding,
                    top: 16,
                    bottom: 88,
                  ),
                  child: Grid(
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    crossAxisCount: 1,
                    children: [
                      if (document != null && document.moduleEnabled)
                        GridItem(
                          child: CommonCard(
                            key: const ValueKey('profiles-local-collection'),
                            isSelected: integrated,
                            onPressed: () {
                              if (document.activeIntegration == null) {
                                _editCollection();
                              } else {
                                _select(
                                  ref,
                                  integrationId: document.activeIntegrationId,
                                );
                              }
                            },
                            child: ListItem(
                              minVerticalPadding: 20,
                              horizontalTitleGap: wide ? 24 : 12,
                              leading: _ProfileSelectionLeading(
                                selected: integrated,
                                icon: Icons.layers_outlined,
                                desktop: wide,
                                onSelect: () {
                                  if (document.activeIntegration == null) {
                                    _editCollection();
                                  } else {
                                    _select(
                                      ref,
                                      integrationId:
                                          document.activeIntegrationId,
                                    );
                                  }
                                },
                              ),
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    appLocalizations.policyLocalCollection,
                                    style: context.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  if (document.activeIntegration == null)
                                    Text(
                                      appLocalizations.policyCollectionPending,
                                    )
                                  else ...[
                                    Text(
                                      document.activeIntegration!.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        Chip(
                                          label: Text(
                                            appLocalizations
                                                .profilesSourceCount(
                                                  document
                                                      .activeIntegration!
                                                      .sourceProfileIds
                                                      .length,
                                                ),
                                          ),
                                        ),
                                        Chip(
                                          label: Text(
                                            appLocalizations.profilesRuleCount(
                                              document.policies
                                                  .where(
                                                    (p) =>
                                                        p.targetId ==
                                                        document
                                                            .activeIntegration!
                                                            .targetId,
                                                  )
                                                  .length,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    integrated
                                        ? collectionInUse
                                              ? appLocalizations
                                                    .policyAppliedStatus
                                              : appLocalizations
                                                    .policySelectedOffline
                                        : appLocalizations
                                              .policySelectCollection,
                                    style:
                                        context.textTheme.labelMedium?.toLight,
                                  ),
                                ],
                              ),
                              trailing: wide
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: _editCollection,
                                          icon: const Icon(Icons.edit_outlined),
                                          label: Text(appLocalizations.edit),
                                        ),
                                        const SizedBox(width: 8),
                                        CommonPopupBox(
                                          popup: CommonPopupMenu(
                                            items: [
                                              PopupMenuItemData(
                                                icon: Icons.edit_outlined,
                                                label: appLocalizations.edit,
                                                onPressed: _editCollection,
                                              ),
                                            ],
                                          ),
                                          targetBuilder: (open) => IconButton(
                                            onPressed: open,
                                            tooltip: appLocalizations.more,
                                            icon: const Icon(Icons.more_vert),
                                          ),
                                        ),
                                      ],
                                    )
                                  : IconButton(
                                      onPressed: _editCollection,
                                      tooltip: appLocalizations.edit,
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                            ),
                          ),
                        ),
                      if (_selecting)
                        const GridItem(child: LinearProgressIndicator()),
                      for (int i = 0; i < state.profiles.length; i++)
                        GridItem(
                          child: ProfileItem(
                            profile: state.profiles[i],
                            groupValue: integrated
                                ? null
                                : state.currentProfileId,
                            onChanged: (profileId) {
                              if (system.isMacOS) {
                                _select(ref, profileId: profileId);
                              } else {
                                ref
                                        .read(currentProfileIdProvider.notifier)
                                        .value =
                                    profileId;
                              }
                            },
                          ),
                        ),
                      if (system.isMacOS)
                        GridItem(
                          child: Card(
                            key: const ValueKey('profiles-module-card'),
                            child: SwitchListTile(
                              secondary: const Icon(Icons.rule_outlined),
                              title: Text(appLocalizations.policyModule),
                              subtitle: Text(
                                appLocalizations.policyModuleOffHint,
                              ),
                              value: document?.moduleEnabled ?? false,
                              onChanged: document == null
                                  ? null
                                  : (value) =>
                                        _select(ref, moduleEnabled: value),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class ProfileItem extends StatelessWidget {
  final Profile profile;
  final int? groupValue;
  final void Function(int? value) onChanged;

  const ProfileItem({
    super.key,
    required this.profile,
    required this.groupValue,
    required this.onChanged,
  });

  Future<void> _handleDeleteProfile(BuildContext context) async {
    final appLocalizations = context.appLocalizations;
    final res = await globalState.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(
        text: appLocalizations.deleteTip(appLocalizations.profile),
      ),
    );
    if (res != true) {
      return;
    }
    await globalState.container
        .read(profilesActionProvider.notifier)
        .deleteProfile(profile.id);
  }

  Future<void> _handlePreview(BuildContext context) async {
    BaseNavigator.push<String>(context, PreviewProfileView(profile: profile));
  }

  Future updateProfile() async {
    if (profile.type == ProfileType.file) return;
    await globalState.loadingRun(() async {
      await globalState.container
          .read(profilesActionProvider.notifier)
          .updateProfile(profile, showLoading: true);
    }, tag: LoadingTag.profiles);
  }

  void _handleShowEditExtendPage(BuildContext context) {
    showExtend(
      context,
      builder: (_) {
        return AdaptiveSheetScaffold(
          body: EditProfileView(profile: profile, context: context),
          title: context.appLocalizations.edit,
        );
      },
    );
  }

  List<Widget> _buildUrlProfileInfo(BuildContext context) {
    final subscriptionInfo = profile.subscriptionInfo;
    return [
      const SizedBox(height: 8),
      if (subscriptionInfo != null)
        SubscriptionInfoView(
          subscriptionInfo: subscriptionInfo,
          updatedAt: profile.lastUpdateDate,
        ),
      LastUpdateTimeText(
        lastUpdateDate: profile.lastUpdateDate,
        style: context.textTheme.labelMedium?.toLighter,
      ),
    ];
  }

  List<Widget> _buildFileProfileInfo(BuildContext context) {
    return [
      const SizedBox(height: 8),
      LastUpdateTimeText(
        lastUpdateDate: profile.lastUpdateDate,
        style: context.textTheme.labelMedium?.toLight,
      ),
    ];
  }

  Future<void> _handleCopyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: profile.url));
    if (context.mounted) {
      context.showNotifier(context.appLocalizations.copySuccess);
    }
  }

  Future<void> _handleExportFile(BuildContext context) async {
    final appLocalizations = context.appLocalizations;
    final res = await globalState.safeRun<bool>(() async {
      final mFile = await profile.file;
      final value = await picker.saveFile(
        profile.realLabel,
        mFile.readAsBytesSync(),
      );
      if (value == null) return false;
      return true;
    }, title: appLocalizations.tip);
    if (res == true && context.mounted) {
      context.showNotifier(appLocalizations.exportSuccess);
    }
  }

  void _handlePushGenProfilePage(BuildContext context, int id) {
    BaseNavigator.push(context, OverwriteView(profileId: id));
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 800;
        return CommonCard(
          key: ValueKey('profile-card-${profile.id}'),
          enterActionsOnRight: true,
          isSelected: profile.id == groupValue,
          onPressed: () {
            onChanged(profile.id);
          },
          child: ListItem(
            key: Key(profile.id.toString()),
            horizontalTitleGap: desktop ? 24 : 12,
            minVerticalPadding: 20,
            leading: _ProfileSelectionLeading(
              selected: profile.id == groupValue,
              icon: profile.type == ProfileType.url
                  ? Icons.cloud_outlined
                  : Icons.description_outlined,
              desktop: desktop,
              onSelect: () => onChanged(profile.id),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (desktop) ...[
                  if (profile.type == ProfileType.url)
                    Consumer(
                      builder: (_, ref, _) {
                        final updating = ref.watch(
                          isUpdatingProvider(profile.updatingKey),
                        );
                        return OutlinedButton.icon(
                          key: ValueKey('profile-update-${profile.id}'),
                          onPressed: updating ? null : updateProfile,
                          icon: updating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CommonCircleLoading(),
                                )
                              : const Icon(Icons.sync),
                          label: Text(
                            appLocalizations.profilesUpdateSubscription,
                          ),
                        );
                      },
                    ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    key: ValueKey('profile-edit-${profile.id}'),
                    onPressed: () => _handleShowEditExtendPage(context),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(appLocalizations.edit),
                  ),
                  const SizedBox(width: 8),
                ],
                SizedBox(
                  height: 40,
                  width: 40,
                  child: Consumer(
                    builder: (_, ref, _) {
                      final isUpdating = ref.watch(
                        isUpdatingProvider(profile.updatingKey),
                      );
                      return FadeThroughBox(
                        child: isUpdating
                            ? const Padding(
                                key: ValueKey('loading'),
                                padding: EdgeInsets.all(8),
                                child: CommonCircleLoading(),
                              )
                            : CommonPopupBox(
                                key: const ValueKey('menu'),
                                popup: CommonPopupMenu(
                                  items: [
                                    PopupMenuItemData(
                                      icon: Icons.edit_outlined,
                                      label: appLocalizations.edit,
                                      onPressed: () {
                                        _handleShowEditExtendPage(context);
                                      },
                                    ),
                                    PopupMenuItemData(
                                      icon: Icons.visibility_outlined,
                                      label: appLocalizations.preview,
                                      onPressed: () {
                                        _handlePreview(context);
                                      },
                                    ),
                                    if (profile.type == ProfileType.url) ...[
                                      PopupMenuItemData(
                                        icon: Icons.sync_alt_sharp,
                                        label: appLocalizations.sync,
                                        onPressed: () {
                                          updateProfile();
                                        },
                                      ),
                                    ],
                                    PopupMenuItemData(
                                      icon: Icons.emergency_outlined,
                                      label: appLocalizations.more,
                                      subItems: [
                                        PopupMenuItemData(
                                          icon: Icons.extension_outlined,
                                          label: appLocalizations.override,
                                          onPressed: () {
                                            _handlePushGenProfilePage(
                                              context,
                                              profile.id,
                                            );
                                          },
                                        ),
                                        if (profile.type ==
                                            ProfileType.url) ...[
                                          PopupMenuItemData(
                                            icon: Icons.copy,
                                            label: appLocalizations.copyLink,
                                            onPressed: () {
                                              _handleCopyLink(context);
                                            },
                                          ),
                                        ],
                                        PopupMenuItemData(
                                          icon: Icons.file_copy_outlined,
                                          label: appLocalizations.exportFile,
                                          onPressed: () {
                                            _handleExportFile(context);
                                          },
                                        ),
                                      ],
                                    ),
                                    PopupMenuItemData(
                                      danger: true,
                                      icon: Icons.delete_outlined,
                                      label: appLocalizations.delete,
                                      onPressed: () {
                                        _handleDeleteProfile(context);
                                      },
                                    ),
                                  ],
                                ),
                                targetBuilder: (open) {
                                  return IconButton(
                                    onPressed: () {
                                      open();
                                    },
                                    icon: const Icon(Icons.more_vert),
                                  );
                                },
                              ),
                      );
                    },
                  ),
                ),
              ],
            ),
            title: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      profile.realLabel,
                      style: context.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ...switch (profile.type) {
                          ProfileType.file => _buildFileProfileInfo(context),
                          ProfileType.url => _buildUrlProfileInfo(context),
                        },
                      ],
                    ),
                  ],
                ),
              ),
            ),
            tileTitleAlignment: ListTileTitleAlignment.titleHeight,
          ),
        );
      },
    );
  }
}

class _ProfileSelectionLeading extends StatelessWidget {
  const _ProfileSelectionLeading({
    required this.selected,
    required this.icon,
    required this.desktop,
    required this.onSelect,
  });
  final bool selected;
  final IconData icon;
  final bool desktop;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ExcludeFocus(
        child: RadioGroup<bool>(
          groupValue: selected,
          onChanged: (_) => onSelect(),
          child: const Radio<bool>(value: true),
        ),
      ),
      if (desktop) ...[
        const SizedBox(width: 12),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: context.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            size: 30,
            color: context.colorScheme.onPrimaryContainer,
          ),
        ),
      ],
    ],
  );
}

class LastUpdateTimeText extends StatelessWidget {
  final DateTime? lastUpdateDate;
  final TextStyle? style;

  const LastUpdateTimeText({
    super.key,
    required this.lastUpdateDate,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (lastUpdateDate == null) {
      return Text('', style: style);
    }
    return TickBuilder(
      duration: const Duration(minutes: 1),
      builder: (context, _) {
        return Text(
          lastUpdateDate!.getLastUpdateTimeDesc(context),
          style: style,
        );
      },
    );
  }
}

class ReorderableProfilesSheet extends StatefulWidget {
  final List<Profile> profiles;

  const ReorderableProfilesSheet({super.key, required this.profiles});

  @override
  State<ReorderableProfilesSheet> createState() =>
      _ReorderableProfilesSheetState();
}

class _ReorderableProfilesSheetState extends State<ReorderableProfilesSheet> {
  late List<Profile> profiles;

  @override
  void initState() {
    super.initState();
    profiles = List.from(widget.profiles);
  }

  Widget _buildItem(int index) {
    final position = ItemPosition.get(index, profiles.length);
    final profile = profiles[index];
    return ItemPositionProvider(
      key: Key(profile.id.toString()),
      position: position,
      child: DecorationListItem(
        trailing: ReorderableDelayedDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle),
        ),
        title: Text(profile.realLabel),
      ),
    );
  }

  void _handleSave() {
    Navigator.of(context).pop();
    globalState.container.read(profilesProvider.notifier).reorder(profiles);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return AdaptiveSheetScaffold(
      sheetTransparentToolBar: true,
      actions: [IconButtonData(icon: Icons.check, onPressed: _handleSave)],
      body: Padding(
        padding: const EdgeInsets.only(bottom: 32),
        child: ReorderableListView.builder(
          buildDefaultDragHandles: false,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
          ).copyWith(top: context.sheetTopPadding),
          proxyDecorator: (child, index, animation) {
            return commonProxyDecorator(_buildItem(index), index, animation);
          },
          onReorderItem: (oldIndex, newIndex) {
            setState(() {
              profiles = profiles.copyAndReorder(oldIndex, newIndex);
            });
          },
          itemBuilder: (_, index) {
            return _buildItem(index);
          },
          itemCount: profiles.length,
        ),
      ),
      title: appLocalizations.profilesSort,
    );
  }
}
