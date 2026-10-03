import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../services/mall_picked_file.dart';
import '../services/mall_management_repository.dart';

/// mall-media bucket standard: JPG/PNG/WEBP, at most 10 MB.
const mallMediaExtensions = ['jpg', 'jpeg', 'png', 'webp'];
const mallMediaMaxBytes = 10 * 1024 * 1024;

typedef MallPickedImage = ({String name, Uint8List bytes});

/// Returns null when the user cancels. Throws [MallManagementException] for
/// unreadable, oversized or wrong-format files.
Future<MallPickedImage?> pickMallImage({required String tag}) async {
  final picked = await FilePicker.platform.pickFiles(
    withData: mallPickerWithData,
    withReadStream: mallPickerWithReadStream,
    type: FileType.custom,
    allowedExtensions: mallMediaExtensions,
  );
  if (picked == null || picked.files.isEmpty) {
    debugPrint('[MALL][$tag] picker cancelled');
    return null;
  }
  final file = picked.files.single;
  final extension = (file.extension ?? '').toLowerCase();
  if (!mallMediaExtensions.contains(extension)) {
    throw MallManagementException('Yalnız JPG, PNG veya WEBP yükleyebilirsiniz.');
  }
  final bytes = await readMallPickedFile(file);
  if (bytes == null || bytes.isEmpty) {
    throw MallManagementException('Dosya okunamadı. Lütfen farklı bir dosya seçin.');
  }
  if (bytes.length > mallMediaMaxBytes) {
    throw MallManagementException('Görsel en fazla 10 MB olabilir.');
  }
  return (name: file.name, bytes: bytes);
}
