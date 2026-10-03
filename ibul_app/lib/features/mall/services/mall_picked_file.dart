import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'mall_picked_file_stub.dart'
    if (dart.library.io) 'mall_picked_file_io.dart' as path_reader;

/// Desktop loads bytes in the picker. Web also keeps a stream because
/// `PlatformFile.bytes` is often empty there. Both are not enabled together
/// on macOS: that combination returns neither bytes nor a usable stream.
bool get mallPickerWithData => true;

bool get mallPickerWithReadStream => kIsWeb;

String get mallRuntimeLabel {
  if (kIsWeb) return 'web';
  return defaultTargetPlatform.name;
}

Future<Uint8List?> readMallPickedFile(PlatformFile file) async {
  final extension = file.extension ?? '';
  debugPrint(
    '[MALL][FILE_PICKER] name=${file.name} extension=$extension '
    'size=${file.size} bytes=${file.bytes != null} path=${file.path != null} '
    'readStream=${file.readStream != null} runtime=$mallRuntimeLabel',
  );
  if (file.bytes != null && file.bytes!.isNotEmpty) return file.bytes;
  final stream = file.readStream;
  if (stream != null) {
    final all = <int>[];
    await for (final chunk in stream) {
      all.addAll(chunk);
    }
    if (all.isNotEmpty) return Uint8List.fromList(all);
  }
  return path_reader.readMallFilePath(file.path);
}
