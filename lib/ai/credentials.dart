import 'package:ai_security/ai_security.dart';

abstract interface class AgentCredentialStore {
  Future<String?> read(String credentialId);
  Future<void> write(String credentialId, String secret);
  Future<void> delete(String credentialId);
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
