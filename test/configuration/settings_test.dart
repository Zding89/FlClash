import 'package:fl_clash/configuration/settings.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalog = SettingsCatalog();
  Map<String, Object?> defaults() =>
      configJson(const Config(themeProps: defaultThemeProps));

  test(
    'fresh application defaults remain valid and unrelated settings can change',
    () {
      final config = catalog.validate(defaults());
      expect(config.windowProps.width, 0);
      expect(config.windowProps.size.width, 680);
      final patched = catalog.applyPatch(defaults(), {
        'appSettingProps.autoLaunch': true,
      });
      expect(catalog.validate(patched).appSettingProps.autoLaunch, true);
    },
  );

  test(
    'every declared enum value survives the actual Config JSON contract',
    () {
      for (final capability in catalog.capabilities.values) {
        final values = capability.values;
        if (values == null) continue;
        for (final value in values) {
          final patched = catalog.applyPatch(defaults(), {
            capability.path: value,
          });
          final normalized = configJson(catalog.validate(patched));
          expect(
            catalog.readPath(normalized, capability.path),
            value,
            reason: capability.path,
          );
        }
      }
    },
  );

  test(
    'numeric window values normalize integers and preserve nullable coordinates',
    () {
      final patched = catalog.applyPatch(defaults(), {
        'windowProps.width': 900,
        'windowProps.height': 600,
        'windowProps.top': -10,
        'windowProps.left': null,
      });
      final window = catalog.validate(patched).windowProps;
      expect(window.size.width, 900);
      expect(window.top, -10);
      expect(window.left, null);
      final reset = catalog.applyPatch(patched, {
        'windowProps.width': 0,
        'windowProps.height': 0,
      });
      expect(catalog.validate(reset).windowProps.size.width, 680);
    },
  );

  test('invalid window sizes and nonfinite coordinates are rejected', () {
    for (final patch in <Map<String, Object?>>[
      {'windowProps.width': 1, 'windowProps.height': 600},
      {'windowProps.width': 900},
      {'windowProps.width': 900, 'windowProps.height': 10000},
      {'windowProps.top': double.infinity},
    ]) {
      expect(
        () => catalog.applyPatch(defaults(), patch),
        throwsFormatException,
      );
    }
  });

  test('ports cannot conflict and system proxy requires a listener', () {
    expect(
      () => catalog.applyPatch(defaults(), {
        'patchClashConfig.port': 40001,
        'patchClashConfig.socks-port': 40001,
      }),
      throwsFormatException,
    );
    expect(
      () => catalog.applyPatch(defaults(), {
        'patchClashConfig.mixed-port': 0,
        'networkProps.systemProxy': true,
      }),
      throwsFormatException,
    );
    expect(
      () => catalog.applyPatch(defaults(), {
        'patchClashConfig.mixed-port': 65536,
      }),
      throwsFormatException,
    );
  });

  test(
    'unknown enums and unsupported native settings never fall back silently',
    () {
      for (final patch in <Map<String, Object?>>[
        {'patchClashConfig.mode': 'imaginary'},
        {'appSettingProps.locale': 'imaginary'},
        {'patchClashConfig.tun.auto-route': false},
        {'vpnProps.enable': true},
      ]) {
        expect(
          () => catalog.applyPatch(defaults(), patch),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'native profile identifiers retain signed 64-bit Snowflake precision',
    () {
      const id = 367048944821309440;
      final patched = catalog.applyPatch(defaults(), {'currentProfileId': id});
      expect(catalog.validate(patched).currentProfileId, id);
      expect(catalog.highRisk(defaults(), patched), true);
    },
  );

  test('settings exposure strips WebDAV password and all URL secrets', () {
    final local = defaults()
      ..['davProps'] = {
        'uri':
            'https://user:password@example.invalid/private/path?token=secret',
        'password': 'never-share',
      };
    final safe = catalog.redact(local)['davProps'] as Map;
    expect(safe['password'], null);
    expect(safe['uri'], 'https://example.invalid');
    expect((local['davProps'] as Map)['password'], 'never-share');
  });
}
