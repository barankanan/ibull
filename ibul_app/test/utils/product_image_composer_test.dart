import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/utils/local_product_background_removal.dart';
import 'package:ibul_app/utils/product_image_composer.dart';
import 'package:image/image.dart' as img;

Uint8List _solidImage(
  int width,
  int height, {
  required img.ColorRgb8 fill,
  img.ColorRgb8? center,
}) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  img.fill(image, color: fill);
  if (center != null) {
    final cx = width ~/ 4;
    final cy = height ~/ 4;
    img.fillRect(
      image,
      x1: cx,
      y1: cy,
      x2: cx + width ~/ 2,
      y2: cy + height ~/ 2,
      color: center,
    );
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  group('ProductImageComposer', () {
    test('finalizeProductImage outputs 1200 square jpeg on white', () {
      final cropped = _solidImage(
        240,
        240,
        fill: img.ColorRgb8(255, 255, 255),
        center: img.ColorRgb8(20, 120, 200),
      );

      final output = ProductImageComposer.finalizeProductImage(
        croppedBytes: cropped,
        background: ProductImageBackgroundChoice.white,
      );

      final decoded = img.decodeImage(output);
      expect(decoded, isNotNull);
      expect(decoded!.width, ProductImageComposer.outputSize);
      expect(decoded.height, ProductImageComposer.outputSize);

      final corner = decoded.getPixel(0, 0);
      expect(corner.r, greaterThan(240));
      expect(corner.g, greaterThan(240));
      expect(corner.b, greaterThan(240));
    });

    test('finalizeProductImage can export transparent png', () {
      final cropped = _solidImage(
        120,
        120,
        fill: img.ColorRgb8(255, 0, 0,),
      );

      final output = ProductImageComposer.finalizeProductImage(
        croppedBytes: cropped,
        background: ProductImageBackgroundChoice.transparent,
        targetSize: 200,
      );

      expect(ProductImageComposer.bytesLookLikePng(output), isTrue);
    });
  });

  group('LocalProductBackgroundRemoval', () {
    test('removes solid white background around colored object', () async {
      final source = _solidImage(
        160,
        160,
        fill: img.ColorRgb8(255, 255, 255),
        center: img.ColorRgb8(220, 40, 40),
      );

      final result = await LocalProductBackgroundRemoval.remove(
        imageBytes: source,
        tolerance: 35,
      );

      expect(result.hasMeaningfulRemoval, isTrue);
      final decoded = img.decodeImage(result.bytes);
      expect(decoded, isNotNull);
      final corner = decoded!.getPixel(0, 0);
      expect(corner.a.toInt(), lessThan(20));
    });
  });
}
