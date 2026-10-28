import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/product_pricing.dart';

/// Shared discount rule: a product is on sale only when the previous price
/// is higher than a positive current price.
class ProductDiscountView {
  const ProductDiscountView({
    required this.hasDiscount,
    required this.currentLabel,
    this.oldLabel,
  });

  final bool hasDiscount;
  final String currentLabel;
  final String? oldLabel;

  static ProductDiscountView resolve({
    required String price,
    String? oldPrice,
    String? currentLabel,
  }) {
    final current = ProductPriceCalculator.parsePriceValue(price);
    final previous = ProductPriceCalculator.parsePriceValue(oldPrice ?? '');
    final hasDiscount = previous > current && current > 0;
    return ProductDiscountView(
      hasDiscount: hasDiscount,
      currentLabel: _label(currentLabel ?? price, current),
      oldLabel: hasDiscount ? _label(oldPrice ?? '', previous) : null,
    );
  }

  static String _label(String raw, double parsed) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || parsed <= 0) {
      return ProductPriceCalculator.formatCatalogAmount(parsed);
    }
    final upper = trimmed.toUpperCase();
    if (upper.contains('TL') || trimmed.contains('₺')) return trimmed;
    return '$trimmed TL';
  }
}

class ProductDiscountPrice extends StatelessWidget {
  const ProductDiscountPrice({
    super.key,
    required this.price,
    this.oldPrice,
    this.currentLabel,
    this.currentFontSize = 14,
    this.oldFontSize = 12,
    this.currentColor = const Color(0xFF1A1A1A),
    this.compact = false,
  });

  final String price;
  final String? oldPrice;
  final String? currentLabel;
  final double currentFontSize;
  final double oldFontSize;
  final Color currentColor;
  final bool compact;

  /// Height of the price column for the given text scale.
  /// Discounted products keep the struck price on its own line.
  static double blockHeight({
    required bool hasDiscount,
    required TextScaler textScaler,
    double currentFontSize = 14,
    double oldFontSize = 12,
    bool compact = false,
  }) {
    final current = _lineHeight(
      TextStyle(
        fontSize: currentFontSize,
        fontWeight: FontWeight.w800,
        height: 1.15,
      ),
      textScaler,
    );
    final badgeText = _lineHeight(
      TextStyle(
        fontSize: compact ? 10 : 11,
        fontWeight: FontWeight.w700,
        height: 1.1,
      ),
      textScaler,
    );
    final badge = badgeText + (compact ? 4 : 6);
    final priceRow = math.max(current, math.max(badge, compact ? 10.0 : 11.0));
    if (!hasDiscount) return priceRow;
    final previous = _lineHeight(
      TextStyle(
        fontSize: oldFontSize,
        fontWeight: FontWeight.w600,
        height: 1.1,
      ),
      textScaler,
    );
    return previous + priceRow;
  }

  static double _lineHeight(TextStyle style, TextScaler textScaler) {
    final painter = TextPainter(
      text: TextSpan(text: 'Ag', style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    return painter.height;
  }

  @override
  Widget build(BuildContext context) {
    final view = ProductDiscountView.resolve(
      price: price,
      oldPrice: oldPrice,
      currentLabel: currentLabel,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (view.oldLabel != null)
          Text(
            view.oldLabel!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: oldFontSize,
              color: const Color(0xFFE53935),
              decoration: TextDecoration.lineThrough,
              decorationColor: const Color(0xFFE53935),
              decorationThickness: compact ? 1.2 : 1.4,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        Row(
          children: [
            Flexible(
              child: Text(
                view.currentLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: currentFontSize,
                  fontWeight: FontWeight.w800,
                  color: currentColor,
                  height: 1.15,
                ),
              ),
            ),
            if (view.hasDiscount) ...[
              SizedBox(width: compact ? 4 : 6),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 5 : 6,
                  vertical: compact ? 2 : 3,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_downward,
                      size: compact ? 10 : 11,
                      color: const Color(0xFF2E7D32),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'İndirim',
                      style: TextStyle(
                        fontSize: compact ? 10 : 11,
                        color: const Color(0xFF2E7D32),
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
