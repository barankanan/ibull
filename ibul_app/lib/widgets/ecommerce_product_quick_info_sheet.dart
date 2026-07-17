import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/constants.dart';
import '../core/favorite_state.dart';
import '../models/product_model.dart';
import '../models/product_pricing.dart';
import '../models/product_quick_view_content.dart';

/// E-ticaret ürün hızlı bakış sheet'i (ana sayfa / ürün kartı göz ikonu).
///
/// Görselsiz, bilgi yoğun tasarım: başlık + fiyat özeti + hızlı bilgi grid'i
/// + öne çıkan özellikler + açıklama + sabit alt aksiyon barı. Ürün görseli
/// bilinçli olarak GÖSTERİLMEZ (kartta zaten var). Restoran/garson akışları
/// eski `ProductQuickInfoSheet`'i kullanmaya devam eder.
///
/// Kart verisiyle anında render edilir; [enrich] verilirse tam ürün
/// [enrichTimeout] içinde arka planda çekilip içerik tazelenir.
class EcommerceProductQuickInfoSheet extends StatefulWidget {
  const EcommerceProductQuickInfoSheet({
    super.key,
    required this.product,
    this.onAddToCart,
    this.onViewDetails,
    this.enrich,
    this.enrichTimeout = const Duration(milliseconds: 1000),
  });

  final Product product;
  final VoidCallback? onAddToCart;
  final VoidCallback? onViewDetails;
  final Future<Product?> Function()? enrich;
  final Duration enrichTimeout;

  /// İlk açılışta gösterilen maksimum özellik sayısı.
  static const int maxVisibleSpecs = 8;

  @override
  State<EcommerceProductQuickInfoSheet> createState() =>
      _EcommerceProductQuickInfoSheetState();
}

class _EcommerceProductQuickInfoSheetState
    extends State<EcommerceProductQuickInfoSheet> {
  late Product _product;
  bool _specsExpanded = false;
  bool _descriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    final enrich = widget.enrich;
    if (enrich != null) {
      Future<Product?> run() async => await enrich();
      unawaited(
        run().timeout(widget.enrichTimeout, onTimeout: () => null).then(
          (enriched) {
            if (enriched != null && mounted) {
              setState(() => _product = _mergeEnriched(_product, enriched));
            }
          },
          onError: (_) {},
        ),
      );
    }
  }

  String? _clean(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Tam ürün satırı bazı alanları taşımaz (ör. products tablosunda
  /// rating yok); karttan gelen dolu değerler korunur.
  Product _mergeEnriched(Product base, Product enriched) {
    return enriched.copyWith(
      rating: enriched.rating > 0 ? enriched.rating : base.rating,
      reviewCount:
          enriched.reviewCount > 0 ? enriched.reviewCount : base.reviewCount,
      store: _clean(enriched.store) ?? base.store,
      oldPrice: _clean(enriched.oldPrice) ?? base.oldPrice,
    );
  }

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

  /// Grid'de gösterilen etiketler özellik listesinden düşülür (tekrar olmasın).
  static const Set<String> _gridSpecLabels = <String>{
    'marka',
    'kategori',
    'mağaza',
    'magaza',
    'garanti',
    'kargo',
    'stok',
  };

  @override
  Widget build(BuildContext context) {
    final product = _product;
    final category = product.displayCategory;
    final brandName = _clean(product.brand);
    final storeName = _clean(product.store);
    final discount = _resolveDiscount();
    final stock = product.stock;
    final allSpecs = ProductQuickViewContent.buildQuickSpecs(product);
    final warranty = _specValue(allSpecs, 'garanti');
    final shipping = _specValue(allSpecs, 'kargo');
    final specs = <ProductQuickSpec>[
      for (final spec in allSpecs)
        if (!_gridSpecLabels.contains(spec.label.toLowerCase())) spec,
    ];
    final chips = ProductQuickViewContent.plainFeatures(product);
    final description = ProductQuickViewContent.resolveDescription(product);
    final hasActions =
        widget.onAddToCart != null || widget.onViewDetails != null;

    final infoTiles = <(String, String)>[
      if (brandName != null) ('Marka', brandName),
      if (category != null) ('Kategori', category),
      if (storeName != null && storeName != brandName) ('Mağaza', storeName),
      if (stock != null) ('Stok', stock > 0 ? 'Stokta var' : 'Stokta yok'),
      if (product.isDigital) ('Teslimat', 'Dijital ürün'),
      if (warranty != null) ('Garanti', warranty),
      if (shipping != null) ('Kargo', shipping),
    ];

    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.82,
        builder: (context, scrollController) {
          return Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2DAF6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
                        children: [
                          _buildHeader(
                            category: category,
                            brandName: brandName,
                            storeName: storeName,
                          ),
                          const SizedBox(height: 14),
                          _buildPriceCard(discount: discount, stock: stock),
                          if (infoTiles.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            _QuickInfoGrid(tiles: infoTiles),
                          ],
                          if (specs.isNotEmpty || chips.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            _buildSpecsSection(specs: specs, chips: chips),
                          ],
                          const SizedBox(height: 14),
                          _buildDescriptionSection(description),
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

  String? _specValue(List<ProductQuickSpec> specs, String labelKeyword) {
    for (final spec in specs) {
      if (spec.label.toLowerCase().contains(labelKeyword)) return spec.value;
    }
    return null;
  }

  Widget _buildHeader({
    String? category,
    String? brandName,
    String? storeName,
  }) {
    final product = _product;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: category != null
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            _FavoriteButton(product: product),
            const SizedBox(width: 6),
            Material(
              color: const Color(0xFFF4F1FA),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.all(7),
                  child: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          product.name,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
            height: 1.2,
          ),
        ),
        if (brandName != null || storeName != null) ...[
          const SizedBox(height: 6),
          Text(
            [
              ?brandName,
              if (storeName != null && storeName != brandName) storeName,
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
        if (product.rating > 0) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                size: 17,
                color: Color(0xFFF59E0B),
              ),
              const SizedBox(width: 3),
              Text(
                product.rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2937),
                ),
              ),
              if (product.reviewCount > 0) ...[
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '(${product.reviewCount} değerlendirme)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPriceCard({required (double, int)? discount, int? stock}) {
    final product = _product;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEAE3FA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  product.displayPricingText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ),
              if (discount != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      '₺${discount.$1.toStringAsFixed(2)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Colors.grey.shade500,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '%${discount.$2}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF15803D),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (stock != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  stock > 0
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  size: 15,
                  color: stock > 0
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                ),
                const SizedBox(width: 5),
                Text(
                  stock > 0 ? 'Stokta var' : 'Stokta yok',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: stock > 0
                        ? const Color(0xFF15803D)
                        : const Color(0xFFB91C1C),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpecsSection({
    required List<ProductQuickSpec> specs,
    required List<String> chips,
  }) {
    final visibleSpecs = _specsExpanded
        ? specs
        : specs.take(EcommerceProductQuickInfoSheet.maxVisibleSpecs).toList();
    final hiddenCount = specs.length - visibleSpecs.length;
    return _SectionCard(
      title: 'Öne Çıkan Özellikler',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final spec in visibleSpecs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      spec.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      spec.value,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (hiddenCount > 0)
            TextButton(
              onPressed: () => setState(() => _specsExpanded = true),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                foregroundColor: AppColors.primary,
              ),
              child: Text(
                '+$hiddenCount özellik daha',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final chip in chips)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F1FA),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      chip,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4C1D95),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(String? description) {
    if (description == null) {
      return Text(
        'Bu ürün için açıklama eklenmemiş.',
        style: TextStyle(
          fontSize: 12.5,
          fontStyle: FontStyle.italic,
          color: Colors.grey.shade500,
        ),
      );
    }
    // Kaba uzunluk eşiği: ~4 satırdan uzun metinlerde "Devamını oku".
    final isLong = description.length > 220;
    return _SectionCard(
      title: 'Açıklama',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            description,
            maxLines: _descriptionExpanded || !isLong ? null : 4,
            overflow: _descriptionExpanded || !isLong
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Colors.grey.shade700,
            ),
          ),
          if (isLong && !_descriptionExpanded)
            TextButton(
              onPressed: () => setState(() => _descriptionExpanded = true),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                foregroundColor: AppColors.primary,
              ),
              child: const Text(
                'Devamını oku',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickInfoGrid extends StatelessWidget {
  const _QuickInfoGrid({required this.tiles});

  final List<(String, String)> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tile in tiles)
              SizedBox(
                width: itemWidth,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFECE7F6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tile.$1,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tile.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
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
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECE7F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF344054),
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
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
      color: const Color(0xFFF4F1FA),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => resolvedAppState.toggleFavorite(product),
        child: Padding(
          padding: const EdgeInsets.all(7),
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
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Detayları Gör',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Sepete Ekle',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
