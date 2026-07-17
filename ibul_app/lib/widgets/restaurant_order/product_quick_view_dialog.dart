import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/favorite_state.dart';
import '../../core/constants.dart';
import '../../models/product_model.dart';
import '../../models/product_pricing.dart';
import '../optimized_image.dart';

/// Ürün hızlı bakış sheet'i (göz ikonu).
///
/// Kart üzerindeki mevcut veriyle ANINDA render edilir; [enrich] verilirse
/// tam ürün verisi arka planda çekilir ve geldiğinde içerik tazelenir
/// ([enrichTimeout] aşılırsa eldeki veriyle devam edilir, popup beklemez).
class ProductQuickInfoSheet extends StatefulWidget {
  const ProductQuickInfoSheet({
    super.key,
    required this.product,
    this.onAddToCart,
    this.onViewDetails,
    this.enrich,
    this.enrichTimeout = const Duration(milliseconds: 1000),
  });

  final Product product;

  /// Alt sabit aksiyon alanı yalnız bu callback'lerden en az biri verilince
  /// gösterilir; mevcut çağrı yerleri (restoran menüsü vb.) etkilenmez.
  final VoidCallback? onAddToCart;
  final VoidCallback? onViewDetails;

  /// Tam ürün verisini getirir (ör. Supabase'ten). null dönerse mevcut
  /// veriyle devam edilir.
  final Future<Product?> Function()? enrich;
  final Duration enrichTimeout;

  @override
  State<ProductQuickInfoSheet> createState() => _ProductQuickInfoSheetState();
}

class _ProductQuickInfoSheetState extends State<ProductQuickInfoSheet> {
  late Product _product;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    final enrich = widget.enrich;
    if (enrich != null) {
      // Not: enrich Future<Product> (non-nullable) dönebilir; timeout'un
      // null üretebilmesi için burada gerçek bir Future<Product?> sarmalanır.
      Future<Product?> run() async => await enrich();
      unawaited(
        run().timeout(widget.enrichTimeout, onTimeout: () => null).then(
          (enriched) {
            if (enriched != null && mounted) {
              setState(() => _product = enriched);
            }
          },
          onError: (_) {},
        ),
      );
    }
  }

  String? _cleanText(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Eski fiyat > güncel fiyat ise (eskiFiyat, indirim %) döner; yoksa null.
  (double, int)? _resolveDiscount() {
    final old = ProductPriceCalculator.parsePriceValue(_product.oldPrice);
    final current = ProductPriceCalculator.parsePriceValue(_product.price);
    if (old <= 0 || current <= 0 || old <= current) return null;
    final percent = (((old - current) / old) * 100).round();
    return percent > 0 ? (old, percent) : null;
  }

  void _popThen(VoidCallback? action) {
    Navigator.of(context).pop();
    action?.call();
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;
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
    final storeName = _cleanText(product.store);
    final brandName = _cleanText(product.brand);
    final discount = _resolveDiscount();
    final stock = product.stock;
    final facts = <_InfoFact>[
      if (product.displayWeightInfo != null)
        _InfoFact(
          label: product.usesWeightSelector ? 'Başlangıç' : 'Ağırlık',
          value: product.displayWeightInfo!,
        ),
      if (preparationTime != null)
        _InfoFact(label: preparationLabel, value: preparationTime),
      if (stock != null)
        _InfoFact(
          label: 'Stok',
          value: stock > 0 ? 'Stokta var' : 'Stokta yok',
        ),
      if (product.isDigital)
        const _InfoFact(label: 'Teslimat', value: 'Dijital ürün'),
    ];
    final hasActions =
        widget.onAddToCart != null || widget.onViewDetails != null;

    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.48,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: DecoratedBox(
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
                          _HeroImage(
                            product: product,
                            categoryBadge: category,
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color:
                                    AppColors.primary.withValues(alpha: 0.08),
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
                                      child: Text(
                                        product.name,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF1F2937),
                                          height: 1.12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () =>
                                            Navigator.of(context).pop(),
                                        borderRadius:
                                            BorderRadius.circular(16),
                                        child: Ink(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF4F0FF),
                                            borderRadius:
                                                BorderRadius.circular(16),
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
                                if (brandName != null ||
                                    storeName != null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.storefront_outlined,
                                        size: 15,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          [
                                            ?brandName,
                                            if (storeName != null &&
                                                storeName != brandName)
                                              storeName,
                                          ].join(' · '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (product.rating > 0) ...[
                                  const SizedBox(height: 10),
                                  _RatingRow(
                                    rating: product.rating,
                                    reviewCount: product.reviewCount,
                                  ),
                                ],
                                const SizedBox(height: 14),
                                _PriceCard(
                                  product: product,
                                  discount: discount,
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
                          const SizedBox(height: 16),
                          _SectionCard(
                            title: 'Açıklama',
                            child: Text(
                              descriptionText ??
                                  'Bu ürün için açıklama eklenmemiş.',
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.55,
                                color: descriptionText == null
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade700,
                                fontStyle: descriptionText == null
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                            ),
                          ),
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
                    if (hasActions)
                      _ActionBar(
                        onAddToCart: widget.onAddToCart == null
                            ? null
                            : () => _popThen(widget.onAddToCart),
                        onViewDetails: widget.onViewDetails == null
                            ? null
                            : () => _popThen(widget.onViewDetails),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({this.onAddToCart, this.onViewDetails});

  final VoidCallback? onAddToCart;
  final VoidCallback? onViewDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          if (onViewDetails != null)
            Expanded(
              child: OutlinedButton(
                onPressed: onViewDetails,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.45),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Detayları Gör',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          if (onViewDetails != null && onAddToCart != null)
            const SizedBox(width: 10),
          if (onAddToCart != null)
            Expanded(
              child: FilledButton(
                onPressed: onAddToCart,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Sepete Ekle',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.rating, required this.reviewCount});

  final double rating;
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ...List.generate(5, (index) {
          final threshold = index + 1;
          return Icon(
            rating >= threshold
                ? Icons.star_rounded
                : rating >= threshold - 0.5
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded,
            size: 18,
            color: const Color(0xFFF59E0B),
          );
        }),
        const SizedBox(width: 6),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
          ),
        ),
        if (reviewCount > 0) ...[
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '($reviewCount değerlendirme)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
          ),
        ],
      ],
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.product, required this.discount});

  final Product product;
  final (double, int)? discount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.usesWeightSelector ? 'Kg fiyatı' : 'Fiyat',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        product.displayPricingText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    if (discount != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '₺${discount!.$1.toStringAsFixed(2)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (discount != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '%${discount!.$2} indirim',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF15803D),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.product, this.categoryBadge});

  final Product product;
  final String? categoryBadge;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: AspectRatio(
        aspectRatio: 1.55,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (product.images.isNotEmpty)
              OptimizedImage(
                imageUrlOrPath: product.images.first,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stackTrace) => const _HeroFallback(),
              )
            else
              const _HeroFallback(),
            if (categoryBadge != null)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    categoryBadge!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 12,
              right: 12,
              child: _FavoriteButton(product: product),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    // Provider ağacı olmayan bağlamlarda (ör. test) butonu sessizce gizle.
    FavoriteState? favoriteState;
    AppState? appState;
    try {
      favoriteState = context.watch<FavoriteState>();
      appState = context.read<AppState>();
    } catch (_) {
      return const SizedBox.shrink();
    }
    final isFavorite = favoriteState.isFavorite(product);
    final resolvedAppState = appState;
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => resolvedAppState.toggleFavorite(product),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            size: 20,
            color: isFavorite ? Colors.red : AppColors.primary,
          ),
        ),
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
              Icons.image_outlined,
              size: 48,
              color: Colors.white,
            ),
            const SizedBox(height: 10),
            Text(
              'Görsel yakında',
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
