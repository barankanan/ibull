import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Ağ ve asset görselleri için önbellek + boyut optimizasyonu.
/// - URL: CachedNetworkImage (diskte önbellek) + cacheWidth/cacheHeight (bellek/decode azaltır).
/// - Asset: Image.asset + cacheWidth/cacheHeight.
/// Görsel depolama ve uygulama hızı için liste/kartlarda bu widget kullanılmalı.
class OptimizedImage extends StatelessWidget {
  const OptimizedImage({
    super.key,
    required this.imageUrlOrPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.cacheHeight,
    this.placeholder,
    this.errorWidget,
  });

  final String imageUrlOrPath;
  final double? width;
  final double? height;
  final BoxFit fit;

  /// Decode/cache için max genişlik (piksel). Liste kartları için 200–400 yeterli.
  final int? cacheWidth;

  /// Decode/cache için max yükseklik (piksel).
  final int? cacheHeight;
  final Widget? placeholder;
  final Widget? errorWidget;

  bool get _isNetwork => imageUrlOrPath.startsWith('http');

  @override
  Widget build(BuildContext context) {
    if (imageUrlOrPath.isEmpty) {
      return _error();
    }
    if (_isNetwork) {
      return CachedNetworkImage(
        imageUrl: imageUrlOrPath,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: cacheWidth,
        memCacheHeight: cacheHeight,
        maxWidthDiskCache: cacheWidth,
        maxHeightDiskCache: cacheHeight,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: placeholder != null
            ? (context, url) => placeholder!
            : null,
        errorWidget: errorWidget != null
            ? (context, url, error) => errorWidget!
            : (context, url, error) => _error(),
      );
    }
    return Image.asset(
      imageUrlOrPath,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      filterQuality: FilterQuality.low,
      errorBuilder: (context, error, stackTrace) => errorWidget ?? _error(),
    );
  }

  Widget _error() {
    return Container(
      color: Colors.grey[200],
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported,
        color: Colors.grey[400],
        size: (cacheHeight ?? 48) / 2,
      ),
    );
  }
}
