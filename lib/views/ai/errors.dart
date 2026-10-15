import 'package:fl_clash/ai/credentials.dart';
import 'package:fl_clash/ai/runtime.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

String aiErrorText(BuildContext context, Object? error) {
  final strings = context.appLocalizations;
  if (error is LegacyCredentialMigrationException) {
    return strings.aiCredentialMigrationRequired;
  }
  if (error is MissingAgentCredentialException) {
    return strings.aiKeyMissing;
  }
  if (error is PolicySourceException) {
    return strings.policyUnsupportedSourceOption(error.option);
  }
  final code = switch (error) {
    AgentRuntimeException(:final code) => code,
    ConfigurationChangeException(:final code) => code,
    SourceDownloadException(:final code) => code,
    PlatformException(:final code) => code,
    MissingPluginException() => 'keychainFailure',
    StateError() => error.message.toString(),
    String() => error,
    _ => '',
  };
  if (error is FormatException) {
    return strings.aiConfigurationInvalid;
  }
  if (error is ConfigurationChangeException &&
      code.startsWith('configuration_') &&
      code != 'configuration_cancelled') {
    return strings.aiConfigurationSaveFailed;
  }
  return switch (code) {
    'authenticationFailed' => strings.aiAuthFailed,
    'quotaExceeded' => strings.aiQuotaExceeded,
    'rateLimited' => strings.aiRateLimited,
    'timeout' || 'requestTimeout' => strings.aiTimedOut,
    'contextLimit' || 'outputLimit' || 'turnLimit' => strings.aiHistoryLimit,
    'keychainFailure' ||
    'invalidCredentialId' ||
    'invalidSecret' => strings.aiCredentialUnavailable,
    'keyMissing' => strings.aiKeyMissing,
    'aiHostNotPackaged' ||
    'hostExited' ||
    'runtimeClosed' ||
    'runtimeUnavailable' => strings.aiHostUnavailable,
    'cancelled' || 'configuration_cancelled' => strings.aiCancelled,
    'configuration_version_conflict' ||
    'configuration_snapshot_expired' => strings.aiDraftInvalid,
    'source_update_proxy_unavailable' => strings.policyUpdateProxyUnavailable,
    'source_download_network_failed' => strings.networkException,
    _ => strings.aiRequestFailed,
  };
}
