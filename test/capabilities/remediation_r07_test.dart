import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:fl_clash/capabilities/gateway.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/configuration/resources.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/policy/compiler.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/policy/profile_service.dart';
import 'package:fl_clash/policy/sources.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:yaml/yaml.dart';

class _PathProvider extends PathProviderPlatform {
  _PathProvider(this.path);
  final String path;
  @override
  Future<String> getApplicationSupportPath() async => path;
  @override
  Future<String> getTemporaryPath() async => path;
  @override
  Future<String> getApplicationCachePath() async => path;
}

class _Core extends Mock implements CoreController {
  _Core(this.raw);
  final Map<String, dynamic> raw;
  String? validated;
  bool invalid = false;
  @override
  Future<Map<String, dynamic>> getConfig(int id) async =>
      jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
  @override
  Future<String> validateConfigWithData(String yaml) async {
    validated = yaml;
    return invalid ? 'fixture-invalid' : '';
  }
}

class _Controller extends Mock implements WorkbenchController {}

class _Environment extends Mock implements ResourceEnvironment {}

class _Profiles extends Profiles {
  _Profiles(this.profile);
  final Profile profile;
  @override
  List<Profile> build() => [profile];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late WorkbenchDatabase store;
  late _Core core;
  late _Controller controller;
  late ProviderContainer container;
  late Map<String, dynamic> raw;
  late LocalPolicyDocument document;
  late SetupState setup;
  late Profile profile;
  var approved = true;
  var launches = 0;
  var approvals = 0;
  setUpAll(() async {
    directory = await Directory(
      await Directory.systemTemp.resolveSymbolicLinks(),
    ).createTemp('flclash-r07-fixture-');
    PathProviderPlatform.instance = _PathProvider(directory.path);
    globalState.packageInfo = PackageInfo(
      appName: 'fixture',
      packageName: 'fixture',
      version: '1',
      buildNumber: '1',
    );
    await AppLocalizations.load(const Locale('en'));
  });
  tearDownAll(() async => directory.delete(recursive: true));
  setUp(() async {
    for (final file in directory.listSync().whereType<File>().where(
      (file) => file.path.contains('export-'),
    )) {
      await file.delete();
    }
    approved = true;
    launches = 0;
    approvals = 0;
    store = WorkbenchDatabase(NativeDatabase.memory());
    profile = Profile.normal(label: 'fixture').copyWith(id: 7);
    raw = {
      'mode': 'rule',
      'proxy-providers': <String, Object?>{},
      'mixed-port': 1,
      'proxies': [
        {
          'name': 'Node',
          'type': 'ss',
          'server': 'fixture.invalid',
          'port': 443,
          'cipher': 'aes-128-gcm',
          'password': 'fixture-password',
        },
      ],
      'proxy-groups': [
        {
          'name': 'Group',
          'type': 'select',
          'proxies': ['Node'],
        },
      ],
      'rules': ['MATCH,DIRECT'],
    };
    final node = const LocalPolicyCompiler()
        .extractNodes(PolicySource(id: '7', label: 'fixture', raw: raw))
        .single;
    document = LocalPolicyDocument(
      policiesEnabled: true,
      policies: [
        LocalPolicy(
          id: 'local',
          label: 'Local',
          targetId: 'profile:7',
          candidateNodeIds: [node.id],
          scope: const PolicyMatch(
            type: PolicyMatchType.domainSuffix,
            values: ['local.example'],
          ),
        ),
      ],
    );
    setup = const SetupState(
      profileId: 7,
      profileLastUpdateDate: null,
      overwriteType: OverwriteType.standard,
      rules: [],
      proxyGroups: [],
      addedRules: [
        Rule(
          ruleAction: RuleAction.DOMAIN_SUFFIX,
          content: 'override.example',
          ruleTarget: 'DIRECT',
        ),
      ],
      script: null,
      overrideDns: false,
      dns: Dns(),
    );
    core = _Core(raw);
    controller = _Controller();
    when(() => controller.readPolicies()).thenAnswer((_) async => document);
    final environment = _Environment();
    registerFallbackValue(const ResourceScope(ResourceKind.profile, 7));
    when(
      () => environment.read(any()),
    ).thenAnswer((_) async => {'protectedContent': jsonEncode(raw)});
    when(
      () => controller.resources,
    ).thenReturn(ResourceChangeService(store: store, environment: environment));
    when(() => controller.profiles).thenReturn(
      PolicyProfileService(
        loader: PolicySourceLoader(
          store: store,
          readFile: (_) async => jsonEncode(raw),
          profilePath: (_) async => '${directory.path}/fixture.yaml',
          homePath: () async => directory.path,
          fetchFile: (_) => throw StateError('network-forbidden'),
        ),
      ),
    );
  });
  tearDown(() async {
    container.dispose();
    await store.close();
  });
  FlutterApplicationCapabilityGateway create() {
    final provider = Provider(
      (ref) => FlutterApplicationCapabilityGateway(
        ref: ref,
        controller: controller,
        core: core,
        approveScript: (proposal) async {
          approvals++;
          expect(proposal.validation['requiresScriptExecutionApproval'], true);
          return approved;
        },
      ),
    );
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => _Profiles(profile)),
        currentProfileIdProvider.overrideWithBuild((_, _) => 7),
        setupStateProvider(7).overrideWith((ref) async => setup),
        patchClashConfigProvider.overrideWithBuild(
          (_, _) => const PatchClashConfig(mixedPort: 17891),
        ),
        proxiesCoreProvider.overrideWithValue(core),
        workbenchControllerProvider.overrideWithValue(controller),
        profileScriptLauncherProvider.overrideWithValue(() {
          launches++;
          return Process.start(
            Platform.environment['FLCLASH_TEST_NODE'] ??
                '/private/tmp/flclash-ai-host-node22-arm64/Resources/ai/node',
            ['${Directory.current.path}/scripts/script_runner.mjs'],
            environment: const {},
            includeParentEnvironment: false,
          );
        }),
      ],
    );
    return container.read(provider);
  }

  Future<(Map<String, Object?>, File)> export(
    FlutterApplicationCapabilityGateway gateway,
    String command,
  ) async {
    final file = File(
      '${directory.path}/export-${DateTime.now().microsecondsSinceEpoch}.yaml',
    );
    final grant = await gateway.execute('file_grant', {
      'mode': 'write',
      'path': file.path,
    }, origin: 'cli');
    final result = await gateway.execute(command, {
      'id': '7',
      'fileGrantId': grant['fileGrantId'],
    }, origin: 'cli');
    return (result, file);
  }

  test(
    'R07 export is generated, validated and contains patch and local rules; raw stays raw',
    () async {
      final gateway = create();
      final (result, file) = await export(gateway, 'profile_effective_export');
      final text = await file.readAsString();
      final output = loadYaml(text) as Map;
      expect(result['status'], 'completed');
      expect(core.validated, text);
      expect(output['mixed-port'], 17891);
      expect(
        (output['rules'] as List).first.toString(),
        contains('local.example'),
      );
      expect(
        output['rules'],
        contains('DOMAIN-SUFFIX,override.example,DIRECT'),
      );
      expect((output['flclash-local-policy'] as Map)['policies'], hasLength(1));
      final (_, original) = await export(gateway, 'profile_export');
      expect(jsonDecode(await original.readAsString()), raw);
      expect(approvals, 0);
    },
    skip: !Platform.isMacOS,
  );
  test(
    'R07 approved script output is exported through the real generator and compiler',
    () async {
      final script = Script(
        id: 9,
        label: 'fixture',
        lastUpdateTime: DateTime.now(),
      );
      await script.save(
        'function main(config) { config["script-marker"] = "executed"; config.rules.unshift("DOMAIN,script.example,DIRECT"); return config; }',
      );
      setup = setup.copyWith(
        overwriteType: OverwriteType.script,
        script: script,
      );
      final gateway = create();
      final (_, file) = await export(gateway, 'profile_effective_export');
      final text = await file.readAsString();
      final output = loadYaml(text) as Map;
      expect(output['script-marker'], 'executed');
      expect(output['mixed-port'], 17891);
      expect(output['rules'], contains('DOMAIN,script.example,DIRECT'));
      expect((output['flclash-local-policy'] as Map)['policies'], hasLength(1));
      expect(core.validated, text);
      expect(approvals, 1);
      expect(launches, 1);
    },
    skip: !Platform.isMacOS,
  );
  test(
    'R07 rejection and validation failure never deliver output',
    () async {
      final script = Script(
        id: 9,
        label: 'fixture',
        lastUpdateTime: DateTime.now(),
      );
      await script.save('function main(config) { return config; }');
      setup = setup.copyWith(
        overwriteType: OverwriteType.script,
        script: script,
      );
      approved = false;
      final gateway = create();
      await expectLater(
        export(gateway, 'profile_effective_export'),
        throwsA(
          isA<ConfigurationChangeException>().having(
            (error) => error.code,
            'code',
            'script_execution_rejected',
          ),
        ),
      );
      expect(launches, 0);
      approved = true;
      core.invalid = true;
      await expectLater(
        export(gateway, 'profile_effective_export'),
        throwsA(
          isA<ConfigurationChangeException>().having(
            (error) => error.code,
            'code',
            'effective_config_validation_failed',
          ),
        ),
      );
      expect(
        directory.listSync().whereType<File>().where(
          (file) => file.path.contains('export-'),
        ),
        isEmpty,
      );
    },
    skip: !Platform.isMacOS,
  );
}
