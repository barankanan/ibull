import 'dart:io';
import 'dart:typed_data';

Future<Uint8List?> readMallFilePath(String? path) async {
  if (path == null || path.trim().isEmpty) return null;
  final file = File(path);
  if (!await file.exists()) return null;
  final bytes = await file.readAsBytes();
  return bytes.isEmpty ? null : bytes;
}
