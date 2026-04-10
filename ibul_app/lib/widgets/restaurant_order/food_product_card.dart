import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/product_model.dart';
import '../optimized_image.dart';
import 'product_quantity_stepper.dart';

class FoodProductCard extends StatelessWidget {
  const FoodProductCard({
    super.key,
    required this.product,
    required this.quantity,
    required this.onImageTap,
    required this.onAdd,
    this.onIncrement,
    this.onDecrement,
    this.onCustomize,
    this.selectedAttributes = const [],
    this.selectionMeta,
    this.stepperValueLabel,
    this.addLabel = 'Ekle',
  });

  final Product product;
  final int quantity;
  final VoidCallback onImageTap;
  final VoidCallback onAdd;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final VoidCallback? onCustomize;
  final List<String> selectedAttributes;
  final String? selectionMeta;
  final String? stepperValueLabel;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    const selectedSurface = Color(0xFFF0F9F3);
    const selectedBorder = Color(0xFFA7E3BE);
    final category = product.displayCategory;
    final preparationTime = product.displayPreparationTime;
    final preparationLabel =
        product.displayPreparationTimeLabel ?? 'Hazırlanma';
    final description = product.displayShortDescription;
    final hasSelectionInfo =
        (selectionMeta?.trim().isNotEmpty ?? false) ||
        selectedAttributes.isNotEmpty;
    final weightInfo =
        product.displayServiceControlInfo ?? product.displayWeightInfo;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: quantity > 0 ? selectedSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: quantity > 0 ? selectedBorder : const Color(0xFFF0F1F5),
          width: quantity > 0 ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: quantity > 0
                ? const Color(0xFF16A34A).withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: quantity > 0 ? 14 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProductImage(product: product, onTap: onImageTap),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                    height: 1.2,
                  ),
                ),
                if (category != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    category,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                if (description != null) ...[
                  const SizedBox(height: 7),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.25,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  product.displayPricingText,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: quantity > 0
                        ? const Color(0xFF15803D)
                        : AppColors.primary,
                  ),
                ),
                if (preparationTime != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 12.5,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '$preparationLabel: $preparationTime',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.25,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (weightInfo != null && !hasSelectionInfo) ...[
                  const SizedBox(height: 4),
                  Text(
                    weightInfo,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                if (hasSelectionInfo) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if ((selectionMeta?.trim().isNotEmpty ?? false))
                        _InfoChip(
                          label: selectionMeta!.trim(),
                          background: AppColors.primary.withValues(alpha: 0.1),
                          foreground: AppColors.primary,
                        ),
                      ...selectedAttributes.map(
                        (value) => _InfoChip(
                          label: value,
                          background: const Color(0xFFFFF4E8),
                          foreground: const Color(0xFFDD6B20),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ProductQuantityStepper(
                quantity: quantity,
                onAdd: onAdd,
                onIncrement: onIncrement ?? () {},
                onDecrement: onDecrement ?? () {},
                compact: true,
                addLabel: addLabel,
                valueLabel: stepperValueLabel,
              ),
              const SizedBox(height: 8),
              if (onCustomize != null)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onCustomize,
                    borderRadius: BorderRadius.circular(12),
                    child: Ink(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        size: 18,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: const Color(0xFFF7F7FB),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: product.images.isNotEmpty
                ? OptimizedImage(
                    imageUrlOrPath: product.images.first,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stackTrace) =>
                        const _ImageFallback(),
                  )
                : const _ImageFallback(),
          ),
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7F7FB),
      alignment: Alignment.center,
      child: Icon(
        Icons.restaurant_menu_rounded,
        color: Colors.grey.shade400,
        size: 28,
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}
