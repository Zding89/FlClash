import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/desktop/model.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/policy/sources.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:yaml/yaml.dart';

class _StandalonePaths extends PathProviderPlatform {
  _StandalonePaths(this.path);
  final String path;
  @override
  Future<String> getApplicationSupportPath() async => path;
  @override
  Future<String> getTemporaryPath() async => path;
  @override
  Future<String> getApplicationCachePath() async => path;
}

class _AirportCore extends CoreHandlerInterface {
  int reads = 0;
  @override
  Future<CoreLifecycleResult> start() async => const CoreLifecycleResult(
    revision: 1,
    outcome: CoreLifecycleOutcome.applied,
  );
  @override
  Future<CoreLifecycleResult> restart() => start();
  @override
  Future<CoreLifecycleResult> stop() => start();
  @override
  Future<CoreLifecycleResult> close() => start();
  @override
  Future<T?> invokeMethod<T>({
    required CoreMethod method,
    Object? arguments,
    Duration? timeout,
  }) async {
    if (method != CoreMethod.getConfig) {
      throw StateError('Unexpected Core call: $method');
    }
    reads++;
    return <String, dynamic>{
          'mode': 'rule',
          'proxies': <Object?>[],
          'proxy-groups': <Object?>[],
          'rule': ['DOMAIN,airport.invalid,DIRECT', 'MATCH,DIRECT'],
          'dns': {
            'enable': true,
            'nameserver': ['https://airport.dns.invalid/query'],
          },
        }
        as T;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late WorkbenchDatabase store;
  late ProviderContainer container;
  late _AirportCore handler;
  const airport = Profile(
    id: 1,
    label: 'Airport',
    autoUpdateDuration: Duration(days: 1),
    overwriteType: OverwriteType.script,
    scriptId: 900,
  );
  const config = Config(
    themeProps: defaultThemeProps,
    currentProfileId: 1,
    patchClashConfig: PatchClashConfig(
      dns: Dns(nameserver: ['https://app.dns.invalid/query']),
    ),
  );
  LocalPolicyDocument document({required bool selected}) =>
      LocalPolicyDocument.fromJson({
        ...const LocalPolicyDocument(
          moduleEnabled: true,
          policiesEnabled: true,
          budgetsEnabled: true,
          integrations: [
            SubscriptionIntegration(
              id: localPolicyProfileId,
              label: 'Local',
              sourceProfileIds: [1],
            ),
          ],
          policies: [
            LocalPolicy(
              id: 'local-rule',
              label: 'Local direct',
              targetId: localPolicyTargetId,
              action: PolicyAction.direct,
              scope: PolicyMatch(
                type: PolicyMatchType.domainKeyword,
                values: ['local-only'],
              ),
            ),
          ],
          budgets: [SourceBudget(sourceId: '1', limitBytes: 1000)],
        ).toJson(),
        'schemaVersion': 4,
        'activeIntegrationId': localPolicyProfileId,
        'integrationEnabled': selected,
      });
  SetupState setup(OverwriteType type) => SetupState(
    profileId: 1,
    profileLastUpdateDate: null,
    overwriteType: type,
    rules: [],
    proxyGroups: [],
    addedRules: [],
    script: Script(
      id: 900,
      label: 'Do not execute source script',
      lastUpdateTime: DateTime(2026, 10, 15),
    ),
    overrideDns: false,
    dns: config.patchClashConfig.dns,
  );
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp(
      'flclash-standalone-setup-',
    );
    PathProviderPlatform.instance = _StandalonePaths(directory.path);
    globalState.packageInfo = PackageInfo(
      appName: 'Fixture',
      packageName: 'fixture',
      version: '1',
      buildNumber: '1',
    );
    await AppLocalizations.load(const Locale('en'));
    final file = File(await appPath.getProfilePath('1'));
    await file.parent.create(recursive: true);
    await file.writeAsString(
      'proxies: [{name: Node, type: ss, server: example.invalid, port: 443, cipher: aes-128-gcm, password: fixture}]\nproxy-groups: [{name: Airport, type: select, proxies: [Node]}]\nrules: ["DOMAIN,airport.invalid,Airport", "MATCH,Airport"]\ndns: {enable: true, nameserver: ["https://airport.dns.invalid/query"]}\n',
    );
  });
  tearDownAll(() async {
    CoreController.resetInstance();
    await directory.delete(recursive: true);
  });
  setUp(() async {
    store = WorkbenchDatabase(NativeDatabase.memory());
    handler = _AirportCore();
    container = ProviderContainer(
      overrides: [
        ...buildConfigOverrides(config),
        workbenchDatabaseProvider.overrideWithValue(store),
        profilesProvider.overrideWithBuild((_, _) => const [airport]),
        proxiesCoreProvider.overrideWithValue(CoreController.test(handler)),
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.disconnected),
      ],
    );
    container.listen(configProvider, (_, _) {});
    await store.writeSection('policies', document(selected: true).toJson());
  });
  tearDown(() async {
    container.dispose();
    await store.close();
  });
  test(
    'selected local configuration ignores source rules DNS and script and keeps app DNS',
    () async {
      final result = await container
          .read(setupActionProvider.notifier)
          .getProfile(
            setupState: setup(OverwriteType.script),
            patchConfig: config.patchClashConfig,
            policyDocument: document(selected: true),
            preview: true,
          );
      final raw = policyObject(
        normalizePolicyYaml(loadYaml(result.a)),
        'config',
      );
      expect(handler.reads, 0);
      expect(raw['rules'], [
        'DOMAIN-KEYWORD,local-only,fl-policy-${policyDigest('local-rule').substring(0, 16)}',
        'MATCH,REJECT',
      ]);
      expect((raw['dns'] as Map)['nameserver'], [
        'https://app.dns.invalid/query',
      ]);
      expect(
        (raw['flclash-local-policy'] as Map)['targetId'],
        localPolicyTargetId,
      );
      expect(result.a, isNot(contains('airport.invalid')));
      expect(result.a, isNot(contains('airport.dns.invalid')));
    },
  );
  test(
    'local direct rule initializes without any ordinary profile or source',
    () async {
      final document = LocalPolicyDocument.fromJson({
        ...const LocalPolicyDocument(
          moduleEnabled: true,
          integrationEnabled: true,
          policiesEnabled: true,
          integrations: [
            SubscriptionIntegration(
              id: localPolicyProfileId,
              label: 'Local',
              sourceProfileIds: [],
            ),
          ],
          policies: [
            LocalPolicy(
              id: 'smoke-local-direct',
              label: 'Local direct',
              targetId: localPolicyTargetId,
              action: PolicyAction.direct,
              scope: PolicyMatch(
                type: PolicyMatchType.domainSuffix,
                values: ['smoke.invalid'],
              ),
            ),
          ],
        ).toJson(),
        'schemaVersion': 4,
        'activeIntegrationId': localPolicyProfileId,
      }).asStandalone();
      container.dispose();
      container = ProviderContainer(
        overrides: [
          ...buildConfigOverrides(config.copyWith(currentProfileId: null)),
          workbenchDatabaseProvider.overrideWithValue(store),
          profilesProvider.overrideWithBuild((_, _) => const []),
          proxiesCoreProvider.overrideWithValue(CoreController.test(handler)),
          coreStatusProvider.overrideWithBuild(
            (_, _) => CoreStatus.disconnected,
          ),
        ],
      );
      final result = await container
          .read(setupActionProvider.notifier)
          .getProfile(
            setupState: setup(OverwriteType.standard).copyWith(profileId: null),
            patchConfig: config.patchClashConfig,
            policyDocument: document,
            preview: true,
          );
      expect(handler.reads, 0);
      final raw = policyObject(
        normalizePolicyYaml(loadYaml(result.a)),
        'config',
      );
      expect(
        (raw['flclash-local-policy'] as Map)['targetId'],
        localPolicyTargetId,
      );
      expect(
        ((raw['flclash-local-policy'] as Map)['policies'] as List)
            .single['action'],
        'direct',
      );
      expect(raw['rules'].toString(), contains('smoke.invalid'));
    },
  );

  test(
    'ordinary airport remains unchanged even when local rules and budgets are enabled',
    () async {
      final result = await container
          .read(setupActionProvider.notifier)
          .getProfile(
            setupState: setup(OverwriteType.standard),
            patchConfig: config.patchClashConfig,
            policyDocument: document(selected: false),
            preview: true,
          );
      final raw = policyObject(
        normalizePolicyYaml(loadYaml(result.a)),
        'config',
      );
      expect(handler.reads, 1);
      expect(raw['rules'], ['DOMAIN,airport.invalid,DIRECT', 'MATCH,DIRECT']);
      expect((raw['dns'] as Map)['nameserver'], [
        'https://airport.dns.invalid/query',
      ]);
      expect(raw, isNot(contains('flclash-local-policy')));
      expect(raw, isNot(contains('flclash-selection-aliases')));
    },
  );
  test(
    'local source references block direct deletion before mutating profile state',
    () async {
      await expectLater(
        container.read(profilesActionProvider.notifier).deleteProfile(1),
        throwsA(
          isA<ConfigurationChangeException>().having(
            (e) => e.code,
            'code',
            'resource_source_referenced',
          ),
        ),
      );
      expect(container.read(profilesProvider), const [airport]);
    },
  );
  test(
    'local source validation does not impose local restrictions on unrelated subscriptions',
    () async {
      final controller = container.read(workbenchControllerProvider);
      final bytes = Uint8List.fromList(
        'proxy-groups: [{name: Native, type: select, filter: unsupported}]'
            .codeUnits,
      );
      await controller.validateSourceUpdate(
        airport.copyWith(id: 2),
        bytes,
        isCurrent: () => true,
      );
      await expectLater(
        controller.validateSourceUpdate(airport, bytes, isCurrent: () => true),
        throwsA(isA<PolicySourceException>()),
      );
    },
  );
}
