import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/ai/runtime.dart';
import 'package:fl_clash/ai/settings.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/views/ai/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _EchoTransport implements AgentTransport {
  _EchoTransport({this.withTool = true, this.hang = false});
  final bool withTool;
  final bool hang;
  final outputController = StreamController<List<int>>.broadcast();
  final diagnosticController = StreamController<List<int>>.broadcast();
  final exit = Completer<int>();
  Map<String, dynamic>? prompt;
  bool closed = false;

  @override
  Stream<List<int>> get output => outputController.stream;
  @override
  Stream<List<int>> get diagnostics => diagnosticController.stream;
  @override
  Future<int> get exitCode => exit.future;

  void event(String type, Map<String, Object?> data) {
    final encoded = jsonEncode({...prompt!, 'type': type, 'data': data});
    outputController.add(utf8.encode('$encoded\n'));
  }

  @override
  Future<void> write(List<int> bytes) async {
    final frame = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (frame['type'] == 'listModels') {
      prompt = frame;
      if (!hang) {
        event('models', {
          'models': [
            {'id': 'available-model', 'name': 'Available'},
          ],
        });
        event('done', {'cancelled': false, 'failed': false});
      }
    } else if (frame['type'] == 'prompt') {
      prompt = frame;
      if (hang) return;
      if (withTool) {
        final user = frame['data']['user'] as String;
        final challenge = RegExp('value "([^"]+)"').firstMatch(user)!.group(1)!;
        event('toolRequest', {
          'requestId': 'echo-request',
          'toolCallId': 'echo-call',
          'name': 'tool_echo',
          'arguments': {'value': challenge},
        });
      } else {
        event('text', {'text': 'chat-only'});
        event('done', {'cancelled': false, 'failed': false});
      }
    } else if (frame['type'] == 'toolResult') {
      event('text', {'text': 'echo-success'});
      event('done', {'cancelled': false, 'failed': false});
    }
  }

  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    exit.complete(0);
    await outputController.close();
    await diagnosticController.close();
  }
}

class _EditorApp extends StatelessWidget {
  const _EditorApp({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ProviderScope(
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  const existing = AgentConnection(
    id: 'existing',
    label: 'My model',
    provider: 'deepseek',
    model: 'deepseek-chat',
  );

  testWidgets(
    'changing destination requires a fresh key and masks entered text',
    (tester) async {
      await tester.pumpWidget(
        const _EditorApp(
          child: AiConnectionEditor(existing: existing, hasKey: true),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('ai-connection-url')),
        'https://new.example/v1',
      );
      await tester.ensureVisible(
        find.text(AppLocalizations.current.aiSaveAndUse),
      );
      await tester.tap(find.text(AppLocalizations.current.aiSaveAndUse));
      await tester.pumpAndSettle();
      expect(find.text(AppLocalizations.current.aiKeyRequired), findsOneWidget);
      expect(
        find.text(AppLocalizations.current.aiTargetChanged),
        findsOneWidget,
      );
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('ai-connection-key')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.obscureText, true);
    },
  );

  testWidgets('closing editor cancels and releases an active connection test', (
    tester,
  ) async {
    final transport = _EchoTransport(hang: true);
    await tester.pumpWidget(
      _EditorApp(
        child: AiConnectionEditor(
          existing: existing,
          hasKey: false,
          runtimeFactory: () => AgentRuntime(launcher: () async => transport),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('ai-connection-key')),
      'test-secret',
    );
    await tester.ensureVisible(
      find.text(AppLocalizations.current.aiTestConnection),
    );
    await tester.tap(find.text(AppLocalizations.current.aiTestConnection));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(transport.prompt, isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    expect(transport.closed, true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('models can be fetched before entering a name or model', (
    tester,
  ) async {
    final transport = _EchoTransport();
    await tester.pumpWidget(
      _EditorApp(
        child: AiConnectionEditor(
          hasKey: false,
          runtimeFactory: () => AgentRuntime(launcher: () async => transport),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('ai-connection-key')),
      'test-key',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('ai-fetch-models')));
    await tester.tap(find.byKey(const ValueKey('ai-fetch-models')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(transport.prompt!['type'], 'listModels');
    expect(transport.prompt!['data']['settings']['model'], '');
    expect(find.text('available-model'), findsOneWidget);
    expect(find.text(AppLocalizations.current.aiTestPassed), findsNothing);
    expect(
      find.text(AppLocalizations.current.aiInvalidConnection),
      findsNothing,
    );
    await tester.ensureVisible(find.text('available-model'));
    await tester.tap(find.text('available-model'));
    await tester.pump();
    final model = tester.widget<TextFormField>(
      find.byKey(const ValueKey('ai-connection-model')),
    );
    expect(model.controller!.text, 'available-model');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('changing endpoint cancels discovery and ignores late models', (
    tester,
  ) async {
    final transport = _EchoTransport(hang: true);
    await tester.pumpWidget(
      _EditorApp(
        child: AiConnectionEditor(
          existing: existing,
          hasKey: false,
          runtimeFactory: () => AgentRuntime(launcher: () async => transport),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('ai-connection-key')),
      'old-target-key',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('ai-fetch-models')));
    await tester.tap(find.byKey(const ValueKey('ai-fetch-models')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(transport.prompt!['type'], 'listModels');
    await tester.ensureVisible(find.byKey(const ValueKey('ai-connection-url')));
    await tester.enterText(
      find.byKey(const ValueKey('ai-connection-url')),
      'https://changed.example/v1',
    );
    transport.event('models', {
      'models': [
        {'id': 'late-model', 'name': 'Late'},
      ],
    });
    await tester.pumpAndSettle();
    final secret = tester.widget<TextFormField>(
      find.byKey(const ValueKey('ai-connection-key')),
    );
    expect(secret.controller!.text, isEmpty);
    expect(find.text('late-model'), findsNothing);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    expect(transport.closed, true);
    expect(tester.takeException(), isNull);
  });

  for (final withTool in [true, false]) {
    testWidgets(
      withTool
          ? 'connection test requires streamed response and tool result'
          : 'chat-only model cannot pass agent connection test',
      (tester) async {
        final transport = _EchoTransport(withTool: withTool);
        await tester.pumpWidget(
          _EditorApp(
            child: AiConnectionEditor(
              existing: existing,
              hasKey: false,
              runtimeFactory: () =>
                  AgentRuntime(launcher: () async => transport),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('ai-connection-key')),
          'test-secret',
        );
        await tester.ensureVisible(
          find.text(AppLocalizations.current.aiTestConnection),
        );
        await tester.tap(find.text(AppLocalizations.current.aiTestConnection));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          transport.prompt,
          isNotNull,
          reason: tester
              .widgetList<Text>(find.byType(Text))
              .map((text) => text.data)
              .join(' | '),
        );
        expect(
          find.text(
            withTool
                ? AppLocalizations.current.aiTestPassed
                : AppLocalizations.current.aiTestPartial,
          ),
          findsOneWidget,
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        expect(transport.closed, true);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
