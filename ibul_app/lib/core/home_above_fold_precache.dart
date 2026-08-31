import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../widgets/optimized_image.dart';

/// Above-the-fold home images: banner first (LCP), then products in parallel.
abstract final class HomeAboveFoldPrecache {
  static ImageProvider<Object>? providerFor({
    required String imagePath,
    required int cacheWidth,
    required int cacheHeight,
  }) {
    final normalized = imagePath.trim();
    if (normalized.isEmpty) return null;
    return OptimizedImage.buildProvider(
      imageUrlOrPath: normalized,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
  }

  static Future<int> precacheProviders({
    required BuildContext context,
    required List<ImageProvider<Object>> providers,
  }) async {
    var failed = 0;
    await Future.wait(
      providers.map((provider) async {
        if (!context.mounted) return;
        try {
          await precacheImage(provider, context);
        } catch (error) {
          failed++;
          debugPrint('Ana sayfa görsel preload başarısız: $error');
        }
      }),
    );
    return failed;
  }
}
