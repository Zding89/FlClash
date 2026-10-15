import 'package:fl_clash/views/ai/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('escaped Markdown renders bold lists and tables', (tester) async {
    const source =
        r'**Result**\n\n- First\n- Second\n\n| Rule | Route |\n| --- | --- |\n| Video | Japan |';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AiAssistantMarkdown(text: source)),
      ),
    );
    await tester.pumpAndSettle();
    final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    expect(
      markdown.data,
      '**Result**\n\n- First\n- Second\n\n| Rule | Route |\n| --- | --- |\n| Video | Japan |',
    );
    expect(find.text('Result'), findsOneWidget);
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
    expect(find.byType(Table), findsOneWidget);
    bool bold(InlineSpan span) =>
        span is TextSpan &&
        ((span.toPlainText() == 'Result' &&
                span.style?.fontWeight == FontWeight.bold) ||
            (span.children?.any(bold) ?? false));
    expect(
      tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .any((widget) => widget.textSpan != null && bold(widget.textSpan!)),
      true,
    );
    expect(tester.takeException(), isNull);
  });

  test(
    'normal Markdown, inline code, fenced code and Windows paths stay intact',
    () {
      const source =
          '**Result**\n\n`value\\n\\n**literal**`\n\n```dart\nconst value = "\\n\\n**literal**";\n```\n\nC:\\new\\notes\\n\\n**file**';
      expect(aiAssistantMarkdownText(source), source);
      expect(
        aiAssistantMarkdownText(r'C:\new\notes\n- file'),
        r'C:\new\notes\n- file',
      );
      expect(
        aiAssistantMarkdownText(r'\\network\notes\n- file'),
        r'\\network\notes\n- file',
      );
      expect(
        aiAssistantMarkdownText(r'Use \n to separate lines'),
        r'Use \n to separate lines',
      );
    },
  );

  testWidgets('escaped fence boundaries preserve literal code escapes', (
    tester,
  ) async {
    const source =
        r'**Result**\n\n```dart\nconst value = "\n\n**literal**";\n```';
    const expected =
        '**Result**\n\n```dart\nconst value = "\\n\\n**literal**";\n```';
    expect(aiAssistantMarkdownText(source), expected);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AiAssistantMarkdown(text: source)),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining(r'const value = "\n\n**literal**";'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
