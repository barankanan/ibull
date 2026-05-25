import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

/// [XFile] önizlemesi: path, blob URL veya `fromData` baytları ile çalışır.
class XFileImageProvider extends ImageProvider<XFileImageProvider> {
  const XFileImageProvider(this.file);

  final XFile file;

  @override
  Future<XFileImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<XFileImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    XFileImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      debugLabel: 'xfile://${key.file.name}',
    );
  }

  Future<ui.Codec> _loadAsync(
    XFileImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    final bytes = await key.file.readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('Görsel dosyası boş.');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is XFileImageProvider &&
        other.file.name == file.name &&
        other.file.path == file.path;
  }

  @override
  int get hashCode => Object.hash(file.name, file.path);
}

ImageProvider<Object> xFileImageProvider(XFile file) => XFileImageProvider(file);
