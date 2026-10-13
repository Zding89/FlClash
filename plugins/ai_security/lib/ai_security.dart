import 'package:flutter/services.dart';

class AiSecurity {
  const AiSecurity();

  static const MethodChannel channel = MethodChannel('flclash/ai_security');
  static final RegExp _identifier = RegExp(r'^[A-Za-z0-9_-]{1,96}$');

  void _validate(String id) {
    if (!_identifier.hasMatch(id) || id.contains('\n'))
      throw ArgumentError.value(id, 'id');
  }

  Future<String?> get(String id) {
    _validate(id);
    return channel.invokeMethod<String>('get', {'id': id});
  }

  Future<void> set(String id, String secret) async {
    _validate(id);
    if (secret.isEmpty || secret.length > 16384) {
      throw ArgumentError('invalidSecret');
    }
    await channel.invokeMethod<void>('set', {'id': id, 'secret': secret});
  }

  Future<void> delete(String id) async {
    _validate(id);
    await channel.invokeMethod<void>('delete', {'id': id});
  }
}
