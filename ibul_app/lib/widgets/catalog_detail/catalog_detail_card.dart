import 'package:flutter/material.dart';

/// Shared product-detail card chrome (center column + section surfaces).
class CatalogDetailCard extends StatelessWidget {
  const CatalogDetailCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.width,
  });

  final Widget child;
  final EdgeInsets padding;
  final double? width;

  static BoxDecoration decorationOf() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: padding,
      decoration: decorationOf(),
      child: child,
    );
  }
}
