import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/views/ai/approval.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'approval displays concrete changes and returns explicit choice',
    (tester) async {
      bool? approval;
      await tester.pumpWidget(
        MaterialApp(
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
                  approval = await showAiConfigurationApproval(
                    context,
                    const ConfigurationProposal(
                      id: 'proposal-1',
                      summary: 'Proxy mode',
                      highRisk: true,
                      expiresAt: 1000,
                      differences: [
                        ConfigurationDifference(
                          path: 'config.mode',
                          before: 'rule',
                          after: 'global',
                        ),
                      ],
                      validation: {},
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('config.mode'), findsOneWidget);
      expect(find.text('"rule"'), findsOneWidget);
      expect(find.text('"global"'), findsOneWidget);
      await tester.tap(find.text(AppLocalizations.current.aiReject));
      await tester.pumpAndSettle();
      expect(approval, false);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppLocalizations.current.aiApprove));
      await tester.pumpAndSettle();
      expect(approval, true);
    },
  );

  test('nested credentials and URL secrets are hidden from approval display', () {
    final text = aiDisplayValue({
      'entries': [
        {
          'apiKey': 'private-key',
          'url':
              'https://user:pass@example.com/api?token=private-token&model=test',
        },
      ],
    });
    expect(text, isNot(contains('private-key')));
    expect(text, isNot(contains('private-token')));
    expect(text, isNot(contains('user:pass')));
    expect(text, contains('model=test'));
  });
}
