import 'dart:convert';

String? legacyClientFingerprint(Map<String, Object?> config) {
  final value = config['global-client-fingerprint'];
  if (value == null || value == '') return null;
  if (value is! String) {
    throw const FormatException('Invalid legacy client fingerprint');
  }
  return value;
}

Map<String, Object?> inheritLegacyClientFingerprint(
  Map<String, Object?> proxy,
  String? fingerprint,
) => {
  ...proxy,
  if (fingerprint != null && proxy['client-fingerprint'] == null)
    'client-fingerprint': fingerprint,
};

Map<String, dynamic> normalizeLegacyClientFingerprint(
  Map<String, dynamic> source,
) {
  final fingerprint = legacyClientFingerprint(source);
  final result = Map<String, dynamic>.from(source)
    ..remove('global-client-fingerprint');
  if (fingerprint == null) return result;
  final proxies = source['proxies'];
  if (proxies is List) {
    result['proxies'] = [
      for (final proxy in proxies)
        if (proxy is Map)
          inheritLegacyClientFingerprint(
            Map<String, Object?>.from(proxy),
            fingerprint,
          )
        else
          proxy,
    ];
  }
  final providers = source['proxy-providers'];
  if (providers is Map) {
    result['proxy-providers'] = {
      for (final entry in providers.entries)
        entry.key: _normalizeProvider(entry.value, fingerprint),
    };
  }
  return result;
}

Object? _normalizeProvider(Object? value, String fingerprint) {
  if (value is! Map) return value;
  final result = Map<String, Object?>.from(value);
  final override = value['override'];
  if (override != null && override is! Map) {
    throw const FormatException('Invalid provider override');
  }
  final overrides = override == null
      ? <String, Object?>{}
      : Map<String, Object?>.from(override as Map);
  final expressions = overrides['override-expr'];
  if (expressions != null && expressions is! List && expressions is! String) {
    throw const FormatException('Invalid provider override expressions');
  }
  result['override'] = {
    ...overrides,
    'override-expr': [
      if (expressions is List) ...expressions,
      if (expressions is String) expressions,
      '.client-fingerprint = .client-fingerprint // ${jsonEncode(fingerprint)}',
    ],
  };
  return result;
}
