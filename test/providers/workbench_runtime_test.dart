import 'dart:async';

import 'package:drift/native.dart';
import 'package:fl_clash/ai/runtime.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ai/runtime_transport_test.dart'
    show FakeTransport, settings, tool, tick;

void main() {
  test(
    'same controller retries a fatal host failure with a fresh runtime',
    () async {
      final store = WorkbenchDatabase(NativeDatabase.memory());
      final container = ProviderContainer();
      final transports = <FakeTransport>[];
      final provider = Provider<WorkbenchController>(
        (ref) => WorkbenchController(
          ref,
          store: store,
          runtimeFactory: () {
            final transport = FakeTransport();
            transports.add(transport);
            return AgentRuntime(launcher: () async => transport);
          },
        ),
      );
      final controller = container.read(provider);
      final old = controller.runtime;
      final oldEvents = <AgentRuntimeEvent>[];
      final oldSubscription = old.events.listen(oldEvents.add);
      final pendingTool = Completer<AgentToolResult>();
      AgentToolRequest? oldRequest;
      final first = old.prompt(
        settings: settings,
        key: 'fixture',
        user: 'first',
        tools: [tool],
        executeTool: (request) {
          oldRequest = request;
          return pendingTool.future;
        },
      );
      final failed = expectLater(first, throwsA(isA<AgentRuntimeException>()));
      try {
        await tick();
        transports.first.send('toolRequest', {
          'requestId': 'pending-request',
          'toolCallId': 'pending-call',
          'name': tool.name,
          'arguments': <String, Object?>{},
        });
        await tick();
        expect(oldRequest!.isCurrent(), isTrue);
        transports.first.exited.complete(9);
        await failed;
        expect(old.isClosed, isTrue);
        expect(oldRequest!.isCurrent(), isFalse);
        final fresh = controller.runtime;
        expect(identical(old, fresh), isFalse);
        expect(identical(controller.runtime, fresh), isTrue);
        final freshEvents = <AgentRuntimeEvent>[];
        final freshSubscription = fresh.events.listen(freshEvents.add);
        final retry = fresh.prompt(
          settings: settings,
          key: 'fixture',
          user: 'retry',
          tools: [tool],
          executeTool: (_) async => const AgentToolResult({}),
        );
        await tick();
        pendingTool.complete(const AgentToolResult({'stale': true}));
        await tick();
        expect(
          transports.first.frames.where(
            (frame) => frame['type'] == 'toolResult',
          ),
          isEmpty,
        );
        expect(
          transports.last.frames.where(
            (frame) => frame['type'] == 'toolResult',
          ),
          isEmpty,
        );
        expect(fresh.isClosed, isFalse);
        transports.last.send('text', {'text': 'retry completed'});
        transports.last.send('done', {'cancelled': false, 'failed': false});
        await retry;
        expect(freshEvents.map((event) => event.type), ['text', 'done']);
        expect(oldEvents.single.data['code'], 'hostExited');
        await freshSubscription.cancel();
      } finally {
        if (!pendingTool.isCompleted) {
          pendingTool.complete(const AgentToolResult({}));
        }
        await old.close();
        await controller.closeAgent();
        await oldSubscription.cancel();
        container.dispose();
        await store.close();
      }
    },
  );
}
