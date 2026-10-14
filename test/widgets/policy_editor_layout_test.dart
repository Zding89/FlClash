import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/views/policy/node_set_editor.dart';
import 'package:fl_clash/views/policy/rule_editor.dart';
import 'package:fl_clash/views/policy/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _captureEnabled = bool.fromEnvironment(
  'GENERATE_POLICY_LAYOUT_SCREENSHOTS',
);
final _captureKey = GlobalKey();
const _set = PolicyNodeSet(
  id: 'japan',
  label: '日本优选',
  targetId: localPolicyTargetId,
  sourceIds: ['1'],
  regions: ['JP'],
  maxMultiplier: 1,
);
const _rule = LocalPolicy(
  id: 'video',
  label: '视频网站',
  targetId: localPolicyTargetId,
  scope: PolicyMatch(
    type: PolicyMatchType.domainSuffix,
    values: ['youtube.com', 'ytimg.com'],
  ),
  choices: [
    PolicyChoice(type: PolicyChoiceType.nodeSet, id: 'japan'),
    PolicyChoice(type: PolicyChoiceType.node, id: '1:hk'),
  ],
);
final _nodes = [
  for (final region in ['JP', 'HK'])
    LocalNode(
      id: '1:${region.toLowerCase()}',
      sourceId: '1',
      label: region == 'JP' ? '东京 A' : '香港备用',
      sourceLabel: '本地订阅集合',
      protocol: 'ss',
      raw: const {},
      attributes: NodeAttributes(region: region, multiplier: 1),
    ),
];
Future<void> _mount(WidgetTester tester, Widget editor, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff4285c5)),
        useMaterial3: true,
      ),
      builder: (context, child) => RepaintBoundary(
        key: _captureKey,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xffffdf8e),
              padding: const EdgeInsets.all(5),
              child: const Text(
                '合成测试画面 · 示例数据 · 非运行中 App',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'FixtureFont',
                  color: Colors.black,
                  fontSize: 12,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            Expanded(child: child!),
          ],
        ),
      ),
      home: Scaffold(body: editor),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _field(String id) => find.descendant(
  of: find.byKey(ValueKey('policy-rule-$id')),
  matching: find.byType(TextFormField),
);
Finder _nodeField(String label) => find.widgetWithText(TextFormField, label);
Future<void> _capture(WidgetTester tester, String filename) async {
  if (!_captureEnabled) return;
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  final boundary =
      _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('/private/tmp/flclash-visual-v1-v2')
        ..createSync(recursive: true);
      await File(
        '${directory.path}/$filename.png',
      ).writeAsBytes(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  setUpAll(() async {
    final font = File('/System/Library/Fonts/Supplemental/Arial Unicode.ttf');
    final data = font.existsSync()
        ? ByteData.sublistView(await font.readAsBytes())
        : await rootBundle.load('assets/fonts/JetBrainsMono-Regular.ttf');
    await (FontLoader('FixtureFont')..addFont(Future.value(data))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final size in [
    const Size(1100, 850),
    const Size(390, 700),
    const Size(944, 568),
    const Size(360, 740),
  ]) {
    final desktop = size.width >= 900;
    final device = switch (size.width) {
      1100 => 'desktop',
      390 => 'narrow',
      944 => 'desktop-944x568',
      _ => 'narrow-360x740',
    };
    testWidgets(
      'rule $device live draft effect, order and failure retain input',
      (tester) async {
        LocalPolicy? attempted;
        await _mount(
          tester,
          LocalPolicyEditor(
            existing: _rule,
            targets: const {'profile:1': '本地订阅集合'},
            loadNodes: (_) async => _nodes,
            nodeSets: const [_set],
            onSave: (rule, _, _) async {
              attempted = rule;
              throw StateError('write_failed');
            },
          ),
          size,
        );
        final strings = AppLocalizations.current;
        expect(
          find.byKey(const ValueKey('policy-traffic-section')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('policy-choice-section')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('policy-schedule-section')),
          findsOneWidget,
        );
        final traffic = tester.getTopLeft(
          find.byKey(const ValueKey('policy-traffic-section')),
        );
        final effect = tester.getTopLeft(
          find.byKey(const ValueKey('policy-current-effect')),
        );
        expect(desktop ? effect.dx > traffic.dx : effect.dy > traffic.dy, true);
        await tester.enterText(
          find.byKey(const ValueKey('root-domainSuffix-values')),
          'video.example',
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('policy-effect-match')))
              .data,
          'video.example',
        );
        await _capture(tester, 'v1-rule-$device');
        await tester.ensureVisible(
          find.byKey(const ValueKey('policy-schedule-section')),
        );
        await _capture(tester, 'v1-rule-$device-schedule');
        await _tap(tester, find.byKey(const ValueKey('policy-more-settings')));
        await _tap(tester, find.text(strings.policyProbe));
        await tester.ensureVisible(_field('timeout'));
        await tester.enterText(_field('timeout'), '8');
        await _tap(tester, find.text(strings.save));
        expect(attempted!.scope.values, ['video.example']);
        expect(attempted!.probe.timeoutSeconds, 8);
        expect(attempted!.choices.map((choice) => choice.id).toList(), [
          'japan',
          '1:hk',
        ]);
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(const ValueKey('root-domainSuffix-values')),
              )
              .initialValue,
          'video.example',
        );
        expect(find.byType(LocalPolicyEditor), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
    testWidgets(
      'node set $device four sections, truthful status and mode preservation',
      (tester) async {
        PolicyNodeSetEdit? attempted;
        var calls = 0;
        await _mount(
          tester,
          PolicyNodeSetEditor(
            existing: _set,
            targetId: localPolicyTargetId,
            sources: const {'1': '本地订阅集合'},
            nodes: _nodes,
            snapshot: const {
              'revision': 7,
              'checksWaiting': 24,
              'checksInFlight': 8,
            },
            loadStatus: (params) async {
              calls++;
              return {
                'revision': 7,
                'nodeSetId': 'japan',
                'offset': 0,
                'probe': _set.probe.toJson(),
                'checksWaiting': 24,
                'checksInFlight': 8,
                'sampleAt': 1791939600000,
                'total': 1,
                'availableCount': 1,
                'nodes': [
                  {
                    'nodeId': '1:jp',
                    'eligible': true,
                    'lastProbeAt': 1791939600000,
                    'latencyMillis': 48,
                  },
                ],
              };
            },
            onSave: (edit) async {
              attempted = edit;
              throw StateError('write_failed');
            },
          ),
          size,
        );
        final strings = AppLocalizations.current;
        await _capture(tester, 'v3-node-group-$device-ordinary');
        await _tap(tester, find.text(strings.advancedConfig));
        for (final id in [
          'node-set-check-method',
          'node-set-check-frequency',
          'node-set-selection-recovery',
          'node-set-check-status',
        ]) {
          expect(find.byKey(ValueKey(id)), findsOneWidget);
        }
        final method = tester.getTopLeft(
          find.byKey(const ValueKey('node-set-check-method')),
        );
        final frequency = tester.getTopLeft(
          find.byKey(const ValueKey('node-set-check-frequency')),
        );
        expect(
          desktop ? frequency.dx > method.dx : frequency.dy > method.dy,
          true,
        );
        expect(
          find.textContaining('${strings.policyChecksWaiting}: 24'),
          findsOneWidget,
        );
        expect(
          find.textContaining(policyBeijingTime(1791939600000)),
          findsWidgets,
        );
        await _capture(tester, 'v2-checks-$device');
        await tester.ensureVisible(
          find.byKey(const ValueKey('node-set-check-status')),
        );
        await _capture(tester, 'v2-checks-$device-status');
        await tester.ensureVisible(_nodeField(strings.policyProbeTimeout));
        await tester.enterText(_nodeField(strings.policyProbeTimeout), '8');
        await tester.pumpAndSettle();
        expect(find.text(strings.policyDraftStatusHint), findsOneWidget);
        expect(
          find.textContaining('${strings.policyChecksWaiting}: 24'),
          findsNothing,
        );
        expect(find.text('48 ms'), findsNothing);
        final initialCalls = calls;
        await tester.pump(const Duration(seconds: 3));
        expect(calls, initialCalls);
        await _tap(tester, find.text(strings.general));
        expect(_nodeField(strings.policyProbeTimeout), findsNothing);
        await _tap(tester, find.text(strings.advancedConfig));
        expect(
          tester
              .widget<TextFormField>(_nodeField(strings.policyProbeTimeout))
              .controller!
              .text,
          '8',
        );
        await _tap(tester, find.text(strings.policyCheckSave));
        expect(attempted!.nodeSet.probe.timeoutSeconds, 8);
        expect(attempted!.nodeSet.regions, ['JP']);
        expect(find.byType(PolicyNodeSetEditor), findsOneWidget);
        expect(
          tester
              .widget<TextFormField>(_nodeField(strings.policyProbeTimeout))
              .controller!
              .text,
          '8',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
