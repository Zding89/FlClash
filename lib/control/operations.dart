import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

class ControlRequestStorageException implements Exception {
  const ControlRequestStorageException();
}

class ControlRequestLedger {
  ControlRequestLedger({
    this.load,
    this.save,
    this.maxRecords = 64,
    this.maxResultBytes = 64 * 1024,
    this.retention = const Duration(hours: 24),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Future<Map<String, Object?>?> Function()? load;
  final Future<void> Function(Map<String, Object?> value)? save;
  final int maxRecords;
  final int maxResultBytes;
  final Duration retention;
  final DateTime Function() _now;
  final Map<String, Map<String, Object?>> _records = {};
  Future<void> _tail = Future.value();
  bool _loaded = false;

  static String digest(Object? value) {
    Object? normalize(Object? item) {
      if (item is Map) {
        final keys = item.keys.map((key) => key.toString()).toList()..sort();
        return {for (final key in keys) key: normalize(item[key])};
      }
      if (item is List) return item.map(normalize).toList();
      return item;
    }

    return sha256.convert(utf8.encode(jsonEncode(normalize(value)))).toString();
  }

  Future<T> _serialized<T>(Future<T> Function() work) {
    final result = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        if (!_loaded) {
          final stored = await load?.call();
          for (final value in (stored?['records'] as List? ?? const []).take(
            maxRecords,
          )) {
            if (value is Map && value['id'] is String) {
              _records[value['id'] as String] = Map<String, Object?>.from(
                value,
              );
            }
          }
          _loaded = true;
        }
        result.complete(await work());
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  void _prune() {
    final cutoff = _now().millisecondsSinceEpoch;
    _records.removeWhere((_, row) => (row['expiresAt'] as int) <= cutoff);
  }

  Future<void> _persist() async {
    await save?.call({'records': _records.values.toList()});
  }

  Future<Map<String, Object?>?> query(String id, String owner) =>
      _serialized(() async {
        _prune();
        final row = _records[id];
        if (row == null) return null;
        if (row['response'] == null && row['owner'] != owner) {
          row['status'] = 'failed';
          row['response'] = {
            'status': 'failed',
            'errorCode': 'operation_interrupted',
          };
          await _persist();
        }
        final response = row['response'];
        return response is Map
            ? {
                ...Map<String, Object?>.from(response),
                'operationId': response['operationId'] ?? id,
                'requestOperationId': id,
              }
            : {'status': row['status'], 'operationId': id};
      });

  Future<Map<String, Object?>?> find(String key, String fingerprint) =>
      _serialized(() async {
        _prune();
        for (final row in _records.values) {
          if (row['key'] != key) continue;
          if (row['fingerprint'] != fingerprint) {
            return {'status': 'conflict', 'errorCode': 'idempotency_conflict'};
          }
          return {'operationId': row['id']};
        }
        return null;
      });

  Future<String> register({
    required String id,
    required String owner,
    required String fingerprint,
    String? key,
  }) => _serialized(() async {
    _prune();
    if (key != null) {
      for (final row in _records.values) {
        if (row['key'] != key) continue;
        if (row['fingerprint'] != fingerprint) {
          throw StateError('idempotency_conflict');
        }
        return row['id'] as String;
      }
    }
    if (_records.length >= maxRecords) {
      final evictable = _records.values
          .where((row) => row['key'] == null && row['response'] != null)
          .firstOrNull;
      if (evictable == null) throw StateError('operation_limit');
      _records.remove(evictable['id']);
    }
    _records[id] = {
      'id': id,
      'owner': owner,
      'fingerprint': fingerprint,
      'key': key,
      'status': 'queued',
      'expiresAt': _now().add(retention).millisecondsSinceEpoch,
    };
    try {
      await _persist();
    } catch (_) {
      _records.remove(id);
      rethrow;
    }
    return id;
  });

  Future<void> running(String id) => _serialized(() async {
    _records[id]?['status'] = 'running';
    await _persist();
  });

  Future<void> complete(String id, Map<String, Object?> response) =>
      _serialized(() async {
        final row = _records[id];
        if (row == null) return;
        final safe = _safe(response) as Map<String, Object?>;
        row['response'] = utf8.encode(jsonEncode(safe)).length > maxResultBytes
            ? {'status': 'failed', 'errorCode': 'result_limit'}
            : safe;
        row['status'] = (row['response'] as Map)['status'];
        try {
          await _persist();
        } catch (_) {
          row['status'] = 'failed';
          row['response'] = {
            'status': 'failed',
            'errorCode': 'operation_result_save_failed',
          };
          throw const ControlRequestStorageException();
        }
      });

  static Object? _safe(Object? value, [String key = '']) {
    if (RegExp(
      r'(password|secret|token|credential|authorization|protected|private.?key|api.?key|^params$|^arguments$|^before$|^after$|^content$|^body$)',
      caseSensitive: false,
    ).hasMatch(key)) {
      return '[redacted]';
    }
    if (value is Map) {
      return <String, Object?>{
        for (final entry in value.entries)
          entry.key.toString(): _safe(entry.value, entry.key.toString()),
      };
    }
    if (value is List) return value.map((item) => _safe(item, key)).toList();
    if (value is String) {
      return value
          .replaceAll(RegExp(r'https?://[^\s\x22\x27<>]+'), '[URL]')
          .replaceAll(RegExp(r'\bsk-[A-Za-z0-9_-]{8,}\b'), '[redacted]')
          .replaceAll(
            RegExp(
              r'(?:Bearer\s+|(?:password|token|secret|api[-_]?key)\s*[:=]\s*)\S+',
              caseSensitive: false,
            ),
            '[redacted]',
          );
    }
    return value;
  }
}
