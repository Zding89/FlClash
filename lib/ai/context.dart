import 'dart:convert';

const aiContextMaxBytes = 192 * 1024;
const aiContextMaxMessages = 100;

List<Map<String, Object?>> aiContextMessages(
  Object? value, {
  String Function(String)? sanitize,
}) {
  if (value is! List || value.length > 1000) {
    throw const FormatException('invalidContext');
  }
  final clean = sanitize ?? (String text) => text;
  Object? object(Object? value, int depth) {
    if (depth > 20) throw const FormatException('invalidContext');
    if (value == null || value is bool || value is num) return value;
    if (value is String) return clean(value);
    if (value is List && value.length <= 10000) {
      return value.map((item) => object(item, depth + 1)).toList();
    }
    if (value is Map && value.length <= 10000) {
      return <String, Object?>{
        for (final entry in value.entries)
          if (entry.key is String)
            entry.key as String:
                sanitize != null &&
                    RegExp(
                      r'^(api_?key|password|authorization|access_?token|refresh_?token|secret|protectedContent)$',
                      caseSensitive: false,
                    ).hasMatch(entry.key as String)
                ? '[redacted]'
                : object(entry.value, depth + 1),
      };
    }
    throw const FormatException('invalidContext');
  }

  String text(String value) {
    if (sanitize == null) return value;
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map || decoded is List) {
        return jsonEncode(object(decoded, 0));
      }
    } on FormatException {
      return clean(value);
    }
    return clean(value);
  }

  final groups = <List<Map<String, Object?>>>[];
  var group = <Map<String, Object?>>[];
  final pending = <String, String>{};
  final used = <String>{};
  void finish() {
    if (group.isNotEmpty && pending.isEmpty) groups.add(group);
    group = [];
    pending.clear();
    used.clear();
  }

  for (final raw in value) {
    if (raw is! Map) throw const FormatException('invalidContext');
    final role = raw['role'];
    if (!const ['user', 'assistant', 'toolResult'].contains(role)) {
      throw const FormatException('invalidContext');
    }
    if (role == 'user') finish();
    if (group.isEmpty && role != 'user') continue;
    final message = <String, Object?>{
      'role': role,
      'timestamp': raw['timestamp'] is int ? raw['timestamp'] : 0,
    };
    final content = raw['content'];
    if (role == 'user' && content is String) {
      message['content'] = text(content);
    } else if (content is List && content.length <= 512) {
      final blocks = <Map<String, Object?>>[];
      for (final block in content) {
        if (block is! Map) throw const FormatException('invalidContext');
        if (block['type'] == 'text' && block['text'] is String) {
          blocks.add({'type': 'text', 'text': text(block['text'] as String)});
        } else if (role == 'assistant' && block['type'] == 'toolCall') {
          final id = block['id'];
          final name = block['name'];
          if (id is! String ||
              id.isEmpty ||
              id.length > 200 ||
              name is! String ||
              !RegExp(r'^[A-Za-z0-9_-]{1,96}$').hasMatch(name) ||
              block['arguments'] is! Map ||
              !used.add(id)) {
            throw const FormatException('invalidContext');
          }
          pending[id] = name;
          blocks.add({
            'type': 'toolCall',
            'id': id,
            'name': name,
            'arguments': object(block['arguments'], 0),
          });
        } else {
          throw const FormatException('invalidContext');
        }
      }
      message['content'] = blocks;
    } else {
      throw const FormatException('invalidContext');
    }
    if (role == 'assistant') {
      for (final key in ['api', 'provider', 'model', 'stopReason']) {
        if (raw[key] is String && (raw[key] as String).length <= 200) {
          message[key] = raw[key];
        }
      }
    } else if (role == 'toolResult') {
      final id = raw['toolCallId'];
      if (id is! String ||
          !pending.containsKey(id) ||
          raw['toolName'] is! String ||
          pending.remove(id) != raw['toolName'] ||
          raw['isError'] is! bool) {
        throw const FormatException('invalidContext');
      }
      message.addAll({
        'toolCallId': id,
        'toolName': raw['toolName'],
        'isError': raw['isError'],
      });
    }
    group.add(message);
  }
  finish();
  final retained = <Map<String, Object?>>[];
  for (final entry in groups.reversed) {
    final candidate = [...entry, ...retained];
    if (candidate.length > aiContextMaxMessages ||
        utf8.encode(jsonEncode(candidate)).length > aiContextMaxBytes) {
      break;
    }
    retained.insertAll(0, entry);
  }
  return retained;
}

List<Map<String, Object?>> aiDiagnosticEvents(Object? value) {
  if (value is! List) return [];
  return [
    for (final event in value.reversed.take(64).toList().reversed)
      if (event is Map)
        <String, Object?>{
          for (final key in ['kind', 'name', 'status', 'code'])
            if (event[key] is String &&
                RegExp(r'^[A-Za-z0-9_-]{1,96}$').hasMatch(event[key] as String))
              key: event[key],
          if (event['at'] is int) 'at': event['at'],
          if (event['turn'] is int) 'turn': event['turn'],
        },
  ];
}
