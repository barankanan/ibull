import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/product_model.dart';
import '../optimized_image.dart';

class ProductQuickInfoSheet extends StatelessWidget {
  const ProductQuickInfoSheet({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final category = product.displayCategory;
    final rawShort = _cleanText(product.shortDescription);
    final rawDescription =
        _cleanText(product.description) ?? product.displayFullDescription;
    final introText = rawShort != null && rawShort != rawDescription
        ? rawShort
        : null;
    final descriptionText =
        rawDescription ??
        (introText == null ? product.displayFullDescription : null);
    final preparationTime = product.displayPreparationTime;
    final preparationLabel =
        product.displayPreparationTimeLabel ?? 'Hazırlanma';
    final features = product.displayFeatures;
    final ingredients = product.displayIngredients;
    final serviceInfo = product.displayServiceInfo;
    final additionalInfo = product.displayAdditionalInfoItems;
    final facts = <_InfoFact>[
      _InfoFact(
        label: product.usesWeightSelector ? 'Kg fiyatı' : 'Fiyat',
        value: product.displayPricingText,
      ),
      if (product.displayWeightInfo != null)
        _InfoFact(
          label: product.usesWeightSelector ? 'Başlangıç' : 'Ağırlık',
          value: product.displayWeightInfo!,
        ),
      if (preparationTime != null)
        _InfoFact(label: preparationLabel, value: preparationTime),
    ];

    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.48,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xFFF7F4FF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8CCF8),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                    children: [
                      _HeroImage(product: product),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.08),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (category != null) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.08,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            category,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                      ],
                                      Text(
                                        product.name,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF1F2937),
                                          height: 1.12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => Navigator.of(context).pop(),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Ink(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF4F0FF),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (introText != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF6F1FF),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Text(
                                  introText,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF4C1D95),
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                            if (facts.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _FactGrid(facts: facts),
                            ],
                          ],
                        ),
                      ),
                      if (descriptionText != null) ...[
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Açıklama',
                          child: Text(
                            descriptionText,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.55,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                      if (features.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Ürün Özellikleri',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: features
                                .map((value) => _TagChip(label: value))
                                .toList(),
                          ),
                        ),
                      ],
                      if (ingredients.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'İçerik / Malzeme',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ingredients
                                .map(
                                  (value) => _TagChip(
                                    label: value,
                                    background: const Color(0xFFFFF3E7),
                                    foreground: const Color(0xFFB45309),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                      if (serviceInfo.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Servis Bilgisi',
                          child: Column(
                            children: serviceInfo
                                .map((value) => _InfoLine(text: value))
                                .toList(),
                          ),
                        ),
                      ],
                      if (additionalInfo.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Ek Bilgiler',
                          child: Column(
                            children: additionalInfo
                                .map((value) => _InfoLine(text: value))
                                .toList(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String? _cleanText(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: AspectRatio(
        aspectRatio: 1.55,
        child: product.images.isNotEmpty
            ? OptimizedImage(
                imageUrlOrPath: product.images.first,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stackTrace) => const _HeroFallback(),
              )
            : const _HeroFallback(),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEDE7FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF344054),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _FactGrid extends StatelessWidget {
  const _FactGrid({required this.facts});

  final List<_InfoFact> facts;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumn = constraints.maxWidth > 360;
        final itemWidth = twoColumn
            ? (constraints.maxWidth - 10) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: facts
              .map(
                (fact) => SizedBox(
                  width: itemWidth,
                  child: _FactCard(fact: fact),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _FactCard extends StatelessWidget {
  const _FactCard({required this.fact});

  final _InfoFact fact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF9F6FF), Color(0xFFF3EEFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4D8FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fact.label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            fact.value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    this.background = const Color(0xFFF3EEFF),
    this.foreground = AppColors.primary,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF8C52F7), Color(0xFF5B1FBF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.restaurant_menu_rounded,
              size: 48,
              color: Colors.white,
            ),
            const SizedBox(height: 10),
            Text(
              'Gorsel yakinda',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoFact {
  const _InfoFact({required this.label, required this.value});

  final String label;
  final String value;
}
