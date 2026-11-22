import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _ChmodNative = Int32 Function(Pointer<Utf8> path, Uint32 mode);
typedef _ChmodDart = int Function(Pointer<Utf8> path, int mode);

/// Sets POSIX permissions through libc `chmod`, in process. A sandboxed app
/// may not start `/bin/chmod`, and the keys must not stay world readable.
/// Returns true when the mode was applied.
bool chmodInProcess(String path, int mode) {
  if (Platform.isWindows) return true;
  final pointer = path.toNativeUtf8();
  try {
    final chmod = DynamicLibrary.process()
        .lookupFunction<_ChmodNative, _ChmodDart>('chmod');
    return chmod(pointer, mode) == 0;
  } catch (_) {
    return false;
  } finally {
    calloc.free(pointer);
  }
}
