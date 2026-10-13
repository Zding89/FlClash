import 'dart:async';

final class ConfigurationWriteBarrier {
  Completer<void>? _idle;
  int _depth = 0;

  bool get active => _depth > 0;

  Future<void> wait() => _idle?.future ?? Future<void>.value();

  Future<T> run<T>(Future<T> Function() action) async {
    _idle ??= Completer<void>();
    _depth++;
    try {
      return await action();
    } finally {
      _depth--;
      if (_depth == 0) {
        final idle = _idle;
        _idle = null;
        idle?.complete();
      }
    }
  }
}

final configurationWriteBarrier = ConfigurationWriteBarrier();
