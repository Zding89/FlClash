import 'dart:convert';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:flutter/material.dart';

final class SettingCapability {
  final String path;
  final String type;
  final bool highRisk;
  final bool nullable;
  final List<Object?>? values;
  final num? minimum;
  final num? maximum;
  final bool zeroMeansDefault;

  const SettingCapability({
    required this.path,
    required this.type,
    this.highRisk = false,
    this.nullable = false,
    this.values,
    this.minimum,
    this.maximum,
    this.zeroMeansDefault = false,
  });

  Map<String, Object?> toJson() => {
    'path': path,
    'type': type,
    'highRisk': highRisk,
    'nullable': nullable,
    if (values != null) 'allowedValues': values,
    if (minimum != null) 'minimum': minimum,
    if (maximum != null) 'maximum': maximum,
    if (zeroMeansDefault) 'zeroMeansDefault': true,
  };

  void validate(Object? value) {
    if (value == null && nullable) return;
    if (zeroMeansDefault && value == 0) return;
    final validType = switch (type) {
      'boolean' => value is bool,
      'integer' => value is int,
      'number' => value is num && value.isFinite,
      'string' => value is String && value.length <= 4096,
      'array' => value is List && value.length <= 500,
      'object' => value is Map && value.length <= 500,
      _ => false,
    };
    if (!validType ||
        (values != null && !values!.contains(value)) ||
        (minimum != null && value is num && value < minimum!) ||
        (maximum != null && value is num && value > maximum!)) {
      throw FormatException('Invalid value for $path');
    }
  }
}

Map<String, Object?> configJson(Config config) =>
    policyObject(jsonDecode(jsonEncode(config)), 'config');

String configurationDigest(Object? value, [String path = '']) {
  bool isDavPassword(String value) {
    return value == 'davProps.password' || value == 'config.davProps.password';
  }

  Object? normalize(Object? entry, String currentPath) {
    if (isDavPassword(currentPath) && (entry is String || entry == null)) {
      return davPasswordFingerprint(entry as String? ?? '');
    }
    if (entry is Map) {
      return {
        for (final item in entry.entries)
          '${item.key}': normalize(
            item.value,
            currentPath.isEmpty ? '${item.key}' : '$currentPath.${item.key}',
          ),
      };
    }
    if (entry is List) {
      return entry.map((item) => normalize(item, currentPath)).toList();
    }
    return entry;
  }

  return policyDigest(normalize(value, path));
}

final class SettingsCatalog {
  late final Map<String, SettingCapability> capabilities = _build();

  Map<String, SettingCapability> _build() {
    final defaults = configJson(const Config(themeProps: defaultThemeProps));
    final result = <String, SettingCapability>{};
    void collect(Object? value, String path) {
      if (path.startsWith('vpnProps.') ||
          path == 'appSettingProps.disclaimerAccepted' ||
          path == 'appSettingProps.crashlyticsTip' ||
          path == 'patchClashConfig.tun.auto-route' ||
          path == 'patchClashConfig.tun.route-address') {
        return;
      }
      final mapValues = {
        'patchClashConfig.hosts',
        'patchClashConfig.dns.nameserver-policy',
        'patchClashConfig.geox-url',
      };
      if (value is Map && !mapValues.contains(path)) {
        for (final entry in value.entries) {
          collect(
            entry.value,
            path.isEmpty ? '${entry.key}' : '$path.${entry.key}',
          );
        }
        return;
      }
      final type = value is bool
          ? 'boolean'
          : value is int
          ? 'integer'
          : value is num
          ? 'number'
          : value is List
          ? 'array'
          : value is Map
          ? 'object'
          : 'string';
      final risk =
          path.startsWith('patchClashConfig.') ||
          path.startsWith('networkProps.') ||
          path.startsWith('davProps') ||
          path == 'appSettingProps.autoRun' ||
          path == 'appSettingProps.crashlytics';
      result[path] = SettingCapability(
        path: path,
        type: type,
        nullable: value == null,
        highRisk: risk,
      );
    }

    collect(defaults, '');
    void enumField<T extends Enum>(
      String path,
      List<T> values, [
      String Function(T)? wireValue,
    ]) {
      final current = result[path]!;
      result[path] = SettingCapability(
        path: path,
        type: 'string',
        highRisk: current.highRisk,
        values: values
            .map((value) => wireValue?.call(value) ?? value.name)
            .toList(),
      );
    }

    enumField('appSettingProps.restoreStrategy', RestoreStrategy.values);
    enumField('networkProps.routeMode', RouteMode.values);
    enumField('themeProps.themeMode', ThemeMode.values);
    enumField('themeProps.schemeVariant', DynamicSchemeVariant.values);
    enumField('proxiesStyleProps.type', ProxiesType.values);
    enumField('proxiesStyleProps.sortType', ProxiesSortType.values);
    enumField('proxiesStyleProps.layout', ProxiesLayout.values);
    enumField('proxiesStyleProps.iconStyle', ProxiesIconStyle.values);
    enumField('proxiesStyleProps.cardType', ProxyCardType.values);
    enumField('patchClashConfig.mode', Mode.values);
    enumField('patchClashConfig.log-level', LogLevel.values);
    enumField('patchClashConfig.find-process-mode', FindProcessMode.values);
    enumField('patchClashConfig.tun.stack', TunStack.values);
    enumField(
      'patchClashConfig.dns.enhanced-mode',
      DnsMode.values,
      (value) => switch (value) {
        DnsMode.fakeIp => 'fake-ip',
        DnsMode.redirHost => 'redir-host',
        _ => value.name,
      },
    );
    enumField('patchClashConfig.geodata-loader', GeodataLoader.values);
    enumField(
      'patchClashConfig.external-controller',
      ExternalControllerStatus.values,
      (value) => value.value,
    );
    for (final key in [
      'mixed-port',
      'port',
      'socks-port',
      'redir-port',
      'tproxy-port',
    ]) {
      final path = 'patchClashConfig.$key';
      result[path] = SettingCapability(
        path: path,
        type: 'integer',
        highRisk: true,
        minimum: 0,
        maximum: 65535,
      );
    }
    result['currentProfileId'] = const SettingCapability(
      path: 'currentProfileId',
      type: 'integer',
      nullable: true,
      highRisk: true,
      minimum: 1,
    );
    result['themeProps.textScale.scale'] = const SettingCapability(
      path: 'themeProps.textScale.scale',
      type: 'number',
      minimum: 0.5,
      maximum: 3,
    );
    result['appSettingProps.locale'] = const SettingCapability(
      path: 'appSettingProps.locale',
      type: 'string',
      nullable: true,
      values: [null, 'en', 'zh_CN', 'ja', 'ru'],
    );
    result['davProps'] = const SettingCapability(
      path: 'davProps',
      type: 'object',
      highRisk: true,
      nullable: true,
    );
    for (final path in ['windowProps.width', 'windowProps.height']) {
      result[path] = SettingCapability(
        path: path,
        type: 'number',
        minimum: path.endsWith('width') ? 380 : 400,
        maximum: 8192,
        zeroMeansDefault: true,
      );
    }
    for (final path in ['windowProps.top', 'windowProps.left']) {
      result[path] = SettingCapability(
        path: path,
        type: 'number',
        nullable: true,
      );
    }
    return Map.unmodifiable(result);
  }

  Map<String, Object?> applyPatch(
    Map<String, Object?> current,
    Map<String, Object?> patch,
  ) {
    if (patch.isEmpty || patch.length > 100) {
      throw const FormatException('A setting patch requires 1–100 fields');
    }
    final result = policyObject(jsonDecode(jsonEncode(current)), 'config');
    for (final entry in patch.entries) {
      final capability = capabilities[entry.key];
      if (capability == null) {
        throw FormatException('Unsupported macOS setting: ${entry.key}');
      }
      capability.validate(entry.value);
      var cursor = result;
      final segments = entry.key.split('.');
      for (final segment in segments.take(segments.length - 1)) {
        cursor = cursor[segment] as Map<String, Object?>;
      }
      cursor[segments.last] = capability.type == 'number' && entry.value is num
          ? (entry.value as num).toDouble()
          : entry.value;
    }
    validate(result);
    return result;
  }

  Config validate(Map<String, Object?> value) {
    final defaults = configJson(const Config(themeProps: defaultThemeProps));
    void checkShape(Object? expected, Object? actual, String path) {
      if (expected is Map && actual is Map) {
        if ({
          'patchClashConfig.hosts',
          'patchClashConfig.dns.nameserver-policy',
          'patchClashConfig.geox-url',
        }.contains(path)) {
          if (actual.keys.any((key) => key is! String) ||
              actual.values.any((value) => value is! String)) {
            throw FormatException('Expected string map: $path');
          }
          return;
        }
        for (final key in actual.keys) {
          if (!expected.containsKey(key)) {
            throw FormatException('Unknown setting: $path.$key');
          }
        }
        for (final key in expected.keys) {
          if (!actual.containsKey(key)) {
            throw FormatException('Missing setting: $path.$key');
          }
          checkShape(
            expected[key],
            actual[key],
            path.isEmpty ? '$key' : '$path.$key',
          );
        }
      } else {
        final descriptor = capabilities[path];
        if (descriptor != null) descriptor.validate(actual);
      }
    }

    checkShape(defaults, value, '');
    final config = Config.fromJson(value);
    if ((config.windowProps.width == 0) != (config.windowProps.height == 0)) {
      throw const FormatException('Set both window dimensions together');
    }
    if (configurationDigest(configJson(config)) != configurationDigest(value)) {
      throw const FormatException(
        'Configuration contains values that cannot be represented',
      );
    }
    final ports = [
      config.patchClashConfig.mixedPort,
      config.patchClashConfig.port,
      config.patchClashConfig.socksPort,
      config.patchClashConfig.redirPort,
      config.patchClashConfig.tproxyPort,
    ].where((port) => port != 0).toList();
    if (ports.toSet().length != ports.length) {
      throw const FormatException('Listener ports must be distinct');
    }
    if (config.networkProps.systemProxy &&
        config.patchClashConfig.mixedPort == 0) {
      throw const FormatException(
        'System proxy requires an enabled mixed port',
      );
    }
    if (config.appSettingProps.testUrl.isNotEmpty) {
      final uri = Uri.tryParse(config.appSettingProps.testUrl);
      if (uri == null ||
          !{'http', 'https'}.contains(uri.scheme) ||
          uri.host.isEmpty) {
        throw const FormatException('Invalid test URL');
      }
    }
    return config;
  }

  bool highRisk(Map<String, Object?> before, Map<String, Object?> after) =>
      capabilities.values.any(
        (capability) =>
            capability.highRisk &&
            configurationDigest(
                  readPath(before, capability.path),
                  capability.path,
                ) !=
                configurationDigest(
                  readPath(after, capability.path),
                  capability.path,
                ),
      );

  Object? readPath(Map<String, Object?> value, String path) {
    Object? cursor = value;
    for (final segment in path.split('.')) {
      if (cursor is! Map) return null;
      cursor = cursor[segment];
    }
    return cursor;
  }

  Map<String, Object?> redact(Map<String, Object?> value) {
    final result = policyObject(jsonDecode(jsonEncode(value)), 'config');
    final dav = result['davProps'];
    if (dav is Map) {
      dav['password'] = null;
      dav['uri'] = _redactUrl(dav['uri']);
    }
    return result;
  }

  Object? _redactUrl(Object? value) {
    if (value is! String) return value;
    final uri = Uri.tryParse(value);
    return uri == null
        ? null
        : '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  }
}
