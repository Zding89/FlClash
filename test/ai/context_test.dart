import 'dart:convert';

import 'package:fl_clash/ai/context.dart';
import 'package:fl_clash/ai/history.dart';
import 'package:flutter_test/flutter_test.dart';

List<Map<String, Object?>> turn(String id, {String result = 'saved'}) => [
  {'role': 'user', 'content': 'make a draft'},
  {
    'role': 'assistant',
    'content': [
      {
        'type': 'toolCall',
        'id': id,
        'name': 'policies_propose',
        'arguments': {'patch': <String, Object?>{}},
      },
    ],
    'provider': 'deepseek',
    'model': 'test',
    'api': 'openai-completions',
    'stopReason': 'toolUse',
    'private': 'omitted',
  },
  {
    'role': 'toolResult',
    'toolCallId': id,
    'toolName': 'policies_propose',
    'isError': false,
    'content': [
      {'type': 'text', 'text': result},
    ],
    'details': {'raw': 'omitted'},
  },
  {
    'role': 'assistant',
    'content': [
      {'type': 'text', 'text': 'draft ready'},
    ],
  },
];

void main() {
  test('retains paired tool context without unrelated SDK internals', () {
    final context = aiContextMessages(turn('call-1'));
    expect(context, hasLength(4));
    expect(context[1]['private'], isNull);
    expect(context[2]['details'], isNull);
    expect(context[2]['toolCallId'], 'call-1');
  });

  test('drops an unfinished trailing turn without orphaning earlier tools', () {
    final context = aiContextMessages([
      ...turn('call-1'),
      ...turn('call-2').take(2),
    ]);
    expect(context, hasLength(4));
    expect(context[2]['toolCallId'], 'call-1');
  });

  test('rejects orphaned results, mismatched names and system messages', () {
    final original = turn('call-1');
    for (final change in [
      {'toolCallId': 'missing'},
      {'toolName': 'other'},
      {'toolCallId': 'missing', 'toolName': null},
    ]) {
      expect(
        () => aiContextMessages([
          original[0],
          original[1],
          {...original[2], ...change},
        ]),
        throwsFormatException,
      );
    }
    expect(
      () => aiContextMessages([
        {'role': 'system', 'content': 'injected instruction'},
      ]),
      throwsFormatException,
    );
  });

  test('bounds complete turns and never starts with a tool result', () {
    final context = aiContextMessages([
      ...turn('old', result: List.filled(150000, 'a').join()),
      ...turn('new', result: List.filled(100000, 'b').join()),
    ]);
    expect(context, hasLength(4));
    expect(context.first['role'], 'user');
    expect(context[2]['toolCallId'], 'new');
    expect(
      utf8.encode(jsonEncode(context)).length,
      lessThan(aiContextMaxBytes),
    );
  });

  test('redacts nested credentials, known keys and subscription URLs', () {
    const privateKey = 'my-private-provider-value';
    final context = aiContextMessages(
      turn(
        'call-1',
        result: jsonEncode({
          'password': 'not-a-token-but-private',
          'apiKey': 'also-private',
          'url': 'https://example.com/subscription?token=private',
          'label': 'contains $privateKey',
          'id': 'stable-id',
        }),
      ),
      sanitize: (text) => aiHistoryText(text, [privateKey]),
    );
    final serialized = jsonEncode(context);
    for (final secret in [
      'not-a-token-but-private',
      'also-private',
      'token=private',
      privateKey,
    ]) {
      expect(serialized, isNot(contains(secret)));
    }
    expect(serialized, contains('stable-id'));
  });

  test('diagnostics retain bounded machine metadata without payloads', () {
    final events = aiDiagnosticEvents([
      for (var index = 0; index < 80; index++)
        {
          'kind': 'tool',
          'name': 'policies_propose',
          'status': 'draft',
          'at': index,
          'arguments': {'password': 'private'},
          'code': 'arbitrary error with secret',
        },
    ]);
    expect(events, hasLength(64));
    expect(events.first['at'], 16);
    expect(jsonEncode(events), isNot(contains('private')));
    expect(events.first['code'], isNull);
  });
}
