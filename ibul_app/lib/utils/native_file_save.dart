import 'dart:io';
import 'dart:typed_data';

/// Kullanıcının seçtiği yola bayt yazar. İptal edildiyse `null` döner.
Future<String?> writeBytesToSelectedPath({
  required String? pickedPath,
  required Uint8List bytes,
  required String fileName,
  Future<void> Function(String path, Uint8List data)? writeFile,
}) async {
  if (pickedPath == null || pickedPath.trim().isEmpty) {
    return null;
  }

  final String targetPath = normalizeCsvSavePath(pickedPath.trim(), fileName);
  final Future<void> Function(String path, Uint8List data) writer =
      writeFile ??
      (String path, Uint8List data) async {
        await File(path).writeAsBytes(data, flush: true);
      };
  await writer(targetPath, bytes);
  return targetPath;
}

/// Save panel bazen uzantısız yol döndürür.
String normalizeCsvSavePath(String path, String fileName) {
  if (path.toLowerCase().endsWith('.csv')) {
    return path;
  }
  if (fileName.toLowerCase().endsWith('.csv')) {
    return path.endsWith('/') || path.endsWith('\\')
        ? '$path$fileName'
        : '$path.csv';
  }
  return '$path.csv';
}
