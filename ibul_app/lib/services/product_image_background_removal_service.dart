import 'dart:typed_data';

import 'package:ibul_app/utils/local_product_background_removal.dart';

class ProductImageBackgroundRemovalException implements Exception {
  ProductImageBackgroundRemovalException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProductImageBackgroundRemovalFailed
    extends ProductImageBackgroundRemovalException {
  ProductImageBackgroundRemovalFailed([String? message])
    : super(
        message ??
            'Arka plan otomatik temizlenemedi. Toleransı artırıp tekrar deneyin.',
      );
}

/// Lokal piksel işleme ile arka plan temizleme (varsayılan).
class ProductImageBackgroundRemovalService {
  Future<Uint8List> removeBackground(
    Uint8List imageBytes, {
    double tolerance = 50,
  }) async {
    if (imageBytes.isEmpty) {
      throw ProductImageBackgroundRemovalFailed();
    }

    final result = await LocalProductBackgroundRemoval.remove(
      imageBytes: imageBytes,
      tolerance: tolerance,
    );

    if (!result.hasMeaningfulRemoval) {
      throw ProductImageBackgroundRemovalFailed();
    }

    return result.bytes;
  }
}
