import 'dart:async';

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/views/policy/match_editor.dart';
import 'package:fl_clash/views/policy/rule_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _nested = PolicyMatch(
  type: PolicyMatchType.all,
  children: [
    PolicyMatch(
      type: PolicyMatchType.any,
      children: [
        PolicyMatch(type: PolicyMatchType.domain, values: ['office.example']),
        PolicyMatch(type: PolicyMatchType.processName, values: ['Browser']),
      ],
    ),
    PolicyMatch(
      type: PolicyMatchType.not,
      children: [
        PolicyMatch(
          type: PolicyMatchType.domainSuffix,
          values: ['excluded.example'],
        ),
      ],
    ),
  ],
);

Future<void> _mount(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1400, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openRule(
  WidgetTester tester,
  Future<void> Function(LocalPolicy) save,
  ValueChanged<LocalPolicy?> returned,
) async {
  await _mount(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async {
            final result = await showDialog<LocalPolicy>(
              context: context,
              builder: (_) => LocalPolicyEditor(
                existing: const LocalPolicy(
                  id: 'fixture-rule',
                  label: 'Fixture rule',
                  targetId: 'profile:1',
                  candidateNodeIds: ['1:fixture'],
                  scope: _nested,
                ),
                targets: const {'profile:1': 'Fixture profile'},
                loadNodes: (_) async => [
                  LocalNode(
                    id: '1:fixture',
                    sourceId: '1',
                    label: 'Fixture node',
                    sourceLabel: 'Fixture profile',
                    protocol: 'ss',
                    raw: const {},
                  ),
                ],
                onSave: (value, _, _) => save(value),
              ),
            );
            returned(result);
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'nested all any not edit typed values and preserve sibling conditions',
    (tester) async {
      var value = _nested;
      var changes = 0;
      await _mount(
        tester,
        StatefulBuilder(
          builder: (context, update) => Scaffold(
            body: SingleChildScrollView(
              child: PolicyMatchEditor(
                value: value,
                onChanged: (next) => update(() {
                  value = next;
                  changes++;
                }),
              ),
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('root-0-1-processName-values')),
        ' Browser One \n Browser Two ',
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('root-1-0-domainSuffix-values')),
        'private.example\ninternal.example',
      );
      await tester.pump();
      expect(changes, 2);
      expect(value.type, PolicyMatchType.all);
      expect(value.children.first.type, PolicyMatchType.any);
      expect(value.children.first.children.first.values, ['office.example']);
      expect(value.children.first.children.last.values, [
        'Browser One',
        'Browser Two',
      ]);
      expect(value.children.last.type, PolicyMatchType.not);
      expect(value.children.last.children.single.values, [
        'private.example',
        'internal.example',
      ]);
      expect(PolicyMatch.fromJson(value.toJson()).toJson(), value.toJson());
      expect(tester.takeException(), null);
    },
  );

  testWidgets(
    'condition dropdown creates nested not and logical add remove retain siblings',
    (tester) async {
      var value = _nested;
      await _mount(
        tester,
        StatefulBuilder(
          builder: (context, update) => Scaffold(
            body: SingleChildScrollView(
              child: PolicyMatchEditor(
                value: value,
                onChanged: (next) => update(() => value = next),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('root-0-1-processName-type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppLocalizations.current.policyMatchNot).last);
      await tester.pumpAndSettle();
      expect(value.children.first.children.last.type, PolicyMatchType.not);
      expect(value.children.first.children.last.children, hasLength(1));
      await tester.enterText(
        find.byKey(const ValueKey('root-0-1-0-domainSuffix-values')),
        'nested.example',
      );
      await tester.pump();
      await tester.tap(
        find.widgetWithText(TextButton, AppLocalizations.current.add).last,
      );
      await tester.pump();
      expect(value.children, hasLength(3));
      expect(value.children[1].toJson(), _nested.children[1].toJson());
      await tester.tap(find.byIcon(Icons.delete_outline).last);
      await tester.pump();
      expect(value.children, hasLength(2));
      expect(value.children.first.children.last.children.single.values, [
        'nested.example',
      ]);
      expect(value.children.last.children, hasLength(1));
      expect(PolicyMatch.fromJson(value.toJson()).toJson(), value.toJson());
      expect(tester.takeException(), null);
    },
  );

  testWidgets('invalid nested values stay in the form and never call save', (
    tester,
  ) async {
    var writes = 0;
    LocalPolicy? saved;
    await _openRule(tester, (value) async {
      writes++;
      saved = value;
    }, (_) {});
    final input = find.byKey(const ValueKey('root-0-0-domain-values'));
    await tester.ensureVisible(input);
    await tester.enterText(input, 'https://invalid.example/path');
    await tester.tap(
      find.widgetWithText(
        FilledButton,
        AppLocalizations.current.save,
      ),
    );
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(
      find.text(AppLocalizations.current.policyInvalidData),
      findsOneWidget,
    );
    expect(
      tester.widget<TextFormField>(input).controller?.text ??
          tester.widget<TextFormField>(input).initialValue,
      'https://invalid.example/path',
    );
    await tester.enterText(input, 'fixed.example');
    await tester.tap(
      find.widgetWithText(
        FilledButton,
        AppLocalizations.current.save,
      ),
    );
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(saved!.scope.children.first.children.first.values, [
      'fixed.example',
    ]);
    expect(tester.takeException(), null);
  });

  testWidgets(
    'failed save retains nested edits, blocks duplicate writes and retries once',
    (tester) async {
      final completion = Completer<void>();
      var attempts = 0;
      var writes = 0;
      LocalPolicy? returned;
      await _openRule(tester, (value) async {
        attempts++;
        if (attempts == 1) await completion.future;
        writes++;
      }, (value) => returned = value);
      final input = find.byKey(const ValueKey('root-0-0-domain-values'));
      await tester.ensureVisible(input);
      await tester.enterText(input, 'edited.example');
      final callback = tester
          .widget<FilledButton>(
            find.widgetWithText(
              FilledButton,
              AppLocalizations.current.save,
            ),
          )
          .onPressed!;
      callback();
      callback();
      await tester.pump();
      expect(attempts, 1);
      completion.completeError(StateError('fixture save failure'));
      await tester.pumpAndSettle();
      expect(writes, 0);
      expect(returned, null);
      expect(
        find.text(AppLocalizations.current.policyOperationFailed),
        findsOneWidget,
      );
      expect(
        tester.widget<TextFormField>(input).controller?.text ??
            tester.widget<TextFormField>(input).initialValue,
        'edited.example',
      );
      expect(find.byKey(const ValueKey('policy-rule-scopeJson')), findsNothing);
      await tester.tap(
        find.widgetWithText(
          FilledButton,
          AppLocalizations.current.save,
        ),
      );
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(writes, 1);
      expect(returned!.scope.children.first.type, PolicyMatchType.any);
      expect(returned!.scope.children.last.type, PolicyMatchType.not);
      expect(returned!.scope.children.first.children.first.values, [
        'edited.example',
      ]);
      expect(tester.takeException(), null);
    },
  );
}
