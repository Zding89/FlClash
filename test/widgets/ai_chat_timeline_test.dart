import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:fl_clash/ai/credentials.dart';
import 'package:fl_clash/ai/runtime.dart';
import 'package:fl_clash/ai/settings.dart';
import 'package:fl_clash/capabilities/service.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/configuration/resources.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/ai_history.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/ai/assistant.dart';
import 'package:fl_clash/views/ai/message.dart';
import 'package:fl_clash/views/ai/presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/ai_visual_capture.dart';

class _Transport implements AgentTransport {
  _Transport({
    this.messageIds = false,
    this.tools = true,
    this.internalProgress = false,
  });
  final bool internalProgress;
  final bool messageIds;
  final bool tools;
  final prompts = <Map<String, dynamic>>[];
  final outputController = StreamController<List<int>>.broadcast();
  final diagnosticsController = StreamController<List<int>>.broadcast();
  final exited = Completer<int>();
  final context = <Map<String, Object?>>[];
  Map<String, dynamic>? prompt;

  void emit(String type, Map<String, Object?> data) {
    outputController.add(
      utf8.encode('${jsonEncode({...prompt!, 'type': type, 'data': data})}\n'),
    );
  }

  @override
  Stream<List<int>> get output => outputController.stream;
  @override
  Stream<List<int>> get diagnostics => diagnosticsController.stream;
  @override
  Future<int> get exitCode => exited.future;

  @override
  Future<void> write(List<int> bytes) async {
    final frame = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final turn = prompts.length;
    if (frame['type'] == 'prompt') {
      prompt = frame;
      prompts.add(frame);
      emit('text', {
        'text': 'Preparing ${prompts.length}',
        if (messageIds) 'messageId': 'progress-${prompts.length}',
        if (internalProgress) 'phase': 'progress',
      });
      emit('text', {
        'text': ' draft',
        if (messageIds) 'messageId': 'progress-${prompts.length}',
        if (internalProgress) 'phase': 'progress',
      });
      if (tools) {
        emit('toolRequest', {
          'requestId': 'request-${prompts.length}',
          'toolCallId': 'call-${prompts.length}',
          'name': 'application_invoke',
          'arguments': {
            'command': 'policies_propose',
            'params': <String, Object?>{},
          },
        });
      } else {
        finish();
      }
    } else if (frame['type'] == 'toolResult') {
      context.addAll([
        {'role': 'user', 'content': prompt!['data']['user']},
        {
          'role': 'assistant',
          'content': [
            {'type': 'text', 'text': 'Preparing $turn draft'},
            {
              'type': 'toolCall',
              'id': 'call-$turn',
              'name': 'application_invoke',
              'arguments': {'command': 'policies_propose', 'params': {}},
            },
          ],
        },
        {
          'role': 'toolResult',
          'toolCallId': 'call-$turn',
          'toolName': 'application_invoke',
          'isError': false,
          'content': [
            {'type': 'text', 'text': jsonEncode(frame['data']['value'])},
          ],
        },
        {
          'role': 'assistant',
          'content': [
            {'type': 'text', 'text': 'Finished $turn'},
          ],
        },
      ]);
      finish();
    }
  }

  void finish() {
    emit('text', {
      'text': 'Finished ${prompts.length}',
      if (messageIds) 'messageId': 'final-${prompts.length}',
      'phase': 'final',
    });
    if (tools) emit('context', {'messages': context});
    emit('done', {'cancelled': false, 'failed': false});
  }

  @override
  Future<void> close() async {
    if (exited.isCompleted) return;
    exited.complete(0);
    unawaited(outputController.close());
    unawaited(diagnosticsController.close());
  }
}

class _Credentials implements AgentCredentialStore {
  @override
  Future<String?> read(String credentialId) async => 'test-secret';
  @override
  Future<void> write(String credentialId, String secret) async {}
  @override
  Future<void> delete(String credentialId) async {}
}

class _Controller extends Mock implements WorkbenchController {
  _Controller(this.runtime);
  @override
  late Ref ref;
  @override
  final store = WorkbenchDatabase(NativeDatabase.memory());
  @override
  final AgentRuntime runtime;
  @override
  ResourceChangeService get resources => ResourceChangeService(
    store: store,
    environment: FlutterResourceEnvironment(ref: ref, store: store),
  );
  @override
  final credentials = _Credentials();
  @override
  Future<void> closeAgent() => runtime.close();
}

class _Capabilities extends Mock implements ApplicationCapabilityService {
  _Capabilities({this.sameId = false});
  final bool sameId;
  int calls = 0;

  @override
  Future<Map<String, Object?>> execute(
    String command,
    Map<String, Object?> params, {
    String? idempotencyKey,
    int? credentialGeneration,
    String origin = 'cli',
    bool Function()? isCurrent,
    ConfigurationApproval? approve,
  }) async {
    calls++;
    final proposal = {
      'id': sameId ? 'draft' : 'draft-$calls',
      'summary': 'Plan $calls',
      'expiresAt': 9999999999999,
      'differences': <Object?>[],
      'validation': <String, Object?>{},
    };
    final value = <String, Object?>{
      'proposal': proposal,
      if (!sameId && calls > 1) 'supersedesId': 'draft-${calls - 1}',
    };
    return calls.isEven
        ? {'status': 'proposed', 'result': value}
        : {'status': 'proposed', ...value};
  }
}

Future<ProviderContainer> _mount(
  WidgetTester tester,
  _Transport transport,
  _Capabilities capabilities,
) async {
  final controller = _Controller(AgentRuntime(launcher: () async => transport));
  final container = ProviderContainer(
    overrides: [
      workbenchControllerProvider.overrideWith((ref) {
        controller.ref = ref;
        return controller;
      }),
      applicationCapabilityServiceProvider.overrideWithValue(capabilities),
      currentProfileProvider.overrideWith((_) => null),
      agentSettingsProvider.overrideWith(
        (_) => Stream.value(
          const AgentSettings(
            enabled: true,
            selectedConnectionId: 'test',
            connections: [
              AgentConnection(
                id: 'test',
                label: 'Test',
                provider: 'deepseek',
                model: 'deepseek-chat',
              ),
            ],
          ),
        ),
      ),
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
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        builder: (context, child) {
          globalState.measure = Measure.of(context, 1);
          return child!;
        },
        home: const AiAssistantView(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(controller.store.close);
  addTearDown(container.dispose);
  return container;
}

Future<void> _send(WidgetTester tester, int turn) async {
  await tester.enterText(
    find.byKey(const ValueKey('ai-prompt')),
    'Question $turn',
  );
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('ai-send')));
  await tester.pump();
  await waitAiCondition(
    tester,
    () => find.byKey(const ValueKey('ai-send')).evaluate().isNotEmpty,
    'The response must finish',
  );
  await tester.pumpAndSettle();
  expect(
    find.text('Finished $turn'),
    findsOneWidget,
    reason: tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data)
        .join(' | '),
  );
}

void main() {
  testWidgets('legacy text stays on either side of its tool card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transport = _Transport();
    final container = await _mount(tester, transport, _Capabilities());
    await _send(tester, 1);
    expect(
      tester
          .widget<ListView>(find.byKey(const ValueKey('ai-conversation-list')))
          .semanticChildCount,
      4,
    );
    final messages = tester.widgetList<AiAssistantMarkdown>(
      find.byType(AiAssistantMarkdown),
    );
    expect(messages.map((message) => message.text), [
      'Preparing 1 draft',
      'Finished 1',
    ]);
    final before = find.byWidgetPredicate(
      (widget) =>
          widget is AiAssistantMarkdown && widget.text == 'Preparing 1 draft',
    );
    final after = find.byWidgetPredicate(
      (widget) => widget is AiAssistantMarkdown && widget.text == 'Finished 1',
    );
    expect(
      tester.getTopLeft(before).dy,
      lessThan(tester.getTopLeft(find.byType(AiToolResultCard)).dy),
    );
    expect(
      tester.getTopLeft(after).dy,
      greaterThan(tester.getBottomLeft(find.byType(AiToolResultCard)).dy),
    );
    final saved = (await container.read(aiHistoryStoreProvider).list()).single;
    expect(saved.messages.map((message) => message['content']), [
      'Question 1',
      'Preparing 1 draft',
      'Finished 1',
    ]);
    expect(saved.context, hasLength(4));
    expect(tester.takeException(), isNull);
  });

  for (final sameId in [false, true]) {
    testWidgets(
      'three draft revisions retain one current card (sameId=$sameId)',
      (tester) async {
        final transport = _Transport(messageIds: true);
        final container = await _mount(
          tester,
          transport,
          _Capabilities(sameId: sameId),
        );
        for (var turn = 1; turn <= 3; turn++) {
          await _send(tester, turn);
          final cards = tester.widgetList<AiToolResultCard>(
            find.byType(AiToolResultCard),
          );
          expect(cards.map((card) => card.proposal?.summary), ['Plan $turn']);
          expect(
            tester
                .widget<ListView>(
                  find.byKey(const ValueKey('ai-conversation-list')),
                )
                .semanticChildCount,
            turn * 3 + 1,
          );
          expect(find.text('Plan ${turn - 1}'), findsNothing);
          final saved =
              (await container.read(aiHistoryStoreProvider).list()).single;
          expect(saved.messages, hasLength(turn * 3));
          expect(saved.context, hasLength(turn * 4));
          if (turn > 1) {
            expect(
              transport.prompts.last['data']['context'],
              hasLength((turn - 1) * 4),
            );
            expect(
              transport.prompts.last['data']['messages'],
              hasLength((turn - 1) * 3),
            );
          }
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'message ids split unclassified and final text without visible tools',
    (tester) async {
      final transport = _Transport(messageIds: true, tools: false);
      await _mount(tester, transport, _Capabilities());
      await _send(tester, 1);
      expect(
        tester
            .widgetList<AiAssistantMarkdown>(find.byType(AiAssistantMarkdown))
            .map((message) => message.text),
        ['Preparing 1 draft', 'Finished 1'],
      );
      expect(find.byType(AiToolResultCard), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'internal progress stays out of visible text and history but keeps context',
    (tester) async {
      final transport = _Transport(messageIds: true, internalProgress: true);
      final container = await _mount(tester, transport, _Capabilities());
      await _send(tester, 1);
      expect(find.text('Preparing 1 draft'), findsNothing);
      expect(
        tester
            .widgetList<AiAssistantMarkdown>(find.byType(AiAssistantMarkdown))
            .map((message) => message.text),
        ['Finished 1'],
      );
      expect(find.byType(AiToolResultCard), findsOneWidget);
      final saved =
          (await container.read(aiHistoryStoreProvider).list()).single;
      expect(saved.messages.map((message) => message['content']), [
        'Question 1',
        'Finished 1',
      ]);
      expect(jsonEncode(saved.context), contains('Preparing 1 draft'));
      expect(saved.context, hasLength(4));
      await _send(tester, 2);
      expect(transport.prompts.last['data']['context'], hasLength(4));
      expect(
        jsonEncode(transport.prompts.last['data']['context']),
        contains('Preparing 1 draft'),
      );
      expect(transport.prompts.last['data']['messages'], [
        {'role': 'user', 'content': 'Question 1'},
        {'role': 'assistant', 'content': 'Finished 1'},
      ]);
      expect(tester.takeException(), isNull);
    },
  );
}
