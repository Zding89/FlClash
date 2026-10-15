import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/ai/credentials.dart';
import 'package:fl_clash/ai/history.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/configuration/resources.dart';
import 'package:drift/native.dart';
import 'package:fl_clash/ai/runtime.dart';
import 'package:fl_clash/ai/settings.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/providers/ai_history.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/ai/assistant.dart';
import 'package:fl_clash/views/ai/composer_context.dart';
import 'package:fl_clash/views/ai/settings.dart';
import 'package:fl_clash/views/ai/presentation.dart';
import 'package:fl_clash/views/ai/message.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:fl_clash/capabilities/service.dart';
import 'package:fl_clash/capabilities/manifest.dart';
import 'package:fl_clash/configuration/changes.dart';

import '../support/ai_visual_capture.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Transport implements AgentTransport {
  _Transport({this.tools = false});
  final bool tools;
  Map<String, dynamic>? prompt;
  int toolResults = 0;
  int promptCalls = 0;

  void event(String type, Map<String, Object?> data) {
    final encoded = jsonEncode({...prompt!, 'type': type, 'data': data});
    outgoing.add(utf8.encode('$encoded\n'));
  }

  void request(String command) => event('toolRequest', {
    'requestId': 'visual-$toolResults',
    'toolCallId': 'call-$toolResults',
    'name': 'application_invoke',
    'arguments': {'command': command, 'params': <String, Object?>{}},
  });
  final outgoing = StreamController<List<int>>.broadcast();
  final diagnostic = StreamController<List<int>>.broadcast();
  final exited = Completer<int>();
  bool closed = false;

  @override
  Stream<List<int>> get output => outgoing.stream;
  @override
  Stream<List<int>> get diagnostics => diagnostic.stream;
  @override
  Future<int> get exitCode => exited.future;
  @override
  Future<void> write(List<int> bytes) async {
    final frame = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (frame['type'] == 'toolResult') {
      toolResults++;
      if (toolResults == 1) {
        request('proxy_select');
      } else {
        event('done', {'cancelled': false, 'failed': false});
      }
      return;
    }
    if (frame['type'] != 'prompt') return;
    promptCalls++;
    prompt = frame;
    if (tools) {
      event('text', {'text': '已检查当前连接。下面的方案等待你的确认。'});
      request('runtime_read');
      return;
    }
    for (final event in [
      {
        'type': 'text',
        'data': {'text': 'streamed answer'},
      },
      {
        'type': 'done',
        'data': {'cancelled': false, 'failed': false},
      },
    ]) {
      final encoded = jsonEncode({...frame, ...event});
      outgoing.add(utf8.encode('$encoded\n'));
    }
  }

  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    exited.complete(0);
    unawaited(outgoing.close());
    unawaited(diagnostic.close());
  }
}

class _StreamingTransport extends _Transport {
  @override
  Future<void> write(List<int> bytes) async {
    final frame = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (frame['type'] != 'prompt') return;
    prompt = frame;
    promptCalls++;
  }
}

class _MarkdownTransport extends _Transport {
  _MarkdownTransport(this.content);
  final String content;

  @override
  Future<void> write(List<int> bytes) async {
    final frame = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (frame['type'] != 'prompt') return;
    promptCalls++;
    prompt = frame;
    event('text', {'text': content});
    event('done', {'cancelled': false, 'failed': false});
  }
}

class _ContextTransport extends _Transport {
  final prompts = <Map<String, dynamic>>[];
  @override
  Future<void> write(List<int> bytes) async {
    final frame = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (frame['type'] != 'prompt') return;
    prompt = frame;
    prompts.add(frame);
    promptCalls++;
    event('text', {'text': 'answer $promptCalls'});
    event('context', {
      'messages': [
        ...?frame['data']['context'] as List?,
        {'role': 'user', 'content': frame['data']['user']},
        {
          'role': 'assistant',
          'content': [
            {
              'type': 'toolCall',
              'id': 'call-$promptCalls',
              'name': 'policies_propose',
              'arguments': {'patch': {}},
            },
          ],
        },
        {
          'role': 'toolResult',
          'toolCallId': 'call-$promptCalls',
          'toolName': 'policies_propose',
          'isError': false,
          'content': [
            {
              'type': 'text',
              'text':
                  '{"proposal":{"id":"draft-$promptCalls"},"private":"test-secret"}',
            },
          ],
        },
        {
          'role': 'assistant',
          'content': [
            {'type': 'text', 'text': 'answer $promptCalls'},
          ],
        },
      ],
    });
    event('done', {
      'cancelled': false,
      'failed': false,
      'taskStatus': 'draft_ready',
    });
  }
}

class _MultiTurnTransport extends _Transport {
  _MultiTurnTransport({this.failFirst = false});
  final bool failFirst;
  final prompts = <Map<String, dynamic>>[];

  @override
  Future<void> write(List<int> bytes) async {
    final frame = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (frame['type'] != 'prompt') return;
    promptCalls++;
    prompt = frame;
    prompts.add(frame);
    if (failFirst && promptCalls == 1) {
      event('error', {'code': 'rateLimited'});
      event('done', {'cancelled': false, 'failed': true});
      return;
    }
    event('text', {'text': 'answer $promptCalls'});
    event('done', {'cancelled': false, 'failed': false});
  }
}

class _RequestTransport extends _Transport {
  _RequestTransport(this.name, this.arguments);
  final String name;
  final Map<String, Object?> arguments;
  Map<String, dynamic>? returnedToolFrame;

  @override
  Future<void> write(List<int> bytes) async {
    final frame = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (frame['type'] == 'toolResult') {
      toolResults++;
      returnedToolFrame = frame;
      event('done', {'cancelled': false, 'failed': false});
    } else if (frame['type'] == 'prompt') {
      promptCalls++;
      prompt = frame;
      event('toolRequest', {
        'requestId': 'history-request',
        'toolCallId': 'history-call',
        'name': name,
        'arguments': arguments,
      });
    }
  }
}

class _Credentials implements AgentCredentialStore {
  _Credentials({this.pending});
  final Completer<String?>? pending;
  @override
  Future<String?> read(String credentialId) =>
      pending?.future ?? Future.value('test-secret');
  @override
  Future<void> write(String credentialId, String secret) async {}
  @override
  Future<void> delete(String credentialId) async {}
}

class _Controller extends Mock implements WorkbenchController {
  _Controller(this.runtime, this.credentials);
  @override
  late Ref ref;
  @override
  final WorkbenchDatabase store = WorkbenchDatabase(NativeDatabase.memory());
  @override
  ResourceChangeService get resources => ResourceChangeService(
    store: store,
    environment: FlutterResourceEnvironment(ref: ref, store: store),
  );
  @override
  AgentRuntime runtime;
  @override
  final AgentCredentialStore credentials;
  @override
  Future<void> closeAgent() => runtime.close();
}

const _proposal = ConfigurationProposal(
  id: 'visual-proposal',
  summary: '调整视频流量规则',
  highRisk: true,
  expiresAt: 9999999999999,
  differences: [
    ConfigurationDifference(
      path: 'video.primary',
      before: '自动选择',
      after: '日本节点集',
    ),
    ConfigurationDifference(
      path: 'video.fallback',
      before: null,
      after: '香港节点集',
    ),
  ],
  validation: {
    'finalConfigValidated': true,
    'finalConfigDifferences': [
      {'path': 'rules.video', 'before': 'MATCH', 'after': '日本 → 香港 → 阻断'},
    ],
  },
);

class _CapabilityService extends Mock implements ApplicationCapabilityService {
  bool? approved;
  Completer<Map<String, Object?>>? readPending;
  Map<String, Object?>? runtimeReadResult;
  Map<String, Object?>? mutationResult;
  Map<String, Object?>? operationQueryResult;
  Future<Map<String, Object?>> Function(Map<String, Object?> params)?
  queryHandler;
  final pending = Completer<void>();
  @override
  List<Map<String, Object?>> get manifest =>
      applicationCapabilities.map((capability) => capability.toJson()).toList();
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
    if (command == 'proxy_select' && mutationResult != null) {
      return mutationResult!;
    }
    if (command == 'capabilities') {
      return {
        'status': 'completed',
        'result': {'capabilities': manifest},
      };
    }
    if (command == 'operation_query') {
      if (queryHandler != null) return queryHandler!(params);
      if (operationQueryResult != null) return operationQueryResult!;
      return {
        'operationId': 'other-conversation-change',
        'status': 'completed',
      };
    }
    if (command == 'runtime_read') {
      if (readPending != null) return readPending!.future;
      if (runtimeReadResult != null) return runtimeReadResult!;
      return {
        'status': 'completed',
        'result': {
          'running': true,
          'mode': 'rule',
          'node': '日本 01',
          'latency': '32 ms',
        },
      };
    }
    if (!pending.isCompleted) pending.complete();
    approved = await approve!(_proposal);
    return {'status': approved! ? 'applied' : 'rejected'};
  }
}

const _settings = AgentSettings(
  enabled: true,
  selectedConnectionId: 'test',
  connections: [
    AgentConnection(
      id: 'test',
      label: 'My model',
      provider: 'deepseek',
      model: 'deepseek-chat',
    ),
  ],
);

Future<ProviderContainer> _mount(
  WidgetTester tester,
  _Controller controller, {
  String? initialPrompt,
  String? offeredContext,
  _CapabilityService? capabilities,
  AgentSettings settings = _settings,
  TargetPlatform? platform,
  TextEditingController? inputController,
}) async {
  final container = ProviderContainer(
    overrides: [
      workbenchControllerProvider.overrideWith((ref) {
        controller.ref = ref;
        return controller;
      }),
      agentSettingsProvider.overrideWith((_) => Stream.value(settings)),
      currentProfileProvider.overrideWith((_) => null),
      if (capabilities != null)
        applicationCapabilityServiceProvider.overrideWithValue(capabilities),
    ],
  );
  globalState.container = container;
  if (offeredContext != null) {
    container.read(aiComposerContextProvider.notifier).offer(offeredContext);
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: aiVisualCapture ? const Locale('zh', 'CN') : null,
        theme: ThemeData(
          platform: platform,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          fontFamily: aiVisualCapture ? 'AiVisualLatin' : null,
          fontFamilyFallback: aiVisualCapture ? const ['AiVisualCjk'] : null,
        ),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
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
          'V3 AI 助手',
          AiAssistantView(
            initialPrompt: initialPrompt,
            inputController: inputController,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(controller.store.close);
  return container;
}

Finder _conversationScrollable(WidgetTester tester) {
  final list = tester.widget<ListView>(
    find.byKey(const ValueKey('ai-conversation-list')),
  );
  final scrollable = find.descendant(
    of: find.byKey(const ValueKey('ai-conversation-list')),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && identical(widget.controller, list.controller),
    ),
  );
  expect(scrollable, findsOneWidget);
  return scrollable;
}

Future<void> _tapAi(WidgetTester tester, Finder target) async {
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.ensureVisible(target);
  await tester.pump(const Duration(milliseconds: 100));
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target.hitTestable());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<ProviderContainer> _mountMixedHeightHistory(WidgetTester tester) async {
  final controller = _Controller(
    AgentRuntime(launcher: () async => _Transport()),
    _Credentials(),
  );
  final container = await _mount(tester, controller);
  await container
      .read(aiHistoryStoreProvider)
      .save(
        AiConversation(
          id: 'c' * 32,
          updatedAt: 1,
          messages: [
            for (var turn = 0; turn < 36; turn++) ...[
              {'role': 'user', 'content': 'mixed history question $turn'},
              {
                'role': 'assistant',
                'content':
                    'answer $turn\n\n${List.generate(turn.isEven ? 2 : 40 + turn, (index) => 'mixed height paragraph $turn / $index').join('\n\n')}${turn == 35 ? '\n\nFINAL ANSWER END' : ''}',
              },
            ],
          ],
        ),
      );
  await _tapAi(
    tester,
    find.byTooltip(AppLocalizations.current.aiConversationHistory),
  );
  await tester.pumpAndSettle();
  await _tapAi(tester, find.text('mixed history question 0'));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets(
    'provided composer sends exact Chinese and remains owner managed',
    (tester) async {
      final transport = _MultiTurnTransport();
      final runtime = AgentRuntime(launcher: () async => transport);
      final input = TextEditingController();
      final container = await _mount(
        tester,
        _Controller(runtime, _Credentials()),
        inputController: input,
      );
      addTearDown(container.dispose);
      addTearDown(input.dispose);
      const message = 'AI 优先迷之屋美国，国内直连，其余香港；先生成草稿。';
      input.text = message;
      await tester.pump();
      await _tapAi(tester, find.byKey(const ValueKey('ai-send')));
      await waitAiCondition(
        tester,
        () => transport.promptCalls == 1 && input.text.isEmpty,
        'Chinese composer text must reach the actual runtime',
      );
      expect(transport.prompts.single['data']['user'], message);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      input.text = '外部仍可管理输入';
      expect(input.text, '外部仍可管理输入');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'latest message reaches the real tail of lazy mixed-height history',
    (tester) async {
      final container = await _mountMixedHeightHistory(tester);
      addTearDown(container.dispose);
      final listFinder = find.byKey(const ValueKey('ai-conversation-list'));
      final list = tester.widget<ListView>(listFinder);
      list.controller!.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ai-latest-message')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ai-latest-message')));
      await tester.pumpAndSettle();
      final finalAnswer = find.byWidgetPredicate(
        (widget) =>
            widget is AiAssistantMarkdown &&
            widget.text.endsWith('FINAL ANSWER END'),
      );
      expect(finalAnswer, findsOneWidget);
      final tail = tester.getRect(finalAnswer).bottom;
      final viewport = tester.getRect(listFinder);
      expect(tail, lessThanOrEqualTo(viewport.bottom));
      expect(tail, greaterThan(viewport.top));
      expect(list.controller!.position.extentAfter, lessThan(1));
      expect(find.byKey(const ValueKey('ai-latest-message')), findsNothing);
      expect(tester.binding.hasScheduledFrame, false);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reader drag cancels a pending lazy-history follow convergence', (
    tester,
  ) async {
    final container = await _mountMixedHeightHistory(tester);
    addTearDown(container.dispose);
    final listFinder = find.byKey(const ValueKey('ai-conversation-list'));
    final list = tester.widget<ListView>(listFinder);
    list.controller!.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ai-latest-message')));
    await tester.pump();
    final gesture = await tester.startGesture(tester.getCenter(listFinder));
    await gesture.moveBy(const Offset(0, 300));
    await tester.pump();
    final readingOffset = list.controller!.offset;
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(list.controller!.offset, readingOffset);
    expect(find.byKey(const ValueKey('ai-latest-message')), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ai-latest-message')), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, false);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reading position survives text, status and completion events', (
    tester,
  ) async {
    final transport = _StreamingTransport();
    final container = await _mount(
      tester,
      _Controller(
        AgentRuntime(launcher: () async => transport),
        _Credentials(),
      ),
      capabilities: _CapabilityService()
        ..runtimeReadResult = const {'status': 'failed'},
    );
    addTearDown(container.dispose);
    await tester.enterText(
      find.byKey(const ValueKey('ai-prompt')),
      'long task',
    );
    await _tapAi(tester, find.byKey(const ValueKey('ai-send')));
    transport.event('text', {
      'text': List.generate(100, (index) => 'paragraph $index').join('\n\n'),
    });
    await tester.pump();
    await tester.pump();
    final list = tester.widget<ListView>(
      find.byKey(const ValueKey('ai-conversation-list')),
    );
    expect(list.controller!.position.extentAfter, lessThan(1));
    list.controller!.jumpTo(0);
    await tester.pump();
    for (final event in [
      ('status', <String, Object?>{'status': 'thinking'}),
      ('text', <String, Object?>{'text': '\nnew output'}),
      (
        'toolRequest',
        <String, Object?>{
          'requestId': 'scroll-check',
          'toolCallId': 'scroll-tool',
          'name': 'application_invoke',
          'arguments': {
            'command': 'runtime_read',
            'params': <String, Object?>{},
          },
        },
      ),
      ('done', <String, Object?>{'cancelled': false, 'failed': false}),
    ]) {
      transport.event(event.$1, event.$2);
      await tester.pump();
      await tester.pump();
      expect(list.controller!.offset, 0);
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ai-latest-message')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ai-latest-message')));
    await tester.pumpAndSettle();
    expect(list.controller!.position.extentAfter, lessThan(1));
    expect(find.byKey(const ValueKey('ai-latest-message')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final failure in ['timeout', 'exception', 'wrong_id']) {
    testWidgets(
      'linked operation keeps its last receipt during $failure and refreshes the complete receipt',
      (tester) async {
        final controller = _Controller(
          AgentRuntime(launcher: () async => _Transport()),
          _Credentials(),
        );
        var phase = 0;
        var finalQueries = 0;
        var blockedQueries = 0;
        final waiting = Completer<Map<String, Object?>>();
        Map<String, Object?> receipt(bool running) => {
          'version': 1,
          'persisted': true,
          'currentStateMatches': true,
          'scope': 'local_policy',
          'outcome': running ? 'effective' : 'saved',
          'activation': {
            'required': true,
            'targetId': 'integration:flclash_local',
            'documentRevision': 7,
            'loadedTargetId': 'integration:flclash_local',
            'loadedDocumentRevision': 7,
            'loaded': true,
            'running': running,
            'effective': running,
            'reason': running ? 'active' : 'network_stopped',
          },
        };
        final finalRunning = failure != 'exception';
        final capabilities = _CapabilityService()
          ..queryHandler = (params) async {
            final id = params['operationId'] as String;
            if (phase == 1) {
              blockedQueries++;
              if (failure == 'timeout') return waiting.future;
              if (failure == 'exception') {
                throw StateError('approval queue temporarily unavailable');
              }
              return {'operationId': 'wrong-operation', 'status': 'completed'};
            }
            if (phase == 2) finalQueries++;
            return {
              'operationId': id,
              'status': id == 'pending-connection'
                  ? (phase == 2 ? 'completed' : 'running')
                  : 'applied',
              if (id == 'selected-target')
                'result': {
                  'completion': receipt(phase == 2 ? finalRunning : false),
                  'marker': phase == 2
                      ? 'fresh-complete-result'
                      : 'last-confirmed-result',
                },
            };
          };
        final container = await _mount(
          tester,
          controller,
          capabilities: capabilities,
        );
        addTearDown(container.dispose);
        for (final id in ['selected-target', 'pending-connection']) {
          await controller.store.saveChange(
            id: id,
            category: id == 'selected-target'
                ? 'capability:profile_select'
                : 'capability:connection_set',
            summary: id,
            highRisk: false,
            fingerprint: 'fixture',
            before: {},
            after: {},
            createdAt: 1,
            expiresAt: 9999999999999,
          );
          await controller.store.changeStatus(
            id,
            id == 'selected-target' ? 'applied' : 'running',
          );
        }
        await container
            .read(aiHistoryStoreProvider)
            .save(
              AiConversation(
                id: 'd' * 32,
                updatedAt: 1,
                messages: const [
                  {'role': 'user', 'content': 'restore queued operation'},
                ],
                changeIds: const ['selected-target', 'pending-connection'],
                changeReferences: const {
                  'selected-target': 1,
                  'pending-connection': 1,
                },
              ),
            );
        await _tapAi(
          tester,
          find.byTooltip(AppLocalizations.current.aiConversationHistory),
        );
        await tester.pumpAndSettle();
        await _tapAi(tester, find.text('restore queued operation'));
        await tester.pumpAndSettle();
        AiToolResultCard selected() => tester
            .widgetList<AiToolResultCard>(find.byType(AiToolResultCard))
            .firstWhere(
              (card) => card.result?['operationId'] == 'selected-target',
            );
        final oldResult = selected().result;
        expect(
          (oldResult!['result'] as Map)['marker'],
          'last-confirmed-result',
        );
        expect(
          find.text(AppLocalizations.current.aiPolicySavedOnly),
          findsOneWidget,
        );
        phase = 1;
        await tester.pump(const Duration(seconds: 3));
        await waitAiCondition(
          tester,
          () => blockedQueries >= 2,
          'Both operation refreshes must enter the temporarily blocked approval queue.',
        );
        if (failure == 'timeout') {
          await tester.pump(const Duration(seconds: 5));
          await tester.pump();
        }
        expect(selected().result, same(oldResult));
        expect(
          find.text(AppLocalizations.current.aiChangesUnavailable),
          findsNothing,
        );
        phase = 2;
        await tester.pump(const Duration(seconds: 3));
        await waitAiCondition(
          tester,
          () => finalQueries >= 2,
          'A later poll must retry both operation queries after the transient failure.',
        );
        await tester.pumpAndSettle();
        expect(finalQueries, greaterThanOrEqualTo(2));
        final fresh = selected().result!;
        expect((fresh['result'] as Map)['marker'], 'fresh-complete-result');
        expect(
          find.text(
            finalRunning
                ? AppLocalizations.current.aiPolicyEffectiveVerified
                : AppLocalizations.current.aiPolicySavedOnly,
          ),
          findsOneWidget,
        );
        expect(
          find.text(AppLocalizations.current.aiChangesUnavailable),
          findsNothing,
        );
        if (!waiting.isCompleted) {
          waiting.complete({
            'operationId': 'old-timed-out-query',
            'status': 'failed',
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'history queries the same operation without restoring approval or raw parameters',
    (tester) async {
      final controller = _Controller(
        AgentRuntime(launcher: () async => _Transport()),
        _Credentials(),
      );
      final capabilities = _CapabilityService()
        ..operationQueryResult = const {
          'operationId': 'recover-operation',
          'status': 'requires_recovery',
        };
      final container = await _mount(
        tester,
        controller,
        capabilities: capabilities,
      );
      addTearDown(container.dispose);
      await controller.store.saveChange(
        id: 'recover-operation',
        category: 'capability:resource_update',
        summary: 'Refresh resources',
        highRisk: false,
        fingerprint: 'operation',
        before: const {},
        after: const {
          'command': 'resource_update',
          'params': {'private': 'hidden-parameter'},
        },
        createdAt: 1,
        expiresAt: 9999999999999,
      );
      await controller.store.changeStatus('recover-operation', 'running');
      await container
          .read(aiHistoryStoreProvider)
          .save(
            AiConversation(
              id: 'b' * 32,
              updatedAt: 1,
              messages: const [
                {'role': 'user', 'content': 'recover operation'},
              ],
              changeIds: const ['recover-operation'],
              changeReferences: const {'recover-operation': 1},
            ),
          );
      await _tapAi(
        tester,
        find.byTooltip(AppLocalizations.current.aiConversationHistory),
      );
      await tester.pumpAndSettle();
      await _tapAi(tester, find.text('recover operation'));
      await tester.pumpAndSettle();
      final card = tester.widget<AiToolResultCard>(
        find.byType(AiToolResultCard),
      );
      expect(card.proposal, isNull);
      expect(card.result!['status'], 'requires_recovery');
      expect(card.summary, 'Refresh resources');
      expect(card.onApprove, isNull);
      expect(find.textContaining('hidden-parameter'), findsNothing);
      expect(find.textContaining('resource_update'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'history restores authoritative current cards without approvals',
    (tester) async {
      final controller = _Controller(
        AgentRuntime(launcher: () async => _Transport()),
        _Credentials(),
      );
      final container = await _mount(tester, controller);
      addTearDown(container.dispose);
      final store = container.read(aiHistoryStoreProvider);
      for (final id in ['old-draft', 'latest-draft', 'applied-change']) {
        await controller.store.saveChange(
          id: id,
          category: 'policies',
          summary: id,
          highRisk: false,
          fingerprint: 'old',
          before: const {
            'settings': {'mode': 'rule'},
          },
          after: const {
            'settings': {'mode': 'global'},
          },
          createdAt: 1,
          expiresAt: 2,
        );
      }
      await controller.store.changeStatus('old-draft', 'superseded');
      await controller.store.changeStatus('applied-change', 'applied');
      await store.save(
        AiConversation(
          id: 'a' * 32,
          updatedAt: 1,
          messages: const [
            {'role': 'user', 'content': 'recover draft'},
            {'role': 'assistant', 'content': 'review plan'},
            {'role': 'user', 'content': 'continue later'},
          ],
          changeIds: const ['old-draft', 'latest-draft', 'applied-change'],
          changeReferences: const {
            'old-draft': 1,
            'latest-draft': 2,
            'applied-change': 2,
          },
        ),
      );
      await _tapAi(
        tester,
        find.byTooltip(AppLocalizations.current.aiConversationHistory),
      );
      await tester.pumpAndSettle();
      await _tapAi(tester, find.text('recover draft'));
      await tester.pumpAndSettle();
      final cards = tester
          .widgetList<AiToolResultCard>(find.byType(AiToolResultCard))
          .toList();
      expect(cards.map((card) => card.proposal!.id), [
        'latest-draft',
        'applied-change',
      ]);
      expect(cards.map((card) => card.result!['status']), ['expired', 'saved']);
      expect(
        cards.every((card) => !card.awaitingApproval && card.onApprove == null),
        true,
      );
      final list = tester.widget<ListView>(
        find.byKey(const ValueKey('ai-conversation-list')),
      );
      expect(list.semanticChildCount, 5);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'successful mutation receipt stays hidden while result and link persist',
    (tester) async {
      const result = {
        'status': 'applied',
        'operationId': 'successful-mutation',
        'summary': 'raw mutation receipt',
      };
      final transport = _RequestTransport('application_invoke', {
        'command': 'proxy_select',
        'params': {'group': 'Proxy', 'node': 'Node A'},
      });
      final capabilities = _CapabilityService()..mutationResult = result;
      final container = await _mount(
        tester,
        _Controller(
          AgentRuntime(launcher: () async => transport),
          _Credentials(),
        ),
        capabilities: capabilities,
      );
      addTearDown(container.dispose);
      await tester.enterText(
        find.byKey(const ValueKey('ai-prompt')),
        'select a proxy',
      );
      await _tapAi(tester, find.byKey(const ValueKey('ai-send')));
      await waitAiCondition(
        tester,
        () =>
            transport.toolResults == 1 &&
            find.byKey(const ValueKey('ai-send')).evaluate().isNotEmpty,
        'Mutation result must return to the model and finish',
      );
      expect(transport.returnedToolFrame!['data']['value'], {
        ...result,
        'taskEffect': 'mutation',
      });
      expect(transport.returnedToolFrame!['data']['isError'], false);
      expect(find.byType(AiToolResultCard), findsNothing);
      expect(find.text('raw mutation receipt'), findsNothing);
      expect(
        find.text(AppLocalizations.current.policyAppliedStatus),
        findsNothing,
      );
      expect(
        find.byTooltip(AppLocalizations.current.aiLinkedChanges),
        findsOneWidget,
      );
      final entries = await container.read(aiHistoryStoreProvider).list();
      expect(entries.single.changeIds, ['successful-mutation']);
      expect(tester.takeException(), isNull);
    },
  );

  for (final tool in ['application_catalog', 'application_invoke']) {
    testWidgets('successful $tool read data stays out of the conversation', (
      tester,
    ) async {
      final transport = _RequestTransport(
        tool,
        tool == 'application_catalog'
            ? {}
            : {'command': 'runtime_read', 'params': <String, Object?>{}},
      );
      final capabilities = _CapabilityService()
        ..runtimeReadResult = {
          'status': 'completed',
          'result': {
            'summary': 'raw tool summary',
            'capabilities': ['raw capability'],
            'rows': ['raw tool row'],
          },
        };
      final container = await _mount(
        tester,
        _Controller(
          AgentRuntime(launcher: () async => transport),
          _Credentials(),
        ),
        capabilities: capabilities,
      );
      addTearDown(container.dispose);
      await tester.enterText(
        find.byKey(const ValueKey('ai-prompt')),
        'inspect settings',
      );
      await _tapAi(tester, find.byKey(const ValueKey('ai-send')));
      await waitAiCondition(
        tester,
        () =>
            transport.toolResults == 1 &&
            find.byKey(const ValueKey('ai-send')).evaluate().isNotEmpty,
        'Read result must still return to the model and finish',
      );
      expect(find.byType(AiToolResultCard), findsNothing);
      expect(find.text(AppLocalizations.current.aiCheckResult), findsNothing);
      for (final text in [
        'summary',
        'capabilities',
        'rows',
        'raw tool summary',
        'raw capability',
        'raw tool row',
      ]) {
        expect(find.text(text), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final (status, errorField) in [
    ('failed', 'errorCode'),
    ('pending_user_input', 'errorCode'),
    ('conflict', 'errorCode'),
    ('conflict', 'error'),
  ]) {
    testWidgets('read result retains necessary $status feedback $errorField', (
      tester,
    ) async {
      final transport = _RequestTransport('application_invoke', {
        'command': 'runtime_read',
        'params': <String, Object?>{},
      });
      final capabilities = _CapabilityService()
        ..runtimeReadResult = {'status': status, errorField: 'core_timeout'};
      final container = await _mount(
        tester,
        _Controller(
          AgentRuntime(launcher: () async => transport),
          _Credentials(),
        ),
        capabilities: capabilities,
      );
      addTearDown(container.dispose);
      await tester.enterText(
        find.byKey(const ValueKey('ai-prompt')),
        'inspect settings',
      );
      await _tapAi(tester, find.byKey(const ValueKey('ai-send')));
      await waitAiCondition(
        tester,
        () =>
            transport.toolResults == 1 &&
            find.byKey(const ValueKey('ai-send')).evaluate().isNotEmpty,
        'Necessary read feedback must finish',
      );
      expect(find.byType(AiToolResultCard), findsOneWidget);
      expect(
        find.text(switch (status) {
          'failed' => AppLocalizations.current.aiRequestFailed,
          'pending_user_input' => AppLocalizations.current.aiAwaitingApproval,
          _ => AppLocalizations.current.aiCheckResult,
        }),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [360.0, 944.0]) {
    testWidgets('selectable Markdown confines tables and code at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final longValue = 'column-value-' * 20;
      final source =
          '# Heading\n\n**strong** and *emphasis*\n\n- one\n- two\n\n| First | Second | Third | Fourth |\n| --- | --- | --- | --- |\n| $longValue | $longValue | $longValue | $longValue |\n\n```yaml\nrule: $longValue$longValue\n```\n\n![remote image](https://example.invalid/image.png)\n\n![local image](file:///private/tmp/image.png)';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: AiAssistantMarkdown(text: source),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MarkdownBody), findsOneWidget);
      expect(
        tester.widget<MarkdownBody>(find.byType(MarkdownBody)).selectable,
        true,
      );
      expect(find.text('Heading'), findsOneWidget);
      expect(find.text('# Heading'), findsNothing);
      expect(find.byType(Table), findsOneWidget);
      expect(find.byType(SelectableText), findsWidgets);
      final horizontal = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable &&
            (widget.axisDirection == AxisDirection.right ||
                widget.axisDirection == AxisDirection.left),
      );
      expect(horizontal, findsNWidgets(2));
      for (final element in horizontal.evaluate()) {
        final state = (element as StatefulElement).state as ScrollableState;
        expect(state.position.maxScrollExtent, greaterThan(0));
        state.position.jumpTo(state.position.maxScrollExtent);
      }
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.text('remote image'), findsOneWidget);
      expect(find.text('local image'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('assistant renders Markdown while user input stays plain text', (
    tester,
  ) async {
    const response = '# Assistant heading\n\n**assistant strong**';
    final transport = _MarkdownTransport(response);
    final container = await _mount(
      tester,
      _Controller(
        AgentRuntime(launcher: () async => transport),
        _Credentials(),
      ),
    );
    addTearDown(container.dispose);
    await tester.enterText(
      find.byKey(const ValueKey('ai-prompt')),
      '**literal user**',
    );
    await _tapAi(tester, find.byKey(const ValueKey('ai-send')));
    await waitAiCondition(
      tester,
      () =>
          find.text('Assistant heading').evaluate().isNotEmpty &&
          find.byKey(const ValueKey('ai-send')).evaluate().isNotEmpty,
      'Markdown response must render after sending',
    );
    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.text(response), findsNothing);
    expect(find.text('assistant strong'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText && widget.data == '**literal user**',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'tool context continues across turns and history restore without rendering tools',
    (tester) async {
      final transport = _ContextTransport();
      final controller = _Controller(
        AgentRuntime(launcher: () async => transport),
        _Credentials(),
      );
      final container = await _mount(tester, controller);
      addTearDown(container.dispose);
      final store = container.read(aiHistoryStoreProvider);
      for (var turn = 1; turn <= 2; turn++) {
        await tester.enterText(
          find.byKey(const ValueKey('ai-prompt')),
          'question $turn',
        );
        await _tapAi(tester, find.byKey(const ValueKey('ai-send')));
        await tester.pumpAndSettle();
      }
      expect(transport.prompts.last['data']['context'], hasLength(4));
      expect(find.byType(AiToolResultCard), findsNothing);
      final saved = (await store.list()).single;
      expect(saved.context, hasLength(8));
      expect(saved.recoveryRequired, false);
      expect(
        saved.diagnostics.any((event) => event['status'] == 'draft_ready'),
        true,
      );
      expect(jsonEncode(saved.context), isNot(contains('test-secret')));
      await _tapAi(
        tester,
        find.byTooltip(AppLocalizations.current.aiConversationHistory),
      );
      await tester.pumpAndSettle();
      await _tapAi(tester, find.text('question 1'));
      await tester.pumpAndSettle();
      await waitAiCondition(
        tester,
        () =>
            find.byKey(const ValueKey('ai-send')).evaluate().isNotEmpty &&
            find.text('answer 2').evaluate().isNotEmpty,
        'History restore must finish closing the previous runtime before continuing',
      );
      final resumedTransport = _ContextTransport();
      controller.runtime = AgentRuntime(launcher: () async => resumedTransport);
      await tester.enterText(
        find.byKey(const ValueKey('ai-prompt')),
        'continue draft',
      );
      await _tapAi(tester, find.byKey(const ValueKey('ai-send')));
      await tester.pumpAndSettle();
      expect(resumedTransport.prompts.single['data']['context'], hasLength(8));
      expect(
        resumedTransport.prompts.single['data']['recoveryRequired'],
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('same runtime sends three arrow turns with accumulated history', (
    tester,
  ) async {
    final transport = _MultiTurnTransport();
    var launches = 0;
    final runtime = AgentRuntime(
      launcher: () async {
        launches++;
        return transport;
      },
    );
    final container = await _mount(
      tester,
      _Controller(runtime, _Credentials()),
    );
    addTearDown(container.dispose);
    final prompt = find.byKey(const ValueKey('ai-prompt'));
    final history = <Map<String, String>>[];
    for (var turn = 1; turn <= 3; turn++) {
      final question = 'question $turn';
      await tester.enterText(prompt, question);
      await _tapAi(tester, find.byKey(const ValueKey('ai-send')));
      await waitAiCondition(
        tester,
        () => find.byKey(const ValueKey('ai-send')).evaluate().isNotEmpty,
        'Each turn must finish and restore the send button',
      );
      expect(
        transport.promptCalls,
        turn,
        reason:
            'turn $turn; generic error visible: ${find.text(AppLocalizations.current.aiRequestFailed).evaluate().isNotEmpty}; composer: ${tester.widget<TextField>(prompt).controller!.text}',
      );
      expect(transport.prompts.last['data']['messages'], history);
      expect(transport.prompts.last['data']['user'], question);
      expect(tester.widget<TextField>(prompt).controller!.text, isEmpty);
      expect(find.text(AppLocalizations.current.aiRequestFailed), findsNothing);
      history.addAll([
        {'role': 'user', 'content': question},
        {'role': 'assistant', 'content': 'answer $turn'},
      ]);
    }
    expect(launches, 1);
    expect(transport.promptCalls, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('same runtime recovers after model error and failed done', (
    tester,
  ) async {
    final transport = _MultiTurnTransport(failFirst: true);
    var launches = 0;
    final runtime = AgentRuntime(
      launcher: () async {
        launches++;
        return transport;
      },
    );
    final container = await _mount(
      tester,
      _Controller(runtime, _Credentials()),
    );
    addTearDown(container.dispose);
    final prompt = find.byKey(const ValueKey('ai-prompt'));
    await tester.enterText(prompt, 'first failed question');
    await _tapAi(tester, find.byKey(const ValueKey('ai-send')));
    await waitAiCondition(
      tester,
      () => find.byKey(const ValueKey('ai-send')).evaluate().isNotEmpty,
      'Each turn must finish and restore the send button',
    );
    expect(transport.promptCalls, 1);
    expect(find.text(AppLocalizations.current.aiRateLimited), findsOneWidget);
    expect(runtime.isClosed, false);
    await tester.enterText(prompt, 'retry question');
    await _tapAi(tester, find.byKey(const ValueKey('ai-send')));
    await waitAiCondition(
      tester,
      () => find.byKey(const ValueKey('ai-send')).evaluate().isNotEmpty,
      'Each turn must finish and restore the send button',
    );
    expect(
      transport.promptCalls,
      2,
      reason:
          'retry; generic error visible: ${find.text(AppLocalizations.current.aiRequestFailed).evaluate().isNotEmpty}; composer: ${tester.widget<TextField>(prompt).controller!.text}',
    );
    expect(launches, 1);
    expect(transport.prompts.last['data']['messages'], [
      {'role': 'user', 'content': 'first failed question'},
    ]);
    expect(transport.prompts.last['data']['user'], 'retry question');
    expect(find.text('answer 2'), findsOneWidget);
    expect(find.text(AppLocalizations.current.aiRateLimited), findsNothing);
    expect(find.text(AppLocalizations.current.aiRequestFailed), findsNothing);
    expect(tester.widget<TextField>(prompt).controller!.text, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    testWidgets('desktop Enter sends once including held key on $platform', (
      tester,
    ) async {
      final transport = _Transport();
      final container = await _mount(
        tester,
        _Controller(
          AgentRuntime(launcher: () async => transport),
          _Credentials(),
        ),
        platform: platform,
      );
      addTearDown(container.dispose);
      await tester.enterText(
        find.byKey(const ValueKey('ai-prompt')),
        'keyboard question',
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(transport.promptCalls, 1);
      expect(transport.prompt!['data']['user'], 'keyboard question');
      expect(find.text('streamed answer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('desktop Shift Enter retains multiline editing without sending', (
    tester,
  ) async {
    const platform = TargetPlatform.macOS;
    final transport = _Transport();
    final container = await _mount(
      tester,
      _Controller(
        AgentRuntime(launcher: () async => transport),
        _Credentials(),
      ),
      platform: platform,
    );
    addTearDown(container.dispose);
    final prompt = find.byKey(const ValueKey('ai-prompt'));
    await tester.enterText(prompt, 'first line');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(transport.promptCalls, 0);
    final field = tester.widget<TextField>(prompt);
    expect(field.keyboardType, TextInputType.multiline);
    expect(field.textInputAction, TextInputAction.newline);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'first line\nsecond line',
        selection: TextSelection.collapsed(offset: 22),
      ),
    );
    await tester.pump();
    expect(field.controller!.text, 'first line\nsecond line');
    await _tapAi(tester, find.byKey(const ValueKey('ai-send')));
    await tester.pumpAndSettle();
    expect(transport.prompt!['data']['user'], 'first line\nsecond line');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'composing Enter waits for committed Chinese text before sending',
    (tester) async {
      const platform = TargetPlatform.macOS;
      final transport = _Transport();
      final container = await _mount(
        tester,
        _Controller(
          AgentRuntime(launcher: () async => transport),
          _Credentials(),
        ),
        platform: platform,
      );
      addTearDown(container.dispose);
      await tester.enterText(find.byKey(const ValueKey('ai-prompt')), 'ni');
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'ni',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(transport.promptCalls, 0);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '你好',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(transport.promptCalls, 1);
      expect(transport.prompt!['data']['user'], '你好');
      expect(tester.takeException(), isNull);
    },
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'mobile Enter keeps multiline input and click sends on $platform',
      (tester) async {
        final transport = _Transport();
        final container = await _mount(
          tester,
          _Controller(
            AgentRuntime(launcher: () async => transport),
            _Credentials(),
          ),
          platform: platform,
        );
        addTearDown(container.dispose);
        final prompt = find.byKey(const ValueKey('ai-prompt'));
        await tester.enterText(prompt, 'mobile question');
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.testTextInput.receiveAction(TextInputAction.newline);
        await tester.pump();
        expect(transport.promptCalls, 0);
        expect(tester.widget<TextField>(prompt).maxLines, 4);
        expect(
          tester.widget<TextField>(prompt).textInputAction,
          TextInputAction.newline,
        );
        await _tapAi(tester, find.byKey(const ValueKey('ai-send')));
        await tester.pumpAndSettle();
        expect(transport.promptCalls, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Enter while credential read is busy does not queue another send',
    (tester) async {
      const platform = TargetPlatform.macOS;
      final pending = Completer<String?>();
      final transport = _Transport();
      final container = await _mount(
        tester,
        _Controller(
          AgentRuntime(launcher: () async => transport),
          _Credentials(pending: pending),
        ),
        platform: platform,
      );
      addTearDown(container.dispose);
      await tester.enterText(
        find.byKey(const ValueKey('ai-prompt')),
        'one request',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(transport.promptCalls, 0);
      pending.complete('test-secret');
      await tester.pumpAndSettle();
      expect(transport.promptCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final settings in [
    _settings,
    const AgentSettings(),
    const AgentSettings(enabled: true),
  ]) {
    testWidgets(
      'empty or unavailable composer ignores Enter for ${settings.enabled}/${settings.selectedConnectionId}',
      (tester) async {
        const platform = TargetPlatform.macOS;
        final transport = _Transport();
        final container = await _mount(
          tester,
          _Controller(
            AgentRuntime(launcher: () async => transport),
            _Credentials(),
          ),
          settings: settings,
          initialPrompt: settings == _settings ? '  ' : 'unavailable question',
          platform: platform,
        );
        addTearDown(container.dispose);
        final prompt = find.byKey(const ValueKey('ai-prompt'));
        if (settings == _settings) await tester.tap(prompt);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(transport.promptCalls, 0);
        expect(
          tester
              .widget<IconButton>(find.byKey(const ValueKey('ai-send')))
              .onPressed,
          isNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'saved text restores without replaying approval or calling model',
    (tester) async {
      final transport = _Transport();
      final controller = _Controller(
        AgentRuntime(launcher: () async => transport),
        _Credentials(),
      );
      final container = await _mount(tester, controller);
      addTearDown(container.dispose);
      final store = container.read(aiHistoryStoreProvider);
      await store.save(
        const AiConversation(
          id: '11111111111111111111111111111111',
          updatedAt: 1700000000000,
          messages: [
            {'role': 'user', 'content': 'saved configuration question'},
            {'role': 'assistant', 'content': 'saved explanation'},
          ],
          changeIds: ['previous-pending-change'],
        ),
      );
      await _tapAi(
        tester,
        find.byTooltip(AppLocalizations.current.aiConversationHistory),
      );
      await tester.pumpAndSettle();
      await _tapAi(tester, find.text('saved configuration question'));
      await tester.pumpAndSettle();
      expect(find.text('saved explanation'), findsOneWidget);
      expect(transport.promptCalls, 0);
      expect(
        find.byTooltip(AppLocalizations.current.aiLinkedChanges),
        findsOneWidget,
      );
      expect(find.byType(AiToolResultCard), findsNothing);
      await _tapAi(
        tester,
        find.byTooltip(AppLocalizations.current.aiNewConversation),
      );
      await tester.pumpAndSettle();
      expect(find.text('saved explanation'), findsNothing);
      final entries = await store.list();
      expect(entries, hasLength(1));
      expect(transport.promptCalls, 0);
    },
  );

  testWidgets('sent text is persisted with selected credential redacted', (
    tester,
  ) async {
    final transport = _Transport();
    final controller = _Controller(
      AgentRuntime(launcher: () async => transport),
      _Credentials(),
    );
    final container = await _mount(tester, controller);
    addTearDown(container.dispose);
    await tester.enterText(
      find.byKey(const ValueKey('ai-prompt')),
      'inspect test-secret',
    );
    await _tapAi(tester, find.byKey(const ValueKey('ai-send')));
    await tester.pumpAndSettle();
    final entries = await container.read(aiHistoryStoreProvider).list();
    expect(entries, hasLength(1));
    expect(entries.single.messages, [
      {'role': 'user', 'content': 'inspect [redacted]'},
      {'role': 'assistant', 'content': 'streamed answer'},
    ]);
    expect(transport.prompt!['data']['user'], 'inspect test-secret');
  });

  testWidgets(
    'a full restore clears stale chat without resaving it over restored history',
    (tester) async {
      final transport = _Transport();
      final controller = _Controller(
        AgentRuntime(launcher: () async => transport),
        _Credentials(),
      );
      final container = await _mount(tester, controller);
      addTearDown(container.dispose);
      final history = container.read(aiHistoryStoreProvider);
      await history.save(
        const AiConversation(
          id: '11111111111111111111111111111111',
          updatedAt: 1700000000000,
          messages: [
            {'role': 'user', 'content': 'old local question'},
            {'role': 'assistant', 'content': 'old local answer'},
          ],
        ),
      );
      await _tapAi(
        tester,
        find.byTooltip(AppLocalizations.current.aiConversationHistory),
      );
      await tester.pumpAndSettle();
      await _tapAi(tester, find.text('old local question'));
      await tester.pumpAndSettle();
      expect(find.text('old local answer'), findsOneWidget);
      const restored = AiConversation(
        id: '22222222222222222222222222222222',
        updatedAt: 1700000000001,
        messages: [
          {'role': 'user', 'content': 'restored question'},
          {'role': 'assistant', 'content': 'restored answer'},
        ],
      );
      await controller.closeAgent();
      await AiHistoryStore.replaceForRestore(
        controller.store,
        () => controller.store.writeSection('aiConversations', {
          'version': 1,
          'conversations': [restored.toJson()],
        }),
      );
      await tester.pumpAndSettle();

      expect(find.text('old local question'), findsNothing);
      expect(find.text('old local answer'), findsNothing);
      expect((await history.list()).map((entry) => entry.id), [restored.id]);
      await tester.pumpAndSettle();
      final historyButton = find.ancestor(
        of: find.byTooltip(AppLocalizations.current.aiConversationHistory),
        matching: find.byType(IconButton),
      );
      expect(controller.runtime.isClosed, isTrue);
      expect(tester.widget<IconButton>(historyButton).onPressed, isNotNull);
      await _tapAi(
        tester,
        find.byTooltip(AppLocalizations.current.aiConversationHistory),
      );
      await tester.pumpAndSettle();
      await _tapAi(tester, find.text('restored question'));
      await tester.pumpAndSettle();
      expect(find.text('restored answer'), findsOneWidget);
      expect(transport.promptCalls, 0);
    },
  );

  for (final tool in ['application_operation', 'application_invoke']) {
    testWidgets('$tool query never associates another conversation change', (
      tester,
    ) async {
      final transport = _RequestTransport(
        tool,
        tool == 'application_operation'
            ? {'operationId': 'other-conversation-change'}
            : {
                'command': 'operation_query',
                'params': {'operationId': 'other-conversation-change'},
              },
      );
      final controller = _Controller(
        AgentRuntime(launcher: () async => transport),
        _Credentials(),
      );
      final container = await _mount(
        tester,
        controller,
        capabilities: _CapabilityService(),
      );
      addTearDown(container.dispose);
      await tester.enterText(
        find.byKey(const ValueKey('ai-prompt')),
        'inspect operation',
      );
      await _tapAi(tester, find.byKey(const ValueKey('ai-send')));
      await tester.pumpAndSettle();
      expect(transport.toolResults, 1);
      final entries = await container.read(aiHistoryStoreProvider).list();
      expect(entries.single.changeIds, isEmpty);
      expect(
        find.byTooltip(AppLocalizations.current.aiLinkedChanges),
        findsNothing,
      );
    });
  }

  testWidgets(
    'fatal host failure suppresses late tool cards and history links',
    (tester) async {
      final pending = Completer<Map<String, Object?>>();
      final capabilities = _CapabilityService()..readPending = pending;
      final transport = _RequestTransport('application_invoke', {
        'command': 'runtime_read',
        'params': <String, Object?>{},
      });
      final runtime = AgentRuntime(launcher: () async => transport);
      final container = await _mount(
        tester,
        _Controller(runtime, _Credentials()),
        capabilities: capabilities,
      );
      addTearDown(container.dispose);
      await tester.enterText(
        find.byKey(const ValueKey('ai-prompt')),
        'inspect runtime',
      );
      await _tapAi(tester, find.byKey(const ValueKey('ai-send')));
      await tester.pump();
      transport.outgoing.add(utf8.encode('invalid-frame\n'));
      await tester.pumpAndSettle();
      expect(runtime.isClosed, true);
      pending.complete({'status': 'completed', 'operationId': 'late-change'});
      await tester.pumpAndSettle();
      expect(find.byType(AiToolResultCard), findsNothing);
      expect(transport.toolResults, 0);
      final entries = await container.read(aiHistoryStoreProvider).list();
      expect(entries.single.changeIds, isEmpty);
    },
  );

  testWidgets(
    'context offered before first mount fills composer once without launching runtime',
    (tester) async {
      final transport = _Transport();
      var launches = 0;
      final runtime = AgentRuntime(
        launcher: () async {
          launches++;
          return transport;
        },
      );
      final container = await _mount(
        tester,
        _Controller(runtime, _Credentials()),
        offeredContext: 'Inspect profile:1 before proposing a change',
      );
      addTearDown(container.dispose);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('ai-prompt')))
            .controller!
            .text,
        'Inspect profile:1 before proposing a change',
      );
      expect(container.read(aiComposerContextProvider), isNull);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('ai-prompt')))
            .controller!
            .text,
        'Inspect profile:1 before proposing a change',
      );
      expect(launches, 0);
      expect(transport.promptCalls, 0);
      expect(find.byType(AiAssistantView), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'offered context preserves the same assistant state chat and existing draft without sending',
    (tester) async {
      final transport = _Transport();
      var launches = 0;
      final runtime = AgentRuntime(
        launcher: () async {
          launches++;
          return transport;
        },
      );
      final container = await _mount(
        tester,
        _Controller(runtime, _Credentials()),
      );
      addTearDown(container.dispose);
      final state = tester.state(find.byType(AiAssistantView));
      await tester.enterText(
        find.byKey(const ValueKey('ai-prompt')),
        'Original conversation',
      );
      await _tapAi(tester, find.byKey(const ValueKey('ai-send')));
      await tester.pumpAndSettle();
      expect(find.text('streamed answer'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('ai-prompt')),
        'Keep this unfinished draft',
      );
      container
          .read(aiComposerContextProvider.notifier)
          .offer('Inspect policy for profile:1');
      await tester.pumpAndSettle();
      expect(
        identical(state, tester.state(find.byType(AiAssistantView))),
        true,
      );
      expect(find.byType(AiAssistantView), findsOneWidget);
      expect(find.text('Original conversation'), findsOneWidget);
      expect(find.text('streamed answer'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('ai-prompt')))
            .controller!
            .text,
        'Keep this unfinished draft\n\nInspect policy for profile:1',
      );
      expect(container.read(aiComposerContextProvider), isNull);
      expect(launches, 1);
      expect(transport.promptCalls, 1);
      await tester.pumpAndSettle();
      expect(transport.promptCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'latest busy context survives credential wait and the later sent-input clear',
    (tester) async {
      final pending = Completer<String?>();
      final transport = _Transport();
      var launches = 0;
      final runtime = AgentRuntime(
        launcher: () async {
          launches++;
          return transport;
        },
      );
      final container = await _mount(
        tester,
        _Controller(runtime, _Credentials(pending: pending)),
      );
      addTearDown(container.dispose);
      await tester.enterText(
        find.byKey(const ValueKey('ai-prompt')),
        'Send only this original request',
      );
      await _tapAi(tester, find.byKey(const ValueKey('ai-send')));
      container
          .read(aiComposerContextProvider.notifier)
          .offer('Superseded context');
      container
          .read(aiComposerContextProvider.notifier)
          .offer('Latest policy context');
      await tester.pump();
      expect(
        container.read(aiComposerContextProvider),
        'Latest policy context',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('ai-prompt')))
            .controller!
            .text,
        'Send only this original request',
      );
      expect(launches, 0);
      pending.complete('test-secret');
      await waitAiCondition(
        tester,
        () =>
            tester
                .widget<TextField>(find.byKey(const ValueKey('ai-prompt')))
                .controller!
                .text ==
            'Latest policy context',
        'Queued context must reach composer after the existing send clears its input',
      );
      expect(
        transport.prompt!['data']['user'],
        'Send only this original request',
      );
      expect(find.text('streamed answer'), findsOneWidget);
      expect(container.read(aiComposerContextProvider), isNull);
      expect(launches, 1);
      expect(transport.promptCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed credential read preserves original draft and queued context without sending',
    (tester) async {
      final pending = Completer<String?>();
      final transport = _Transport();
      var launches = 0;
      final runtime = AgentRuntime(
        launcher: () async {
          launches++;
          return transport;
        },
      );
      final container = await _mount(
        tester,
        _Controller(runtime, _Credentials(pending: pending)),
      );
      addTearDown(container.dispose);
      await tester.enterText(
        find.byKey(const ValueKey('ai-prompt')),
        'Unsent draft',
      );
      await _tapAi(tester, find.byKey(const ValueKey('ai-send')));
      container
          .read(aiComposerContextProvider.notifier)
          .offer('Policy context after failure');
      pending.complete(null);
      await waitAiCondition(
        tester,
        () =>
            tester
                .widget<TextField>(find.byKey(const ValueKey('ai-prompt')))
                .controller!
                .text ==
            'Unsent draft\n\nPolicy context after failure',
        'Failed send must append queued context to its unsent draft',
      );
      expect(find.text(AppLocalizations.current.aiKeyMissing), findsOneWidget);
      expect(container.read(aiComposerContextProvider), isNull);
      expect(launches, 0);
      expect(transport.promptCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'stopping a credential wait appends context and late credentials cannot erase it',
    (tester) async {
      final pending = Completer<String?>();
      final transport = _Transport();
      var launches = 0;
      final runtime = AgentRuntime(
        launcher: () async {
          launches++;
          return transport;
        },
      );
      final container = await _mount(
        tester,
        _Controller(runtime, _Credentials(pending: pending)),
      );
      addTearDown(container.dispose);
      await tester.enterText(
        find.byKey(const ValueKey('ai-prompt')),
        'Keep unsent request',
      );
      await _tapAi(tester, find.byKey(const ValueKey('ai-send')));
      container
          .read(aiComposerContextProvider.notifier)
          .offer('Context after stop');
      await _tapAi(tester, find.byTooltip(AppLocalizations.current.aiStop));
      await waitAiCondition(
        tester,
        () =>
            tester
                .widget<TextField>(find.byKey(const ValueKey('ai-prompt')))
                .controller!
                .text ==
            'Keep unsent request\n\nContext after stop',
        'Stopping must accept its pending composer context',
      );
      pending.complete('late-secret');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('ai-prompt')))
            .controller!
            .text,
        'Keep unsent request\n\nContext after stop',
      );
      expect(container.read(aiComposerContextProvider), isNull);
      expect(launches, 0);
      expect(transport.promptCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'opening settings keeps chat and draft while accepting context on the same assistant',
    (tester) async {
      final transport = _Transport();
      var launches = 0;
      final runtime = AgentRuntime(
        launcher: () async {
          launches++;
          return transport;
        },
      );
      final container = await _mount(
        tester,
        _Controller(runtime, _Credentials()),
      );
      addTearDown(container.dispose);
      final state = tester.state(find.byType(AiAssistantView));
      await tester.enterText(
        find.byKey(const ValueKey('ai-prompt')),
        'Existing conversation',
      );
      await _tapAi(tester, find.byKey(const ValueKey('ai-send')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('ai-prompt')),
        'Keep settings draft',
      );
      await _tapAi(
        tester,
        find.byTooltip(AppLocalizations.current.aiSettingsTitle),
      );
      container
          .read(aiComposerContextProvider.notifier)
          .offer('Context across settings');
      await waitAiCondition(
        tester,
        () => find.byType(AiSettingsView).evaluate().isNotEmpty,
        'Settings must open on its own route',
      );
      expect(find.byType(AiAssistantView, skipOffstage: false), findsOneWidget);
      Navigator.of(tester.element(find.byType(AiSettingsView))).pop();
      await waitAiCondition(
        tester,
        () =>
            find.byKey(const ValueKey('ai-prompt')).evaluate().isNotEmpty &&
            tester
                    .widget<TextField>(find.byKey(const ValueKey('ai-prompt')))
                    .controller!
                    .text ==
                'Keep settings draft\n\nContext across settings',
        'Returning from settings must retain the existing draft and consume pending context',
      );
      expect(
        identical(state, tester.state(find.byType(AiAssistantView))),
        true,
      );
      expect(find.text('Existing conversation'), findsOneWidget);
      expect(find.text('streamed answer'), findsOneWidget);
      expect(container.read(aiComposerContextProvider), isNull);
      expect(launches, 1);
      expect(transport.promptCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [1100.0, 944.0, 390.0, 360.0]) {
    testWidgets(
      'read results stay hidden while pending approval is usable $width',
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
        final transport = _Transport(tools: true);
        final runtime = AgentRuntime(launcher: () async => transport);
        final capabilities = _CapabilityService();
        final container = await _mount(
          tester,
          _Controller(runtime, _Credentials()),
          capabilities: capabilities,
        );
        addTearDown(container.dispose);
        expect(find.byType(AiCapabilityPanel), findsNothing);
        expect(transport.prompt, isNull);
        await tester.enterText(
          find.byKey(const ValueKey('ai-prompt')),
          '检查当前连接，再提出视频流量方案',
        );
        await tester.pump();
        await _tapAi(tester, find.byKey(const ValueKey('ai-send')));
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          find.byKey(const ValueKey('ai-result-visual-proposal')),
          findsOneWidget,
        );
        expect(capabilities.approved, isNull);
        expect(
          find.text(AppLocalizations.current.aiAwaitingApproval),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('ai-result-check')), findsNothing);
        expect(find.text(AppLocalizations.current.aiCheckResult), findsNothing);
        await tester.scrollUntilVisible(
          find.text(AppLocalizations.current.aiReviewPlan),
          150,
          scrollable: _conversationScrollable(tester),
        );
        await captureAiVisual(tester, 'v3-pending-${width.toInt()}');
        await tester.ensureVisible(
          find.text(AppLocalizations.current.aiReviewPlan),
        );
        await _tapAi(tester, find.text(AppLocalizations.current.aiReviewPlan));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.text(AppLocalizations.current.aiFinalConfigDifferences),
          findsOneWidget,
        );
        expect(capabilities.approved, isNull);
        await _tapAi(tester, find.text(AppLocalizations.current.cancel).last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.ensureVisible(
          find.text(AppLocalizations.current.aiApprove),
        );
        await _tapAi(tester, find.text(AppLocalizations.current.aiApprove));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.text(AppLocalizations.current.aiFinalConfigDifferences),
          findsOneWidget,
        );
        expect(capabilities.approved, isNull);
        await _tapAi(tester, find.text(AppLocalizations.current.aiReject));
        await tester.pumpAndSettle();
        expect(capabilities.approved, false);
        expect(
          find.text(AppLocalizations.current.policyAppliedStatus),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await captureAiVisual(tester, 'v3-rejected-${width.toInt()}');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        var closed = false;
        unawaited(runtime.close().then((_) => closed = true));
        await waitAiCondition(
          tester,
          () => closed && transport.closed,
          'Disposed assistant must finish runtime closure',
        );
      },
    );
  }

  testWidgets(
    'narrow capability catalog opens without sending a model request',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await loadAiVisualFonts(tester);
      final transport = _Transport();
      final runtime = AgentRuntime(launcher: () async => transport);
      final container = await _mount(
        tester,
        _Controller(runtime, _Credentials()),
        capabilities: _CapabilityService(),
      );
      addTearDown(container.dispose);
      await _tapAi(tester, find.text(AppLocalizations.current.aiCanHelp));
      await tester.pumpAndSettle();
      expect(find.byType(AiCapabilityPanel), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(AppLocalizations.current.delayTest),
        100,
        scrollable: find
            .descendant(
              of: find.byType(AiCapabilityPanel),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text(AppLocalizations.current.delayTest), findsWidgets);
      expect(transport.prompt, isNull);
      await captureAiVisual(tester, 'v3-capabilities-360');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('approved decision stays visible without a successful receipt', (
    tester,
  ) async {
    final transport = _Transport(tools: true);
    final runtime = AgentRuntime(launcher: () async => transport);
    final capabilities = _CapabilityService();
    final container = await _mount(
      tester,
      _Controller(runtime, _Credentials()),
      capabilities: capabilities,
    );
    addTearDown(container.dispose);
    await tester.enterText(
      find.byKey(const ValueKey('ai-prompt')),
      'inspect connection',
    );
    await tester.pump();
    await _tapAi(tester, find.byKey(const ValueKey('ai-send')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.ensureVisible(find.text(AppLocalizations.current.aiApprove));
    await _tapAi(tester, find.text(AppLocalizations.current.aiApprove));
    await tester.pump(const Duration(milliseconds: 300));
    expect(capabilities.approved, isNull);
    expect(
      find.text(AppLocalizations.current.aiFinalConfigDifferences),
      findsOneWidget,
    );
    await _tapAi(tester, find.text(AppLocalizations.current.aiApprove).last);
    await tester.pumpAndSettle();
    expect(capabilities.approved, true);
    expect(transport.toolResults, 2);
    expect(find.byType(AiToolResultCard), findsOneWidget);
    expect(find.text(AppLocalizations.current.aiApproved), findsOneWidget);
    expect(
      find.text(AppLocalizations.current.policyAppliedStatus),
      findsNothing,
    );
    expect(
      find.text(AppLocalizations.current.aiAwaitingApproval),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    var closed = false;
    unawaited(runtime.close().then((_) => closed = true));
    await waitAiCondition(
      tester,
      () => closed && transport.closed,
      'Approved conversation must close its runtime on disposal',
    );
  });

  testWidgets(
    'stop rejects pending approval and suppresses late tool results',
    (tester) async {
      final transport = _Transport(tools: true);
      final runtime = AgentRuntime(launcher: () async => transport);
      final capabilities = _CapabilityService()
        ..readPending = Completer<Map<String, Object?>>();
      final container = await _mount(
        tester,
        _Controller(runtime, _Credentials()),
        capabilities: capabilities,
      );
      addTearDown(container.dispose);
      await tester.enterText(
        find.byKey(const ValueKey('ai-prompt')),
        'inspect connection',
      );
      await tester.pump();
      await _tapAi(tester, find.byKey(const ValueKey('ai-send')));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await _tapAi(tester, find.byTooltip(AppLocalizations.current.aiStop));
      FocusManager.instance.primaryFocus?.unfocus();
      await waitAiCondition(
        tester,
        () =>
            transport.closed &&
            find.byType(CircularProgressIndicator).evaluate().isEmpty,
        'Stopping assistant must close the transport and clear progress',
      );
      capabilities.readPending!.complete({
        'status': 'completed',
        'result': {'running': true},
      });
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text(AppLocalizations.current.aiResultCompleted),
        findsNothing,
      );
      expect(find.byType(AiToolResultCard), findsNothing);
      expect(transport.closed, true);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'stop while local approval is pending rejects its original callback',
    (tester) async {
      final transport = _Transport(tools: true);
      final runtime = AgentRuntime(launcher: () async => transport);
      final capabilities = _CapabilityService();
      final container = await _mount(
        tester,
        _Controller(runtime, _Credentials()),
        capabilities: capabilities,
      );
      addTearDown(container.dispose);
      await tester.enterText(
        find.byKey(const ValueKey('ai-prompt')),
        'inspect connection',
      );
      await tester.pump();
      await _tapAi(tester, find.byKey(const ValueKey('ai-send')));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(capabilities.approved, isNull);
      await _tapAi(tester, find.byTooltip(AppLocalizations.current.aiStop));
      FocusManager.instance.primaryFocus?.unfocus();
      await waitAiCondition(
        tester,
        () =>
            transport.closed &&
            find.byType(CircularProgressIndicator).evaluate().isEmpty,
        'Stopping assistant must close the transport and clear progress',
      );
      expect(capabilities.approved, false);
      expect(
        find.text(AppLocalizations.current.aiAwaitingApproval),
        findsNothing,
      );
      expect(find.text(AppLocalizations.current.aiApprove), findsNothing);
      expect(
        find.text(AppLocalizations.current.policyAppliedStatus),
        findsNothing,
      );
      await tester.ensureVisible(
        find.text(AppLocalizations.current.aiReviewPlan),
      );
      await _tapAi(tester, find.text(AppLocalizations.current.aiReviewPlan));
      await tester.pumpAndSettle();
      expect(
        find.text(AppLocalizations.current.aiFinalConfigDifferences),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed and pending user results never display applied status', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(
          body: ListView(
            children: const [
              AiToolResultCard(
                result: {'status': 'failed', 'errorCode': 'core_timeout'},
              ),
              AiToolResultCard(
                result: {
                  'status': 'pending_user_input',
                  'result': {'panel': 'file_picker'},
                },
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(AppLocalizations.current.policyAppliedStatus),
      findsNothing,
    );
    expect(
      find.text(AppLocalizations.current.aiAwaitingApproval),
      findsOneWidget,
    );
    expect(find.text(AppLocalizations.current.aiRequestFailed), findsWidgets);
  });

  testWidgets('rule generation prefill does not launch a paid model request', (
    tester,
  ) async {
    var launches = 0;
    final runtime = AgentRuntime(
      launcher: () async {
        launches++;
        return _Transport();
      },
    );
    final container = await _mount(
      tester,
      _Controller(runtime, _Credentials()),
      initialPrompt: 'Create a draft for profile:7',
    );
    addTearDown(container.dispose);
    expect(launches, 0);
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('ai-prompt')),
    );
    expect(field.controller!.text, 'Create a draft for profile:7');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await runtime.close();
  });

  testWidgets(
    'chat calls the model only after an explicit send and displays stream',
    (tester) async {
      final transport = _Transport();
      var launches = 0;
      final runtime = AgentRuntime(
        launcher: () async {
          launches++;
          return transport;
        },
      );
      final container = await _mount(
        tester,
        _Controller(runtime, _Credentials()),
      );
      addTearDown(container.dispose);
      expect(launches, 0);
      await tester.enterText(
        find.byKey(const ValueKey('ai-prompt')),
        'inspect settings',
      );
      await tester.pump();
      await _tapAi(tester, find.byKey(const ValueKey('ai-send')));
      await tester.pumpAndSettle();
      expect(
        launches,
        1,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((text) => text.data)
            .join(' | '),
      );
      expect(find.text('streamed answer'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      var closed = false;
      unawaited(runtime.close().then((_) => closed = true));
      await waitAiCondition(
        tester,
        () => closed && transport.closed,
        'Runtime closure must finish after assistant disposal',
      );
      expect(transport.closed, true);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'stop during pending Keychain read prevents any later model call',
    (tester) async {
      final pending = Completer<String?>();
      var launches = 0;
      final runtime = AgentRuntime(
        launcher: () async {
          launches++;
          return _Transport();
        },
      );
      final container = await _mount(
        tester,
        _Controller(runtime, _Credentials(pending: pending)),
      );
      addTearDown(container.dispose);
      await tester.enterText(
        find.byKey(const ValueKey('ai-prompt')),
        'inspect settings',
      );
      await tester.pump();
      await _tapAi(tester, find.byKey(const ValueKey('ai-send')));
      await tester.pump();
      await _tapAi(tester, find.byTooltip(AppLocalizations.current.aiStop));
      FocusManager.instance.primaryFocus?.unfocus();
      await waitAiCondition(
        tester,
        () =>
            launches == 0 &&
            find.byType(CircularProgressIndicator).evaluate().isEmpty,
        'Stopping assistant must close the transport and clear progress',
      );
      pending.complete('late-secret');
      await tester.pumpAndSettle();
      expect(launches, 0);
      expect(find.text('streamed answer'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
