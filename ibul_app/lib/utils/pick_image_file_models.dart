import 'dart:typed_data';

/// Platformdan bağımsız seçilmiş görsel dosyası.
class PickedImageFile {
  const PickedImageFile({
    required this.name,
    required this.bytes,
    this.path,
  });

  final String name;
  final Uint8List bytes;
  final String? path;
}
