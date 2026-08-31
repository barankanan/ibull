import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../utils/xfile_memory_image_provider.dart';
import 'optimized_image.dart';

/// Catalog thumbnail — kare alan, contain, hafif padding; ürün kesilmez.
class ProductListThumbnail extends StatelessWidget {
  const ProductListThumbnail({
    super.key,
    this.imageUrlOrPath,
    this.imageFile,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.backgroundColor = const Color(0xFFF8FAFC),
    this.padding = const EdgeInsets.all(8),
    this.fallbackIconSize = 32,
    this.cacheWidth,
    this.cacheHeight,
    this.priority = OptimizedImagePriority.lazy,
    this.onFirstFrameReady,
  });

  final String? imageUrlOrPath;
  final XFile? imageFile;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final Color backgroundColor;
  final EdgeInsetsGeometry padding;
  final double fallbackIconSize;
  final int? cacheWidth;
  final int? cacheHeight;
  final OptimizedImagePriority priority;
  final VoidCallback? onFirstFrameReady;

  @override
  Widget build(BuildContext context) {
    final child = _buildImageChild();

    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        width: width,
        height: height,
        color: backgroundColor,
        alignment: Alignment.center,
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }

  Widget _buildImageChild() {
    if (imageFile != null) {
      return Image(
        image: xFileImageProvider(imageFile!),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
        gaplessPlayback: false,
        errorBuilder: (_, _, _) => _fallbackIcon(),
      );
    }

    final url = imageUrlOrPath?.trim() ?? '';
    if (url.isEmpty) {
      return _fallbackIcon();
    }

    if (url.startsWith('http')) {
      return OptimizedImage(
        imageUrlOrPath: url,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        priority: priority,
        onFirstFrameReady: onFirstFrameReady,
        errorWidget: _fallbackIcon(),
      );
    }

    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _fallbackIcon(),
      );
    }

    return Image(
      image: xFileImageProvider(XFile(url)),
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => _fallbackIcon(),
    );
  }

  Widget _fallbackIcon() {
    return Icon(
      Icons.image_not_supported_outlined,
      color: Colors.grey[400],
      size: fallbackIconSize,
    );
  }
}
