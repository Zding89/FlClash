import 'dart:async';

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/profile.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/views/policy/editors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _integration = SubscriptionIntegration(
  id: 'fixture-collection',
  label: 'Collection',
  sourceProfileIds: [1, 999],
  excludedNodeIds: ['999:missing-node'],
);
const _budget = SourceBudget(sourceId: '999', limitBytes: 1073741824);

Future<void> _open(
  WidgetTester tester,
  bool integration,
  Future<void> Function(Object) save,
  ValueChanged<Object?> result,
) async {
  tester.view.physicalSize = const Size(1200, 1200);
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
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final value = await showDialog<Object>(
                context: context,
                builder: (_) => integration
                    ? PolicyIntegrationEditor(
                        existing: _integration,
                        profiles: [
                          const Profile(
                            id: 1,
                            label: 'Present source',
                            autoUpdateDuration: Duration(hours: 24),
                          ),
                        ],
                        loadNodes: (_) async => [],
                        onSave: save,
                      )
                    : PolicyBudgetEditor(
                        existing: _budget,
                        sources: const {'1': 'Present source'},
                        onSave: save,
                      ),
              );
              result(value);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Finder _field(bool integration) => find.descendant(
  of: find.byKey(
    ValueKey(integration ? 'policy-integration-name' : 'policy-budget-limit'),
  ),
  matching: find.byType(TextFormField),
);

void main() {
  for (final integration in [true, false]) {
    final label = integration ? 'collection' : 'budget';
    testWidgets(
      '$label awaits saving, prevents duplicate taps, edits and back',
      (tester) async {
        final completion = Completer<void>();
        var calls = 0;
        Object? saved;
        Object? returned;
        await _open(tester, integration, (value) {
          calls++;
          saved = value;
          return completion.future;
        }, (value) => returned = value);
        final callback = tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, AppLocalizations.current.save),
            )
            .onPressed!;
        callback();
        callback();
        await tester.pump();
        expect(calls, 1);
        expect(returned, null);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(
                  FilledButton,
                  AppLocalizations.current.save,
                ),
              )
              .onPressed,
          null,
        );
        expect(
          tester
              .widget<TextButton>(
                find.widgetWithText(
                  TextButton,
                  AppLocalizations.current.cancel,
                ),
              )
              .onPressed,
          null,
        );
        expect(
          tester
              .widget<AbsorbPointer>(
                find
                    .ancestor(
                      of: _field(integration),
                      matching: find.byType(AbsorbPointer),
                    )
                    .first,
              )
              .absorbing,
          true,
        );
        expect(
          tester
              .widget<ExcludeFocus>(
                find
                    .ancestor(
                      of: _field(integration),
                      matching: find.byType(ExcludeFocus),
                    )
                    .first,
              )
              .excluding,
          true,
        );
        await tester.tap(_field(integration), warnIfMissed: false);
        await tester.tapAt(const Offset(5, 5));
        await tester.pump();
        expect(
          tester
              .widget<EditableText>(
                find.descendant(
                  of: _field(integration),
                  matching: find.byType(EditableText),
                ),
              )
              .focusNode
              .hasFocus,
          false,
        );
        await Navigator.of(tester.element(_field(integration))).maybePop();
        await tester.pump();
        expect(
          find.text(AppLocalizations.current.policyUnsavedTitle),
          findsNothing,
        );
        expect(
          find.byType(
            integration ? PolicyIntegrationEditor : PolicyBudgetEditor,
          ),
          findsOneWidget,
        );
        completion.complete();
        await tester.pumpAndSettle();
        expect(returned, same(saved));
        if (integration) {
          expect((saved! as SubscriptionIntegration).sourceProfileIds, [
            1,
            999,
          ]);
          expect((saved! as SubscriptionIntegration).excludedNodeIds, [
            '999:missing-node',
          ]);
        } else {
          expect((saved! as SourceBudget).sourceId, '999');
        }
        expect(tester.takeException(), null);
      },
    );

    testWidgets('$label save failure retains edited form and permits retry', (
      tester,
    ) async {
      final completion = Completer<void>();
      var calls = 0;
      Object? returned;
      await _open(tester, integration, (_) {
        calls++;
        return calls == 1 ? completion.future : Future.value();
      }, (value) => returned = value);
      final text = integration ? 'Edited collection' : '2';
      await tester.enterText(_field(integration), text);
      await tester.tap(
        find.widgetWithText(FilledButton, AppLocalizations.current.save),
      );
      await tester.pump();
      completion.completeError(StateError('fixture failure'));
      await tester.pumpAndSettle();
      expect(returned, null);
      expect(
        find.text(AppLocalizations.current.policyOperationFailed),
        findsOneWidget,
      );
      expect(
        tester.widget<TextFormField>(_field(integration)).controller!.text,
        text,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, AppLocalizations.current.save),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(
        find.widgetWithText(FilledButton, AppLocalizations.current.save),
      );
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(returned, isNotNull);
      expect(tester.takeException(), null);
    });

    testWidgets('$label unsaved back supports continue and explicit discard', (
      tester,
    ) async {
      var calls = 0;
      var closed = false;
      Object? returned;
      await _open(
        tester,
        integration,
        (_) async {
          calls++;
        },
        (value) {
          closed = true;
          returned = value;
        },
      );
      await tester.enterText(
        _field(integration),
        integration ? 'Unsaved' : '2',
      );
      await Navigator.of(tester.element(_field(integration))).maybePop();
      await tester.pumpAndSettle();
      expect(
        find.text(AppLocalizations.current.policyUnsavedTitle),
        findsOneWidget,
      );
      await tester.tap(
        find.text(AppLocalizations.current.policyContinueEditing),
      );
      await tester.pumpAndSettle();
      expect(closed, false);
      await tester.tap(
        find.widgetWithText(TextButton, AppLocalizations.current.cancel),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(AppLocalizations.current.policyDiscardChanges),
      );
      await tester.pumpAndSettle();
      expect(closed, true);
      expect(returned, null);
      expect(calls, 0);
      expect(tester.takeException(), null);
    });

    testWidgets('$label unchanged cancel closes without discard confirmation', (
      tester,
    ) async {
      var closed = false;
      await _open(
        tester,
        integration,
        (_) async => fail('unexpected save'),
        (_) => closed = true,
      );
      await tester.tap(
        find.widgetWithText(TextButton, AppLocalizations.current.cancel),
      );
      await tester.pumpAndSettle();
      expect(closed, true);
      expect(
        find.text(AppLocalizations.current.policyUnsavedTitle),
        findsNothing,
      );
    });

    testWidgets('$label disposed pending save ignores late failure safely', (
      tester,
    ) async {
      final completion = Completer<void>();
      await _open(tester, integration, (_) => completion.future, (_) {});
      await tester.tap(
        find.widgetWithText(FilledButton, AppLocalizations.current.save),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      completion.completeError(StateError('late fixture failure'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
    });
  }
}
