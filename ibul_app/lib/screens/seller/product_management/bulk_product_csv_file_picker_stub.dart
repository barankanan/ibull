import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

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

  final PlatformFile file = result.files.first;
  Uint8List? bytes = file.bytes;
  if ((bytes == null || bytes.isEmpty) &&
      file.path != null &&
      file.path!.trim().isNotEmpty) {
    bytes = await File(file.path!).readAsBytes();
  }
  if (bytes == null || bytes.isEmpty) {
    throw Exception('CSV dosyası okunamadı.');
  }

  return BulkProductSelectedFile(
    name: file.name.trim().isNotEmpty ? file.name : 'urunler.csv',
    bytes: bytes,
  );
}
