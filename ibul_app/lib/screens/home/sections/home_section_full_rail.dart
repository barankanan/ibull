import 'package:flutter/material.dart';

import '../../../core/catalog_image_priority.dart';
import '../../../core/constants.dart';
import '../../../core/home_ui_diagnostics.dart';
import '../../../models/db_product.dart';
import '../../../models/product_model.dart';
import '../../../widgets/product_card.dart';
import '../../../widgets/skeleton_loading.dart';
import '../home_product_rail_groups.dart';

/// Horizontal [ProductCard] rails. When [grouped] is true, products are split
/// into Fırsat / Elektronik / Ev / Telefonlar sections.
class HomeFullProductRailSection extends StatelessWidget {
  const HomeFullProductRailSection({
    super.key,
    required this.title,
    required this.products,
    this.isLoading = false,
    this.maxItems = 12,
    this.errorMessage,
    this.onRetry,
    this.showViewAll = true,
    this.grouped = false,
  });

  final String title;
  final List<DBProduct> products;
  final bool isLoading;
  final int maxItems;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final bool showViewAll;
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    if (isLoading && products.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HomeProductRailSkeleton(),
          if (grouped) const HomeProductRailSkeleton(),
        ],
      );
    }

    if (errorMessage != null && products.isEmpty) {
      return _HomeProductEmptyState(message: errorMessage!, onRetry: onRetry);
    }

    if (products.isEmpty) {
      HomeUiDiagnostics.noProductsEmptyState();
      if (!showViewAll) return const SizedBox.shrink();
      return _HomeProductEmptyState(
        message: 'Henüz ürün bulunmuyor.',
        onRetry: onRetry,
      );
    }

    final groups = grouped
        ? HomeProductRailGroups.build(products, maxPerRail: maxItems)
        : [
            HomeProductRailGroup(
              id: 'single',
              title: title,
              products: products.take(maxItems).toList(growable: false),
            ),
          ];

    if (groups.isEmpty) {
      HomeUiDiagnostics.noProductsEmptyState();
      return const SizedBox.shrink();
    }

    final cardCount = groups.fold<int>(0, (sum, g) => sum + g.products.length);
    HomeUiDiagnostics.realProductCard(count: cardCount);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final group in groups)
          _HomeProductHorizontalRail(
            title: group.title,
            items: group.products,
            showViewAll: showViewAll,
          ),
      ],
    );
  }
}

class _HomeProductHorizontalRail extends StatefulWidget {
  const _HomeProductHorizontalRail({
    required this.title,
    required this.items,
    required this.showViewAll,
  });

  final String title;
  final List<DBProduct> items;
  final bool showViewAll;

  @override
  State<_HomeProductHorizontalRail> createState() =>
      _HomeProductHorizontalRailState();
}

class _HomeProductHorizontalRailState
    extends State<_HomeProductHorizontalRail> {
  static const double _cardWidth = 220;
  static const double _cardHeight = 348;
  static const double _gap = 12;

  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollBy(double delta) {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      (_scrollController.offset + delta).clamp(
        0,
        _scrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final showArrows =
        widget.items.length > 3 && MediaQuery.sizeOf(context).width >= 700;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
              if (widget.showViewAll)
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: const Text(
                    'Tümünü Gör',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: _cardHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ListView.separated(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  itemCount: widget.items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: _gap),
                  itemBuilder: (context, index) {
                    return SizedBox(
                      width: _cardWidth,
                      height: _cardHeight,
                      child: ProductCard(
                        product: Product.fromDBProduct(widget.items[index]),
                        width: _cardWidth,
                        margin: EdgeInsets.zero,
                        imagePriority: CatalogImagePriority.forRailIndex(index),
                      ),
                    );
                  },
                ),
                if (showArrows) ...[
                  Positioned(
                    left: 0,
                    child: _RailArrow(
                      icon: Icons.chevron_left,
                      onTap: () => _scrollBy(-(_cardWidth + _gap) * 2),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    child: _RailArrow(
                      icon: Icons.chevron_right,
                      onTap: () => _scrollBy((_cardWidth + _gap) * 2),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RailArrow extends StatelessWidget {
  const _RailArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 22, color: const Color(0xFF333333)),
        ),
      ),
    );
  }
}

class _HomeProductEmptyState extends StatelessWidget {
  const _HomeProductEmptyState({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 40,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onRetry, child: const Text('Tekrar dene')),
            ],
          ],
        ),
      ),
    );
  }
}

Widget buildHomeFullProductRailSection({
  required String title,
  required List<DBProduct> products,
  bool isLoading = false,
  int maxItems = 12,
  String? errorMessage,
  VoidCallback? onRetry,
  bool showViewAll = true,
  bool grouped = false,
}) {
  return HomeFullProductRailSection(
    title: title,
    products: products,
    isLoading: isLoading,
    maxItems: maxItems,
    errorMessage: errorMessage,
    onRetry: onRetry,
    showViewAll: showViewAll,
    grouped: grouped,
  );
}
