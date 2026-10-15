import 'dart:async';

import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class AiAssistantMarkdown extends StatelessWidget {
  const AiAssistantMarkdown({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => MarkdownBody(
    data: aiAssistantMarkdownText(text),
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

String aiAssistantMarkdownText(String text) {
  final structure = RegExp(
    r'[ \t]*(?:#{1,6} |[-*+] |[0-9]+[.)] |[|>]|`{3,}|~{3,}|\*\*)',
  );
  String prose(String value, {String followingCode = ''}) {
    final paths = RegExp(
      r'(?:[A-Za-z]:\\|\\\\)[^\s]*',
    ).allMatches(value).toList();
    var pathIndex = 0;
    return value.replaceAllMapped(RegExp(r'(?:\\r\\n|\\n)+'), (match) {
      final escaped = match.group(0)!;
      while (pathIndex < paths.length && paths[pathIndex].end <= match.start) {
        pathIndex++;
      }
      if ((match.start > 0 && value[match.start - 1] == r'\') ||
          (pathIndex < paths.length &&
              paths[pathIndex].start < match.start &&
              paths[pathIndex].end > match.start)) {
        return escaped;
      }
      final normalized = escaped.replaceAll(r'\r\n', r'\n');
      if (normalized.contains(r'\n\n') ||
          structure.matchAsPrefix(value, match.end) != null ||
          (match.end == value.length &&
              structure.matchAsPrefix(followingCode) != null)) {
        return normalized.replaceAll(r'\n', '\n');
      }
      return escaped;
    });
  }

  final result = StringBuffer();
  final protected = RegExp(
    r'(`{3,}[\s\S]*?`{3,}|~{3,}[\s\S]*?~{3,}|`+[^`]*`+)',
  );
  var offset = 0;
  for (final match in protected.allMatches(text)) {
    result.write(
      prose(
        text.substring(offset, match.start),
        followingCode: match.group(0)!,
      ),
    );
    var code = match.group(0)!;
    if (code.startsWith('```') || code.startsWith('~~~')) {
      code = code.replaceFirstMapped(
        RegExp(r'^(`{3,}|~{3,})([A-Za-z0-9_-]*)(?:\\r\\n|\\n)'),
        (opening) => '${opening.group(1)}${opening.group(2)}\n',
      );
      code = code.replaceFirstMapped(
        RegExp(r'(?:\\r\\n|\\n)(`{3,}|~{3,})$'),
        (closing) => '\n${closing.group(1)}',
      );
    }
    result.write(code);
    offset = match.end;
  }
  result.write(prose(text.substring(offset)));
  return result.toString();
}
