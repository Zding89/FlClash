import 'dart:convert';

import 'package:cryptography/cryptography.dart';

final class AgentCredentialCipher {
  static const version = 1;
  static final _algorithm = AesGcm.with256bits();
  static final _key = SecretKey(const [
    0x65,
    0x28,
    0x9a,
    0xd4,
    0xe3,
    0x16,
    0x77,
    0xb1,
    0x0c,
    0x8f,
    0x45,
    0x99,
    0xc0,
    0x3b,
    0xd6,
    0x2a,
    0x7d,
    0xf0,
    0xa3,
    0x54,
    0x12,
    0x6b,
    0x88,
    0xe9,
    0x4f,
    0x20,
    0x5c,
    0xb7,
    0x31,
    0xda,
    0x06,
    0x93,
  ]);
  static final _identifier = RegExp(r'^[A-Za-z0-9_-]{1,96}$');
  static final _encoding = RegExp(r'^v1\.[A-Za-z0-9_-]+={0,2}$');

  static void validateId(String id) {
    if (!_identifier.hasMatch(id) || id.contains('\n')) {
      throw ArgumentError.value(id, 'credentialId');
    }
  }

  static void validateSecret(String secret) {
    if (secret.isEmpty || secret.length > 16384) {
      throw ArgumentError('invalidSecret');
    }
  }

  static List<int> _aad(String id) =>
      utf8.encode('flclash.aiCredentials.$version:$id');

  static List<int> _decode(String value) {
    if (value.length > 131072 || !_encoding.hasMatch(value)) {
      throw const FormatException('Invalid encrypted AI credential');
    }
    final encoded = value.substring(3);
    final bytes = base64Url.decode(encoded);
    if (bytes.length < 29 || base64Url.encode(bytes) != encoded) {
      throw const FormatException('Invalid encrypted AI credential');
    }
    return bytes;
  }

  static void validateEncoding(String value) => _decode(value);

  Future<String> encrypt(String id, String secret) async {
    validateId(id);
    validateSecret(secret);
    final box = await _algorithm.encrypt(
      utf8.encode(secret),
      secretKey: _key,
      nonce: _algorithm.newNonce(),
      aad: _aad(id),
    );
    return 'v$version.${base64Url.encode(box.concatenation())}';
  }

  Future<String> decrypt(String id, String value) async {
    validateId(id);
    final bytes = _decode(value);
    try {
      final plaintext = await _algorithm.decrypt(
        SecretBox.fromConcatenation(bytes, nonceLength: 12, macLength: 16),
        secretKey: _key,
        aad: _aad(id),
      );
      final secret = utf8.decode(plaintext);
      validateSecret(secret);
      return secret;
    } on Object {
      throw const FormatException('Unable to decrypt AI credential');
    }
  }
}
