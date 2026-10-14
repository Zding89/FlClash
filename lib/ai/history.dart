import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:fl_clash/database/workbench_database.dart';

String aiConversationId() => List.generate(
  16,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

String aiHistoryText(String text, Iterable<String> secrets) {
  var result = text;
  for (final secret in secrets.where((value) => value.isNotEmpty)) {
    result = result.replaceAll(secret, '[redacted]');
  }
  return result
      .replaceAll(RegExp(r'sk-[A-Za-z0-9_-]{8,}'), '[redacted]')
      .replaceAll(
        RegExp(r'Bearer\s+[^\s"\x27]+', caseSensitive: false),
        'Bearer [redacted]',
      )
      .replaceAllMapped(RegExp(r'https?://[^\s<>"\x27]+'), (match) {
        final uri = Uri.tryParse(match[0]!);
        if (uri == null || uri.host.isEmpty) return '[redacted]';
        return Uri(
          scheme: uri.scheme,
          host: uri.host,
          port: uri.hasPort ? uri.port : null,
          path: '/[redacted]',
        ).toString();
      });
}

class AiConversation {
  const AiConversation({
    required this.id,
    required this.updatedAt,
    required this.messages,
    this.targetLabel,
    this.changeIds = const [],
  });

  final String id;
  final int updatedAt;
  final List<Map<String, String>> messages;
  final String? targetLabel;
  final List<String> changeIds;

  String get title =>
      messages
          .where((message) => message['role'] == 'user')
          .map((message) => message['content'] ?? '')
          .firstOrNull ??
      messages.firstOrNull?['content'] ??
      '';

  Map<String, Object?> toJson() => {
    'id': id,
    'updatedAt': updatedAt,
    'messages': messages,
    if (targetLabel != null) 'targetLabel': targetLabel,
    'changeIds': changeIds,
  };

  static AiConversation? parse(Object? value) {
    if (value is! Map ||
        value['id'] is! String ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(value['id'] as String) ||
        value['updatedAt'] is! int ||
        value['messages'] is! List) {
      return null;
    }
    var bytes = 0;
    final messages = <Map<String, String>>[];
    for (final message in (value['messages'] as List).reversed) {
      if (message is! Map ||
          !const ['user', 'assistant'].contains(message['role']) ||
          message['content'] is! String) {
        continue;
      }
      final text = message['content'] as String;
      bytes += utf8.encode(text).length;
      if (bytes > 256 * 1024 || messages.length >= 80) break;
      messages.insert(0, {'role': message['role'] as String, 'content': text});
    }
    if (messages.isEmpty) return null;
    final ids = value['changeIds'];
    return AiConversation(
      id: value['id'] as String,
      updatedAt: value['updatedAt'] as int,
      messages: messages,
      targetLabel: value['targetLabel'] is String
          ? (value['targetLabel'] as String).substring(
              0,
              min(160, (value['targetLabel'] as String).length),
            )
          : null,
      changeIds: ids is List
          ? ids
                .whereType<String>()
                .where((id) => id.length <= 160)
                .toSet()
                .take(96)
                .toList()
          : const [],
    );
  }
}

class _AiHistoryState {
  Future<void> tail = Future.value();
  final deleted = <String>{};
  final pendingDeletes = <String, int>{};
  final restores = StreamController<int>.broadcast();
  bool restoring = false;
  int generation = 0;
}

class AiHistoryStore {
  AiHistoryStore(this.database)
    : _state = _states[database] ??= _AiHistoryState();
  final WorkbenchDatabase database;
  final _AiHistoryState _state;
  static final _states = Expando<_AiHistoryState>();
  Set<String> get _deleted => _state.deleted;
  Map<String, int> get _pendingDeletes => _state.pendingDeletes;
  int get generation => _state.generation;
  Stream<int> get restores => _state.restores.stream;

  static Future<void> replaceForRestore(
    WorkbenchDatabase database,
    Future<void> Function() action,
  ) async {
    final state = _states[database] ??= _AiHistoryState();
    if (state.restoring) throw StateError('history_restore_in_progress');
    state.restoring = true;
    try {
      await state.tail;
      await action();
      state.deleted.clear();
      state.pendingDeletes.clear();
      state.generation++;
      state.restores.add(state.generation);
    } finally {
      state.restoring = false;
    }
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _state.tail.then((_) => action());
    _state.tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<List<AiConversation>> _read() async {
    Map<String, Object?>? raw;
    try {
      raw = await database.readSection('aiConversations');
    } on FormatException {
      return [];
    }
    final entries = raw?['conversations'];
    if (entries is! List) return [];
    return entries
        .map(AiConversation.parse)
        .whereType<AiConversation>()
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<List<AiConversation>> list() => _serial(_read);

  Future<void> save(AiConversation conversation) {
    if (_state.restoring) return Future.value();
    return _serial(() async {
      if (_deleted.contains(conversation.id) ||
          _pendingDeletes.containsKey(conversation.id)) {
        return;
      }
      final bounded = AiConversation.parse(conversation.toJson());
      if (bounded == null) return;
      final evicted = <String>[];
      await database.transaction(() async {
        final entries = await _read();
        entries.removeWhere((entry) => entry.id == bounded.id);
        entries.add(bounded);
        entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        for (final entry in entries.skip(20)) {
          evicted.add(entry.id);
        }
        await database.writeSection('aiConversations', {
          'version': 1,
          'conversations': entries
              .take(20)
              .map((entry) => entry.toJson())
              .toList(),
        });
      });
      _deleted.addAll(evicted);
    });
  }

  Future<void> delete(String id) {
    if (_state.restoring) return Future.value();
    _pendingDeletes.update(id, (count) => count + 1, ifAbsent: () => 1);
    return _serial(() async {
      try {
        final entries = await _read();
        await database.writeSection('aiConversations', {
          'version': 1,
          'conversations': entries
              .where((entry) => entry.id != id)
              .map((entry) => entry.toJson())
              .toList(),
        });
        _deleted.add(id);
      } finally {
        final count = _pendingDeletes[id]!;
        if (count == 1) {
          _pendingDeletes.remove(id);
        } else {
          _pendingDeletes[id] = count - 1;
        }
      }
    });
  }
}
