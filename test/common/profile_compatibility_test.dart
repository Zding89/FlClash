import 'dart:convert';

import 'package:fl_clash/common/profile_compatibility.dart';
import 'package:fl_clash/common/task.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/policy/compiler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test(
    'legacy fingerprint migrates to inline proxies without changing input',
    () {
      final source = <String, dynamic>{
        'global-client-fingerprint': 'chrome',
        'proxies': [
          {'name': 'inherited', 'type': 'vless'},
          {
            'name': 'specific',
            'type': 'vless',
            'client-fingerprint': 'firefox',
          },
          {'name': 'explicit-empty', 'type': 'vless', 'client-fingerprint': ''},
        ],
      };
      final before = jsonEncode(source);
      final result = normalizeLegacyClientFingerprint(source);
      expect(result.containsKey('global-client-fingerprint'), isFalse);
      expect((result['proxies'] as List).map((p) => p['client-fingerprint']), [
        'chrome',
        'firefox',
        '',
      ]);
      expect(jsonEncode(source), before);
      expect(normalizeLegacyClientFingerprint(result), result);
    },
  );

  test('provider defaults preserve overrides and apply to refreshed nodes', () {
    for (final type in ['http', 'file', 'inline']) {
      final source = <String, dynamic>{
        'global-client-fingerprint': 'chrome',
        'proxy-providers': {
          'airport': {
            'type': type,
            'url': 'https://example.com/provider',
            'path': './provider.yaml',
            'payload': [
              {'name': 'HK', 'type': 'vless'},
            ],
            'override': {
              'additional-prefix': 'Airport ',
              'override-expr': [
                '.udp = true',
                '.client-fingerprint = "firefox"',
              ],
            },
          },
        },
      };
      final original = jsonEncode(source);
      final result = normalizeLegacyClientFingerprint(source);
      final provider = result['proxy-providers']['airport'];
      expect(provider['override']['additional-prefix'], 'Airport ');
      expect(provider['override']['override-expr'], [
        '.udp = true',
        '.client-fingerprint = "firefox"',
        '.client-fingerprint = .client-fingerprint // "chrome"',
      ]);
      expect(provider['type'], type);
      expect(jsonEncode(source), original);
    }
  });

  test('missing and empty legacy setting do not add proxy defaults', () {
    for (final value in [null, '']) {
      final result = normalizeLegacyClientFingerprint({
        'global-client-fingerprint': value,
        'proxies': [
          {'name': 'HK', 'type': 'ss'},
        ],
      });
      expect(result.containsKey('global-client-fingerprint'), isFalse);
      expect(
        result['proxies'].single.containsKey('client-fingerprint'),
        isFalse,
      );
    }
    expect(
      () => normalizeLegacyClientFingerprint({'global-client-fingerprint': 7}),
      throwsFormatException,
    );
  });

  test('provider default expression escapes the legacy value as data', () {
    const fingerprint = 'chrome" | .udp = false';
    final result = normalizeLegacyClientFingerprint({
      'global-client-fingerprint': fingerprint,
      'proxy-providers': {
        'p': {'type': 'inline', 'payload': []},
      },
    });
    expect(result['proxy-providers']['p']['override']['override-expr'], [
      '.client-fingerprint = .client-fingerprint // ${jsonEncode(fingerprint)}',
    ]);
  });

  test(
    'local nodes inherit per-source defaults while retaining stable IDs',
    () {
      const compiler = LocalPolicyCompiler();
      final proxy = <String, Object?>{
        'name': 'HK',
        'type': 'vless',
        'server': 'example.com',
        'port': 443,
      };
      PolicySource source(String id, String? fingerprint) => PolicySource(
        id: id,
        label: id,
        raw: {
          'proxies': [proxy],
          'global-client-fingerprint': ?fingerprint,
        },
      );
      final prior = compiler.extractNodes(source('one', null)).single;
      final chrome = compiler.extractNodes(source('one', 'chrome')).single;
      final firefox = compiler.extractNodes(source('two', 'firefox')).single;
      expect(chrome.id, prior.id);
      expect(chrome.raw['client-fingerprint'], 'chrome');
      expect(firefox.raw['client-fingerprint'], 'firefox');
      expect(proxy.containsKey('client-fingerprint'), isFalse);
    },
  );

  test('runtime profile generation removes the deprecated key', () async {
    final raw = <String, dynamic>{
      'global-client-fingerprint': 'chrome',
      'proxies': [
        {'name': 'HK', 'type': 'vless'},
      ],
      'rules': ['MATCH,DIRECT'],
    };
    final generated = await makeRealProfileTask(
      MakeRealProfileState(
        profilesPath: '/profiles',
        profileId: 7,
        rawConfig: raw,
        realPatchConfig: const PatchClashConfig(),
        overrideDns: false,
        appendSystemDns: false,
        proxyGroups: const [],
        rules: const [],
        addedRules: const [],
        defaultUA: 'FlClash-Test',
      ),
    );
    final parsed = loadYaml(generated.a) as YamlMap;
    expect(parsed.containsKey('global-client-fingerprint'), isFalse);
    expect(parsed['proxies'].single['client-fingerprint'], 'chrome');
    expect(raw['global-client-fingerprint'], 'chrome');
  });
}
