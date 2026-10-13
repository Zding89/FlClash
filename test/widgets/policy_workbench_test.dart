import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/policy/policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

const _document = LocalPolicyDocument(
  policiesEnabled: true,
  policies: [
    LocalPolicy(
      id: 'rule',
      label: 'Priority rule',
      targetId: 'profile:1',
      candidateNodeIds: ['1:a', '1:b'],
    ),
  ],
);

class _Controller extends Mock implements WorkbenchController {
  LocalPolicyDocument? proposed;
  int applies = 0;
  @override
  Future<LocalPolicyDocument> readPolicies() async => _document;
  @override
  Future<ConfigurationProposal> proposePolicies(
    LocalPolicyDocument value,
  ) async {
    proposed = value;
    return const ConfigurationProposal(
      id: 'proposal',
      summary: 'Change local policies',
      highRisk: true,
      expiresAt: 9999999999999,
      differences: [
        ConfigurationDifference(
          path: 'policiesEnabled',
          before: true,
          after: false,
        ),
      ],
      validation: {},
    );
  }

  @override
  Future<Map<String, Object?>> commit(
    ConfigurationProposal proposal, {
    required ConfigurationApproval approve,
    bool Function()? isCurrent,
  }) async {
    if (!await approve(proposal) || isCurrent?.call() == false) {
      return {'status': 'rejected'};
    }
    applies++;
    return {'status': 'applied'};
  }
}

void main() {
  testWidgets(
    'disabling one rule retains definitions and rejecting approval prevents apply',
    (tester) async {
      tester.view.physicalSize = const Size(680, 580);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _Controller();
      final container = ProviderContainer(
        overrides: [
          workbenchControllerProvider.overrideWithValue(controller),
          localPoliciesProvider.overrideWith((_) => Stream.value(_document)),
          localPolicyStatusProvider.overrideWith(
            (_) => Stream.value({'state': 'core_disconnected'}),
          ),
          workbenchChangesProvider.overrideWith((_) => Stream.value([])),
          profilesProvider.overrideWithBuild((_, _) => []),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.delegate.supportedLocales,
            builder: (context, child) {
              globalState.measure = Measure.of(context, 1);
              return child!;
            },
            home: const LocalPolicyWorkbenchView(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppLocalizations.current.policyRulesTab));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(controller.proposed?.policies.single.enabled, false);
      expect(controller.proposed?.policies.single.candidateNodeIds, [
        '1:a',
        '1:b',
      ]);
      expect(controller.applies, 0);
      await tester.tap(find.text(AppLocalizations.current.aiReject));
      await tester.pumpAndSettle();
      expect(controller.applies, 0);
      expect(
        find.text(AppLocalizations.current.policyRejectedStatus),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
