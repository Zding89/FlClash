import 'dart:async';

import 'package:drift/native.dart';
import 'package:fl_clash/ai/settings.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/policy/profile_service.dart';
import 'package:fl_clash/policy/sources.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Profiles extends Profiles {
  final List<Profile> initial;

  _Profiles(this.initial);

  @override
  List<Profile> build() => initial;

  void replace(List<Profile> value) {
    state = value;
  }
}

void main() {
  late WorkbenchDatabase store;
  late ProviderContainer container;
  late FlutterConfigurationBackend backend;
  late Profile profile;
  late SetupState setup;
  late String source;
  Future<void> Function()? beforeRead;

  setUp(() {
    store = WorkbenchDatabase(NativeDatabase.memory());
    profile = const Profile(
      id: 7,
      label: 'fixture',
      autoUpdateDuration: Duration(days: 1),
      selectedMap: {'outbound': 'proxy'},
    );
    setup = const SetupState(
      profileId: 7,
      profileLastUpdateDate: null,
      overwriteType: OverwriteType.standard,
      rules: [],
      proxyGroups: [],
      addedRules: [],
      script: null,
      overrideDns: false,
      dns: Dns(),
    );
    source = '''
proxies:
  - {name: proxy, type: http, server: proxy.invalid, port: 8080}
proxy-groups:
  - {name: outbound, type: select, proxies: [proxy]}
rules: [MATCH,outbound]
''';
    beforeRead = null;
    final provider = Provider<FlutterConfigurationBackend>((ref) {
      return FlutterConfigurationBackend(
        ref: ref,
        store: store,
        profiles: PolicyProfileService(
          loader: PolicySourceLoader(
            store: store,
            profilePath: (id) async => '/fixture/$id.yaml',
            readFile: (_) async {
              await beforeRead?.call();
              return source;
            },
            fetchFile: (_) => throw StateError('Network is forbidden'),
          ),
        ),
      );
    });
    container = ProviderContainer(
      overrides: [
        ...buildConfigOverrides(
          const Config(themeProps: defaultThemeProps, currentProfileId: 7),
        ),
        profilesProvider.overrideWith(() => _Profiles([profile])),
        setupStateProvider(7).overrideWith((ref) async => setup),
      ],
    );
    container.listen(configProvider, (_, _) {});
    backend = container.read(provider);
  });

  tearDown(() async {
    container.dispose();
    await store.close();
  });

  Future<String> signature() async =>
      policyDigest(await backend.readActivationState());

  test(
    'window changes during source reads do not cancel configuration',
    () async {
      final baseline = await signature();
      final reading = Completer<void>();
      final release = Completer<void>();
      beforeRead = () async {
        if (!reading.isCompleted) reading.complete();
        await release.future;
      };
      final pending = signature();
      await reading.future;
      container
          .read(windowSettingProvider.notifier)
          .update((value) => value.copyWith(width: 900, left: 10));
      release.complete();
      expect(await pending, baseline);
      expect(await signature(), baseline);
    },
  );

  test('tab initialization and profile reorder preserve Core inputs', () async {
    final second = profile.copyWith(id: 8, label: 'other');
    final profiles = container.read(profilesProvider.notifier) as _Profiles;
    profiles.replace([profile, second]);
    final activation = await signature();
    final transaction = policyDigest(await backend.readState());
    profiles.replace([
      second.copyWith(currentGroupName: 'GLOBAL', unfoldSet: {'outbound'}),
      profile.copyWith(currentGroupName: 'outbound', order: 1),
    ]);
    expect(await signature(), activation);
    expect(policyDigest(await backend.readState()), isNot(transaction));
  });

  test('UI and AI changes remain covered by full approval snapshots', () async {
    final activation = await signature();
    final transaction = policyDigest(await backend.readState());
    container
        .read(themeSettingProvider.notifier)
        .update((value) => value.copyWith(pureBlack: true));
    await store.writeSection(
      'ai',
      const AgentSettings(
        connections: [
          AgentConnection(
            id: 'fixture',
            label: 'fixture',
            provider: 'openai',
            model: 'fixture',
          ),
        ],
      ).toJson(),
    );
    expect(await signature(), activation);
    expect(policyDigest(await backend.readState()), isNot(transaction));
  });

  test('real network settings and probe targets change Core inputs', () async {
    final original = await signature();
    container
        .read(patchClashConfigProvider.notifier)
        .update((value) => value.copyWith(mode: Mode.global));
    final mode = await signature();
    expect(mode, isNot(original));
    container
        .read(appSettingProvider.notifier)
        .update(
          (value) => value.copyWith(testUrl: 'https://example.com/probe'),
        );
    expect(await signature(), isNot(mode));
  });

  test('source content and selected nodes change Core inputs', () async {
    final original = await signature();
    source = source.replaceFirst('8080', '8081');
    final refreshed = await signature();
    expect(refreshed, isNot(original));
    (container.read(profilesProvider.notifier) as _Profiles).replace([
      profile.copyWith(selectedMap: {'outbound': 'DIRECT'}),
    ]);
    expect(await signature(), isNot(refreshed));
  });

  test(
    'policy metadata and added rules remain in the conflict check',
    () async {
      final original = await signature();
      await store.writeSection(
        'policies',
        const LocalPolicyDocument(revision: 1).toJson(),
      );
      final policies = await signature();
      expect(policies, isNot(original));
      setup = setup.copyWith(
        addedRules: [
          const Rule(id: 9, content: 'example.com', ruleTarget: 'DIRECT'),
        ],
      );
      container.invalidate(setupStateProvider(7));
      expect(await signature(), isNot(policies));
    },
  );
}
