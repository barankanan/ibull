import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/product_model.dart';
import '../../widgets/optimized_image.dart';
import '../../widgets/premium_interactions.dart';
import '../../widgets/product_discount_price.dart';

/// Mobile browse-card geometry shared by Beğendiklerim and Öneriler.
///
/// The image is shorter than a square so a two-line name and a two-line
/// discount block fit without stretching the grid cell past the content.
class FavoriteBrowseCardLayout {
  FavoriteBrowseCardLayout._();

  /// width / height. 1.25 makes the image 80% of a square.
  static const imageAspectRatio = 1.25;

  static const contentPadding = EdgeInsets.fromLTRB(8, 6, 8, 8);
  static const chipGap = 2.0;
  static const titleGap = 1.0;
  static const ratingGap = 4.0;

  static const chipStyle = TextStyle(
    color: Colors.white,
    fontSize: 8,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  static const titleStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: Colors.black87,
    height: 1.25,
  );

  static const ratingStyle = TextStyle(
    fontSize: 9,
    color: Colors.grey,
    height: 1.2,
  );

  static const currentFontSize = 13.0;
  static const oldFontSize = 11.0;

  static double _textHeight(
    TextStyle style,
    TextScaler textScaler, {
    int maxLines = 1,
    String text = 'Ag',
    double maxWidth = double.infinity,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: maxLines,
    )..layout(maxWidth: maxWidth);
    return painter.height;
  }

  static double chipHeight(TextScaler textScaler) =>
      _textHeight(chipStyle, textScaler) + 4;

  static double titleHeight(TextScaler textScaler) => _textHeight(
        titleStyle,
        textScaler,
        maxLines: 2,
        text: 'Ag\nAg',
      );

  static double ratingHeight(TextScaler textScaler) =>
      math.max(textScaler.scale(10), _textHeight(ratingStyle, textScaler)).toDouble();

  static double priceSlotHeight(TextScaler textScaler) =>
      ProductDiscountPrice.blockHeight(
        hasDiscount: true,
        textScaler: textScaler,
        currentFontSize: currentFontSize,
        oldFontSize: oldFontSize,
        compact: true,
      );

  /// Info column under the image, including padding.
  /// Always reserves the discounted price block so a row stays even.
  static double infoBlockHeight(TextScaler textScaler) {
    return contentPadding.vertical +
        chipHeight(textScaler) +
        chipGap +
        titleHeight(textScaler) +
        titleGap +
        ratingHeight(textScaler) +
        ratingGap +
        priceSlotHeight(textScaler);
  }

  static double imageHeightFor(double tileWidth) =>
      tileWidth / imageAspectRatio;

  static double extent({
    required double tileWidth,
    required TextScaler textScaler,
  }) {
    final raw = imageHeightFor(tileWidth) + infoBlockHeight(textScaler);
    return raw.ceilToDouble();
  }
}

class FavoriteBrowseProductCard extends StatelessWidget {
  const FavoriteBrowseProductCard({
    super.key,
    required this.product,
    required this.isFavorite,
    required this.onTap,
    required this.onQuickView,
    required this.onToggleFavorite,
  });

  final Product product;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onQuickView;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageHeight = FavoriteBrowseCardLayout.imageHeightFor(
          constraints.maxWidth,
        );
        final bounded = constraints.maxHeight.isFinite;
        return GestureDetector(
          onTap: onTap,
          onLongPress: onQuickView,
          child: PremiumPressable(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  _image(imageHeight),
                  if (bounded)
                    Expanded(child: _info(textScaler, fill: true))
                  else
                    _info(textScaler, fill: false),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _image(double height) {
    final image = product.images.isNotEmpty ? product.images.first : null;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: ColoredBox(
              color: const Color(0xFFF5F5F5),
              child: SizedBox.expand(
                child: image != null && image.isNotEmpty
                    ? (image.startsWith('http')
                        ? OptimizedImage(
                            imageUrlOrPath: image,
                            fit: BoxFit.contain,
                            cacheWidth: 200,
                            cacheHeight: 200,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.image_not_supported,
                              color: Colors.grey,
                              size: 30,
                            ),
                          )
                        : Image.asset(
                            image,
                            fit: BoxFit.contain,
                            cacheWidth: 200,
                            cacheHeight: 200,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.image_not_supported,
                              color: Colors.grey,
                              size: 30,
                            ),
                          ))
                    : const Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                        size: 30,
                      ),
              ),
            ),
          ),
          Positioned(
            top: 6,
            left: 6,
            child: _roundAction(
              icon: Icons.remove_red_eye_outlined,
              color: AppColors.primary,
              onTap: onQuickView,
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: _roundAction(
              icon: isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? Colors.red : Colors.grey.shade400,
              onTap: onToggleFavorite,
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundAction({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  Widget _info(TextScaler textScaler, {required bool fill}) {
    final label = (product.category ?? '').trim();
    final chip = label.isEmpty
        ? (product.tags.isNotEmpty ? product.tags.first : 'Önerilen')
        : label;
    final ratingValue = product.rating;
    final filledStars = ratingValue.isFinite
        ? ratingValue.clamp(0, 4).floor()
        : 0;
    return Padding(
      padding: FavoriteBrowseCardLayout.contentPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              chip,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FavoriteBrowseCardLayout.chipStyle,
            ),
          ),
          const SizedBox(height: FavoriteBrowseCardLayout.chipGap),
          SizedBox(
            height: FavoriteBrowseCardLayout.titleHeight(textScaler),
            child: Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: FavoriteBrowseCardLayout.titleStyle,
            ),
          ),
          const SizedBox(height: FavoriteBrowseCardLayout.titleGap),
          SizedBox(
            height: FavoriteBrowseCardLayout.ratingHeight(textScaler),
            child: Row(
              children: [
                for (var index = 0; index < 4; index++)
                  Icon(
                    index < filledStars ? Icons.star : Icons.star_border,
                    color: Colors.orange,
                    size: 10,
                  ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    '(${product.reviewCount})',
                    overflow: TextOverflow.ellipsis,
                    style: FavoriteBrowseCardLayout.ratingStyle,
                  ),
                ),
              ],
            ),
          ),
          if (fill) const Spacer(),
          ProductDiscountPrice(
            price: product.price,
            oldPrice: product.oldPrice,
            currentFontSize: FavoriteBrowseCardLayout.currentFontSize,
            oldFontSize: FavoriteBrowseCardLayout.oldFontSize,
            compact: true,
          ),
        ],
      ),
    );
  }
}
