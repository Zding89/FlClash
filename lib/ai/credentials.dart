import 'package:ai_security/ai_security.dart';

abstract interface class AgentCredentialStore {
  Future<String?> read(String credentialId);
  Future<void> write(String credentialId, String secret);
  Future<void> delete(String credentialId);
}

class KeychainAgentCredentialStore implements AgentCredentialStore {
  const KeychainAgentCredentialStore({AiSecurity security = const AiSecurity()})
    : _security = security;

  final AiSecurity _security;

  @override
  Future<String?> read(String credentialId) => _security.get(credentialId);

  @override
  Future<void> write(String credentialId, String secret) =>
      _security.set(credentialId, secret);

  @override
  Future<void> delete(String credentialId) => _security.delete(credentialId);
}
