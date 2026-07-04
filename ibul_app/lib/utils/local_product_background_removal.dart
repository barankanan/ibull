import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class LocalBackgroundRemovalResult {
  const LocalBackgroundRemovalResult({
    required this.bytes,
    required this.removedPixelRatio,
  });

  final Uint8List bytes;
  final double removedPixelRatio;

  bool get hasMeaningfulRemoval => removedPixelRatio >= 0.005;
}

class _BackgroundRemovalArgs {
  const _BackgroundRemovalArgs({
    required this.imageBytes,
    required this.tolerance,
    required this.feather,
  });

  final Uint8List imageBytes;
  final double tolerance;
  final int feather;
}

LocalBackgroundRemovalResult _removeBackgroundIsolate(
  _BackgroundRemovalArgs args,
) {
  final decoded = img.decodeImage(args.imageBytes);
  if (decoded == null) {
    throw const FormatException('Görsel okunamadı');
  }

  final rgba = LocalProductBackgroundRemoval.ensureRgba(decoded);

  final bg = LocalProductBackgroundRemoval.estimateBackgroundColor(rgba);
  final threshold = 8 + (args.tolerance.clamp(0, 100) * 0.92);
  final featherWidth = math.max(2, args.feather + args.tolerance * 0.08);

  var removed = 0;
  final total = rgba.width * rgba.height;

  for (var y = 0; y < rgba.height; y++) {
    for (var x = 0; x < rgba.width; x++) {
      final pixel = rgba.getPixel(x, y);
      final dist = LocalProductBackgroundRemoval.colorDistance(pixel, bg);

      if (dist <= threshold) {
        rgba.setPixelRgba(
          x,
          y,
          pixel.r.toInt(),
          pixel.g.toInt(),
          pixel.b.toInt(),
          0,
        );
        removed++;
        continue;
      }

      if (dist <= threshold + featherWidth) {
        final t = (dist - threshold) / featherWidth;
        final alpha = (t * 255).round().clamp(0, 255);
        if (alpha < 20) removed++;
        rgba.setPixelRgba(
          x,
          y,
          pixel.r.toInt(),
          pixel.g.toInt(),
          pixel.b.toInt(),
          alpha,
        );
      }
    }
  }

  return LocalBackgroundRemovalResult(
    bytes: Uint8List.fromList(img.encodePng(rgba)),
    removedPixelRatio: total == 0 ? 0 : removed / total,
  );
}

/// Köşe/kenar rengi tahmini ile lokal arka plan temizleme (harici API yok).
class LocalProductBackgroundRemoval {
  LocalProductBackgroundRemoval._();

  static Future<LocalBackgroundRemovalResult> remove({
    required Uint8List imageBytes,
    required double tolerance,
    int feather = 2,
  }) {
    return compute(
      _removeBackgroundIsolate,
      _BackgroundRemovalArgs(
        imageBytes: imageBytes,
        tolerance: tolerance,
        feather: feather,
      ),
    );
  }

  @visibleForTesting
  static img.Image ensureRgba(img.Image source) => _ensureRgba(source);

  @visibleForTesting
  static img.ColorRgb8 estimateBackgroundColor(img.Image image) =>
      _estimateBackgroundColor(image);

  @visibleForTesting
  static double colorDistance(img.Pixel pixel, img.ColorRgb8 bg) =>
      _colorDistance(pixel, bg);

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

  static img.ColorRgb8 _estimateBackgroundColor(img.Image image) {
    final samples = <List<int>>[];
    final patch = math.min(8, math.min(image.width, image.height) ~/ 6);

    void samplePatch(int x, int y) {
      for (var dy = 0; dy < patch; dy++) {
        for (var dx = 0; dx < patch; dx++) {
          final px = image.getPixel(x + dx, y + dy);
          samples.add([px.r.toInt(), px.g.toInt(), px.b.toInt()]);
        }
      }
    }

    samplePatch(0, 0);
    samplePatch(image.width - patch, 0);
    samplePatch(0, image.height - patch);
    samplePatch(image.width - patch, image.height - patch);
    samplePatch(image.width ~/ 2 - patch ~/ 2, 0);
    samplePatch(image.width ~/ 2 - patch ~/ 2, image.height - patch);

    var r = 0;
    var g = 0;
    var b = 0;
    for (final sample in samples) {
      r += sample[0];
      g += sample[1];
      b += sample[2];
    }
    final count = samples.length;
    return img.ColorRgb8(
      (r / count).round(),
      (g / count).round(),
      (b / count).round(),
    );
  }

  static double _colorDistance(img.Pixel pixel, img.ColorRgb8 bg) {
    final dr = pixel.r - bg.r;
    final dg = pixel.g - bg.g;
    final db = pixel.b - bg.b;
    return math.sqrt(dr * dr + dg * dg + db * db);
  }
}
