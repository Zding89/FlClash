import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/ai/credentials.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/configuration/resources.dart';
import 'package:drift/native.dart';
import 'package:fl_clash/ai/runtime.dart';
import 'package:fl_clash/ai/settings.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/ai/assistant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Transport implements AgentTransport {
  final outgoing = StreamController<List<int>>();
  final diagnostic = StreamController<List<int>>();
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
    if (frame['type'] != 'prompt') return;
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
    await outgoing.close();
    await diagnostic.close();
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
  final AgentRuntime runtime;
  @override
  final AgentCredentialStore credentials;
  @override
  Future<void> closeAgent() => runtime.close();
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
  _Controller controller,
) async {
  final container = ProviderContainer(
    overrides: [
      workbenchControllerProvider.overrideWith((ref) {
        controller.ref = ref;
        return controller;
      }),
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
  return container;
}

void main() {
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
      await tester.tap(find.byKey(const ValueKey('ai-send')));
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
      await tester.runAsync(() => runtime.close());
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
      await tester.tap(find.byKey(const ValueKey('ai-send')));
      await tester.pump();
      await tester.tap(find.byTooltip(AppLocalizations.current.aiStop));
      await tester.pumpAndSettle();
      pending.complete('late-secret');
      await tester.pumpAndSettle();
      expect(launches, 0);
      expect(find.text('streamed answer'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
