import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

enum ProductImageBackgroundChoice {
  white,
  lightGray,
  black,
  transparent,
  custom,
}

class _EditorImagePrepArgs {
  const _EditorImagePrepArgs(this.bytes, this.maxEdge);

  final Uint8List bytes;
  final int maxEdge;
}

Uint8List _prepareEditorImageBytesIsolate(_EditorImagePrepArgs args) {
  final decoded = img.decodeImage(args.bytes);
  if (decoded == null) {
    return args.bytes;
  }

  final int maxDim = math.max(decoded.width, decoded.height);
  if (maxDim <= args.maxEdge) {
    if (bytesLookLikeJpeg(args.bytes)) {
      return args.bytes;
    }
    return Uint8List.fromList(img.encodeJpg(decoded, quality: 90));
  }

  final double scale = args.maxEdge / maxDim;
  final resized = img.copyResize(
    decoded,
    width: (decoded.width * scale).round(),
    height: (decoded.height * scale).round(),
    interpolation: img.Interpolation.linear,
  );
  return Uint8List.fromList(img.encodeJpg(resized, quality: 90));
}

bool bytesLookLikeJpeg(Uint8List bytes) {
  return bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF;
}

class ProductImageComposer {
  ProductImageComposer._();

  static const int outputSize = 1200;
  static const int editorMaxEdge = 1600;
  static const int previewSnapshotSize = 320;

  static ({int width, int height})? decodeDimensions(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    return (width: decoded.width, height: decoded.height);
  }

  /// Crop editörü için UI thread dışında downsample edilmiş görsel üretir.
  static Future<Uint8List> prepareEditorImageBytes(
    Uint8List bytes, {
    int maxEdge = editorMaxEdge,
  }) {
    return compute(
      _prepareEditorImageBytesIsolate,
      _EditorImagePrepArgs(bytes, maxEdge),
    );
  }

  /// cropperx çıktısını ürün görsel standardına getirir.
  static Uint8List finalizeProductImage({
    required Uint8List croppedBytes,
    ProductImageBackgroundChoice background = ProductImageBackgroundChoice.white,
    Color? customColor,
    int targetSize = outputSize,
  }) {
    final decoded = img.decodeImage(croppedBytes);
    if (decoded == null) {
      throw const FormatException('Görsel okunamadı');
    }

    final resized = img.copyResize(
      decoded,
      width: targetSize,
      height: targetSize,
      interpolation: img.Interpolation.linear,
    );

    if (background == ProductImageBackgroundChoice.transparent) {
      return Uint8List.fromList(img.encodePng(_ensureRgba(resized)));
    }

    final bg = _resolveBackground(background, customColor);
    final canvas = img.Image(width: targetSize, height: targetSize, numChannels: 3);
    img.fill(canvas, color: bg);

    img.compositeImage(canvas, _ensureRgba(resized));

    return Uint8List.fromList(img.encodeJpg(canvas, quality: 92));
  }

  static img.ColorRgb8 _resolveBackground(
    ProductImageBackgroundChoice choice,
    Color? customColor,
  ) {
    switch (choice) {
      case ProductImageBackgroundChoice.white:
        return img.ColorRgb8(255, 255, 255);
      case ProductImageBackgroundChoice.lightGray:
        return img.ColorRgb8(245, 245, 245);
      case ProductImageBackgroundChoice.black:
        return img.ColorRgb8(0, 0, 0);
      case ProductImageBackgroundChoice.custom:
        final color = customColor ?? const Color(0xFFFFFFFF);
        final argb = color.toARGB32();
        return img.ColorRgb8(
          (argb >> 16) & 0xFF,
          (argb >> 8) & 0xFF,
          argb & 0xFF,
        );
      case ProductImageBackgroundChoice.transparent:
        return img.ColorRgb8(255, 255, 255);
    }
  }

  static img.Image _ensureRgba(img.Image source) {
    if (source.numChannels == 4) {
      return source.clone();
    }
    final out = img.Image(
      width: source.width,
      height: source.height,
      numChannels: 4,
    );
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        final pixel = source.getPixel(x, y);
        out.setPixelRgba(
          x,
          y,
          pixel.r.toInt(),
          pixel.g.toInt(),
          pixel.b.toInt(),
          255,
        );
      }
    }
    return out;
  }

  static bool bytesLookLikePng(Uint8List bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
  }
}
