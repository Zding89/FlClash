import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/ai/runtime.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTransport implements AgentTransport {
  final outgoing = StreamController<List<int>>();
  final errors = StreamController<List<int>>();
  final exited = Completer<int>();
  final frames = <Map<String, dynamic>>[];
  bool closed = false;

  @override
  Stream<List<int>> get output => outgoing.stream;
  @override
  Stream<List<int>> get diagnostics => errors.stream;
  @override
  Future<int> get exitCode => exited.future;
  @override
  Future<void> write(List<int> bytes) async {
    frames.add(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
  }

  void send(String type, Map<String, Object?> data, {int? generation}) {
    final prompt = frames.firstWhere(
      (frame) => frame['type'] == 'prompt' || frame['type'] == 'listModels',
    );
    final encoded = jsonEncode({
      ...prompt,
      'generation': generation ?? prompt['generation'],
      'type': type,
      'data': data,
    });
    outgoing.add(utf8.encode('$encoded\n'));
  }

  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    if (!exited.isCompleted) exited.complete(0);
    await outgoing.close();
    await errors.close();
  }
}

const settings = AgentConnectionSettings(provider: 'deepseek', model: 'test');
const tool = AgentToolDefinition(
  name: 'read_config',
  description: 'Read config',
  parameters: {'type': 'object'},
);

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'model discovery is independent of prompts and rejects stale replies',
    () async {
      final transport = FakeTransport();
      final runtime = AgentRuntime(launcher: () async => transport);
      final models = runtime.listModels(
        settings: const AgentConnectionSettings(
          provider: 'deepseek',
          model: '',
        ),
        key: 'test-key',
      );
      await tick();
      expect(transport.frames.single['type'], 'listModels');
      transport.send('models', {
        'models': [
          {'id': 'stale', 'name': 'Stale'},
        ],
      }, generation: 99);
      transport.send('models', {
        'models': [
          {'id': 'real-result', 'name': 'Result'},
        ],
      });
      transport.send('done', {'cancelled': false, 'failed': false});
      expect((await models).single.id, 'real-result');
      await runtime.close();
    },
  );

  test('closing discovery settles it as cancelled without a result', () async {
    final transport = FakeTransport();
    final runtime = AgentRuntime(launcher: () async => transport);
    final models = runtime.listModels(settings: settings, key: 'test-key');
    final check = expectLater(models, throwsA(isA<AgentRuntimeException>()));
    await tick();
    await runtime.close();
    await check;
    expect(transport.closed, true);
  });

  test('streams replies and rejects stale-generation tool requests', () async {
    final transport = FakeTransport();
    final runtime = AgentRuntime(launcher: () async => transport);
    final events = <AgentRuntimeEvent>[];
    final subscription = runtime.events.listen(events.add);
    var executions = 0;
    final prompt = runtime.prompt(
      settings: settings,
      key: 'transient-secret',
      user: 'hello',
      tools: [tool],
      executeTool: (request) async {
        executions++;
        return const AgentToolResult({'safe': true});
      },
    );
    await tick();
    transport.send('toolRequest', {
      'requestId': 'tool-1',
      'toolCallId': 'call-1',
      'name': 'read_config',
      'arguments': <String, dynamic>{},
    }, generation: 99);
    transport.send('text', {'text': 'hello'});
    transport.send('done', {'cancelled': false, 'failed': false});
    await prompt;
    expect(executions, 0);
    expect(events.map((event) => event.type), ['text', 'done']);
    expect(transport.frames.single['data']['key'], 'transient-secret');
    await runtime.close();
    await subscription.cancel();
  });

  test(
    'late approved tool result after cancellation cannot write a reply',
    () async {
      final transport = FakeTransport();
      final runtime = AgentRuntime(launcher: () async => transport);
      final subscription = runtime.events.listen((_) {});
      final approval = Completer<AgentToolResult>();
      AgentToolRequest? pending;
      final prompt = runtime.prompt(
        settings: settings,
        key: 'secret',
        user: 'hello',
        tools: [tool],
        executeTool: (request) {
          pending = request;
          return approval.future;
        },
      );
      await tick();
      transport.send('toolRequest', {
        'requestId': 'tool-1',
        'toolCallId': 'call-1',
        'name': 'read_config',
        'arguments': <String, dynamic>{},
      });
      await tick();
      expect(pending!.isCurrent(), true);
      runtime.cancel();
      expect(pending!.isCurrent(), false);
      approval.complete(const AgentToolResult({'safe': true}));
      await tick();
      transport.send('done', {'cancelled': true, 'failed': false});
      await prompt;
      expect(
        transport.frames.where((frame) => frame['type'] == 'toolResult'),
        isEmpty,
      );
      await runtime.close();
      await subscription.cancel();
    },
  );

  test(
    'duplicate tool requests fail terminally without duplicate execution',
    () async {
      final transport = FakeTransport();
      final runtime = AgentRuntime(launcher: () async => transport);
      final events = <AgentRuntimeEvent>[];
      final subscription = runtime.events.listen(events.add);
      final approval = Completer<AgentToolResult>();
      var executions = 0;
      final prompt = runtime.prompt(
        settings: settings,
        key: 'secret',
        user: 'hello',
        tools: [tool],
        executeTool: (_) {
          executions++;
          return approval.future;
        },
      );
      await tick();
      final request = {
        'requestId': 'tool-1',
        'toolCallId': 'call-1',
        'name': 'read_config',
        'arguments': <String, dynamic>{},
      };
      transport.send('toolRequest', request);
      transport.send('toolRequest', request);
      await expectLater(prompt, throwsA(isA<AgentRuntimeException>()));
      expect(executions, 1);
      expect(events.single.data['code'], 'invalidToolRequest');
      approval.complete(const AgentToolResult({}));
      await runtime.close();
      await subscription.cancel();
    },
  );

  test('host exit settles prompt and invalidates pending approval', () async {
    final transport = FakeTransport();
    final runtime = AgentRuntime(launcher: () async => transport);
    final events = <AgentRuntimeEvent>[];
    final subscription = runtime.events.listen(events.add);
    final prompt = runtime.prompt(
      settings: settings,
      key: 'secret',
      user: 'hello',
      tools: [],
      executeTool: (_) async => const AgentToolResult({}),
    );
    await tick();
    transport.exited.complete(9);
    await expectLater(prompt, throwsA(isA<AgentRuntimeException>()));
    expect(events.single.data['code'], 'hostExited');
    await runtime.close();
    await subscription.cancel();
  });

  test('oversized stream and host exit settle the active prompt', () async {
    final transport = FakeTransport();
    final runtime = AgentRuntime(launcher: () async => transport);
    final events = <AgentRuntimeEvent>[];
    final subscription = runtime.events.listen(events.add);
    final prompt = runtime.prompt(
      settings: settings,
      key: 'secret',
      user: 'hello',
      tools: [],
      executeTool: (_) async => const AgentToolResult({}),
    );
    await tick();
    transport.outgoing.add(List.filled(AgentRuntime.maxFrameBytes + 1, 65));
    await expectLater(prompt, throwsA(isA<AgentRuntimeException>()));
    expect(events.single.data['code'], 'frameLimit');
    await runtime.close();
    await subscription.cancel();
    await expectLater(runtime.start(), throwsStateError);
  });
  test(
    'structured context is passed and emitted with generation checks',
    () async {
      final transport = FakeTransport();
      final runtime = AgentRuntime(launcher: () async => transport);
      final events = <AgentRuntimeEvent>[];
      final subscription = runtime.events.listen(events.add);
      final context = <Map<String, Object?>>[
        {'role': 'user', 'content': 'previous request'},
        {
          'role': 'assistant',
          'content': [
            {'type': 'text', 'text': 'previous answer'},
          ],
        },
      ];
      final prompt = runtime.prompt(
        settings: settings,
        key: 'secret',
        user: 'continue',
        context: context,
        tools: [],
        executeTool: (_) async => const AgentToolResult({}),
      );
      await tick();
      expect(transport.frames.single['data']['context'], hasLength(2));
      transport.send('context', {'messages': context}, generation: 99);
      transport.send('context', {'messages': context});
      transport.send('task', {'status': 'draft_ready'});
      transport.send('done', {'cancelled': false, 'failed': false});
      await prompt;
      expect(events.map((event) => event.type), ['context', 'task', 'done']);
      await runtime.close();
      await subscription.cancel();
    },
  );

  test(
    'approval waiting frames bracket the active run and allow completion',
    () async {
      final transport = FakeTransport();
      final runtime = AgentRuntime(launcher: () async => transport);
      final subscription = runtime.events.listen((_) {});
      var completed = false;
      final prompt = runtime
          .prompt(
            settings: settings,
            key: 'secret',
            user: 'apply',
            tools: [],
            executeTool: (_) async => const AgentToolResult({}),
          )
          .then((_) => completed = true);
      await tick();
      await runtime.setApprovalPending(true);
      await tick();
      expect(completed, false);
      expect(runtime.isClosed, false);
      await runtime.setApprovalPending(false);
      expect(
        transport.frames
            .where((frame) => frame['type'] == 'approvalWait')
            .map((frame) => frame['data']['pending']),
        [true, false],
      );
      transport.send('done', {'cancelled': false, 'failed': false});
      await tick();
      await prompt;
      await runtime.close();
      await subscription.cancel();
    },
  );
}
