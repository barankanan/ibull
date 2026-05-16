import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

import 'pick_image_file_models.dart';

/// Mobil/masaüstü: file_picker (macOS sandbox için bayt olarak okunur).
Future<List<PickedImageFile>> pickImageFiles({
  bool allowMultiple = false,
}) async {
  final bool loadBytes = defaultTargetPlatform == TargetPlatform.macOS;
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: allowMultiple,
    withData: loadBytes,
  );
  if (result == null || result.files.isEmpty) return const <PickedImageFile>[];

  final picked = <PickedImageFile>[];
  for (final file in result.files) {
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      picked.add(
        PickedImageFile(
          name: file.name.trim().isNotEmpty ? file.name : 'image.jpg',
          bytes: file.bytes!,
          path: file.path,
        ),
      );
      continue;
    }

    final path = file.path;
    if (path != null && path.trim().isNotEmpty) {
      picked.add(
        PickedImageFile(
          name: file.name.trim().isNotEmpty ? file.name : 'image.jpg',
          bytes: await File(path).readAsBytes(),
          path: path,
        ),
      );
    }
  }
  return picked;
}

Future<PickedImageFile?> pickImageFile() async {
  final files = await pickImageFiles();
  if (files.isEmpty) return null;
  return files.first;
}
