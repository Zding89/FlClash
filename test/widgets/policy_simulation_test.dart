import 'package:drift/native.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/policy/compiler.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/policy/profile_service.dart';
import 'package:fl_clash/policy/simulation.dart';
import 'package:fl_clash/policy/sources.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:fl_clash/views/policy/simulation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Controller extends Mock implements WorkbenchController {
  final database = WorkbenchDatabase(NativeDatabase.memory());
  @override
  PolicyProfileService get profiles =>
      PolicyProfileService(loader: PolicySourceLoader(store: database));
  int calls = 0;
  Map<String, bool?>? suppliedHealth;
  @override
  Future<List<LocalNode>> loadNodes(
    String targetId, {
    bool refresh = false,
    LocalPolicyDocument? document,
  }) async => [
    LocalNode(
      id: '1:a',
      sourceId: '1',
      label: 'Node A',
      sourceLabel: 'Source',
      protocol: 'ss',
      raw: {},
    ),
  ];
  @override
  Future<PolicySimulationResult> simulatePolicies({
    required LocalPolicyDocument document,
    required String targetId,
    required List<PolicySource> sources,
    required Map<String, bool?> health,
    required DateTime now,
    Map<String, int> localUsage = const {},
    List<Map<String, Object?>> steps = const [],
  }) async {
    calls++;
    suppliedHealth = health;
    return const PolicySimulationResult(
      snapshot: {},
      results: [],
      timeline: [
        {
          'at': 0,
          'decisions': [
            {'policyId': 'rule', 'selectedNodeId': '1:a', 'state': 'active'},
            {'policyId': 'empty', 'state': 'skipped'},
          ],
        },
      ],
    );
  }
}

void main() {
  testWidgets(
    'simulation invokes shared evaluator with unknown health and renders Beijing timeline',
    (tester) async {
      final controller = _Controller();
      addTearDown(controller.database.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [profilesProvider.overrideWithBuild((_, _) => [])],
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.delegate.supportedLocales,
            home: Scaffold(
              body: PolicySimulationDialog(
                document: const LocalPolicyDocument(),
                targets: const {'profile:1': 'Source'},
                snapshot: const {},
                controller: controller,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(
          FilledButton,
          AppLocalizations.current.policySimulation,
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.calls, 1);
      expect(controller.suppliedHealth, {'1:a': null});
      expect(find.text('1970-01-01 08:00:00'), findsOneWidget);
      expect(find.textContaining('rule: Source · Node A'), findsOneWidget);
      expect(
        find.textContaining(
          'empty: ${AppLocalizations.current.policyContinueNextRule}',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'empty: ${AppLocalizations.current.policyFallbackReject}',
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
