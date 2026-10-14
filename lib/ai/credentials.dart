import 'package:ai_security/ai_security.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/policy/models.dart';

import 'credential_cipher.dart';
import 'settings.dart';

abstract interface class AgentCredentialStore {
  Future<String?> read(String credentialId);
  Future<void> write(String credentialId, String secret);
  Future<void> delete(String credentialId);
}

final class LegacyCredentialMigrationException extends FormatException {
  const LegacyCredentialMigrationException()
    : super('Unable to migrate AI credential; enter the API key again');
}

final class MissingAgentCredentialException extends FormatException {
  const MissingAgentCredentialException()
    : super('AI credential missing; enter the API key before backup');
}

final class _CredentialQueue {
  Future<void> pending = Future<void>.value();
  int migrationEpoch = 0;

  Future<T> run<T>(Future<T> Function() action) {
    final result = pending.then((_) => action());
    pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}

final class EncryptedConfigAgentCredentialStore
    implements AgentCredentialStore {
  EncryptedConfigAgentCredentialStore(
    this.store, {
    AgentCredentialStore? legacy,
  }) : _legacy = legacy;

  final WorkbenchDatabase store;
  final AgentCredentialStore? _legacy;
  final _cipher = AgentCredentialCipher();
  static final _queues = Expando<_CredentialQueue>();
  static const section = 'aiCredentials';

  _CredentialQueue get _queue => _queues[store] ??= _CredentialQueue();

  static void invalidatePendingMigrations(WorkbenchDatabase store) {
    final queue = _queues[store] ??= _CredentialQueue();
    queue.migrationEpoch++;
  }

  static Future<Map<String, Object?>> validateSection(
    Map<String, Object?> payload,
  ) async {
    final normalized = _parseSection(payload);
    final cipher = AgentCredentialCipher();
    for (final entry in (normalized['values'] as Map<String, String>).entries) {
      await cipher.decrypt(entry.key, entry.value);
    }
    return normalized;
  }

  static Map<String, Object?> _parseSection(Map<String, Object?> payload) {
    if (payload.length != 3 ||
        payload['version'] is! int ||
        payload['version'] != 1 ||
        payload['values'] is! Map ||
        payload['legacyAttempted'] is! List) {
      throw const FormatException('Invalid AI credential configuration');
    }
    final values = <String, String>{};
    final attempted = <String>{};
    try {
      for (final entry in (payload['values'] as Map).entries) {
        if (entry.key is! String || entry.value is! String) {
          throw const FormatException('Invalid encrypted AI credential');
        }
        final id = entry.key as String;
        final value = entry.value as String;
        AgentCredentialCipher.validateId(id);
        AgentCredentialCipher.validateEncoding(value);
        values[id] = value;
      }
      for (final id in payload['legacyAttempted'] as List) {
        if (id is! String || !attempted.add(id)) {
          throw const FormatException('Invalid AI credential migration state');
        }
        AgentCredentialCipher.validateId(id);
      }
    } on ArgumentError {
      throw const FormatException('Invalid AI credential configuration');
    }
    if (!attempted.containsAll(values.keys)) {
      throw const FormatException('Invalid AI credential migration state');
    }
    return {
      'version': 1,
      'values': values,
      'legacyAttempted': attempted.toList(),
    };
  }

  Future<Map<String, Object?>> _load() async {
    final payload = await store.readSection(section);
    return payload == null
        ? {
            'version': 1,
            'values': <String, String>{},
            'legacyAttempted': <String>[],
          }
        : _parseSection(payload);
  }

  Future<String?> _read(String id) async {
    var migrate = false;
    final epoch = _queue.migrationEpoch;
    String? expectedCredentials;
    String? expectedSettings;
    final encrypted = await store.transaction(() async {
      final payload = await _load();
      final values = payload['values'] as Map<String, String>;
      final value = values[id];
      if (value != null) return value;
      final attempted = payload['legacyAttempted'] as List<String>;
      if (attempted.contains(id)) return null;
      if (_legacy != null) {
        final settingsPayload = await store.readSection('ai') ?? const {};
        final settings = AgentSettings.fromJson(settingsPayload);
        migrate = settings.connections.any((entry) => entry.credentialId == id);
        expectedSettings = policyDigest(settingsPayload);
      }
      attempted.add(id);
      await store.writeSection(section, payload);
      expectedCredentials = policyDigest(payload);
      return null;
    });
    if (encrypted != null) return _cipher.decrypt(id, encrypted);
    if (!migrate) return null;
    final String? secret;
    try {
      secret = await _legacy!.read(id);
      if (secret != null) AgentCredentialCipher.validateSecret(secret);
    } on Object {
      throw const LegacyCredentialMigrationException();
    }
    if (secret == null) return null;
    final value = await _cipher.encrypt(id, secret);
    return store.transaction(() async {
      final payload = await _load();
      final values = payload['values'] as Map<String, String>;
      final current = values[id];
      if (current != null) return _cipher.decrypt(id, current);
      if (_queue.migrationEpoch != epoch ||
          policyDigest(payload) != expectedCredentials ||
          policyDigest(await store.readSection('ai') ?? const {}) !=
              expectedSettings) {
        return null;
      }
      values[id] = value;
      await store.writeSection(section, payload);
      return secret;
    });
  }

  Future<void> _write(String id, String secret) async {
    final value = await _cipher.encrypt(id, secret);
    await store.transaction(() async {
      final payload = await _load();
      (payload['values'] as Map<String, String>)[id] = value;
      final attempted = payload['legacyAttempted'] as List<String>;
      if (!attempted.contains(id)) attempted.add(id);
      await store.writeSection(section, payload);
    });
  }

  @override
  Future<String?> read(String credentialId) => _queue.run(() async {
    AgentCredentialCipher.validateId(credentialId);
    return _read(credentialId);
  });

  @override
  Future<void> write(String credentialId, String secret) =>
      _queue.run(() async {
        AgentCredentialCipher.validateId(credentialId);
        AgentCredentialCipher.validateSecret(secret);
        await _write(credentialId, secret);
      });

  @override
  Future<void> delete(String credentialId) => _queue.run(() async {
    AgentCredentialCipher.validateId(credentialId);
    await store.transaction(() async {
      final payload = await _load();
      (payload['values'] as Map<String, String>).remove(credentialId);
      final attempted = payload['legacyAttempted'] as List<String>;
      if (!attempted.contains(credentialId)) attempted.add(credentialId);
      await store.writeSection(section, payload);
    });
  });

  Future<void> ensurePortable(Iterable<String> credentialIds) =>
      _queue.run(() async {
        for (final id in credentialIds.toSet()) {
          AgentCredentialCipher.validateId(id);
          if (await _read(id) == null) {
            throw const MissingAgentCredentialException();
          }
        }
      });
}

class KeychainAgentCredentialStore implements AgentCredentialStore {
  KeychainAgentCredentialStore({AiSecurity security = const AiSecurity()})
    : _security = security;

  final AiSecurity _security;
  final _secrets = <String, String>{};
  Future<void> _pending = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void _remember(String credentialId, String secret) {
    _secrets.remove(credentialId);
    if (_secrets.length >= 32) _secrets.remove(_secrets.keys.first);
    _secrets[credentialId] = secret;
  }

  @override
  Future<String?> read(String credentialId) => _serial(() async {
    final cached = _secrets[credentialId];
    if (cached != null) return cached;
    final secret = await _security.get(credentialId);
    if (secret != null && secret.isNotEmpty) _remember(credentialId, secret);
    return secret;
  });

  @override
  Future<void> write(String credentialId, String secret) => _serial(() async {
    _secrets.remove(credentialId);
    await _security.set(credentialId, secret);
    _remember(credentialId, secret);
  });

  @override
  Future<void> delete(String credentialId) => _serial(() async {
    _secrets.remove(credentialId);
    await _security.delete(credentialId);
  });
}
