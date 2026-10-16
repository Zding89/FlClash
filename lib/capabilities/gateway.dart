import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:fl_clash/ai/settings.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/dav_client.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/configuration/resources.dart';
import 'package:fl_clash/configuration/settings.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/ai/settings.dart';
import 'package:fl_clash/views/ai/approval.dart';
import 'package:fl_clash/views/backup_and_restore.dart';
import 'package:fl_clash/views/control/settings.dart';
import 'package:fl_clash/providers/control.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as paths;

import 'runtime_events.dart';
import 'file_access.dart';

Future<String?> selectLocalOutputPath(String filename) =>
    const MethodChannel(
      'miguelruivo.flutter.plugins.filepicker',
    ).invokeMethod<String>('saveFile', {
      'fileName': filename,
      'dialogTitle': currentAppLocalizations.save,
      'allowedExtensions': <String>[],
    });

abstract interface class ApplicationCapabilityGateway {
  bool get supported;
  Future<String> version();
  Future<Map<String, Object?>> execute(
    String command,
    Map<String, Object?> params, {
    required String origin,
    Future<bool> Function()? beginMutation,
    bool Function()? isCurrent,
  });
}

abstract interface class ApplicationCompletionGateway {
  Future<ConfigurationActivationBasis?> captureActivationBasis();
  Future<ConfigurationCompletionReceipt> readActivationBasis(
    ConfigurationActivationBasis basis,
  );
}

abstract interface class ApplicationReviewGateway {
  Future<Map<String, Object?>> reviewState(
    String command,
    Map<String, Object?> params,
  );
}

class _FileGrant {
  const _FileGrant(this.path, this.mode, this.expiresAt);
  final String path;
  final String mode;
  final DateTime expiresAt;
}

class FlutterApplicationCapabilityGateway
    implements
        ApplicationCapabilityGateway,
        ApplicationCompletionGateway,
        ApplicationReviewGateway {
  FlutterApplicationCapabilityGateway({
    required this.ref,
    required this.controller,
    CoreController? core,
    this.approveScript,
  }) : core = core ?? coreController;
  final Ref ref;
  final WorkbenchController controller;
  final CoreController core;
  final ConfigurationApproval? approveScript;
  final Map<String, _FileGrant> _files = {};

  @override
  bool get supported => system.isMacOS;

  @override
  Future<String> version() async =>
      configurationDigest(await controller.backend.readState());

  @override
  Future<ConfigurationActivationBasis?> captureActivationBasis() =>
      controller.backend.captureActivationBasis();

  @override
  Future<ConfigurationCompletionReceipt> readActivationBasis(
    ConfigurationActivationBasis basis,
  ) => controller.backend.readActivationBasis(basis);

  @override
  Future<Map<String, Object?>> reviewState(
    String command,
    Map<String, Object?> params,
  ) async {
    final before = <String, Object?>{};
    final after = Map<String, Object?>.from(redactResource(params));
    final labels = <String, String>{};
    switch (command) {
      case 'connection_set':
        before['running'] = ref.read(isStartProvider);
      case 'core_restart':
        before['running'] = ref.read(isStartProvider);
      case 'proxy_select':
        final group = (await _groups())
            .where((group) => group.name == params['group'])
            .firstOrNull;
        if (group == null ||
            group.type != GroupType.Selector ||
            !group.all.any((node) => node.name == params['node'])) {
          throw const ConfigurationChangeException('proxy_selection_invalid');
        }
        before.addAll({'group': group.name, 'node': group.now});
      case 'profile_select':
        final selected = ref.read(currentProfileProvider);
        final profiles = ref.read(profilesProvider);
        if (params.containsKey('profileId')) {
          before['profileId'] = selected?.id.toString();
          final target = profiles
              .where((profile) => '${profile.id}' == '${params['profileId']}')
              .firstOrNull;
          if (selected != null) {
            labels['before.profileId'] = selected.realLabel;
          }
          if (target != null) {
            labels['profileId'] = target.realLabel;
            labels['after.profileId'] = target.realLabel;
          }
        }
        if (params.containsKey('integrationId') ||
            params.containsKey('moduleEnabled')) {
          final document = await controller.readPolicies();
          if (params.containsKey('moduleEnabled')) {
            before['moduleEnabled'] = document.moduleEnabled;
          }
          if (params.containsKey('integrationId')) {
            before['integrationId'] = document.activeIntegrationId;
            for (final integration in document.integrations) {
              if (integration.id == document.activeIntegrationId) {
                labels['before.integrationId'] = integration.label;
              }
              if (integration.id == params['integrationId']) {
                labels['integrationId'] = integration.label;
                labels['after.integrationId'] = integration.label;
              }
            }
          }
        }
      case 'policy_nodes_check':
      case 'policy_nodes_cancel':
        var nodeSetId = params['nodeSetId'];
        if (command == 'policy_nodes_cancel') {
          final check = await core.checkLocalPolicyNodes({
            'revision': params['revision'],
            'operationId': params['operationId'],
          });
          nodeSetId = check['nodeSetId'];
        }
        final document = await controller.readPolicies();
        final group = document.nodeSets
            .where((group) => group.id == nodeSetId)
            .firstOrNull;
        if (group != null) {
          labels['nodeSetId'] = group.label;
          if (command == 'policy_nodes_cancel') {
            labels['operationId'] = group.label;
          }
        }
      case 'profile_propose':
        final profiles = ref.read(profilesProvider);
        final target = profiles
            .where((profile) => '${profile.id}' == '${params['profileId']}')
            .firstOrNull;
        if (target != null) {
          labels['profileId'] = target.realLabel;
          before['sourceVersion'] = policyDigest(target.toJson());
        }
        final patch = params['patch'];
        if (patch is Map) {
          after.remove('patch');
          after.addAll(redactResource(Map<String, Object?>.from(patch)));
        }
      case 'profiles_refresh_all':
        final sources = ref
            .read(profilesProvider)
            .where((profile) => profile.url.isNotEmpty)
            .toList();
        before['sourceVersion'] = policyDigest(
          sources.map((profile) => profile.toJson()).toList(),
        );
        after['profiles'] = sources
            .map((profile) => profile.realLabel)
            .toList();
      case 'operation_cancel':
        final row = await controller.store.readChange(
          '${params['operationId']}',
        );
        if (row != null) {
          labels['operationId'] = row.summary;
          before['operationStatus'] = row.status;
          after['operationStatus'] = 'cancelled';
        }
      case 'profiles_reorder':
        final profiles = ref.read(profilesProvider);
        before['ids'] = profiles.map((profile) => '${profile.id}').toList();
        for (final profile in profiles) {
          labels['profile.${profile.id}'] = profile.realLabel;
        }
      case 'usage_set_enabled':
        before['enabled'] = await ref.read(usageStoreProvider).isEnabled();
      case 'webdav_upload' || 'webdav_restore':
        final destination = ref.read(davSettingProvider);
        if (destination == null) {
          throw const ConfigurationChangeException('webdav_not_configured');
        }
        after['url'] = Uri.parse(destination.uri).origin;
      case 'app_show' || 'app_hide':
        after['visible'] = command == 'app_show';
      default:
        break;
    }
    if ({
      'profile_export',
      'profile_effective_export',
      'script_export',
      'script_patch',
    }.contains(command)) {
      final field = command == 'script_patch' ? 'scriptId' : 'id';
      final id = params[field];
      if (id != null) {
        if (command.startsWith('script')) {
          final scripts = await ref.read(scriptsProvider.future);
          final source = scripts
              .where((script) => '${script.id}' == '$id')
              .firstOrNull;
          if (source != null) labels[field] = source.label;
        } else {
          final source = ref
              .read(profilesProvider)
              .where((profile) => '${profile.id}' == '$id')
              .firstOrNull;
          if (source != null) labels[field] = source.realLabel;
        }
      }
    }
    final grant = _files[params['fileGrantId']];
    if (grant != null) labels['fileGrantId'] = paths.basename(grant.path);
    return {
      'command': command,
      'before': before,
      'after': after,
      'labels': labels,
    };
  }

  Future<List<Group>> _groups() => core.getProxiesGroups(
    sortType: ProxiesSortType.none,
    delayMap: ref.read(delayDataSourceProvider),
    selectedMap: ref.read(currentProfileProvider)?.selectedMap ?? {},
    defaultTestUrl: ref.read(appSettingProvider).testUrl,
  );

  static String _safeText(String text) {
    final bounded = text.length > 2000 ? text.substring(0, 2000) : text;
    return bounded
        .replaceAll(RegExp(r'https?://[^\s\x22\x27<>]+'), '[URL]')
        .replaceAll(RegExp(r'\bsk-[A-Za-z0-9_-]{8,}\b'), '[redacted]')
        .replaceAll(
          RegExp(
            r'(?:Bearer\s+|(?:password|api[-_]?key|token|secret|authorization)\s*[:=]\s*)\S+',
            caseSensitive: false,
          ),
          '[redacted]',
        );
  }

  List<Map<String, Object?>> _page(
    List<Map<String, Object?>> values,
    Map<String, Object?> params,
  ) => values
      .skip(policyInt(params, 'offset', fallback: 0))
      .take(policyInt(params, 'limit', fallback: 100, minimum: 1, maximum: 200))
      .toList();

  Future<File> _file(Map<String, Object?> params, String mode) async {
    final id = policyString(params, 'fileGrantId', maximum: 96);
    final grant = _files[id];
    if (grant == null ||
        grant.mode != mode ||
        DateTime.now().isAfter(grant.expiresAt)) {
      throw const ConfigurationChangeException('file_grant_expired');
    }
    await _validatePath(grant.path, mode);
    return File(grant.path);
  }

  Future<void> _validatePath(String path, String mode) async {
    if (!paths.isAbsolute(path) ||
        paths.normalize(path) != path ||
        path.contains('\u0000')) {
      throw const FormatException('Invalid absolute file path');
    }
    final parent = Directory(paths.dirname(path));
    if (!await parent.exists() ||
        paths.normalize(await parent.resolveSymbolicLinks()) != parent.path ||
        await FileSystemEntity.type(path, followLinks: false) ==
            FileSystemEntityType.link) {
      throw const ConfigurationChangeException('file_path_unsafe');
    }
    if (mode == 'read' &&
        (!await File(path).exists() ||
            await File(path).length() > 128 * 1024 * 1024)) {
      throw const ConfigurationChangeException('file_input_unavailable');
    }
    if (mode == 'write' && await File(path).exists()) {
      throw const ConfigurationChangeException('file_output_exists');
    }
  }

  Future<Map<String, Object?>> _grant(
    Map<String, Object?> params,
    String origin,
    Future<bool> Function()? beginMutation,
    bool Function()? isCurrent,
  ) async {
    final mode = policyString(params, 'mode');
    String? path = params['path'] as String?;
    if (origin == 'agent') {
      if (path != null) {
        throw const ConfigurationChangeException('local_input_required');
      }
      if (mode == 'read') {
        path = (await picker.pickerFile())?.path;
      } else {
        path = await selectLocalOutputPath('FlClash-export.bin');
      }
    }
    if (path == null ||
        isCurrent?.call() == false ||
        beginMutation != null && !await beginMutation()) {
      return {'status': 'cancelled'};
    }
    await _validatePath(path, mode);
    if (isCurrent?.call() == false) return {'status': 'cancelled'};
    _files.removeWhere((_, grant) => DateTime.now().isAfter(grant.expiresAt));
    if (_files.length >= 32) {
      throw const ConfigurationChangeException('file_grant_limit');
    }
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    _files[id] = _FileGrant(
      path,
      mode,
      DateTime.now().add(const Duration(minutes: 10)),
    );
    return {
      'status': 'completed',
      'fileGrantId': id,
      'mode': mode,
      'fileName': paths.basename(path),
      'expiresAt': _files[id]!.expiresAt.millisecondsSinceEpoch,
    };
  }

  Future<Map<String, Object?>> _export(
    String command,
    Map<String, Object?> params,
  ) async {
    final destination = await _file(params, 'write');
    String text;
    switch (command) {
      case 'logs_export':
        text = ref
            .read(logsProvider)
            .list
            .map(
              (log) => '${log.dateTime}\t${log.logLevel.name}\t${log.payload}',
            )
            .join('\n');
      case 'usage_export':
        final filter = _usageFilter(params);
        final store = ref.read(usageStoreProvider);
        final buffer = StringBuffer(
          'dimension,label,upload,download,connections\n',
        );
        for (final dimension in [
          UsageDimension.node,
          UsageDimension.application,
          UsageDimension.domain,
          UsageDimension.profile,
        ]) {
          await store.forEachRankingPage(
            filter,
            dimension,
            sort: UsageSort.total,
            search: '',
            onPage: (rows) async {
              for (final row in rows) {
                final label = row.label.replaceAll('"', '""');
                buffer.writeln(
                  '${dimension.name},"$label",${row.upload},${row.download},${row.connections}',
                );
                if (buffer.length > 16 * 1024 * 1024) {
                  throw const ConfigurationChangeException('export_limit');
                }
              }
            },
          );
        }
        text = buffer.toString();
      case 'profile_effective_export':
        final id = resourceId(params, 'id');
        final setup = await ref.read(setupStateProvider(id).future);
        final document = LocalPolicyDocument.fromJson({
          ...(await controller.readPolicies()).toJson(),
          'integrationEnabled': false,
        }).asStandalone();
        var scriptApproved = false;
        if (setup.overwriteType == OverwriteType.script &&
            setup.script != null &&
            !(document.moduleEnabled && document.integrationEnabled)) {
          final context = globalState.navigatorKey.currentContext;
          if (approveScript == null && (context == null || !context.mounted)) {
            throw const ConfigurationChangeException(
              'script_authorization_required',
            );
          }
          final proposal = ConfigurationProposal(
            id: 'script-export-$id',
            summary: currentAppLocalizations.script,
            highRisk: true,
            expiresAt: DateTime.now().millisecondsSinceEpoch + 600000,
            differences: [
              ConfigurationDifference(
                path: 'scriptId',
                before: null,
                after: setup.script!.id,
              ),
            ],
            validation: const {
              'executionOnly': true,
              'requiresScriptExecutionApproval': true,
            },
          );
          scriptApproved =
              await (approveScript?.call(proposal) ??
                  showAiConfigurationApproval(context!, proposal));
          if (!scriptApproved) {
            throw const ConfigurationChangeException(
              'script_execution_rejected',
            );
          }
        }
        final generated = await ref
            .read(setupActionProvider.notifier)
            .getProfile(
              setupState: setup,
              patchConfig: ref.read(patchClashConfigProvider),
              policyDocument: document,
              preview: true,
              allowScriptExecution: scriptApproved,
            );
        if (generated.a.isEmpty ||
            (await core.validateConfigWithData(generated.a)).isNotEmpty) {
          throw const ConfigurationChangeException(
            'effective_config_validation_failed',
          );
        }
        text = generated.a;
      case 'profile_export':
      case 'script_export':
        final id = resourceId(params, 'id');
        final scope = ResourceScope(
          command == 'script_export'
              ? ResourceKind.script
              : ResourceKind.profile,
          id,
        );
        final state = await controller.resources.environment.read(scope);
        text = policyString(
          state,
          'protectedContent',
          maximum: 16 * 1024 * 1024,
        );
      default:
        throw const FormatException();
    }
    if (utf8.encode(text).length > 16 * 1024 * 1024) {
      throw const ConfigurationChangeException('export_limit');
    }
    SecureLocalFiles.write(
      destination.path,
      Uint8List.fromList(utf8.encode(text)),
    );
    _files.remove(params['fileGrantId']);
    return {
      'status': 'completed',
      'bytes': await destination.length(),
      'contentDigest': policyDigest(text),
      'localFileDelivered': true,
    };
  }

  UsageFilter _usageFilter(Map<String, Object?> params) {
    final start = policyInt(params, 'start', minimum: 1);
    final end = policyInt(params, 'end', minimum: start);
    if (end - start > const Duration(days: 366).inMilliseconds) {
      throw const FormatException('Range too large');
    }
    return UsageFilter(
      start: DateTime.fromMillisecondsSinceEpoch(start),
      end: DateTime.fromMillisecondsSinceEpoch(end),
      scope: UsageTrafficScope.values.singleWhere(
        (scope) => scope.name == (params['scope'] ?? 'proxy'),
      ),
    );
  }

  Future<Map<String, Object?>> _credentialState() async {
    final settings = await controller.readAgentSettings();
    return {
      'settings': settings.toJson(),
      'credentialDigests': {
        for (final connection in settings.connections)
          connection.id: policyDigest(
            await controller.credentials.read(connection.credentialId),
          ),
      },
    };
  }

  @override
  Future<Map<String, Object?>> execute(
    String command,
    Map<String, Object?> params, {
    required String origin,
    Future<bool> Function()? beginMutation,
    bool Function()? isCurrent,
  }) async {
    switch (command) {
      case 'local_policy_details':
        if ((params['policyId'] == null) == (params['nodeSetId'] == null)) {
          throw const FormatException();
        }
        return coreController.getLocalPolicyDetails({
          ...params,
          'offset': policyInt(params, 'offset', fallback: 0, maximum: 5000),
          'limit': policyInt(
            params,
            'limit',
            fallback: 100,
            minimum: 1,
            maximum: 200,
          ),
        });
      case 'policy_nodes_check':
      case 'policy_nodes_state':
      case 'policy_nodes_cancel':
        return coreController.checkLocalPolicyNodes({
          ...params,
          if (command == 'policy_nodes_cancel') 'cancel': true,
        });
      case 'profile_select':
        if (params['profileId'] != null && params['integrationId'] != null ||
            params.isEmpty) {
          throw const FormatException();
        }
        return controller.selectPolicyTarget(
          profileId: params['profileId'] == null
              ? null
              : resourceId(params, 'profileId'),
          integrationId: params['integrationId'] as String?,
          moduleEnabled: params['moduleEnabled'] as bool?,
          approve: (proposal) async {
            if (proposal.validation['requiresScriptExecutionApproval'] !=
                    true &&
                !proposal.validation.containsKey('finalConfigDifferences')) {
              return true;
            }
            final context = globalState.navigatorKey.currentContext;
            return context != null && context.mounted
                ? showAiConfigurationApproval(context, proposal)
                : false;
          },
        );
      case 'usage_set_enabled':
        await ref
            .read(usageRuntimeProvider.notifier)
            .setEnabled(policyBool(params, 'enabled'));
        return {
          'status':
              await ref.read(usageStoreProvider).isEnabled() ==
                  params['enabled']
              ? 'completed'
              : 'failed',
        };
      case 'usage_clear':
        await ref.read(usageRuntimeProvider.notifier).clear();
        return {'status': 'completed', 'sourceBudgetLedgerPreserved': true};
      case 'resource_update':
        final kind = policyString(params, 'kind');
        if (kind == 'provider') {
          final name = policyString(params, 'providerName');
          final providers = await coreController.getExternalProviders();
          final provider = providers
              .where((provider) => provider.name == name)
              .firstOrNull;
          if (provider == null) {
            throw const ConfigurationChangeException(
              'resource_provider_missing',
            );
          }
          final error = await ref
              .read(proxiesActionProvider.notifier)
              .updateProvider(provider);
          if (error.isNotEmpty) {
            throw const ConfigurationChangeException('resource_update_failed');
          }
          return {'status': 'completed'};
        }
        if (params['providerName'] != null) throw const FormatException();
        final revision = capabilityRuntimeEvents.revision;
        final resource = GeoResource.values.singleWhere(
          (resource) => resource.name.toLowerCase() == kind,
        );
        if ((await coreController.updateGeoData(resource.name)).isNotEmpty) {
          throw const ConfigurationChangeException('resource_update_failed');
        }
        final event = await capabilityRuntimeEvents.waitForGeo(
          kind,
          afterRevision: revision,
        );
        return {
          'status': event['failed'] == true
              ? 'failed'
              : event['skipped'] == true
              ? 'skipped'
              : 'completed',
          'observed': event,
        };
      case 'runtime_read':
        return {
          'coreStatus': ref.read(coreStatusProvider).name,
          'running': ref.read(isStartProvider),
          'runTime': ref.read(runTimeProvider),
          'coreInitialized': await coreController.isInit,
          'traffic': (await coreController.getTraffic(false)).toJson(),
          'totalTraffic': (await coreController.getTotalTraffic(
            false,
          )).toJson(),
          'memoryBytes': await coreController.getMemory(),
        };
      case 'connection_set':
        final running = policyBool(params, 'running');
        await ref
            .read(setupActionProvider.notifier)
            .setRunning(
              running,
              initialize: running && !ref.read(initProvider),
            );
        return {
          'status': ref.read(isStartProvider) == running
              ? 'completed'
              : 'superseded',
          'running': ref.read(isStartProvider),
          'coreStatus': ref.read(coreStatusProvider).name,
        };
      case 'core_restart':
        await ref.read(coreActionProvider.notifier).restartCore();
        return {
          'status': ref.read(coreStatusProvider) == CoreStatus.connected
              ? 'completed'
              : 'failed',
          'coreStatus': ref.read(coreStatusProvider).name,
        };
      case 'app_show':
      case 'app_hide':
        if (window == null) {
          return {'status': 'unsupported', 'errorCode': 'window_unavailable'};
        }
        final visible = command == 'app_show';
        if (visible) {
          await window!.show();
        } else {
          await window!.hide();
        }
        if (!await window!.waitForVisibility(visible)) {
          throw const ConfigurationChangeException('window_visibility_timeout');
        }
        return {'status': 'completed', 'visible': visible};
      case 'app_exit':
        unawaited(
          Future<void>.delayed(
            const Duration(milliseconds: 200),
            () => ref.read(systemActionProvider.notifier).handleExit(true),
          ),
        );
        return {'status': 'accepted', 'exitAccepted': true};
      case 'proxies_read':
        return {
          'groups': [
            for (final group in await _groups())
              {
                'name': group.name,
                'type': group.type.value,
                'selected': group.now,
                'nodes': group.all
                    .map((node) => {'name': node.name, 'type': node.type})
                    .toList(),
              },
          ],
        };
      case 'proxy_select':
        final name = policyString(params, 'group');
        final node = policyString(params, 'node');
        final groups = await _groups();
        final group = groups.where((group) => group.name == name).firstOrNull;
        if (group == null ||
            group.type != GroupType.Selector ||
            !group.all.any((item) => item.name == node)) {
          throw const ConfigurationChangeException('proxy_selection_invalid');
        }
        await ref
            .read(proxiesActionProvider.notifier)
            .changeProxy(groupName: name, proxyName: node);
        final applied = (await _groups())
            .where((group) => group.name == name)
            .firstOrNull
            ?.now;
        return {
          'status': applied == node ? 'completed' : 'conflict',
          'selected': applied,
        };
      case 'proxy_test':
        final groups = await _groups();
        final group = params['group'] == null
            ? null
            : groups
                  .where((group) => group.name == params['group'])
                  .firstOrNull;
        final node = params['node'] as String?;
        final nodes = node != null
            ? groups
                  .expand((group) => group.all)
                  .where((item) => item.name == node)
                  .map((item) => item.name)
                  .toSet()
            : group?.all.map((item) => item.name).toSet() ?? <String>{};
        if (nodes.isEmpty || nodes.length > 5000) {
          throw const ConfigurationChangeException('proxy_test_scope_invalid');
        }
        final queue = nodes.toList();
        final results = <Map<String, Object?>>[];
        Future<void> worker() async {
          while (queue.isNotEmpty && isCurrent?.call() != false) {
            final name = queue.removeLast();
            final delay = await coreController
                .getDelay(
                  group?.testUrl ?? ref.read(appSettingProvider).testUrl,
                  name,
                )
                .timeout(const Duration(seconds: 15));
            if (isCurrent?.call() == false) return;
            ref.read(proxiesActionProvider.notifier).setDelay(delay);
            results.add({
              'name': name,
              'delayMs': delay.value,
              'completedAt': DateTime.now().millisecondsSinceEpoch,
            });
          }
        }
        await Future.wait(List.generate(min(8, queue.length), (_) => worker()));
        return {
          'status': isCurrent?.call() == false ? 'cancelled' : 'completed',
          'results': results,
        };
      case 'providers_read':
        return {
          'providers': (await coreController.getExternalProviders())
              .map((provider) => redactResource(provider.toJson()))
              .toList(),
          'observedResources': capabilityRuntimeEvents.snapshot,
        };
      case 'policies_runtime':
        return coreController.getLocalPolicyStatus();
      case 'network_status':
        return {
          'tunAuthorization': ref.read(authorizedTunEnableProvider).name,
          'configuredTun': ref.read(patchClashConfigProvider).tun.enable,
          'observed': capabilityRuntimeEvents.snapshot,
        };
      case 'ip_detect':
        final detected = await request.checkIp();
        await ref.read(systemActionProvider.notifier).updateLocalIp();
        return {
          'status': detected.data == null ? 'failed' : 'completed',
          'outbound': detected.data == null
              ? null
              : {
                  'ip': detected.data!.ip,
                  'countryCode': detected.data!.countryCode,
                },
          'localIp': ref.read(localIpProvider),
        };
      case 'connections_read':
        final connections = await coreController.getConnections();
        final values = connections
            .where((item) => params['id'] == null || item.id == params['id'])
            .map((item) => redactResource(item.toJson()))
            .toList();
        return {'connections': _page(values, params), 'total': values.length};
      case 'connection_close':
        if (params['all'] == true && params['id'] == null) {
          await coreController.closeConnections();
        } else if (params['id'] is String && params['all'] != true) {
          await coreController.closeConnection(policyString(params, 'id'));
        } else {
          throw const FormatException();
        }
        final remaining = await coreController.getConnections();
        return {
          'status': params['all'] == true
              ? (remaining.isEmpty ? 'completed' : 'pending')
              : (!remaining.any((connection) => connection.id == params['id'])
                    ? 'completed'
                    : 'pending'),
        };
      case 'logs_read':
        final search = (params['search'] as String? ?? '').toLowerCase();
        final logs = ref
            .read(logsProvider)
            .list
            .where((log) => log.payload.toLowerCase().contains(search))
            .map(
              (log) => {
                'level': log.logLevel.name,
                'observedAt': log.dateTime,
                'message': _safeText(log.payload),
              },
            )
            .toList();
        return {
          'logs': _page(logs, params),
          'total': logs.length,
          'recording': ref.read(appSettingProvider).openLogs,
        };
      case 'requests_read':
        final search = (params['search'] as String? ?? '').toLowerCase();
        final values = ref
            .read(requestsProvider)
            .list
            .where((item) => item.desc.toLowerCase().contains(search))
            .map((item) => redactResource(item.toJson()))
            .toList();
        return {'requests': _page(values, params), 'total': values.length};
      case 'usage_history':
        final filter = _usageFilter(params);
        final store = ref.read(usageStoreProvider);
        final summary = await store.summary(filter);
        final dimension = UsageDimension.values.singleWhere(
          (dimension) => dimension.name == (params['dimension'] ?? 'overview'),
        );
        final rows = dimension == UsageDimension.overview
            ? <UsageRankingItem>[]
            : await store.ranking(
                filter,
                dimension,
                search: params['search'] as String? ?? '',
                offset: policyInt(params, 'offset', fallback: 0),
                limit: policyInt(
                  params,
                  'limit',
                  fallback: 100,
                  minimum: 1,
                  maximum: 200,
                ),
              );
        return {
          'summary': {
            'upload': summary.upload,
            'download': summary.download,
            'connections': summary.connections,
          },
          'degraded': await store.hasDegradedData(filter),
          'recording': await store.isEnabled(),
          'rows': [
            for (final row in rows)
              {
                'key': row.key,
                'label': row.label,
                'upload': row.upload,
                'download': row.download,
                'connections': row.connections,
              },
          ],
        };
      case 'version_read':
        return {
          'version': ref.read(versionProvider),
          'coreInitialized': await coreController.isInit,
        };
      case 'update_check':
        final release = await request.checkForUpdate();
        return {
          'status': release == null ? 'failed' : 'completed',
          'release': release == null
              ? null
              : {
                  'tag': release['tag_name'],
                  'publishedAt': release['published_at'],
                  'downloadUrl': release['html_url'],
                },
        };
      case 'hotkeys_status':
        return {
          'configured': ref
              .read(hotKeyActionsProvider)
              .map((action) => action.toJson())
              .toList(),
          'registration': capabilityRuntimeEvents.snapshot['hotkeys'],
        };
      case 'profiles_reorder':
        final ids = (params['ids'] as List)
            .map((id) => resourceId({'id': id}, 'id'))
            .toList();
        final profiles = ref.read(profilesProvider);
        if (ids.length != profiles.length ||
            ids.toSet().length != profiles.length ||
            !ids.toSet().containsAll(profiles.map((profile) => profile.id))) {
          throw const FormatException();
        }
        await ref.read(profilesActionProvider.notifier).reorder([
          for (final id in ids)
            profiles.singleWhere((profile) => profile.id == id),
        ]);
        await preferences.saveConfig(ref.read(configProvider));
        return {
          'status': 'completed',
          'order': ids.map((id) => '$id').toList(),
        };
      case 'file_grant':
        return _grant(params, origin, beginMutation, isCurrent);
      case 'profile_export':
      case 'profile_effective_export':
      case 'script_export':
      case 'logs_export':
      case 'usage_export':
        return _export(command, params);
      case 'profile_file_propose':
        final file = await _file(params, 'read');
        if (await file.length() > 8 * 1024 * 1024) {
          throw const ConfigurationChangeException('profile_file_limit');
        }
        final id = params['profileId'] == null
            ? snowflake.id
            : resourceId(params, 'profileId');
        final scope = ResourceScope(ResourceKind.profile, id);
        final state = await controller.resources.environment.read(scope);
        state['profile'] ??= Profile(
          autoUpdateDuration: const Duration(hours: 1),
          id: id,
          label: params['label'] as String? ?? paths.basename(file.path),
        ).toJson();
        state['protectedContent'] = utf8.decode(
          SecureLocalFiles.read(file.path, maximumBytes: 8 * 1024 * 1024),
        );
        return {
          'proposal': (await controller.resources.propose(
            scope,
            state,
            summary: currentAppLocalizations.profiles,
          )).toJson(),
        };
      case 'source_repair_propose':
        final input = await _file(params, 'read');
        final content = utf8.decode(
          SecureLocalFiles.read(input.path, maximumBytes: 8 * 1024 * 1024),
        );
        final proposal = await controller.resources.proposeRepairSource(
          policyString(params, 'recoveryId', maximum: 96),
          resourceId(params, 'profileId'),
          content: content,
          label: params['label'] as String?,
        );
        return {
          'proposal': proposal.toJson(),
          'preparationOnly': true,
          'recoveryPending': true,
        };
      case 'script_patch':
        final id = resourceId(params, 'scriptId');
        final scope = ResourceScope(ResourceKind.script, id);
        final state = await controller.resources.environment.read(scope);
        final content = policyString(
          state,
          'protectedContent',
          maximum: 512 * 1024,
        );
        final find = policyString(params, 'find');
        if (find.isEmpty || find.allMatches(content).length != 1) {
          throw const ConfigurationChangeException('script_patch_not_unique');
        }
        state['protectedContent'] = content.replaceFirst(
          find,
          policyString(params, 'replace', fallback: ''),
        );
        return {
          'proposal': (await controller.resources.propose(
            scope,
            state,
            summary: currentAppLocalizations.script,
          )).toJson(),
        };
      case 'backup_create':
        final destination = await _file(params, 'write');
        final path = await ref.read(backupActionProvider.notifier).backup();
        try {
          SecureLocalFiles.write(
            destination.path,
            SecureLocalFiles.read(path, maximumBytes: 128 * 1024 * 1024),
          );
          _files.remove(params['fileGrantId']);
          return {
            'status': 'completed',
            'localFileDelivered': true,
            'bytes': await destination.length(),
          };
        } finally {
          await File(path).safeDelete();
        }
      case 'backup_restore':
        final source = await _file(params, 'read');
        await File(await appPath.backupFilePath).writeAsBytes(
          SecureLocalFiles.read(source.path, maximumBytes: 128 * 1024 * 1024),
          flush: true,
        );
        await ref
            .read(backupActionProvider.notifier)
            .restore(
              RestoreOption.values.singleWhere(
                (option) => option.name == params['option'],
              ),
            );
        return {'status': 'completed'};
      case 'webdav_upload':
      case 'webdav_restore':
        final props = ref.read(davSettingProvider);
        if (props == null) {
          throw const ConfigurationChangeException('webdav_not_configured');
        }
        final client = DAVClient(props);
        if (command == 'webdav_upload') {
          final path = await ref.read(backupActionProvider.notifier).backup();
          try {
            await client.backup(path);
          } finally {
            await File(path).safeDelete();
          }
        } else {
          await client.restore();
          await ref
              .read(backupActionProvider.notifier)
              .restore(
                RestoreOption.values.singleWhere(
                  (option) => option.name == params['option'],
                ),
              );
        }
        return {'status': 'completed'};
      case 'agent_settings_read':
        final settings = await controller.readAgentSettings();
        return {
          'settings': settings.toJson(),
          'hasKeyByConnection': {
            for (final connection in settings.connections)
              connection.id:
                  (await controller.credentials.read(
                    connection.credentialId,
                  ))?.isNotEmpty ==
                  true,
          },
        };
      case 'agent_settings_propose':
        final settings = AgentSettings.fromJson(
          policyObject(params['settings'], 'settings'),
        );
        return {
          'proposal': (await controller.proposeAgentSettings(
            settings,
          )).toJson(),
        };
      case 'backup_panel':
        final navigator = globalState.navigatorKey.currentState;
        if (navigator == null) {
          throw const ConfigurationChangeException('local_ui_unavailable');
        }
        final completed = Completer<String>();
        final action = policyString(params, 'action');
        unawaited(
          navigator.push<void>(
            MaterialPageRoute(
              builder: (_) => BackupAndRestore(
                requestedAction: action,
                canStart: beginMutation,
                onComplete: (status) async {
                  if (!completed.isCompleted) completed.complete(status);
                },
              ),
            ),
          ),
        );
        return {'status': await completed.future};
      case 'profile_qr_import':
        final url = await picker.pickerConfigQRCode();
        if (url == null ||
            isCurrent?.call() == false ||
            beginMutation != null && !await beginMutation()) {
          return {'status': 'cancelled'};
        }
        final response = await controller.fetchSourceResponse(url);
        if (isCurrent?.call() == false) return {'status': 'cancelled'};
        final bytes = response.data;
        if (bytes == null || bytes.isEmpty || bytes.length > 8 * 1024 * 1024) {
          throw const ConfigurationChangeException('resource_download_invalid');
        }
        final id = snowflake.id;
        final scope = ResourceScope(ResourceKind.profile, id);
        final state = await controller.resources.environment.read(scope);
        state['profile'] = Profile(
          id: id,
          url: url,
          label: Uri.parse(url).host,
          autoUpdateDuration: const Duration(hours: 1),
          subscriptionInfo: SubscriptionInfo.formHString(
            response.headers.value('subscription-userinfo'),
          ),
        ).toJson();
        state['protectedContent'] = utf8.decode(bytes);
        return {
          'proposal': (await controller.resources.propose(
            scope,
            state,
            summary: currentAppLocalizations.profiles,
          )).toJson(),
        };
      case 'profile_import_panel':
        final file = await picker.pickerFile();
        if (file?.path == null ||
            isCurrent?.call() == false ||
            beginMutation != null && !await beginMutation()) {
          return {'status': 'cancelled'};
        }
        final path = file!.path!;
        await _validatePath(path, 'read');
        final id = snowflake.id;
        final scope = ResourceScope(ResourceKind.profile, id);
        final state = await controller.resources.environment.read(scope);
        state['profile'] = Profile(
          id: id,
          label: paths.basename(path),
          autoUpdateDuration: const Duration(hours: 1),
        ).toJson();
        state['protectedContent'] = utf8.decode(
          SecureLocalFiles.read(path, maximumBytes: 8 * 1024 * 1024),
        );
        return {
          'proposal': (await controller.resources.propose(
            scope,
            state,
            summary: currentAppLocalizations.profiles,
          )).toJson(),
        };
      case 'credentials_panel':
        final navigator = globalState.navigatorKey.currentState;
        if (navigator == null) {
          throw const ConfigurationChangeException('local_ui_unavailable');
        }
        if (params['kind'] == 'cli') {
          final service = ref.read(localControlServiceProvider);
          final before = {
            'configured': service.passwordConfigured,
            'generation': service.credentialGeneration,
            'enabled': service.enabled,
          };
          await navigator.push<void>(
            MaterialPageRoute(
              builder: (_) => LocalControlSettings(service: service),
            ),
          );
          final after = {
            'configured': service.passwordConfigured,
            'generation': service.credentialGeneration,
            'enabled': service.enabled,
          };
          final changed = policyDigest(before) != policyDigest(after);
          return {
            'status': changed ? 'completed' : 'cancelled',
            'result': after,
          };
        }
        final before = await _credentialState();
        await navigator.push<void>(
          MaterialPageRoute(builder: (_) => const AiSettingsView()),
        );
        final changed =
            policyDigest(before) != policyDigest(await _credentialState());
        return {
          'status': changed ? 'completed' : 'cancelled',
          'configurationChanged': changed,
        };
      case 'maintenance_clear_cache':
        await ref.read(storeActionProvider.notifier).shakingStore();
        return {'status': 'completed'};
      case 'maintenance_clear_data':
        await ref.read(storeActionProvider.notifier).handleClear();
        return {'status': 'accepted', 'exitAccepted': true};
      case 'developer_test':
        if (!ref.read(appSettingProvider).developerMode) {
          throw const ConfigurationChangeException('developer_mode_required');
        }
        switch (params['kind']) {
          case 'notification':
            globalState.showNotifier(currentAppLocalizations.messageTestTip);
          case 'logs':
            for (var i = 0; i < 1000; i++) {
              ref.read(logsProvider.notifier).add(Log.app('diagnostic $i'));
            }
          case 'core_crash':
            if (!globalState.canCrashCore) {
              throw const ConfigurationChangeException(
                'core_crash_unsupported',
              );
            }
            await coreController.crash();
        }
        return {'status': 'completed'};
      case 'platform_tool':
        return {
          'status': 'unsupported',
          'errorCode': 'target_platform_required',
          'platform': params['kind'] == 'windows_loopback'
              ? 'windows'
              : 'android',
        };
      default:
        throw const ConfigurationChangeException('command_unknown');
    }
  }
}
