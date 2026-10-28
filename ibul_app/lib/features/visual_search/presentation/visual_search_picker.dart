import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PickedVisualImage {
  const PickedVisualImage({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

Future<PickedVisualImage?> pickVisualSearchImage(
  BuildContext context,
  ImageSource source,
) async {
  try {
    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final name = file.name.trim().isEmpty ? 'gorsel.jpg' : file.name.trim();
    return PickedVisualImage(bytes: bytes, fileName: name);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Fotoğraf açılamadı. Kamera iznini veya dosya türünü kontrol edin.',
          ),
        ),
      );
    }
    return null;
  }
}
