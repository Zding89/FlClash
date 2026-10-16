import 'dart:convert';
import 'dart:async';

import 'package:fl_clash/ai/runtime.dart';
import '../support/ai_visual_capture.dart';

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
  bool failDelete = false;
  bool failMigration = false;
  final pending = <String, Completer<String?>>{};
  @override
  Future<String?> read(String credentialId) {
    if (failMigration) {
      failMigration = false;
      return Future.error(const LegacyCredentialMigrationException());
    }
    return pending[credentialId]?.future ?? Future.value(secret);
  }

  @override
  Future<void> write(String credentialId, String value) async {
    secret = value;
  }

  @override
  Future<void> delete(String credentialId) async {
    if (failDelete) throw StateError('credential deletion failed');
    secret = null;
  }
}

class _Controller extends Mock implements WorkbenchController {
  _Controller({
    this.scriptPreview = false,
    this.settings = _settings,
    this.proposalError,
  });
  final AgentSettings settings;
  final bool scriptPreview;
  final Exception? proposalError;
  AgentSettings? proposed;
  int closes = 0;
  bool finalApproved = false;
  @override
  final _Keys credentials = _Keys();
  @override
  Future<AgentSettings> readAgentSettings() async => settings;
  @override
  Future<void> closeAgent() async {
    closes++;
  }

  @override
  Future<ConfigurationProposal> proposeAgentSettings(
    AgentSettings settings,
  ) async {
    if (proposalError != null) throw proposalError!;
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
    bool requireApproval = false,
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
  _Controller controller, {
  bool settle = true,
  AgentRuntime Function()? runtimeFactory,
}) async {
  final container = ProviderContainer(
    overrides: [
      workbenchControllerProvider.overrideWithValue(controller),
      agentSettingsProvider.overrideWith(
        (_) => Stream.value(controller.settings),
      ),
    ],
  );
  globalState.container = container;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: aiVisualCapture ? const Locale('zh', 'CN') : null,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          fontFamily: aiVisualCapture ? 'AiVisualLatin' : null,
          fontFamilyFallback: aiVisualCapture ? const ['AiVisualCjk'] : null,
        ),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        builder: (context, child) {
          globalState.measure = Measure.of(context, 1);
          return RepaintBoundary(
            key: const ValueKey('ai-visual-root'),
            child: child,
          );
        },
        home: aiVisualSurface(
          'V4 AI 连接与模型',
          AiSettingsView(runtimeFactory: runtimeFactory ?? createAiTestRuntime),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
  return container;
}

Future<void> _editKey(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('ai-edit-existing')));
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

class _ModelsTransport implements AgentTransport {
  final outputController = StreamController<List<int>>.broadcast();
  final diagnosticController = StreamController<List<int>>.broadcast();
  final exited = Completer<int>();
  bool closed = false;
  @override
  Stream<List<int>> get output => outputController.stream;
  @override
  Stream<List<int>> get diagnostics => diagnosticController.stream;
  @override
  Future<int> get exitCode => exited.future;
  @override
  Future<void> write(List<int> bytes) async {
    final frame = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (frame['type'] != 'listModels') return;
    for (final event in [
      {
        'type': 'models',
        'data': {
          'models': [
            {'id': 'deepseek-chat', 'name': 'DeepSeek Chat'},
            {'id': 'deepseek-reasoner', 'name': 'DeepSeek Reasoner'},
          ],
        },
      },
      {
        'type': 'done',
        'data': {'cancelled': false, 'failed': false},
      },
    ]) {
      outputController.add(
        utf8.encode('${jsonEncode({...frame, ...event})}\n'),
      );
    }
  }

  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    exited.complete(0);
    unawaited(outputController.close());
    unawaited(diagnosticController.close());
  }
}

const _secondConnection = AgentConnection(
  id: 'second',
  label: '备用连接',
  provider: 'openai',
  model: 'gpt-test',
);
const _multipleSettings = AgentSettings(
  enabled: true,
  selectedConnectionId: 'existing',
  connections: [_connection, _secondConnection],
);

void main() {
  testWidgets(
    'a declined legacy key import still opens an editable key field',
    (tester) async {
      final controller = _Controller();
      controller.credentials.failMigration = true;
      final container = await _mount(tester, controller);
      addTearDown(container.dispose);

      expect(find.byKey(const ValueKey('ai-connection-key')), findsOneWidget);
      expect(
        tester
            .widget<AiConnectionEditor>(find.byType(AiConnectionEditor))
            .hasKey,
        isFalse,
      );
      expect(
        find.text(AppLocalizations.current.aiCredentialMigrationRequired),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('ai-connection-key')),
        'replacement-key',
      );
      expect(find.text('replacement-key'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final fails in [false, true]) {
    testWidgets(
      'deleting key updates embedded credential presence only on success $fails',
      (tester) async {
        final controller = _Controller();
        controller.credentials.failDelete = fails;
        final container = await _mount(tester, controller);
        addTearDown(container.dispose);
        expect(
          tester
              .widget<AiConnectionEditor>(find.byType(AiConnectionEditor))
              .hasKey,
          true,
        );
        await tester.tap(find.byType(PopupMenuButton<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(AppLocalizations.current.aiDeleteKey));
        await tester.pumpAndSettle();
        await tester.tap(find.text(AppLocalizations.current.delete));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<AiConnectionEditor>(find.byType(AiConnectionEditor))
              .hasKey,
          fails,
        );
        expect(controller.credentials.secret, fails ? 'old-secret' : null);
        if (!fails) {
          expect(find.text(AppLocalizations.current.aiKeyStored), findsNothing);
          expect(
            find.text(AppLocalizations.current.aiKeyRequired),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'credential loading freezes the old editor while latest connection may still change',
    (tester) async {
      final controller = _Controller(settings: _multipleSettings);
      final container = await _mount(tester, controller);
      addTearDown(container.dispose);
      final pending = Completer<String?>();
      controller.credentials.pending[_secondConnection.credentialId] = pending;
      await tester.tap(find.byKey(const ValueKey('ai-edit-second')));
      await tester.pump();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('ai-connection-name')),
            )
            .enabled,
        false,
      );
      await tester.tap(find.byKey(const ValueKey('ai-edit-existing')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('ai-connection-name')),
            )
            .enabled,
        true,
      );
      pending.complete('late-second-key');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('ai-connection-model')),
            )
            .controller!
            .text,
        'deepseek-chat',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('late credential read cannot replace newer connection draft', (
    tester,
  ) async {
    final controller = _Controller(settings: _multipleSettings);
    final pending = Completer<String?>();
    controller.credentials.pending[_connection.credentialId] = pending;
    final container = await _mount(tester, controller, settle: false);
    addTearDown(container.dispose);
    await tester.tap(find.byKey(const ValueKey('ai-edit-second')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.enterText(
      find.byKey(const ValueKey('ai-connection-name')),
      '备用草稿',
    );
    pending.complete('late-key');
    await tester.pumpAndSettle();
    final field = tester.widget<TextFormField>(
      find.byKey(const ValueKey('ai-connection-name')),
    );
    expect(field.controller!.text, '备用草稿');
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('ai-connection-model')),
          )
          .controller!
          .text,
      'gpt-test',
    );
    expect(tester.takeException(), isNull);
  });

  for (final width in [1100.0, 944.0, 390.0, 360.0]) {
    testWidgets(
      'connection workspace discovery and unsaved switch protection $width',
      (tester) async {
        tester.view.physicalSize = Size(width, switch (width) {
          944 => 568,
          360 => 740,
          _ => width > 500 ? 850 : 700,
        });
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await loadAiVisualFonts(tester);
        final controller = _Controller(settings: _multipleSettings);
        final transport = _ModelsTransport();
        final container = await _mount(
          tester,
          controller,
          runtimeFactory: () => AgentRuntime(launcher: () async => transport),
        );
        addTearDown(container.dispose);
        final editor = tester.getRect(find.byType(AiConnectionEditor));
        final connection = tester.getRect(
          find.byKey(const ValueKey('ai-edit-existing')),
        );
        if (width > 500) {
          expect(editor.left, greaterThan(connection.right));
        } else {
          expect(editor.top, greaterThan(connection.bottom));
        }
        await captureAiVisual(tester, 'v4-service-${width.toInt()}');
        await tester.ensureVisible(
          find.byKey(const ValueKey('ai-fetch-models')),
        );
        await tester.tap(find.byKey(const ValueKey('ai-fetch-models')));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await waitAiCondition(
          tester,
          () =>
              transport.closed &&
              find.byType(LinearProgressIndicator).evaluate().isEmpty,
          'Discovery must close its transport and clear fetching progress',
        );
        expect(find.text('deepseek-reasoner'), findsOneWidget);
        expect(find.text(AppLocalizations.current.aiTestPassed), findsNothing);
        await captureAiVisual(tester, 'v4-models-${width.toInt()}');
        expect(
          tester
              .widget<FilledButton>(
                find.ancestor(
                  of: find.text(AppLocalizations.current.aiSaveAndUse),
                  matching: find.byType(FilledButton),
                ),
              )
              .onPressed,
          isNotNull,
        );
        await tester.ensureVisible(
          find.text(AppLocalizations.current.aiAdvanced),
        );
        await captureAiVisual(tester, 'v4-test-more-${width.toInt()}');
        expect(
          find.text(AppLocalizations.current.aiTestConnection),
          findsOneWidget,
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('ai-search-models')),
        );
        await tester.enterText(
          find.byKey(const ValueKey('ai-search-models')),
          'reasoner',
        );
        await tester.pump();
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('ai-model-options')),
            matching: find.text('deepseek-chat'),
          ),
          findsNothing,
        );
        await tester.ensureVisible(find.text('deepseek-reasoner'));
        await tester.tap(find.text('deepseek-reasoner'));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('ai-edit-second')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.text(AppLocalizations.current.aiUnsavedChanges),
          findsOneWidget,
        );
        await captureAiVisual(tester, 'v4-unsaved-${width.toInt()}');
        await tester.tap(find.text(AppLocalizations.current.cancel).last);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(const ValueKey('ai-connection-model')),
              )
              .controller!
              .text,
          'deepseek-reasoner',
        );
        final pendingSwitch = Completer<String?>();
        controller.credentials.pending[_secondConnection.credentialId] =
            pendingSwitch;
        await tester.tap(find.byKey(const ValueKey('ai-edit-second')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text(AppLocalizations.current.aiDiscardChanges));
        await tester.pump();
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(const ValueKey('ai-connection-name')),
              )
              .enabled,
          false,
        );
        expect(
          tester
              .widgetList<ListTile>(
                find.descendant(
                  of: find.byKey(const ValueKey('ai-model-options')),
                  matching: find.byType(ListTile),
                ),
              )
              .every((tile) => tile.onTap == null),
          true,
        );
        pendingSwitch.complete('second-test-key');
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(const ValueKey('ai-connection-model')),
              )
              .controller!
              .text,
          'gpt-test',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }

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

  for (final invalid in [true, false]) {
    testWidgets(
      'local configuration failure is not reported as a network error: invalid=$invalid',
      (tester) async {
        final controller = _Controller(
          proposalError: invalid
              ? const FormatException('fixture-invalid-config')
              : const ConfigurationChangeException(
                  'configuration_version_conflict',
                ),
        );
        final container = await _mount(tester, controller);
        addTearDown(container.dispose);
        await _editKey(tester);
        final strings = AppLocalizations.current;
        expect(
          find.text(
            invalid
                ? strings.aiConfigurationInvalid
                : strings.aiConfigurationSaveFailed,
          ),
          findsOneWidget,
        );
        expect(find.text(strings.aiRequestFailed), findsNothing);
        expect(controller.credentials.secret, 'old-secret');
        expect(controller.closes, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

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
      expect(find.text(AppLocalizations.current.mode), findsOneWidget);
      expect(controller.credentials.secret, 'new-secret');
      await tester.tap(find.text(AppLocalizations.current.cancel).last);
      await tester.pumpAndSettle();
      expect(controller.finalApproved, false);
      expect(controller.credentials.secret, 'old-secret');
      expect(tester.takeException(), isNull);
    },
  );
}
