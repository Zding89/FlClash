import 'dart:convert';

import 'package:fl_clash/ai/credentials.dart';
import 'package:fl_clash/ai/settings.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/ai/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

const _connection = AgentConnection(
  id: 'existing',
  label: 'My model',
  provider: 'deepseek',
  model: 'deepseek-chat',
);
const _settings = AgentSettings(
  enabled: true,
  selectedConnectionId: 'existing',
  connections: [_connection],
);

class _Keys implements AgentCredentialStore {
  String? secret = 'old-secret';
  @override
  Future<String?> read(String credentialId) async => secret;
  @override
  Future<void> write(String credentialId, String value) async {
    secret = value;
  }

  @override
  Future<void> delete(String credentialId) async {
    secret = null;
  }
}

class _Controller extends Mock implements WorkbenchController {
  _Controller({this.scriptPreview = false});
  final bool scriptPreview;
  AgentSettings? proposed;
  int closes = 0;
  bool finalApproved = false;
  @override
  final _Keys credentials = _Keys();
  @override
  Future<AgentSettings> readAgentSettings() async => _settings;
  @override
  Future<void> closeAgent() async {
    closes++;
  }

  @override
  Future<ConfigurationProposal> proposeAgentSettings(
    AgentSettings settings,
  ) async {
    proposed = settings;
    return ConfigurationProposal(
      id: 'proposal',
      summary: 'Connection',
      highRisk: scriptPreview,
      expiresAt: 1000,
      differences: const [
        ConfigurationDifference(
          path: 'ai.connections',
          before: 'old',
          after: 'new',
        ),
      ],
      validation: scriptPreview
          ? {'executionOnly': true, 'requiresScriptExecutionApproval': true}
          : {},
    );
  }

  @override
  Future<Map<String, Object?>> commit(
    ConfigurationProposal proposal, {
    required ConfigurationApproval approve,
    bool Function()? isCurrent,
  }) async {
    if (!scriptPreview) {
      throw const ConfigurationChangeException('configuration_apply_failed');
    }
    finalApproved = await approve(
      const ConfigurationProposal(
        id: 'proposal',
        summary: 'Connection',
        highRisk: true,
        expiresAt: 1000,
        differences: [
          ConfigurationDifference(
            path: 'ai.connections',
            before: 'old',
            after: 'new',
          ),
        ],
        validation: {
          'finalConfigValidated': true,
          'finalConfigDifferences': [
            {'path': 'mode', 'before': 'rule', 'after': 'global'},
          ],
        },
      ),
    );
    return {'status': finalApproved ? 'applied' : 'rejected'};
  }
}

Future<ProviderContainer> _mount(
  WidgetTester tester,
  _Controller controller,
) async {
  final container = ProviderContainer(
    overrides: [
      workbenchControllerProvider.overrideWithValue(controller),
      agentSettingsProvider.overrideWith((_) => Stream.value(_settings)),
    ],
  );
  globalState.container = container;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        builder: (context, child) {
          globalState.measure = Measure.of(context, 1);
          return child!;
        },
        home: const AiSettingsView(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _editKey(WidgetTester tester) async {
  await tester.tap(find.text('My model'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('ai-connection-name')),
    'Renamed',
  );
  await tester.enterText(
    find.byKey(const ValueKey('ai-connection-key')),
    'new-secret',
  );
  await tester.tap(find.text(AppLocalizations.current.aiSaveAndUse));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('failed configuration commit restores the previous key', (
    tester,
  ) async {
    final controller = _Controller();
    final container = await _mount(tester, controller);
    addTearDown(container.dispose);
    await _editKey(tester);
    expect(controller.credentials.secret, 'old-secret');
    expect(controller.closes, 1);
    expect(
      jsonEncode(controller.proposed!.toJson()),
      isNot(contains('new-secret')),
    );
    expect(find.text(AppLocalizations.current.aiSaveFailed), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'preview approval does not approve the final result and rejected final restores key',
    (tester) async {
      final controller = _Controller(scriptPreview: true);
      final container = await _mount(tester, controller);
      addTearDown(container.dispose);
      await _editKey(tester);
      expect(
        find.text(AppLocalizations.current.aiScriptExecutionOnly),
        findsOneWidget,
      );
      expect(find.text(AppLocalizations.current.aiApprove), findsNothing);
      await tester.tap(
        find.text(AppLocalizations.current.aiApproveScriptExecution),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text(AppLocalizations.current.aiFinalConfigDifferences),
        findsOneWidget,
      );
      expect(find.text('mode'), findsOneWidget);
      expect(controller.credentials.secret, 'new-secret');
      await tester.tap(find.text(AppLocalizations.current.aiReject));
      await tester.pumpAndSettle();
      expect(controller.finalApproved, false);
      expect(controller.credentials.secret, 'old-secret');
      expect(tester.takeException(), isNull);
    },
  );
}
