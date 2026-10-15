import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/control/password.dart';
import 'package:fl_clash/control/service.dart';
import 'package:fl_clash/control/transport.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/views/ai/composer_context.dart';
import 'package:fl_clash/views/ai/assistant.dart';
import 'package:fl_clash/widgets/sheet.dart';
import 'package:fl_clash/models/profile.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/control/settings.dart';
import 'package:fl_clash/views/policy/node_set_editor.dart';
import 'package:fl_clash/views/policy/policy.dart';
import 'package:fl_clash/views/policy/rule_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

const _captureEnabled = bool.fromEnvironment(
  'GENERATE_POLICY_FIXTURE_SCREENSHOTS',
);
final _captureKey = GlobalKey();
const _nodeSet = PolicyNodeSet(
  id: 'fixture-japan',
  label: '日本常用节点集',
  targetId: localPolicyTargetId,
  sourceIds: ['1', '2'],
  regions: ['JP'],
  maxMultiplier: 1.5,
  unknownMultiplier: UnknownMultiplier.exclude,
);
const _manual = LocalPolicy(
  id: 'fixture-manual',
  label: '办公网站',
  targetId: localPolicyTargetId,
  priority: 1,
  origin: PolicyOrigin.manual,
  scope: PolicyMatch(
    type: PolicyMatchType.domainSuffix,
    values: ['office.example'],
  ),
  choices: [PolicyChoice(type: PolicyChoiceType.nodeSet, id: 'fixture-japan')],
  schedule: PolicySchedule(
    windows: [PolicyWindow(startMinute: 540, endMinute: 1080)],
  ),
);
const _ai = LocalPolicy(
  id: 'fixture-ai',
  label: 'AI 初始规则',
  targetId: localPolicyTargetId,
  priority: 2,
  origin: PolicyOrigin.ai,
  scope: PolicyMatch(
    type: PolicyMatchType.domainSuffix,
    values: ['example.test'],
  ),
  candidateNodeIds: ['1:fixture-known'],
);
const _remaining = LocalPolicy(
  id: 'fixture-remaining',
  label: '其余流量',
  targetId: localPolicyTargetId,
  priority: 3,
  scope: PolicyMatch(type: PolicyMatchType.global),
  candidateNodeIds: ['1:fixture-known'],
);
const _document = LocalPolicyDocument(
  schemaVersion: 4,
  integrationEnabled: true,
  activeIntegrationId: localPolicyProfileId,
  integrations: [
    SubscriptionIntegration(
      id: localPolicyProfileId,
      label: 'Local',
      sourceProfileIds: [1, 2],
    ),
  ],
  moduleEnabled: true,
  policiesEnabled: true,
  policies: [_manual, _ai, _remaining],
  nodeSets: [_nodeSet],
);
final _nodes = [
  LocalNode(
    id: '1:fixture-known',
    sourceId: '1',
    label: '东京 A · 1×',
    sourceLabel: '测试来源 A',
    protocol: 'ss',
    raw: const {},
    attributes: const NodeAttributes(
      region: 'JP',
      regionBasis: NodeAttributeBasis.subscription,
      multiplier: 1,
      multiplierBasis: NodeAttributeBasis.subscription,
    ),
  ),
  LocalNode(
    id: '2:fixture-unknown',
    sourceId: '2',
    label: '大阪 B · 倍率未知',
    sourceLabel: '测试来源 B',
    protocol: 'ss',
    raw: const {},
    attributes: const NodeAttributes(
      region: 'JP',
      regionBasis: NodeAttributeBasis.name,
    ),
  ),
  LocalNode(
    id: '1:fixture-expensive',
    sourceId: '1',
    label: '东京 C · 3×',
    sourceLabel: '测试来源 A',
    protocol: 'ss',
    raw: const {},
    attributes: const NodeAttributes(
      region: 'JP',
      regionBasis: NodeAttributeBasis.subscription,
      multiplier: 3,
      multiplierBasis: NodeAttributeBasis.subscription,
    ),
  ),
  LocalNode(
    id: '2:fixture-outside',
    sourceId: '2',
    label: '香港 D · 1×',
    sourceLabel: '测试来源 B',
    protocol: 'ss',
    raw: const {},
    attributes: const NodeAttributes(
      region: 'HK',
      regionBasis: NodeAttributeBasis.name,
      multiplier: 1,
      multiplierBasis: NodeAttributeBasis.name,
    ),
  ),
];
const _snapshot = <String, Object?>{
  'state': 'connected',
  'revision': 7,
  'checksWaiting': 2,
  'checksInFlight': 1,
  'policies': [
    {
      'policyId': 'fixture-manual',
      'reason': 'schedule_inactive',
      'state': 'inactive',
      'nodes': [],
    },
    {'policyId': 'fixture-ai', 'reason': '', 'state': 'proxy', 'nodes': []},
  ],
  'nodeSets': [
    {
      'policyId': 'fixture-japan',
      'nodes': [
        {
          'nodeId': '1:fixture-known',
          'eligible': true,
          'healthy': true,
          'lastProbeAt': 1791939600000,
          'latencyMillis': 48,
        },
        {
          'nodeId': '2:fixture-unknown',
          'eligible': true,
          'healthy': true,
          'lastProbeAt': 1791939600000,
          'latencyMillis': 63,
        },
      ],
    },
  ],
};

class _FixtureWorkbench extends Mock implements WorkbenchController {
  LocalPolicyDocument? proposed;
  int commits = 0;
  bool fail = false;
  @override
  Future<LocalPolicyDocument> readPolicies() async => _document;
  @override
  Future<List<LocalNode>> loadNodes(
    String targetId, {
    LocalPolicyDocument? document,
    bool refresh = true,
  }) async => _nodes;
  @override
  Future<ConfigurationProposal> proposePolicies(
    LocalPolicyDocument document, {
    String? draftId,
    String? expectedPolicyDigest,
  }) async {
    proposed = document;
    return const ConfigurationProposal(
      id: 'fixture-proposal',
      summary: 'Fixture policy update',
      highRisk: false,
      expiresAt: 9999999999999,
      differences: [],
      validation: {},
    );
  }

  @override
  Future<Map<String, Object?>> commit(
    ConfigurationProposal proposal, {
    required ConfigurationApproval approve,
    bool Function()? isCurrent,
  }) async {
    commits++;
    if (fail) {
      throw const ConfigurationChangeException('configuration_apply_failed');
    }
    return {'status': 'applied'};
  }
}

class _FixturePasswords implements ControlPasswordStore {
  String? value;
  int writes = 0;
  bool fail = false;
  @override
  Future<String?> read() async {
    if (fail) throw StateError('fixture_keychain_locked');
    return value;
  }

  @override
  Future<void> write(String password) async {
    if (fail) throw StateError('fixture_keychain_locked');
    value = password;
    writes++;
  }
}

class _FixtureControlTransport implements ControlTransport {
  @override
  void start(String instanceId) {}
  @override
  ControlPacket? poll() => null;
  @override
  void reply(int token, Map<String, Object?> response) {}
  @override
  void stop() {}
}

Future<void> _pump(
  WidgetTester tester,
  Widget child,
  Size size, {
  _FixtureWorkbench? workbench,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  final container = ProviderContainer(
    overrides: [
      viewSizeProvider.overrideWithBuild((ref, notifier) => size),
      workbenchControllerProvider.overrideWithValue(
        workbench ?? _FixtureWorkbench(),
      ),
      localPoliciesProvider.overrideWith((_) => Stream.value(_document)),
      localPolicyStatusProvider.overrideWith((_) => Stream.value(_snapshot)),
      workbenchChangesProvider.overrideWith((_) => Stream.value([])),
      currentProfileIdProvider.overrideWithBuild((ref, notifier) => 1),
      profilesProvider.overrideWithBuild(
        (ref, notifier) => const [
          Profile(
            id: 1,
            label: '测试来源 A',
            autoUpdateDuration: Duration(hours: 24),
          ),
          Profile(
            id: 2,
            label: '测试来源 B',
            autoUpdateDuration: Duration(hours: 24),
          ),
        ],
      ),
    ],
  );
  globalState.container = container;
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        theme: ThemeData(
          fontFamily: 'FixtureFont',
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xff9fcafd),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        builder: (context, child) {
          globalState.measure = Measure.of(context, 1);
          return RepaintBoundary(
            key: _captureKey,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  color: const Color(0xffe5bc58),
                  child: const Text(
                    'FIXTURE TEST RENDER · SYNTHETIC DATA · NOT LIVE APP',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'FixtureFont',
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                Expanded(child: child!),
              ],
            ),
          );
        },
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!_captureEnabled) return;
  final boundary =
      _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('docs/design/implementation-runtime-20261014')
        ..createSync(recursive: true);
      await File(
        '${directory.path}/fixture-$name.png',
      ).writeAsBytes(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);
Finder _switch(String title) => find.widgetWithText(SwitchListTile, title);
Finder _unknownOne(String title) =>
    find.widgetWithText(CheckboxListTile, title);
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  setUpAll(() async {
    final fixtureDirectory = Directory.systemTemp.createTempSync(
      'flclash-policy-widget-fixture-',
    );
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => fixtureDirectory.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (fixtureDirectory.existsSync()) {
        fixtureDirectory.deleteSync(recursive: true);
      }
    });
    final font = File('/System/Library/Fonts/Supplemental/Arial Unicode.ttf');
    final bytes = font.existsSync()
        ? await font.readAsBytes()
        : (await rootBundle.load(
            'assets/fonts/JetBrainsMono-Regular.ttf',
          )).buffer.asUint8List();
    final loader = FontLoader('FixtureFont')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final mono = FontLoader('JetBrainsMono')
      ..addFont(rootBundle.load('assets/fonts/JetBrainsMono-Regular.ttf'));
    await mono.load();
  });
  testWidgets(
    'new node set capacity default preserves explicit and existing validity',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final nodes = List.generate(
        5000,
        (index) => LocalNode(
          id: 'capacity-$index',
          sourceId: _nodes.first.sourceId,
          label: 'Capacity member $index',
          sourceLabel: _nodes.first.sourceLabel,
          protocol: _nodes.first.protocol,
          raw: _nodes.first.raw,
          attributes: _nodes.first.attributes,
        ),
      );
      const capacity = <String, Object?>{
        'targetId': localPolicyTargetId,
        'checkTaskCount': 5000,
        'maxCheckTimeoutSeconds': 5,
        'recommendedCheckCycleSeconds': 3960,
      };
      Future<void> open(
        PolicyNodeSet? existing,
        Map<String, Object?> snapshot,
      ) => _pump(
        tester,
        Scaffold(
          body: PolicyNodeSetEditor(
            existing: existing,
            targetId: localPolicyTargetId,
            sources: const {'1': '测试来源 A'},
            nodes: nodes,
            snapshot: snapshot,
          ),
        ),
        const Size(1100, 850),
      );
      await open(null, capacity);
      final strings = AppLocalizations.current;
      await _tapVisible(tester, find.text(strings.advancedConfig));
      String validity() => tester
          .widget<TextFormField>(_field(strings.policyValiditySeconds))
          .controller!
          .text;
      expect(int.parse(validity()), greaterThanOrEqualTo(3930));
      await _tapVisible(tester, _field(strings.policyValiditySeconds));
      await tester.enterText(_field(strings.policyProbeTimeout), '6');
      await tester.pumpAndSettle();
      expect(validity(), '4620');
      await tester.enterText(_field(strings.policyValiditySeconds), '600');
      await tester.enterText(_field(strings.policyProbeTimeout), '10');
      await tester.pumpAndSettle();
      expect(validity(), '600');
      expect(find.text(strings.policyCheckCapacityHint(7140)), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await open(_nodeSet, capacity);
      await _tapVisible(tester, find.text(strings.advancedConfig));
      expect(validity(), '600');
      await tester.enterText(_field(strings.policyProbeTimeout), '10');
      await tester.pumpAndSettle();
      expect(validity(), '600');
      await tester.pumpWidget(const SizedBox());
      await open(null, const {
        'targetId': 'profile:other',
        'checkTaskCount': 5000,
        'maxCheckTimeoutSeconds': 60,
        'recommendedCheckCycleSeconds': 50000,
      });
      await _tapVisible(tester, find.text(strings.advancedConfig));
      expect(validity(), '3960');
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'node set details aggregate bounded pages and reject late responses',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final nodes = List.generate(
        205,
        (index) => LocalNode(
          id: 'fixture-page-$index',
          sourceId: '1',
          label: 'Fixture member ${index.toString().padLeft(3, '0')}',
          sourceLabel: '测试来源 A',
          protocol: 'ss',
          raw: const {},
          attributes: _nodes.first.attributes,
        ),
      );
      final requests = <Map<String, Object?>>[];
      Completer<Map<String, Object?>>? waiting;
      Map<String, Object?> response(int offset, {int latency = 48}) => {
        'revision': 7,
        'nodeSetId': _nodeSet.id,
        'offset': offset,
        'limit': 200,
        'total': nodes.length,
        'hasMore': offset + 200 < nodes.length,
        'memberCount': nodes.length,
        'availableCount': nodes.length,
        'pendingCount': 0,
        'restrictedCount': 0,
        'checksWaiting': 2,
        'checksInFlight': 1,
        'sampleAt': 1791939600000,
        'probe': _nodeSet.probe.toJson(),
        'nodes': [
          for (final node in nodes.skip(offset).take(200))
            {
              'nodeId': node.id,
              'eligible': true,
              'healthy': true,
              'lastProbeAt': 1791939600000,
              'latencyMillis': latency,
            },
        ],
      };
      await _pump(
        tester,
        Scaffold(
          body: PolicyNodeSetEditor(
            existing: _nodeSet,
            targetId: localPolicyTargetId,
            sources: const {'1': '测试来源 A'},
            nodes: nodes,
            snapshot: _snapshot,
            loadStatus: (params) async {
              requests.add(params);
              final pending = waiting;
              if (pending != null) return pending.future;
              return response(params['offset']! as int);
            },
          ),
        ),
        const Size(1100, 850),
      );
      expect(requests.map((request) => request['offset']), [0, 200]);
      expect(requests.every((request) => request['limit'] == 200), isTrue);
      expect(
        requests.every((request) => request['includeUnavailable'] == true),
        isTrue,
      );
      expect(find.text('Fixture member 000'), findsOneWidget);
      expect(find.text('Fixture member 049'), findsOneWidget);
      expect(find.text('Fixture member 050'), findsNothing);
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('node-members-next-page')),
      );
      expect(requests, hasLength(2));
      expect(find.text('Fixture member 000'), findsNothing);
      expect(find.text('Fixture member 050'), findsOneWidget);
      final search = find.byKey(const ValueKey('node-members-search'));
      await tester.ensureVisible(search);
      await tester.enterText(search, 'member 204');
      await tester.pumpAndSettle();
      expect(find.text('Fixture member 204'), findsOneWidget);
      expect(find.text('48 ms'), findsOneWidget);
      expect(requests, hasLength(2));
      final strings = AppLocalizations.current;
      await _tapVisible(tester, find.text(strings.advancedConfig));
      waiting = Completer<Map<String, Object?>>();
      await tester.pump(const Duration(seconds: 6));
      expect(requests.last['offset'], 0);
      final old = waiting;
      await tester.enterText(_field(strings.policyProbeTimeout), '9');
      await tester.pump();
      old.complete(response(0, latency: 999));
      await tester.pumpAndSettle();
      expect(find.text('999 ms'), findsNothing);
      expect(find.text('48 ms'), findsNothing);
      await tester.enterText(_field(strings.policyProbeTimeout), '5');
      await tester.pump();
      waiting = Completer<Map<String, Object?>>();
      await tester.pump(const Duration(seconds: 6));
      final disposed = waiting;
      await tester.pumpWidget(const SizedBox());
      disposed.complete(response(0, latency: 999));
      await tester.pump();
      expect(tester.takeException(), null);
    },
  );
  for (final width in [944.0, 360.0]) {
    testWidgets(
      'rule AI shortcut uses the main module without execution $width',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = _FixtureWorkbench();
        final desktop = width > 600;
        final launcher = Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showExtend<void>(
                context,
                props: const ExtendProps(forceFull: true),
                builder: (_) => const LocalPolicyWorkbenchView(),
              ),
              child: const Text('Open rules'),
            ),
          ),
        );
        await _pump(
          tester,
          desktop ? const LocalPolicyWorkbenchView() : launcher,
          Size(width, desktop ? 568 : 740),
          workbench: controller,
        );
        if (!desktop) await _tapVisible(tester, find.text('Open rules'));
        final strings = AppLocalizations.current;
        await _tapVisible(
          tester,
          find.widgetWithText(Tab, strings.policyRulesTab),
        );
        await tester.scrollUntilVisible(
          find.text(strings.policyAiOptimizeRule),
          200,
          scrollable: find
              .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable),
              )
              .first,
          maxScrolls: 12,
        );
        await _tapVisible(tester, find.text(strings.policyAiOptimizeRule));
        final container = globalState.container;
        expect(container.read(currentPageLabelProvider), PageLabel.aiAssistant);
        expect(
          container.read(aiComposerContextProvider),
          strings.policyAiOptimizationRequest(localPolicyTargetId),
        );
        expect(find.byType(AiAssistantView), findsNothing);
        expect(controller.commits, 0);
        expect(controller.proposed, isNull);
        if (!desktop) {
          expect(find.byType(LocalPolicyWorkbenchView), findsNothing);
          expect(find.text('Open rules'), findsOneWidget);
        }
        final ai = navigation.getItems().singleWhere(
          (item) => item.label == PageLabel.aiAssistant,
        );
        expect(ai.modes, contains(NavigationItemMode.mobile));
        expect(ai.modes, contains(NavigationItemMode.desktop));
        expect(ai.modes, isNot(contains(NavigationItemMode.more)));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
      skip: !Platform.isMacOS,
    );
  }
  testWidgets(
    'node set ordinary advanced preserves values and unknown multiplier modes exclude each other',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      PolicyNodeSetEdit? saved;
      await _pump(
        tester,
        Scaffold(
          body: PolicyNodeSetEditor(
            existing: _nodeSet,
            targetId: localPolicyTargetId,
            sources: const {'1': '测试来源 A', '2': '测试来源 B'},
            nodes: _nodes,
            snapshot: _snapshot,
            referencedRules: const ['办公网站'],
            onSave: (edit) async {
              saved = edit;
              throw StateError('fixture_write_failed');
            },
          ),
        ),
        const Size(1100, 850),
      );
      final strings = AppLocalizations.current;
      expect(find.text('大阪 B · 倍率未知'), findsNothing);
      await _capture(tester, '04-node-set-ordinary-desktop');
      await tester.enterText(_field(strings.policyMultiplierLimit), '1.2');
      await _tapVisible(tester, _unknownOne(strings.policyUnknownOne));
      expect(find.text('大阪 B · 倍率未知'), findsOneWidget);
      expect(find.text('香港 D · 1×'), findsNothing);
      expect(find.text('东京 C · 3×'), findsNothing);
      await _tapVisible(tester, find.text(strings.advancedConfig));
      await _tapVisible(
        tester,
        _switch(strings.policyUnknownMultiplierAllowed),
      );
      expect(
        tester
            .widget<CheckboxListTile>(_unknownOne(strings.policyUnknownOne))
            .value,
        false,
      );
      expect(
        tester
            .widget<SwitchListTile>(
              _switch(strings.policyUnknownMultiplierAllowed),
            )
            .value,
        true,
      );
      await tester.enterText(_field(strings.policyProbeTimeout), '7');
      await tester.pumpAndSettle();
      expect(find.text('48 ms'), findsNothing);
      await _capture(tester, '05-node-set-advanced-desktop');
      await _tapVisible(tester, find.text(strings.advancedConfig));
      expect(
        tester
            .widget<ExpansionTile>(
              find.byKey(const ValueKey('node-set-advanced-settings')),
            )
            .maintainState,
        isTrue,
      );
      expect(_field(strings.policyProbeTimeout), findsNothing);
      expect(
        tester
            .widget<TextFormField>(_field(strings.policyMultiplierLimit))
            .controller!
            .text,
        '1.2',
      );
      await _tapVisible(tester, _unknownOne(strings.policyUnknownOne));
      await _tapVisible(tester, find.text(strings.advancedConfig));
      expect(
        tester
            .widget<SwitchListTile>(
              _switch(strings.policyUnknownMultiplierAllowed),
            )
            .value,
        false,
      );
      expect(
        tester
            .widget<TextFormField>(_field(strings.policyProbeTimeout))
            .controller!
            .text,
        '7',
      );
      await _tapVisible(tester, find.text(strings.policyCheckSave));
      expect(saved!.nodeSet.maxMultiplier, 1.2);
      expect(saved!.nodeSet.unknownMultiplier, UnknownMultiplier.assumeOne);
      expect(saved!.nodeSet.probe.timeoutSeconds, 7);
      expect(find.byType(PolicyNodeSetEditor), findsOneWidget);
      await _tapVisible(tester, find.text(strings.advancedConfig));
      expect(
        tester
            .widget<TextFormField>(_field(strings.policyMultiplierLimit))
            .controller!
            .text,
        '1.2',
      );
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'node set narrow keyboard and view switching preserve failed save inputs',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      PolicyNodeSetEdit? saved;
      await _pump(
        tester,
        Scaffold(
          body: PolicyNodeSetEditor(
            existing: _nodeSet,
            targetId: localPolicyTargetId,
            sources: const {'1': '测试来源 A', '2': '测试来源 B'},
            nodes: _nodes,
            snapshot: _snapshot,
            onSave: (edit) async {
              saved = edit;
              throw StateError('fixture_failure');
            },
          ),
        ),
        const Size(390, 700),
      );
      final strings = AppLocalizations.current;
      final view = find.byKey(const ValueKey('node-set-mobile-view'));
      final name = _field(strings.name);
      await tester.enterText(name, '键盘下保留的节点组');
      await _capture(tester, '04-node-set-ordinary-narrow');
      await _tapVisible(tester, find.text(strings.advancedConfig));
      await _tapVisible(tester, _field(strings.policyProbeTimeout));
      await tester.enterText(_field(strings.policyProbeTimeout), '8');
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.descendant(of: view, matching: find.text(strings.policyNodes)),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<SegmentedButton<bool>>(view).selected, {true});
      expect(find.byKey(const ValueKey('node-members-search')), findsOneWidget);
      expect(tester.widget<TextFormField>(name).controller!.text, '键盘下保留的节点组');
      await tester.tap(
        find.descendant(of: view, matching: find.text(strings.general)),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(_field(strings.policyProbeTimeout))
            .controller!
            .text,
        '8',
      );
      final save = find.widgetWithText(FilledButton, strings.policyCheckSave);
      expect(save.hitTestable(), findsOneWidget);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saved!.nodeSet.label, '键盘下保留的节点组');
      expect(saved!.nodeSet.probe.timeoutSeconds, 8);
      expect(find.byType(PolicyNodeSetEditor), findsOneWidget);
      expect(tester.widget<TextFormField>(name).controller!.text, '键盘下保留的节点组');
      expect(
        tester
            .widget<TextFormField>(_field(strings.policyProbeTimeout))
            .controller!
            .text,
        '8',
      );
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await _capture(tester, '05-node-set-advanced-narrow');
      await _tapVisible(tester, find.byTooltip(strings.cancel));
      expect(find.text(strings.policyUnsavedTitle), findsOneWidget);
      await _tapVisible(tester, find.text(strings.policyContinueEditing));
      expect(find.byType(PolicyNodeSetEditor), findsOneWidget);
      expect(tester.widget<TextFormField>(name).controller!.text, '键盘下保留的节点组');
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('node set desktop settings and members scroll independently', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final nodes = List.generate(
      75,
      (index) => LocalNode(
        id: 'scroll-$index',
        sourceId: '1',
        label: 'Scroll member $index',
        sourceLabel: '测试来源 A',
        protocol: 'ss',
        raw: const {},
        attributes: _nodes.first.attributes,
      ),
    );
    await _pump(
      tester,
      Scaffold(
        body: PolicyNodeSetEditor(
          existing: _nodeSet,
          targetId: localPolicyTargetId,
          sources: const {'1': '测试来源 A'},
          nodes: nodes,
        ),
      ),
      const Size(1100, 850),
    );
    final settings = find.byKey(const ValueKey('node-set-settings-scroll'));
    final members = find.byKey(const ValueKey('node-members-scroll'));
    final settingsScroll = tester
        .widget<SingleChildScrollView>(settings)
        .controller!;
    final membersScroll = tester
        .widget<SingleChildScrollView>(members)
        .controller!;
    final name = _field(AppLocalizations.current.name);
    final save = find.widgetWithText(
      FilledButton,
      AppLocalizations.current.policyCheckSave,
    );
    final namePosition = tester.getTopLeft(name);
    final savePosition = tester.getTopLeft(save);
    expect(tester.getSize(settings).width, inInclusiveRange(320, 340));
    expect(
      tester.getRect(settings).right,
      lessThanOrEqualTo(tester.getRect(members).left),
    );
    expect(find.byKey(const ValueKey('node-set-mobile-view')), findsNothing);
    await tester.drag(settings, const Offset(0, -240));
    await tester.pumpAndSettle();
    expect(settingsScroll.offset, greaterThan(0));
    expect(membersScroll.offset, 0);
    final leftOffset = settingsScroll.offset;
    await tester.drag(members, const Offset(0, -280));
    await tester.pumpAndSettle();
    expect(membersScroll.offset, greaterThan(0));
    expect(settingsScroll.offset, leftOffset);
    expect(tester.getTopLeft(name), namePosition);
    expect(tester.getTopLeft(save), savePosition);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'rules render order schedule skip right edit and freely movable all traffic',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _FixtureWorkbench();
      await _pump(
        tester,
        const LocalPolicyWorkbenchView(),
        const Size(1100, 1000),
        workbench: controller,
      );
      final strings = AppLocalizations.current;
      await _tapVisible(
        tester,
        find.widgetWithText(Tab, strings.policyRulesTab),
      );
      expect(
        tester.getTopLeft(find.text(strings.policyAddRule)).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('fixture-manual'))).dy,
        ),
      );
      expect(
        tester.getTopLeft(find.text(strings.policyAiOptimizeRule)).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('fixture-manual'))).dy,
        ),
      );
      expect(
        tester.getTopLeft(find.text('办公网站')).dy <
            tester.getTopLeft(find.text('AI 初始规则')).dy,
        true,
      );
      expect(
        tester.getTopLeft(find.text('AI 初始规则')).dy <
            tester.getTopLeft(find.text('其余流量').first).dy,
        true,
      );
      expect(find.textContaining(strings.policyScheduleSkip), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('fixture-remaining')),
          matching: find.byType(ReorderableDragStartListener),
        ),
        findsOneWidget,
      );
      await _capture(tester, '02-rules-desktop');
      final source = find.descendant(
        of: find.byKey(const ValueKey('fixture-ai')),
        matching: find.byType(ReorderableDragStartListener),
      );
      final point = tester.getCenter(source);
      final gesture = await tester.startGesture(point);
      await tester.pump();
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(
        Offset(
          point.dx,
          tester.getCenter(find.byKey(const ValueKey('fixture-manual'))).dy,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.proposed!.policies.map((rule) => rule.id).toList(), [
        'fixture-ai',
        'fixture-manual',
        'fixture-remaining',
      ]);
      final allTrafficHandle = find.descendant(
        of: find.byKey(const ValueKey('fixture-remaining')),
        matching: find.byType(ReorderableDragStartListener),
      );
      await tester.ensureVisible(allTrafficHandle);
      await tester.pumpAndSettle();
      final start = tester.getCenter(allTrafficHandle);
      final upward = await tester.startGesture(start);
      await tester.pump();
      await upward.moveBy(const Offset(0, -20));
      await tester.pump(const Duration(milliseconds: 50));
      await upward.moveTo(
        Offset(
          start.dx,
          tester.getTopLeft(find.byKey(const ValueKey('fixture-manual'))).dy +
              4,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await upward.up();
      await tester.pumpAndSettle();
      expect(
        controller.proposed!.policies.indexWhere(
          (rule) => rule.id == 'fixture-remaining',
        ),
        lessThan(controller.proposed!.policies.length - 1),
      );
      controller.fail = true;
      await _tapVisible(
        tester,
        find.descendant(
          of: find.byKey(const ValueKey('fixture-manual')),
          matching: find.byIcon(Icons.edit_outlined),
        ),
      );
      expect(find.byType(LocalPolicyEditor), findsOneWidget);
      final name = find.descendant(
        of: find.byKey(const ValueKey('policy-rule-name')),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(name, '修改后保留输入');
      await _capture(tester, '03-rule-editor-desktop');
      await _tapVisible(tester, find.text(strings.save));
      expect(find.byType(LocalPolicyEditor), findsOneWidget);
      expect(tester.widget<TextFormField>(name).controller!.text, '修改后保留输入');
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('rules and editor narrow viewport remain usable', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(tester, const LocalPolicyWorkbenchView(), const Size(390, 700));
    await _tapVisible(
      tester,
      find.widgetWithText(Tab, AppLocalizations.current.policyRulesTab),
    );
    await _capture(tester, '02-rules-narrow');
    await _tapVisible(
      tester,
      find.descendant(
        of: find.byKey(const ValueKey('fixture-manual')),
        matching: find.byIcon(Icons.edit_outlined),
      ),
    );
    await _capture(tester, '03-rule-editor-narrow');
    expect(find.byType(LocalPolicyEditor), findsOneWidget);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'manual node attributes update member preview and dispose safely',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pump(
        tester,
        Scaffold(
          body: PolicyNodeSetEditor(
            existing: _nodeSet,
            targetId: localPolicyTargetId,
            sources: const {'1': '测试来源 A', '2': '测试来源 B'},
            nodes: _nodes,
            snapshot: _snapshot,
          ),
        ),
        const Size(1100, 850),
      );
      final strings = AppLocalizations.current;
      await _tapVisible(tester, find.text('东京 A · 1×'));
      final popup = find.widgetWithText(
        AlertDialog,
        '${strings.policyManualAttribute} · 东京 A · 1×',
      );
      final fields = find.descendant(
        of: popup,
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.first, 'HK');
      await _tapVisible(
        tester,
        find.descendant(of: popup, matching: find.text(strings.save)),
      );
      expect(tester.takeException(), null);
      expect(find.text('东京 A · 1×'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'CLI fixture shows actual service result and cancelling password edit retains it',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = _FixturePasswords();
      final service = LocalControlService(
        passwordStore: store,
        transport: _FixtureControlTransport(),
        supported: true,
        executor: (_) async => {'status': 'completed'},
      );
      await _pump(
        tester,
        Scaffold(body: LocalControlSettings(service: service)),
        const Size(1100, 850),
      );
      final strings = AppLocalizations.current;
      expect(find.text(strings.localControlDisabled), findsOneWidget);
      await _tapVisible(tester, find.byType(SwitchListTile));
      expect(service.enabled, true);
      expect(find.text(strings.localControlReady), findsOneWidget);
      await _capture(tester, '10-cli-desktop');
      final previous = store.value;
      await _tapVisible(tester, find.text(strings.localControlChangePassword));
      await tester.enterText(
        find.byType(TextFormField),
        'fixture-new-password-123',
      );
      await _tapVisible(tester, find.text(strings.cancel));
      expect(store.value, previous);
      expect(store.writes, 1);
      await service.disable();
      store.fail = true;
      await service.enable();
      await _pump(
        tester,
        Scaffold(body: LocalControlSettings(service: service)),
        const Size(390, 700),
      );
      await _capture(tester, '10-cli-narrow');
      expect(find.text(strings.localControlUnavailable), findsOneWidget);
      expect(service.enabled, false);
      expect(tester.takeException(), null);
      await service.close();
      await tester.pumpWidget(const SizedBox());
      service.dispose();
    },
  );
}
