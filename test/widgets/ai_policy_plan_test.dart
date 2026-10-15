import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_clash/ai/policy_summary.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/views/ai/approval.dart';
import 'package:fl_clash/views/ai/policy_plan.dart';
import 'package:fl_clash/views/ai/presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../support/ai_visual_capture.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [380.0, 1180.0]) {
    testWidgets('local plan is readable without raw paths at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await loadAiVisualFonts(tester);
      await AppLocalizations.load(const Locale('zh', 'CN'));
      const after = LocalPolicyDocument(
        nodeSets: [
          PolicyNodeSet(
            id: 'us',
            label: '美国低倍率',
            targetId: localPolicyTargetId,
            sourceIds: ['7'],
            regions: ['US'],
            preferences: [
              NodePreference(
                type: NodePreferenceType.multiplier,
                direction: SortDirection.ascending,
              ),
            ],
          ),
          PolicyNodeSet(
            id: 'hk',
            label: '香港',
            targetId: localPolicyTargetId,
            sourceIds: ['7'],
            regions: ['HK'],
          ),
        ],
        policies: [
          LocalPolicy(
            id: 'ai',
            label: 'AI 服务',
            targetId: localPolicyTargetId,
            priority: 1,
            scope: PolicyMatch(
              type: PolicyMatchType.domainKeyword,
              values: ['chatgpt', 'claude'],
            ),
            choices: [PolicyChoice(type: PolicyChoiceType.nodeSet, id: 'us')],
          ),
          LocalPolicy(
            id: 'cn',
            label: '国内直连',
            targetId: localPolicyTargetId,
            priority: 2,
            scope: PolicyMatch(
              type: PolicyMatchType.destinationRegion,
              values: ['CN'],
            ),
            action: PolicyAction.direct,
          ),
          LocalPolicy(
            id: 'other',
            label: '其他流量',
            targetId: localPolicyTargetId,
            priority: 3,
            choices: [PolicyChoice(type: PolicyChoiceType.nodeSet, id: 'hk')],
          ),
        ],
      );
      final plan = {
        'before': policyBusinessSummary(
          const LocalPolicyDocument(),
          AppLocalizations.current,
        ),
        'after': policyBusinessSummary(
          after,
          AppLocalizations.current,
          sourceLabels: {'7': '测试机场'},
        ),
      };
      final proposal = ConfigurationProposal(
        id: 'synthetic',
        summary: '内部摘要',
        highRisk: true,
        expiresAt: 2000000000000,
        differences: const [
          ConfigurationDifference(
            path: 'policies.policies',
            before: [],
            after: [],
          ),
          ConfigurationDifference(
            path: 'policies.revision',
            before: 7,
            after: 8,
          ),
        ],
        validation: {'localPolicyPlan': plan},
      );
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh', 'CN'),
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: const Color(0xff006b91),
            fontFamily: aiVisualCapture ? 'AiVisualLatin' : null,
            fontFamilyFallback: aiVisualCapture ? ['AiVisualCjk'] : null,
          ),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          home: Scaffold(
            appBar: AppBar(title: const Text('AI 配置助手')),
            body: RepaintBoundary(
              key: boundary,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: AiToolResultCard(
                  proposal: proposal,
                  result: width < 500
                      ? const {}
                      : const {'status': 'pending_confirmation'},
                  onReview: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('本地规则方案'), findsOneWidget);
      expect(find.text('方案已生成，尚未应用'), findsOneWidget);
      expect(find.text('检查结果'), findsNothing);
      expect(find.text('3 条规则 · 2 个节点组'), findsOneWidget);
      expect(find.textContaining('国内（中国） (GeoIP) → 直连'), findsOneWidget);
      expect(find.text('policies.policies'), findsNothing);
      expect(find.text('policies.revision'), findsNothing);
      expect(find.text(AppLocalizations.current.aiHighRisk), findsNothing);
      expect(find.byType(AiPolicyPlanView), findsOneWidget);
      expect(tester.takeException(), isNull);
      final output = Platform.environment['FLCLASH_CAPTURE_AI_PLAN'];
      if (output != null) {
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$output/plan-${width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
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
          home: Scaffold(
            body: AiConfigurationApprovalDialog(
              proposal: ConfigurationProposal(
                id: proposal.id,
                summary: proposal.summary,
                highRisk: proposal.highRisk,
                expiresAt: proposal.expiresAt,
                differences: proposal.differences,
                validation: {
                  'localPolicyDocuments': {
                    'before': const LocalPolicyDocument()
                        .asStandalone()
                        .toJson(),
                    'after': after.asStandalone().toJson(),
                    'sourceLabels': {'7': '测试机场'},
                  },
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AiPolicyPlanView), findsOneWidget);
      expect(find.text('policies.policies'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'uncovered changes retain full confirmation instead of an empty summary',
    (tester) async {
      await AppLocalizations.load(const Locale('zh', 'CN'));
      const base = LocalPolicy(
        id: 'fixed',
        label: '固定节点规则',
        targetId: localPolicyTargetId,
        choices: [PolicyChoice(type: PolicyChoiceType.node, id: 'node-A')],
      );
      final changes = [
        const ConfigurationDifference(
          path: 'policies.moduleEnabled',
          before: true,
          after: false,
        ),
        ConfigurationDifference(
          path: 'policies.policies',
          before: [base.toJson()],
          after: [
            {
              ...base.toJson(),
              'choices': [
                {'type': 'node', 'id': 'node-B'},
              ],
            },
          ],
        ),
        ConfigurationDifference(
          path: 'policies.policies',
          before: [base.toJson()],
          after: [
            {...base.toJson(), 'cooldownSeconds': 180},
          ],
        ),
      ];
      for (final change in changes) {
        final proposal = ConfigurationProposal(
          id: 'uncovered',
          summary: '完整确认',
          highRisk: true,
          expiresAt: 2000000000000,
          differences: [change],
          validation: const {},
        );
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
            home: Scaffold(
              body: AiConfigurationApprovalDialog(proposal: proposal),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AiPolicyPlanView), findsNothing);
        expect(find.text(change.path), findsOneWidget);
        expect(find.text(AppLocalizations.current.aiHighRisk), findsOneWidget);
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
            home: Scaffold(
              body: SingleChildScrollView(
                child: AiToolResultCard(proposal: proposal),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AiPolicyChangeOverview), findsOneWidget);
        expect(find.text(change.path), findsNothing);
        expect(find.textContaining('node-A'), findsNothing);
        expect(find.textContaining('node-B'), findsNothing);
      }
    },
  );
  testWidgets('unknown region inclusion is visible in a node group edit', (
    tester,
  ) async {
    await AppLocalizations.load(const Locale('zh', 'CN'));
    const group = PolicyNodeSet(
      id: 'us',
      label: '美国组',
      targetId: localPolicyTargetId,
      sourceIds: ['7'],
      regions: ['US'],
    );
    const before = LocalPolicyDocument(nodeSets: [group]);
    final after = LocalPolicyDocument(
      nodeSets: [
        PolicyNodeSet.fromJson({...group.toJson(), 'allowUnknownRegion': true}),
      ],
    );
    final proposal = ConfigurationProposal(
      id: 'unknown-region',
      summary: '本地规则',
      highRisk: true,
      expiresAt: 2000000000000,
      differences: [
        ConfigurationDifference(
          path: 'policies.nodeSets',
          before: [group.toJson()],
          after: [after.nodeSets.single.toJson()],
        ),
      ],
      validation: {
        'localPolicyPlan': {
          'before': policyBusinessSummary(before, AppLocalizations.current),
          'after': policyBusinessSummary(after, AppLocalizations.current),
        },
      },
    );
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
        home: Scaffold(
          body: SingleChildScrollView(
            child: AiToolResultCard(proposal: proposal),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AiPolicyPlanView), findsOneWidget);
    expect(find.textContaining('允许地区未知的节点入组'), findsOneWidget);
    expect(find.textContaining('调整 1'), findsOneWidget);
  });
}
