import 'dart:async';

import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class AiAssistantMarkdown extends StatelessWidget {
  const AiAssistantMarkdown({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => MarkdownBody(
    data: text,
    selectable: true,
    fitContent: false,
    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      tableColumnWidth: const IntrinsicColumnWidth(),
      tableScrollbarThumbVisibility: true,
      code: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(fontFamily: 'JetBrainsMono'),
    ),
    imageBuilder: (_, _, alt) => Text(alt ?? ''),
    onTapLink: (_, href, _) {
      final uri = href == null ? null : Uri.tryParse(href);
      if (uri == null ||
          !{'https', 'http'}.contains(uri.scheme) ||
          uri.host.isEmpty) {
        return;
      }
      unawaited(globalState.openUrl(uri.toString()));
    },
  );
}
