import 'package:flutter/painting.dart';

/// Caps decoded-image RAM so catalog scrolling does not blow the heap.
/// Quality of on-screen images is unchanged (decode size still comes from
/// [OptimizedImage] cacheWidth/Height).
abstract final class CommerceImageCache {
  static const int maxLiveImages = 160;
  static const int maxBytes = 64 * 1024 * 1024;

  static void configure() {
    final cache = PaintingBinding.instance.imageCache;
    cache.maximumSize = maxLiveImages;
    cache.maximumSizeBytes = maxBytes;
  }
}
