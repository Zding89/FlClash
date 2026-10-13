import 'dart:convert';
import 'dart:math';

import 'package:ai_security/ai_security.dart';
import 'package:crypto/crypto.dart';

abstract interface class ControlPasswordStore {
  Future<String?> read();
  Future<void> write(String password);
}

class KeychainControlPasswordStore implements ControlPasswordStore {
  const KeychainControlPasswordStore();

  static const _security = AiSecurity.control();

  @override
  Future<String?> read() => _security.get('password');

  @override
  Future<void> write(String password) => _security.set('password', password);
}

String generateControlPassword() {
  final random = Random.secure();
  return base64Url
      .encode(List.generate(32, (_) => random.nextInt(256)))
      .replaceAll('=', '');
}

int generateControlCredentialGeneration() {
  final random = Random.secure();
  var value = 0;
  while (value == 0) {
    value = (random.nextInt(1 << 21) << 32) | random.nextInt(1 << 32);
  }
  return value;
}

bool isValidControlPassword(String password) {
  final runes = password.runes.toList();
  return runes.length >= 12 &&
      runes.length <= 128 &&
      !runes.any(
        (rune) =>
            rune <= 0x1f ||
            (rune >= 0x7f && rune <= 0x9f) ||
            (rune >= 0xd800 && rune <= 0xdfff),
      );
}

bool matchesControlPassword(String supplied, String expected) {
  if (!isValidControlPassword(supplied) || !isValidControlPassword(expected)) {
    return false;
  }
  final first = sha256.convert(utf8.encode(supplied)).bytes;
  final second = sha256.convert(utf8.encode(expected)).bytes;
  var difference = 0;
  for (var index = 0; index < 32; index++) {
    difference |= first[index] ^ second[index];
  }
  return difference == 0;
}
