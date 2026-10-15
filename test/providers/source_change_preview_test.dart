import 'dart:io';

import 'package:drift/native.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/desktop/model.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/policy/profile_service.dart';
import 'package:fl_clash/policy/source_change.dart';
import 'package:fl_clash/policy/sources.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _PreviewPaths extends PathProviderPlatform {
  _PreviewPaths(this.path);

  final String path;

  @override
  Future<String> getApplicationSupportPath() async => path;

  @override
  Future<String> getTemporaryPath() async => path;

  @override
  Future<String> getApplicationCachePath() async => path;
}

class _PreviewCore extends CoreHandlerInterface {
  final calls = <CoreMethod>[];
  final lifecycleCalls = <String>[];

  Future<CoreLifecycleResult> _unexpectedLifecycle(String method) {
    lifecycleCalls.add(method);
    throw StateError('Unexpected Core lifecycle call: $method');
  }

  @override
  Future<CoreLifecycleResult> start() => _unexpectedLifecycle('start');

  @override
  Future<CoreLifecycleResult> restart() => _unexpectedLifecycle('restart');

  @override
  Future<CoreLifecycleResult> stop() => _unexpectedLifecycle('stop');

  @override
  Future<CoreLifecycleResult> close() => _unexpectedLifecycle('close');

  @override
  Future<T?> invokeMethod<T>({
    required CoreMethod method,
    Object? arguments,
    Duration? timeout,
  }) async {
    calls.add(method);
    if (method == CoreMethod.validateConfig) return '' as T;
    if (method == CoreMethod.getConfig) {
      return <String, dynamic>{
            'proxies': <Object?>[],
            'proxy-groups': <Object?>[],
            'rule': ['MATCH,DIRECT'],
          }
          as T;
    }
    throw StateError('Unexpected Core call: $method');
  }
}

LocalPolicyDocument _document(List<int> sourceIds) =>
    LocalPolicyDocument.fromJson({
      ...const LocalPolicyDocument().asStandalone().toJson(),
      'moduleEnabled': true,
      'integrationEnabled': false,
      'integrations': [
        SubscriptionIntegration(
          id: localPolicyProfileId,
          label: 'Local',
          sourceProfileIds: sourceIds,
        ).toJson(),
      ],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late PathProviderPlatform previousPaths;
  late WorkbenchDatabase store;
  late ProviderContainer container;
  late FlutterConfigurationBackend backend;
  late ConfigurationChangeService changes;
  late _PreviewCore handler;
  late File sourceFile;
  const original = Config(
    themeProps: defaultThemeProps,
    networkProps: NetworkProps(systemProxy: false),
  );
  const airport = Profile(
    id: 7,
    label: 'Provider airport',
    autoUpdateDuration: Duration(days: 1),
    subscriptionInfo: SubscriptionInfo(
      total: 1000,
      upload: 100,
      download: 200,
      knownFields: {'total', 'upload', 'download'},
    ),
  );
  const setup = SetupState(
    profileId: null,
    profileLastUpdateDate: null,
    overwriteType: OverwriteType.standard,
    rules: [],
    proxyGroups: [],
    addedRules: [],
    script: null,
    overrideDns: false,
    dns: Dns(),
  );

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp(
      'flclash-source-preview-',
    );
    previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _PreviewPaths(directory.path);
    sourceFile = File('${directory.path}/provider-only.yaml');
    await sourceFile.writeAsString('''
proxy-providers:
  remote:
    type: inline
    payload:
      - {name: Japan, type: ss, server: jp.example.invalid, port: 443}
      - {name: Hong Kong, type: ss, server: hk.example.invalid, port: 443}
proxy-groups:
  - {name: Japan pool, type: url-test, use: [remote], filter: Japan, exclude-filter: Hong, exclude-type: vmess}
  - {name: Airport, type: select, proxies: [Japan pool], include-all-providers: true, filter: Japan}
rules: ["MATCH,Airport"]
dns: {nameserver: [airport.dns.invalid]}
''');
  });

  tearDownAll(() async {
    PathProviderPlatform.instance = previousPaths;
    await directory.delete(recursive: true);
  });

  setUp(() async {
    store = WorkbenchDatabase(NativeDatabase.memory());
    await store.writeSection('policies', _document([]).toJson());
    handler = _PreviewCore();
    final backendProvider = Provider<FlutterConfigurationBackend>((ref) {
      return FlutterConfigurationBackend(
        ref: ref,
        store: store,
        profiles: PolicyProfileService(
          loader: PolicySourceLoader(
            store: store,
            profilePath: (_) async => sourceFile.path,
            fetchFile: (_) => throw StateError('Network is forbidden'),
          ),
        ),
        closeAgent: () async => throw StateError('Unexpected activation'),
      );
    });
    container = ProviderContainer(
      overrides: [
        ...buildConfigOverrides(original),
        workbenchDatabaseProvider.overrideWithValue(store),
        profilesProvider.overrideWithBuild((_, _) => const [airport]),
        setupStateProvider(null).overrideWith((_) async => setup),
        proxiesCoreProvider.overrideWithValue(CoreController.test(handler)),
      ],
    );
    container.listen(configProvider, (_, _) {});
    backend = container.read(backendProvider);
    changes = ConfigurationChangeService(backend: backend, store: store);
  });

  tearDown(() async {
    container.dispose();
    await store.close();
  });

  Future<Map<String, Object?>> candidate() async => {
    ...await backend.readState(),
    'policies': _document([7]).toJson(),
  };

  test(
    'real backend proposal previews provider leaves and quota without selecting local configuration',
    () async {
      final persisted = await store.readSection('policies');
      final proposal = await changes.propose(
        category: 'policies',
        summary: 'Add source',
        candidate: await candidate(),
      );
      final summary = LocalSourceChangeSummary.tryParse(
        proposal.validation[localSourceChangeValidationKey],
      );
      expect(summary, isNotNull);
      expect(summary!.addedSources, ['Provider airport']);
      expect(summary.removedSources, isEmpty);
      expect(summary.before.sourceCount, 0);
      expect(summary.before.nodeCount, 0);
      expect(summary.before.remainingBytes, 0);
      expect(summary.after.sourceCount, 1);
      expect(summary.after.nodeCount, 2);
      expect(summary.after.remainingBytes, 700);
      expect(summary.after.nodesComplete, isTrue);
      expect(summary.after.quotaComplete, isTrue);
      expect(proposal.highRisk, isTrue);
      expect(proposal.validation['finalConfigValidated'], isTrue);
      expect(proposal.differences, isNotEmpty);
      expect(
        proposal.differences.every(
          (difference) => difference.path.startsWith('policies.'),
        ),
        isTrue,
      );
      expect(await store.readSection('policies'), persisted);
      final result = await changes.commit(
        id: proposal.id,
        approve: (approval) async {
          expect(
            LocalSourceChangeSummary.tryParse(
              approval.validation[localSourceChangeValidationKey],
            )!.after.nodeCount,
            2,
          );
          return false;
        },
      );
      expect(result['status'], 'rejected');
      expect((await store.readChange(proposal.id))!.status, 'rejected');
      expect(await store.readSection('policies'), persisted);
      expect(container.read(configProvider), original);
      expect(handler.calls, isEmpty);
      expect(handler.lifecycleCalls, isEmpty);
    },
  );

  test(
    'mixed source and listener change keeps configuration differences without a source-only summary',
    () async {
      final value = await candidate();
      final config = policyObject(value['config'], 'config');
      final patch = policyObject(
        config['patchClashConfig'],
        'patchClashConfig',
      );
      value['config'] = {
        ...config,
        'patchClashConfig': {...patch, 'mixed-port': 45678},
      };
      final persisted = await store.readSection('policies');
      final proposal = await changes.propose(
        category: 'policies',
        summary: 'Add source and change listener',
        candidate: value,
      );
      expect(
        proposal.validation,
        isNot(contains(localSourceChangeValidationKey)),
      );
      final difference = proposal.differences.singleWhere(
        (entry) => entry.path == 'config.patchClashConfig.mixed-port',
      );
      expect(difference.before, original.patchClashConfig.mixedPort);
      expect(difference.after, 45678);
      expect(
        proposal.differences.any(
          (entry) => entry.path.startsWith('policies.integrations'),
        ),
        isTrue,
      );
      expect(await store.readSection('policies'), persisted);
      expect(container.read(configProvider), original);
      expect(handler.calls, isEmpty);
      expect(handler.lifecycleCalls, isEmpty);
    },
  );
}
