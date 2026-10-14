import 'package:fl_clash/capabilities/gateway.dart';
import 'package:fl_clash/configuration/settings.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Controller extends Mock implements WorkbenchController {}

class _Backend extends Mock implements FlutterConfigurationBackend {}

class _Core extends Mock implements CoreController {}

void main() {
  test(
    'gateway versions ignore DAV nonces and retain real conflicts',
    () async {
      var config = const Config(
        themeProps: defaultThemeProps,
        davProps: DAVProps(
          uri: 'https://example.invalid/dav',
          user: 'fixture',
          password: 'synthetic-password',
        ),
      );
      final backend = _Backend();
      final controller = _Controller();
      when(() => controller.backend).thenReturn(backend);
      when(
        () => backend.readState(),
      ).thenAnswer((_) async => {'config': configJson(config)});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final gateway = container.read(
        Provider(
          (ref) => FlutterApplicationCapabilityGateway(
            ref: ref,
            controller: controller,
            core: _Core(),
          ),
        ),
      );
      final original = await gateway.version();
      expect(await gateway.version(), original);
      config = config.copyWith(
        davProps: config.davProps!.copyWith(password: 'changed-password'),
      );
      final changedPassword = await gateway.version();
      expect(changedPassword, isNot(original));
      expect(await gateway.version(), changedPassword);
      config = config.copyWith(
        appSettingProps: config.appSettingProps.copyWith(autoLaunch: true),
      );
      expect(await gateway.version(), isNot(changedPassword));
    },
  );
}
