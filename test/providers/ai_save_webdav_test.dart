import 'dart:io';

import 'package:drift/native.dart';
import 'package:fl_clash/ai/settings.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/configuration/settings.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String> getApplicationSupportPath() async => path;
  @override
  Future<String> getTemporaryPath() async => path;
  @override
  Future<String> getApplicationCachePath() async => path;
}

class _Profiles extends Profiles {
  @override
  List<Profile> build() => const [
    Profile(id: 7, label: 'fixture', autoUpdateDuration: Duration(days: 1)),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late WorkbenchDatabase store;
  late ProviderContainer container;
  const original = Config(
    themeProps: defaultThemeProps,
    currentProfileId: 7,
    davProps: DAVProps(
      uri: 'https://example.invalid/dav',
      user: 'fixture',
      password: 'synthetic-password',
    ),
  );
  const settings = AgentSettings(
    enabled: true,
    selectedConnectionId: 'ds',
    connections: [
      AgentConnection(
        id: 'ds',
        label: 'DS fixture',
        provider: 'deepseek',
        model: 'fixture-model',
      ),
    ],
  );

  ProviderContainer createContainer(Config config) {
    final value = ProviderContainer(
      overrides: [
        ...buildConfigOverrides(config),
        workbenchDatabaseProvider.overrideWithValue(store),
        profilesProvider.overrideWith(_Profiles.new),
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
      ],
    );
    value.listen(configProvider, (_, _) {});
    return value;
  }

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('flclash-ai-save-');
    PathProviderPlatform.instance = _Paths(directory.path);
    SharedPreferences.setMockInitialValues({});
    await preferences.sharedPreferencesCompleter.future;
    await AppLocalizations.load(const Locale('en'));
    final file = File(await appPath.getProfilePath('7'));
    await file.parent.create(recursive: true);
    await file.writeAsString('proxies: []\nproxy-groups: []\nrules: []\n');
  });
  tearDownAll(() async => directory.delete(recursive: true));
  setUp(() async {
    store = WorkbenchDatabase(NativeDatabase.memory());
    await preferences.saveConfig(original);
    container = createContainer(original);
  });
  tearDown(() async {
    container.dispose();
    await store.close();
  });

  test(
    'DS settings save, reload and undo with existing WebDAV password',
    () async {
      var controller = container.read(workbenchControllerProvider);
      final proposal = await controller.proposeAgentSettings(settings);
      expect(proposal.highRisk, false);
      expect(
        proposal.differences.every((diff) => diff.path.startsWith('ai.')),
        true,
      );
      final result = await controller.commit(
        proposal,
        approve: (_) async => true,
      );
      expect(result['status'], 'applied');
      expect(
        (await controller.readAgentSettings()).toJson(),
        settings.toJson(),
      );
      expect((await store.readChange(proposal.id))!.status, 'applied');
      final saved = (await preferences.getConfig())!;
      expect(saved.davProps, original.davProps);
      expect(
        configurationDigest(configJson(saved)),
        configurationDigest(configJson(original)),
      );

      await controller.closeAgent();
      container.dispose();
      container = createContainer(saved);
      controller = container.read(workbenchControllerProvider);
      expect(
        (await controller.readAgentSettings()).toJson(),
        settings.toJson(),
      );
      final undo = await controller.changes.proposeUndo(proposal.id);
      expect(
        (await controller.commit(undo, approve: (_) async => true))['status'],
        'applied',
      );
      expect(
        (await controller.readAgentSettings()).toJson(),
        const AgentSettings().toJson(),
      );
      expect((await preferences.getConfig())!.davProps, original.davProps);
    },
  );

  test('a real DAV password change still invalidates DS approval', () async {
    final controller = container.read(workbenchControllerProvider);
    final proposal = await controller.proposeAgentSettings(settings);
    container
        .read(davSettingProvider.notifier)
        .update((value) => value!.copyWith(password: 'concurrent-password'));
    await expectLater(
      controller.commit(proposal, approve: (_) async => true),
      throwsA(isA<Exception>()),
    );
    expect(
      (await controller.readAgentSettings()).toJson(),
      const AgentSettings().toJson(),
    );
    expect((await store.readChange(proposal.id))!.status, 'superseded');
    expect(
      container.read(configProvider).davProps!.password,
      'concurrent-password',
    );
  });
}
