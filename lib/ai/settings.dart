import 'package:fl_clash/policy/models.dart';

import 'runtime.dart';

const agentProviderPresets = <String, String>{
  'glm-cn': 'GLM · CN API',
  'glm-coding-cn': 'GLM · CN Coding',
  'glm-global': 'GLM · Global API',
  'glm-coding-global': 'GLM · Global Coding',
  'kimi-cn': 'Kimi · CN API',
  'kimi-global': 'Kimi · Global API',
  'kimi-coding': 'Kimi · Coding',
  'deepseek': 'DeepSeek',
  'openai': 'OpenAI',
  'anthropic': 'Claude',
  'xai': 'Grok',
  'custom': 'Custom',
};

final class AgentConnection {
  final String id;
  final String label;
  final String provider;
  final String model;
  final String baseUrl;
  final String api;
  final bool useProxy;
  final int timeoutSeconds;
  final int maxTokens;

  const AgentConnection({
    required this.id,
    required this.label,
    required this.provider,
    required this.model,
    this.baseUrl = '',
    this.api = 'openai-completions',
    this.useProxy = false,
    this.timeoutSeconds = 90,
    this.maxTokens = 4096,
  });

  String get credentialId =>
      'connection-$id-${policyDigest({'provider': provider, 'baseUrl': baseUrl.isEmpty ? '' : Uri.parse(baseUrl).normalizePath().toString(), 'api': api}).substring(0, 16)}';

  factory AgentConnection.fromJson(Map<String, Object?> json) {
    policyKeys(json, {
      'id',
      'label',
      'provider',
      'model',
      'baseUrl',
      'api',
      'useProxy',
      'timeoutSeconds',
      'maxTokens',
    });
    final id = policyString(json, 'id', maximum: 64);
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id)) {
      throw const FormatException('Invalid AI connection ID');
    }
    final provider = policyString(json, 'provider', maximum: 64);
    if (!agentProviderPresets.containsKey(provider)) {
      throw const FormatException('Unsupported AI provider');
    }
    final model = policyString(json, 'model', maximum: 200);
    final label = policyString(json, 'label', maximum: 200);
    if (model.trim().isEmpty || label.trim().isEmpty) {
      throw const FormatException('AI model and label are required');
    }
    final url = policyString(json, 'baseUrl', fallback: '');
    if (url.isNotEmpty || provider == 'custom') {
      final uri = Uri.tryParse(url);
      if (uri == null ||
          !{'http', 'https'}.contains(uri.scheme) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment ||
          (uri.scheme == 'http' &&
              (provider != 'custom' ||
                  !{'localhost', '127.0.0.1', '::1'}.contains(uri.host)))) {
        throw const FormatException(
          'AI endpoints require HTTPS or a local HTTP service',
        );
      }
    }
    final api = policyString(json, 'api', fallback: 'openai-completions');
    if (!{
      'openai-completions',
      'openai-responses',
      'anthropic-messages',
    }.contains(api)) {
      throw const FormatException('Unsupported AI API protocol');
    }
    return AgentConnection(
      id: id,
      label: label,
      provider: provider,
      model: model,
      baseUrl: url,
      api: api,
      useProxy: policyBool(json, 'useProxy'),
      timeoutSeconds: policyInt(
        json,
        'timeoutSeconds',
        fallback: 90,
        minimum: 5,
        maximum: 300,
      ),
      maxTokens: policyInt(
        json,
        'maxTokens',
        fallback: 4096,
        minimum: 64,
        maximum: 32768,
      ),
    );
  }

  AgentConnectionSettings runtimeSettings({required int mixedPort}) =>
      AgentConnectionSettings(
        provider: provider,
        model: model,
        baseUrl: baseUrl,
        api: api,
        timeoutSeconds: timeoutSeconds,
        maxTokens: maxTokens,
        proxyUrl: useProxy ? 'http://127.0.0.1:$mixedPort' : null,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'provider': provider,
    'model': model,
    'baseUrl': baseUrl,
    'api': api,
    'useProxy': useProxy,
    'timeoutSeconds': timeoutSeconds,
    'maxTokens': maxTokens,
  };
}

final class AgentSettings {
  final int schemaVersion;
  final bool enabled;
  final String? selectedConnectionId;
  final List<AgentConnection> connections;

  const AgentSettings({
    this.schemaVersion = 1,
    this.enabled = false,
    this.selectedConnectionId,
    this.connections = const [],
  });

  AgentConnection? get selected {
    for (final connection in connections) {
      if (connection.id == selectedConnectionId) return connection;
    }
    return null;
  }

  factory AgentSettings.fromJson(Map<String, Object?> json) {
    policyKeys(json, {
      'schemaVersion',
      'enabled',
      'selectedConnectionId',
      'connections',
    });
    final version = policyInt(json, 'schemaVersion', fallback: 1, minimum: 1);
    if (version != 1) {
      throw const FormatException('Unsupported AI settings version');
    }
    final selected = json['selectedConnectionId'];
    if (selected != null && selected is! String) {
      throw const FormatException('Invalid selected AI connection');
    }
    final connections = policyItems(
      json,
      'connections',
      AgentConnection.fromJson,
      maximum: 20,
    );
    if (connections.map((entry) => entry.id).toSet().length !=
        connections.length) {
      throw const FormatException('Duplicate AI connections');
    }
    final settings = AgentSettings(
      schemaVersion: version,
      enabled: policyBool(json, 'enabled'),
      selectedConnectionId: selected as String?,
      connections: connections,
    );
    if (settings.enabled && settings.selected == null) {
      throw const FormatException('Select an AI connection before enabling AI');
    }
    return settings;
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'enabled': enabled,
    'selectedConnectionId': selectedConnectionId,
    'connections': connections.map((entry) => entry.toJson()).toList(),
  };
}
