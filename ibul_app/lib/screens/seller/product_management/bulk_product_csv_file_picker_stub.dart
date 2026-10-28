import 'dart:io' if (dart.library.html) 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'bulk_product_import_models.dart';

Future<BulkProductSelectedFile?> pickBulkProductCsvFile() async {
  final FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const <String>['csv'],
    withData: true,
    allowMultiple: false,
  );
  if (result == null || result.files.isEmpty) {
    return null;
  }

  // Web ortamında dosya içeriği result.files.single.bytes üzerinden okunur (asla .path üzerinden File açılmaz).
  final PlatformFile file = result.files.single;
  Uint8List? bytes = file.bytes;
  if (!kIsWeb && (bytes == null || bytes.isEmpty) && file.path != null && file.path!.trim().isNotEmpty) {
    try {
      bytes = await File(file.path!).readAsBytes();
    } catch (_) {}
  }
  if (bytes == null || bytes.isEmpty) {
    throw Exception('CSV dosyası okunamadı.');
  }

  return BulkProductSelectedFile(
    name: file.name.trim().isNotEmpty ? file.name : 'urunler.csv',
    bytes: bytes,
  );
}
