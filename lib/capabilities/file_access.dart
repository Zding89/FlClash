import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as paths;

class SecureLocalFiles {
  static final _library = DynamicLibrary.process();
  static final _open = _library
      .lookupFunction<
        Int32 Function(Pointer<Utf8>, Int32, VarArgs<(Int32,)>),
        int Function(Pointer<Utf8>, int, int)
      >('open');
  static final _openAt = _library
      .lookupFunction<
        Int32 Function(Int32, Pointer<Utf8>, Int32, VarArgs<(Int32,)>),
        int Function(int, Pointer<Utf8>, int, int)
      >('openat');
  static final _close = _library
      .lookupFunction<Int32 Function(Int32), int Function(int)>('close');
  static final _read = _library
      .lookupFunction<
        IntPtr Function(Int32, Pointer<Uint8>, IntPtr),
        int Function(int, Pointer<Uint8>, int)
      >('read');
  static final _write = _library
      .lookupFunction<
        IntPtr Function(Int32, Pointer<Uint8>, IntPtr),
        int Function(int, Pointer<Uint8>, int)
      >('write');
  static final _sync = _library
      .lookupFunction<Int32 Function(Int32), int Function(int)>('fsync');

  static int _descriptor(String path, {required bool write}) {
    if (!Platform.isMacOS ||
        !paths.isAbsolute(path) ||
        paths.normalize(path) != path ||
        path.contains('\u0000')) {
      throw const FileSystemException('Unsafe local file');
    }
    const directoryFlags = 0x100000 | 0x100 | 0x1000000;
    final root = '/'.toNativeUtf8();
    var parent = -1;
    try {
      parent = _open(root, directoryFlags, 0);
    } finally {
      calloc.free(root);
    }
    if (parent < 0) throw const FileSystemException('Cannot open directory');
    final parts = paths.split(path).skip(1).toList();
    try {
      for (final part in parts.take(parts.length - 1)) {
        final name = part.toNativeUtf8();
        int next;
        try {
          next = _openAt(parent, name, directoryFlags, 0);
        } finally {
          calloc.free(name);
        }
        if (next < 0) throw const FileSystemException('Unsafe local directory');
        _close(parent);
        parent = next;
      }
      final name = parts.last.toNativeUtf8();
      int descriptor;
      try {
        descriptor = _openAt(
          parent,
          name,
          write
              ? 0x1 | 0x200 | 0x800 | 0x100 | 0x1000000
              : 0x4 | 0x100 | 0x1000000,
          0x180,
        );
      } finally {
        calloc.free(name);
      }
      if (descriptor < 0) {
        throw const FileSystemException('Local file unavailable');
      }
      return descriptor;
    } finally {
      _close(parent);
    }
  }

  static Uint8List read(String path, {required int maximumBytes}) {
    final descriptor = _descriptor(path, write: false);
    final memory = calloc<Uint8>(65536);
    final result = BytesBuilder(copy: false);
    try {
      while (true) {
        final count = _read(descriptor, memory, 65536);
        if (count < 0) throw const FileSystemException('Local read failed');
        if (count == 0) return result.takeBytes();
        if (result.length + count > maximumBytes) {
          throw const FileSystemException('Local input too large');
        }
        result.add(Uint8List.fromList(memory.asTypedList(count)));
      }
    } finally {
      calloc.free(memory);
      _close(descriptor);
    }
  }

  static void write(String path, Uint8List bytes) {
    final descriptor = _descriptor(path, write: true);
    final memory = calloc<Uint8>(65536);
    try {
      var offset = 0;
      while (offset < bytes.length) {
        final count = bytes.length - offset > 65536
            ? 65536
            : bytes.length - offset;
        memory.asTypedList(count).setRange(0, count, bytes, offset);
        final written = _write(descriptor, memory, count);
        if (written <= 0) throw const FileSystemException('Local write failed');
        offset += written;
      }
      if (_sync(descriptor) < 0) {
        throw const FileSystemException('Local sync failed');
      }
    } finally {
      calloc.free(memory);
      _close(descriptor);
    }
  }
}
