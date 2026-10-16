import 'package:collection/collection.dart';
import 'package:fl_clash/ai/settings.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/policy/source_change.dart';
import 'package:fl_clash/views/policy/source_change_summary.dart';
import 'package:flutter/material.dart';

import 'policy_plan.dart';

class AiReviewRow {
  const AiReviewRow(
    this.label,
    this.after, {
    this.before,
    this.changeCount = 1,
  });
  final String label;
  final String? before;
  final String after;
  final int changeCount;
}

bool aiReviewCanConfirm(ConfigurationProposal proposal, String? status) {
  final state = status ?? proposal.validation['reviewStatus'] ?? 'draft';
  return proposal.expiresAt > DateTime.now().millisecondsSinceEpoch &&
      !(state == 'proposal_ready' &&
          (proposal.validation['agentReview'] is Map ||
              '${proposal.validation['reviewCategory']}'.startsWith(
                'capability:',
              ))) &&
      const {'draft', 'proposal_ready', 'pending_confirmation'}.contains(state);
}

String aiReviewTitle(AppLocalizations s, ConfigurationProposal proposal) {
  final metadata = proposal.validation['agentReview'];
  if (metadata is Map && metadata['command'] is String) {
    return aiReviewCommandTitle(s, metadata['command'] as String);
  }
  final category = '${proposal.validation['reviewCategory']}';
  if (category.contains(':rules:') ||
      proposal.differences.any(
        (change) => {
          'addedRules',
          'customRules',
          'disabledRules',
        }.contains(change.path),
      )) {
    return s.rule;
  }
  if (category.contains(':groups:') ||
      proposal.differences.any((change) => change.path == 'groups')) {
    return s.proxyGroup;
  }
  if (category.contains(':profile:') ||
      proposal.differences.any(
        (change) =>
            change.path == 'profile' || change.path.startsWith('profile.'),
      )) {
    return s.profiles;
  }
  if (category.contains(':script:') ||
      proposal.differences.any(
        (change) =>
            change.path == 'script' || change.path.startsWith('script.'),
      )) {
    return s.script;
  }
  if (proposal.differences.any(
    (change) => change.path.startsWith('policies.'),
  )) {
    return s.aiPolicyPlanTitle;
  }
  if (proposal.differences.any((change) => change.path.startsWith('config.'))) {
    return s.settings;
  }
  if (proposal.differences.any((change) => change.path.startsWith('ai.'))) {
    return s.aiSettingsTitle;
  }
  return s.aiReviewUnknownAction;
}

String aiReviewCommandTitle(AppLocalizations s, String command) =>
    switch (command) {
      'capabilities_list' => s.aiCanHelp,
      'local_policy_details' || 'policies_runtime' => s.localPolicies,
      'policy_nodes_state' => s.aiReviewProbe,
      'policy_nodes_cancel' => s.aiReviewCancelProbe,
      'runtime_read' => s.coreStatus,
      'proxies_read' => s.proxies,
      'providers_read' => s.resources,
      'network_status' || 'ip_detect' => s.networkDetection,
      'connections_read' => s.connections,
      'connection_close' => s.aiReviewCloseConnections,
      'logs_read' => s.logs,
      'requests_read' => s.requests,
      'version_read' => s.about,
      'update_check' => s.checkUpdate,
      'hotkeys_status' => s.hotkeyManagement,
      'profiles_reorder' => '${s.profiles} · ${s.sort}',
      'file_grant' => s.aiReviewGrantFile,
      'profile_export' ||
      'profile_effective_export' => '${s.exportFile} · ${s.profiles}',
      'script_export' => '${s.exportFile} · ${s.script}',
      'logs_export' => s.exportLogs,
      'usage_export' => s.exportCsv,
      'credentials_panel' => s.aiServiceCredentials,
      'maintenance_clear_cache' => s.pruneCache,
      'maintenance_clear_data' => s.clearData,
      'developer_test' => s.aiReviewDiagnostics,
      'platform_tool' => s.tools,
      'operation_query' => s.aiCheckResult,
      'operation_cancel' => s.aiReviewCancelOperation,
      'capability_confirm' => s.aiReviewAndConfirm,
      'agent_settings_read' || 'agent_settings_propose' => s.aiSettingsTitle,
      'source_repair_propose' => s.policyRecoveryStatus,
      'profile_import_panel' => '${s.import} · ${s.profiles}',
      'proxy_select' => s.aiReviewSelectNode,
      'profile_select' => s.aiReviewSelectProfile,
      'connection_set' => s.aiReviewSetConnection,
      'core_restart' => s.restart,
      'proxy_test' || 'policy_nodes_check' => s.aiReviewProbe,
      'profiles_refresh_all' || 'profile_refresh' => s.aiReviewRefresh,
      'resource_update' || 'provider_update' => s.aiReviewResource,
      'profile_propose' || 'profile_file_propose' => s.profiles,
      'rule_propose' => s.rule,
      'group_propose' => s.proxyGroup,
      'profile_qr_import' => '${s.import} · ${s.qrcode}',
      'settings_propose' => s.settings,
      'policies_propose' || 'rules_edit' || 'node_sets_edit' => s.localPolicies,
      'usage_set_enabled' || 'usage_history' => s.usage,
      'usage_clear' => s.clearUsageData,
      'backup_create' => s.backup,
      'backup_restore' => s.restore,
      'backup_panel' => s.backupAndRestore,
      'webdav_upload' => 'WebDAV · ${s.upload}',
      'webdav_restore' => 'WebDAV · ${s.download}',
      'app_show' => '${s.show} · ${s.application}',
      'app_hide' => s.aiReviewHideApplication,
      'app_exit' => '${s.exit} · ${s.application}',
      'script_patch' || 'script_propose' => s.script,
      _ => s.aiReviewUnknownAction,
    };

String _safe(String value) {
  final text = value
      .replaceAll(RegExp(r'[\x00-\x1f\u202a-\u202e\u2066-\u2069]+'), ' ')
      .replaceAllMapped(RegExp(r'https?://\S+', caseSensitive: false), (match) {
        final uri = Uri.tryParse(match[0]!);
        return uri == null ? '…' : '${uri.scheme}://${uri.host}';
      })
      .trim();
  return text.length > 180 ? '${text.substring(0, 180)}…' : text;
}

bool _sensitive(String field) =>
    field != 'maxTokens' &&
    !field.endsWith('.maxTokens') &&
    RegExp(
      r'(password|secret|token|credential|api.?key|authorization|protectedContent)',
      caseSensitive: false,
    ).hasMatch(field);

String? aiReviewFieldLabel(AppLocalizations s, String path) {
  final field = path.startsWith('config.') ? path.substring(7) : path;
  return switch (field) {
    'running' || 'connected' => s.coreStatus,
    'coreStatus' => s.coreStatus,
    'group' => s.proxyGroup,
    'operationId' || 'nodeSetId' || 'scriptId' || 'id' => s.aiReviewTarget,
    'fileGrantId' => s.file,
    'option' => s.aiReviewActionScope,
    'ids' => '${s.profiles} · ${s.sort}',
    'operation' => s.action,
    'all' => s.connections,
    'moduleEnabled' => s.policyModule,
    'visible' => s.application,
    'node' || 'selected' => s.proxies,
    'profileId' || 'currentProfileId' => s.profiles,
    'integrationId' => s.localPolicies,
    'kind' => s.resources,
    'providerName' => s.policySources,
    'enabled' => s.status,
    'action' => s.action,
    'label' || 'name' => s.name,
    'provider' => s.aiProvider,
    'model' => s.aiModel,
    'baseUrl' => s.aiBaseUrl,
    'api' => s.aiApiProtocol,
    'useProxy' => s.aiUseProxy,
    'timeoutSeconds' => s.aiTimeout,
    'maxTokens' => s.aiMaxTokens,
    'ai.enabled' => s.aiEnable,
    'ai.selectedConnectionId' => s.aiCurrentConnection,
    'ai.connections' => s.aiConnection,
    'url' => s.url,
    'mode' || 'settings.mode' || 'patchClashConfig.mode' => s.mode,
    'profile' => s.profiles,
    'profile.label' || 'script.label' => s.name,
    'profile.url' => s.url,
    'profile.autoUpdate' => s.autoUpdate,
    'profile.autoUpdateInterval' => s.autoUpdateInterval,
    'script' => s.script,
    'addedRules' || 'customRules' || 'disabledRules' => s.rule,
    'groups' => s.proxyGroup,
    'protectedContent' || 'protectedScriptContent' => s.aiReviewContent,
    'dns.enable' => s.aiReviewDns,
    'networkProps.systemProxy' => s.systemProxy,
    'networkProps.routeMode' => s.routeMode,
    'networkProps.bypassDomain' => s.bypassDomain,
    'networkProps.autoSetSystemDns' ||
    'networkProps.appendSystemDns' => s.aiReviewDns,
    'davProps' => s.webDAVConfiguration,
    'excludeSSIDs' => s.excludeSsids,
    'hotKeyActions' => s.hotkeyManagement,
    'overrideDns' => s.overrideDns,
    'patchClashConfig.tun.enable' => s.tun,
    'patchClashConfig.tun.stack' => s.stackMode,
    'patchClashConfig.allow-lan' => s.allowLan,
    'patchClashConfig.ipv6' => 'IPv6',
    'patchClashConfig.mixed-port' => s.mixedPort,
    'patchClashConfig.port' ||
    'patchClashConfig.socks-port' ||
    'patchClashConfig.redir-port' ||
    'patchClashConfig.tproxy-port' => s.port,
    'patchClashConfig.log-level' => s.logLevel,
    'patchClashConfig.find-process-mode' => s.findProcessMode,
    'patchClashConfig.unified-delay' => s.unifiedDelay,
    'patchClashConfig.tcp-concurrent' => s.tcpConcurrent,
    'patchClashConfig.external-controller' => s.externalController,
    'patchClashConfig.geodata-loader' => s.geodataLoader,
    'patchClashConfig.geo-auto-update' => s.geoAutoUpdate,
    'patchClashConfig.geo-update-interval' => s.geoAutoUpdateInterval,
    'patchClashConfig.geox-url' => '${s.geoResources} · ${s.url}',
    'patchClashConfig.global-ua' => s.userAgent,
    'patchClashConfig.keep-alive-interval' => s.keepAliveIntervalDesc,
    'patchClashConfig.tun.device' => '${s.tun} · ${s.name}',
    'patchClashConfig.tun.dns-hijack' => s.dnsHijacking,
    'patchClashConfig.hosts' => 'Hosts',
    'themeProps.themeMode' => s.themeMode,
    'themeProps.primaryColor' || 'themeProps.primaryColors' => s.themeColor,
    'themeProps.schemeVariant' => s.colorSchemes,
    'themeProps.pureBlack' => s.pureBlackMode,
    'themeProps.textScale.scale' ||
    'themeProps.textScale.enable' => s.textScale,
    'appSettingProps.locale' => s.language,
    'appSettingProps.autoLaunch' => s.autoLaunch,
    'appSettingProps.silentLaunch' => s.silentLaunch,
    'appSettingProps.autoRun' => s.autoRun,
    'appSettingProps.openLogs' => s.logcat,
    'appSettingProps.autoCheckUpdate' => s.autoCheckUpdate,
    'appSettingProps.minimizeOnExit' => s.minimizeOnExit,
    'appSettingProps.developerMode' => s.developerMode,
    'appSettingProps.restoreStrategy' => s.restoreStrategy,
    'appSettingProps.customUserAgent' => s.userAgent,
    'appSettingProps.testUrl' => s.testUrl,
    'appSettingProps.closeConnections' => s.autoCloseConnections,
    'appSettingProps.crashlytics' => s.crashlytics,
    'appSettingProps.dashboardWidgets' => '${s.dashboard} · ${s.layout}',
    'appSettingProps.hidden' => s.exclude,
    'appSettingProps.isAnimateToPage' => s.tabAnimation,
    'appSettingProps.onlyStatisticsProxy' => s.onlyStatisticsProxy,
    'appSettingProps.showLabel' => '${s.show} · ${s.name}',
    'appSettingProps.showTrayTitle' => s.speedStatistics,
    'windowProps.width' || 'windowProps.height' => s.aiReviewWindowSize,
    'windowProps.top' || 'windowProps.left' => s.aiReviewWindowPosition,
    'proxiesStyleProps.type' => s.proxyType,
    'proxiesStyleProps.sortType' => s.sort,
    'proxiesStyleProps.layout' => s.layout,
    'proxiesStyleProps.iconStyle' => s.iconStyle,
    'proxiesStyleProps.cardType' => s.size,
    'connections' => s.connections,
    'profiles' => s.profiles,
    'nodes' => s.proxies,
    'latency' || 'delay' => s.delay,
    'rules' => s.rule,
    'upload' => s.upload,
    'download' => s.download,
    'remainingBytes' => s.policySourceQuota,
    _ => field.startsWith('patchClashConfig.dns.') ? s.aiReviewDns : null,
  };
}

String _value(
  AppLocalizations s,
  String field,
  Object? raw, {
  Map labels = const {},
  bool before = false,
}) {
  if (_sensitive(field)) return '••••';
  if (raw == null) return s.defaultText;
  if (field == 'ai.selectedConnectionId') {
    final side = labels[before ? 'before' : 'after'];
    final name = side is Map ? side['$raw'] : null;
    return name is String ? _safe(name) : s.aiReviewUnknownValue;
  }
  if (field == 'provider') {
    return agentProviderPresets['$raw'] ?? s.aiCustomProvider;
  }
  if ({
    'fileGrantId',
    'id',
    'operationId',
    'nodeSetId',
    'scriptId',
  }.contains(field)) {
    final label = labels[field];
    return label is String ? _safe(label) : s.aiReviewUnknownValue;
  }
  if (field == 'option') {
    return raw == 'onlyProfiles' ? s.restoreOnlyConfig : s.restoreAllData;
  }
  if (field == 'all' && raw is bool) {
    return raw ? s.allTraffic : '${s.selected} · ${s.connections}';
  }
  if (field == 'visible' && raw is bool) {
    return raw ? s.show : s.aiReviewHideApplication;
  }
  if (field == 'mode' && raw == 'read') return s.aiReviewReadFile;
  if (field == 'mode' && raw == 'write') return s.aiReviewWriteFile;
  if (field == 'kind') {
    final kind = switch (raw) {
      'ai' => s.aiSettingsTitle,
      'cli' => s.aiReviewCliCredentials,
      'notification' => s.messageTest,
      'logs' => s.logsTest,
      'core_crash' => s.crashTest,
      'windows_loopback' => 'Windows',
      'android_access' => 'Android',
      _ => null,
    };
    if (kind != null) return kind;
  }
  if (field == 'operation' || field == 'action') {
    final action = switch (raw) {
      'add' || 'create' => s.add,
      'refresh' || 'update' => s.update,
      'delete' || 'remove' => s.delete,
      'backup' => s.backup,
      'restore' => s.restore,
      _ => null,
    };
    if (action != null) return action;
  }
  if (field.endsWith('ProfileId') ||
      {'profileId', 'integrationId'}.contains(field)) {
    final label =
        labels['${before ? 'before' : 'after'}.$field'] ??
        labels['$field:$raw'] ??
        (before ? null : labels[field]);
    return label is String ? _safe(label) : s.unknownProfile;
  }
  if (raw is bool) {
    return raw ? s.aiPolicyChangeEnabled : s.aiPolicyChangeDisabled;
  }
  if (raw is num) return '$raw';
  if (raw is List) {
    if (field == 'ids') {
      return raw
          .take(4)
          .map(
            (id) => labels['profile.$id'] is String
                ? _safe(labels['profile.$id'] as String)
                : s.unknownProfile,
          )
          .join(' / ');
    }
    if (raw.every((value) => value is String || value is num)) {
      if (raw.isEmpty) return s.aiPolicyChangeEmpty;
      final text = raw.take(4).map((value) => _safe('$value')).join(' / ');
      return '$text${raw.length > 4 ? ' / ${s.aiPolicyChangeMore('${raw.length - 4}')}' : ''}';
    }
    return s.aiPolicyChangeReferences('${raw.length}');
  }
  if ({'profile', 'script'}.contains(field) && raw is Map) {
    return raw['label'] is String ? _safe(raw['label'] as String) : s.unnamed;
  }
  if (raw is Map) return s.aiReviewChanged;
  final value = '$raw';
  if (field.endsWith('.locale')) {
    return switch (value) {
      'en' => s.en,
      'zh_CN' => s.zh_CN,
      'ja' => s.ja,
      'ru' => s.ru,
      _ => s.system,
    };
  }
  if (field.endsWith('.themeMode')) {
    return switch (value) {
      'light' => s.light,
      'dark' => s.dark,
      _ => s.system,
    };
  }
  if (field.endsWith('.routeMode')) {
    return value == 'bypassPrivate'
        ? s.routeMode_bypassPrivate
        : s.routeMode_config;
  }
  if (field == 'mode' || field.endsWith('.mode')) {
    return switch (value) {
      'global' => s.global,
      'rule' => s.rule,
      'direct' => s.direct,
      _ => _safe(value),
    };
  }
  if (field == 'running' || field == 'coreStatus') {
    return switch (value) {
      'connected' => s.start,
      'disconnected' => s.stop,
      _ => s.status,
    };
  }
  return _safe(value);
}

List<AiReviewRow> aiReviewRows(
  AppLocalizations s,
  ConfigurationProposal proposal,
) {
  final metadata = proposal.validation['agentReview'];
  if (metadata is Map) {
    final before = metadata['before'] is Map
        ? metadata['before'] as Map
        : const {};
    final after = metadata['after'] is Map
        ? metadata['after'] as Map
        : const {};
    final labels = metadata['labels'] is Map
        ? metadata['labels'] as Map
        : const {};
    final rows = <AiReviewRow>[];
    for (final field in {...before.keys, ...after.keys}.whereType<String>()) {
      final label = aiReviewFieldLabel(s, field);
      if (label == null || _sensitive(field)) continue;
      rows.add(
        AiReviewRow(
          label,
          _value(s, field, after[field], labels: labels),
          before: before.containsKey(field) && before[field] != after[field]
              ? _value(s, field, before[field], labels: labels, before: true)
              : null,
        ),
      );
    }
    if (rows.isEmpty) {
      rows.add(
        AiReviewRow(
          s.aiReviewActionScope,
          aiReviewCommandTitle(s, '${metadata['command']}'),
        ),
      );
    }
    return rows;
  }
  final connectionNames = <String, Map<String, String>>{
    'before': {},
    'after': {},
  };
  for (final difference in proposal.differences.where(
    (change) => change.path == 'ai.connections',
  )) {
    for (final side in ['before', 'after']) {
      final values = side == 'before' ? difference.before : difference.after;
      if (values is! List) continue;
      for (final connection in values.whereType<Map>()) {
        if (connection['id'] != null && connection['label'] is String) {
          connectionNames[side]!['${connection['id']}'] =
              connection['label'] as String;
        }
      }
    }
  }
  final savedNames = proposal.validation['aiReviewConnections'];
  if (savedNames is Map) {
    for (final side in ['before', 'after']) {
      final names = savedNames[side];
      if (names is! Map) continue;
      for (final entry in names.entries) {
        if (entry.value is String) {
          connectionNames[side]!['${entry.key}'] = entry.value as String;
        }
      }
    }
  }
  return [
    if (proposal.validation['reviewTarget'] case final String target)
      AiReviewRow(s.aiReviewTarget, _safe(target)),
    for (final indexed in proposal.differences.indexed)
      if (_resourceRows(s, indexed.$2) case final List<AiReviewRow> rows)
        ...rows
      else if (!const {
        'profile.id',
        'script.id',
        'scope.id',
        'policyRevision',
        'settingsSignature',
        'otherContextSignature',
      }.contains(indexed.$2.path))
        AiReviewRow(
          indexed.$2.path.startsWith('protected')
              ? s.aiReviewContent
              : _sensitive(indexed.$2.path)
              ? s.aiReviewSensitiveValue
              : aiReviewFieldLabel(s, indexed.$2.path) ??
                    '${s.aiReviewOtherSetting} ${indexed.$1 + 1}',
          indexed.$2.path.startsWith('protected')
              ? s.aiReviewChanged
              : _sensitive(indexed.$2.path)
              ? '••••'
              : aiReviewFieldLabel(s, indexed.$2.path) == null
              ? s.aiReviewChanged
              : _value(
                  s,
                  indexed.$2.path,
                  indexed.$2.after,
                  labels: connectionNames,
                ),
          before:
              indexed.$2.before == null ||
                  indexed.$2.path.startsWith('protected')
              ? null
              : _sensitive(indexed.$2.path)
              ? '••••'
              : aiReviewFieldLabel(s, indexed.$2.path) == null
              ? null
              : _value(
                  s,
                  indexed.$2.path,
                  indexed.$2.before,
                  before: true,
                  labels: connectionNames,
                ),
        ),
  ];
}

String _ruleMatch(AppLocalizations s, Map rule) {
  final type = switch (rule['ruleAction'] ?? rule['type']) {
    'DOMAIN' || 'domain' => s.policyDomainScope,
    'DOMAIN_SUFFIX' ||
    'DOMAIN-SUFFIX' ||
    'domainSuffix' => s.policyDomainSuffix,
    'DOMAIN_KEYWORD' ||
    'DOMAIN-KEYWORD' ||
    'domainKeyword' => s.policyDomainKeyword,
    'PROCESS_NAME' || 'PROCESS-NAME' => s.policyProcessName,
    'PROCESS_PATH' || 'PROCESS-PATH' => s.policyProcessPath,
    'MATCH' || 'match' => s.policyRemainingTraffic,
    'GEOIP' => 'GeoIP',
    'GEOSITE' => 'GeoSite',
    'IP_CIDR' || 'IP_CIDR6' || 'IP-CIDR' || 'IP-CIDR6' => 'IP',
    _ => s.aiPolicyFilterConditions,
  };
  final content = rule['content'];
  return content is String && content.isNotEmpty
      ? '$type: ${_safe(content)}'
      : type;
}

String _ruleRoute(AppLocalizations s, Map rule) {
  final target = switch (rule['ruleTarget'] ?? rule['target']) {
    'DIRECT' => s.direct,
    'REJECT' || 'REJECT-DROP' => s.policyActionReject,
    final String name => _safe(name),
    _ => s.aiReviewUnknownValue,
  };
  return '${_ruleMatch(s, rule)} → $target';
}

String _groupMembers(AppLocalizations s, Map group) {
  String list(Object? raw) {
    if (raw is! List || raw.isEmpty) return s.aiPolicyChangeEmpty;
    final text = raw.whereType<String>().take(4).map(_safe).join(' / ');
    return '$text${raw.length > 4 ? ' / ${s.aiPolicyChangeMore('${raw.length - 4}')}' : ''}';
  }

  return '${list(group['proxies'])}${group['use'] is List && (group['use'] as List).isNotEmpty ? ' · ${s.policySources}: ${list(group['use'])}' : ''}';
}

List<AiReviewRow>? _resourceRows(
  AppLocalizations s,
  ConfigurationDifference difference,
) {
  if (difference.path == 'ai.connections' &&
      difference.before is List &&
      difference.after is List) {
    Map<Object, Map> index(List values) => {
      for (final item in values.whereType<Map>())
        if (item['id'] case final Object id) id: item,
    };
    final old = index(difference.before as List);
    final next = index(difference.after as List);
    final rows = <AiReviewRow>[];
    for (final entry in old.entries) {
      if (!next.containsKey(entry.key)) {
        rows.add(
          AiReviewRow(
            s.aiPolicyChangeRemoved(
              s.aiConnection,
              _safe('${entry.value['label'] ?? s.unnamed}'),
            ),
            s.delete,
          ),
        );
      }
    }
    for (final entry in next.entries) {
      final before = old[entry.key];
      final name = _safe('${entry.value['label'] ?? s.unnamed}');
      if (before == null) {
        rows.add(
          AiReviewRow(s.aiPolicyChangeAdded(s.aiConnection, name), s.add),
        );
      }
      for (final field in [
        'label',
        'provider',
        'model',
        'baseUrl',
        'api',
        'useProxy',
        'timeoutSeconds',
        'maxTokens',
      ]) {
        if (before != null &&
            const DeepCollectionEquality().equals(
              before[field],
              entry.value[field],
            )) {
          continue;
        }
        rows.add(
          AiReviewRow(
            '${s.aiConnection} · $name · ${aiReviewFieldLabel(s, field)}',
            _value(s, field, entry.value[field]),
            before: before == null ? null : _value(s, field, before[field]),
          ),
        );
      }
    }
    return rows.length <= 24
        ? rows
        : [
            ...rows.take(23),
            AiReviewRow(
              s.more,
              s.aiPolicyChangeMore('${rows.length - 23}'),
              changeCount: rows.length - 23,
            ),
          ];
  }
  if ({'profile', 'script'}.contains(difference.path) &&
      (difference.before == null || difference.after == null)) {
    final added = difference.before == null;
    final resource = added ? difference.after : difference.before;
    if (resource is! Map) return null;
    final kind = difference.path == 'profile' ? s.profiles : s.script;
    final name = _safe('${resource['label'] ?? resource['name'] ?? s.unnamed}');
    return [
      AiReviewRow(s.aiReviewTarget, name),
      AiReviewRow(
        s.action,
        added
            ? s.aiPolicyChangeAdded(kind, name)
            : s.aiPolicyChangeRemoved(kind, name),
      ),
      if (difference.path == 'profile' &&
          resource['url'] is String &&
          (resource['url'] as String).isNotEmpty)
        AiReviewRow(s.url, _safe(resource['url'] as String)),
    ];
  }
  final groups = difference.path == 'groups';
  if (!groups &&
      !{
        'addedRules',
        'customRules',
        'disabledRules',
      }.contains(difference.path)) {
    return null;
  }
  if (difference.before is! List || difference.after is! List) return null;
  Map<Object, Map> index(List raw) => {
    for (final item in raw.whereType<Map>())
      if (item['id'] ?? item['name'] case final Object id) id: item,
  };
  final before = index(difference.before as List);
  final after = index(difference.after as List);
  final kind = groups
      ? s.proxyGroup
      : difference.path == 'disabledRules'
      ? '${s.rule} (${s.aiPolicyChangeDisabled})'
      : s.rule;
  String label(Map item) =>
      groups ? _safe('${item['name'] ?? s.unnamed}') : _ruleMatch(s, item);
  String details(Map item) =>
      groups ? _groupMembers(s, item) : _ruleRoute(s, item);
  final rows = <AiReviewRow>[];
  var total = 0;
  void add(AiReviewRow row) {
    total++;
    if (rows.length < 23) rows.add(row);
  }

  for (final entry in before.entries) {
    if (!after.containsKey(entry.key)) {
      add(
        AiReviewRow(
          s.aiPolicyChangeRemoved(kind, label(entry.value)),
          details(entry.value),
        ),
      );
    }
  }
  for (final entry in after.entries) {
    final old = before[entry.key];
    if (old == null) {
      add(
        AiReviewRow(
          s.aiPolicyChangeAdded(kind, label(entry.value)),
          details(entry.value),
        ),
      );
      continue;
    }
    Map comparable(Map item) => Map.from(item)
      ..remove('id')
      ..remove('profileId')
      ..remove('order');
    if (const DeepCollectionEquality().equals(
      comparable(old),
      comparable(entry.value),
    )) {
      continue;
    }
    if (groups && old['name'] != entry.value['name']) {
      add(
        AiReviewRow(
          '$kind · ${s.name}',
          label(entry.value),
          before: label(old),
        ),
      );
    }
    if (!groups || details(old) != details(entry.value)) {
      add(
        AiReviewRow(
          '$kind · ${label(entry.value)}',
          details(entry.value),
          before: details(old),
        ),
      );
    } else if (groups && old['name'] == entry.value['name']) {
      add(AiReviewRow('$kind · ${label(entry.value)}', s.aiReviewChanged));
    }
  }
  if (total > rows.length) {
    rows.add(
      AiReviewRow(
        s.more,
        s.aiPolicyChangeMore('${total - rows.length}'),
        changeCount: total - rows.length,
      ),
    );
  }
  return rows;
}

List<AiReviewRow> aiReadableResultRows(
  AppLocalizations s,
  Map<String, Object?> result,
) {
  final nested = result['result'];
  final values = {
    ...result,
    if (nested is Map)
      for (final entry in nested.entries) '${entry.key}': entry.value,
  };
  return [
    for (final entry in values.entries)
      if (aiReviewFieldLabel(s, entry.key) case final String label)
        if (!_sensitive(entry.key))
          AiReviewRow(label, _value(s, entry.key, entry.value)),
  ].take(6).toList();
}

class AiReviewRowsView extends StatelessWidget {
  const AiReviewRowsView({super.key, required this.rows, this.compact = false});
  final List<AiReviewRow> rows;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final limit = compact ? 4 : 24;
    final remaining = rows
        .skip(limit)
        .fold<int>(0, (sum, row) => sum + row.changeCount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in rows.take(limit))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    children: [
                      if (row.before != null)
                        TextSpan(
                          text: '${row.before} → ',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      TextSpan(text: row.after),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (remaining > 0)
          Text(context.appLocalizations.aiPolicyChangeMore('$remaining')),
      ],
    );
  }
}

class AiProposalReviewBody extends StatelessWidget {
  const AiProposalReviewBody({
    super.key,
    required this.proposal,
    this.compact = false,
  });
  final ConfigurationProposal proposal;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = context.appLocalizations;
    final sourceOnly =
        proposal.validation['executionOnly'] != true &&
        proposal.validation['finalConfigDifferences'] == null &&
        proposal.differences.every(
          (change) =>
              change.path == 'policies.revision' ||
              change.path == 'policies.integrations' ||
              change.path.startsWith('policies.integrations.'),
        );
    final source = sourceOnly
        ? LocalSourceChangeSummary.tryParse(
            proposal.validation[localSourceChangeValidationKey],
          )
        : null;
    final policies =
        proposal.differences.isNotEmpty &&
        proposal.differences.every(
          (change) => change.path.startsWith('policies.'),
        );
    if (source != null) return LocalSourceChangeSummaryView(summary: source);
    if (policies) {
      return aiPolicyPlan(context, proposal) != null
          ? AiPolicyPlanView(proposal: proposal, compact: compact)
          : AiPolicyChangeOverview(proposal: proposal, compact: compact);
    }
    final rows = aiReviewRows(s, proposal);
    final metadata = proposal.validation['agentReview'];
    final fetching =
        metadata is Map &&
        const {
          'profile_propose',
          'profiles_refresh_all',
        }.contains(metadata['command']);
    if (fetching) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.aiReviewFetchThenApply,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          AiReviewRowsView(rows: rows, compact: compact),
        ],
      );
    }
    return rows.isEmpty
        ? Text(s.aiNoDifferences)
        : AiReviewRowsView(rows: rows, compact: compact);
  }
}
