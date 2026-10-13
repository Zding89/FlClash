import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

class ControlPacket {
  const ControlPacket(this.token, this.body);
  final int token;
  final String body;
}

abstract interface class ControlTransport {
  void start(String instanceId);
  ControlPacket? poll();
  void reply(int token, Map<String, Object?> response);
  void stop();
}

class NativeControlTransport implements ControlTransport {
  NativeControlTransport({DynamicLibrary? library})
    : _providedLibrary = library;

  final DynamicLibrary? _providedLibrary;
  bool _started = false;
  late final DynamicLibrary _library =
      _providedLibrary ??
      DynamicLibrary.open(
        p.join(
          p.dirname(Platform.resolvedExecutable),
          '..',
          'Resources',
          'control',
          'libflclash_control.dylib',
        ),
      );
  late final _start = _library
      .lookupFunction<
        Int32 Function(Pointer<Utf8>),
        int Function(Pointer<Utf8>)
      >('fl_control_start');
  late final _poll = _library
      .lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>(
        'fl_control_poll',
      );
  late final _reply = _library
      .lookupFunction<
        Void Function(Uint64, Pointer<Utf8>),
        void Function(int, Pointer<Utf8>)
      >('fl_control_reply');
  late final _stop = _library.lookupFunction<Void Function(), void Function()>(
    'fl_control_stop',
  );
  late final _free = _library
      .lookupFunction<
        Void Function(Pointer<Utf8>),
        void Function(Pointer<Utf8>)
      >('fl_control_free');

  @override
  void start(String instanceId) {
    final value = instanceId.toNativeUtf8();
    try {
      if (_start(value) != 0) throw StateError('control_transport_unavailable');
      _started = true;
    } finally {
      malloc.free(value);
    }
  }

  @override
  ControlPacket? poll() {
    if (!_started) return null;
    final value = _poll();
    if (value == nullptr) return null;
    try {
      final packet = jsonDecode(value.toDartString()) as Map<String, dynamic>;
      return ControlPacket(packet['token'] as int, packet['body'] as String);
    } finally {
      _free(value);
    }
  }

  @override
  void reply(int token, Map<String, Object?> response) {
    if (!_started) return;
    var body = jsonEncode(response);
    if (utf8.encode(body).length > 1024 * 1024) {
      body = jsonEncode({
        'requestId': response['requestId'],
        'status': 'failed',
        'errorCode': 'result_too_large',
      });
    }
    final value = body.toNativeUtf8();
    try {
      _reply(token, value);
    } finally {
      malloc.free(value);
    }
  }

  @override
  void stop() {
    if (!_started) return;
    _stop();
    _started = false;
  }
}
