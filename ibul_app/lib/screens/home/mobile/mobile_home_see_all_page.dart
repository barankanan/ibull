import 'package:flutter/material.dart';

import '../../../app/ibul_router.dart';
import '../../../app/marketplace_paths.dart';
import '../../../features/products/helpers/product_filter_engine.dart';
import '../../../features/products/models/product_filter_models.dart';
import '../../../features/products/widgets/product_filter_bottom_sheet.dart';
import '../../../features/products/widgets/product_sort_bottom_sheet.dart';
import '../../../models/product_model.dart';
import '../../../widgets/product_card.dart';
import 'mobile_home_models.dart';

class MobileHomeSeeAllPage extends StatelessWidget {
  const MobileHomeSeeAllPage.products({
    super.key,
    required this.title,
    required this.products,
  }) : stores = const [],
       malls = const [];

  const MobileHomeSeeAllPage.stores({
    super.key,
    required this.title,
    required this.stores,
  }) : products = const [],
       malls = const [];

  const MobileHomeSeeAllPage.malls({
    super.key,
    required this.title,
    required this.malls,
  }) : products = const [],
       stores = const [];

  final String title;
  final List<Product> products;
  final List<MobileNearbyStore> stores;
  final List<MobileHomeMall> malls;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: const Color(0xFF111827),
        centerTitle: true,
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: products.isNotEmpty
          ? _ProductGrid(products: products)
          : stores.isNotEmpty
          ? _StoreList(stores: stores)
          : malls.isNotEmpty
          ? _MallList(malls: malls)
          : const Center(
              child: Text(
                'Şu an görüntülenecek kayıt yok.',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
    );
  }
}

class _SeeAllToolButton extends StatelessWidget {
  const _SeeAllToolButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        foregroundColor: const Color(0xFF4B5563),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductGrid extends StatefulWidget {
  const _ProductGrid({required this.products});

  final List<Product> products;

  @override
  State<_ProductGrid> createState() => _ProductGridState();
}

class _ProductGridState extends State<_ProductGrid> {
  ProductFilterState _filter = const ProductFilterState();
  late final List<ProductFilterGroup> _groups = ProductFilterEngine
      .buildFilterGroups(
        products: widget.products,
        mainCategory: '',
        subCategory: '',
      )
      .where((group) => !group.isEmpty)
      .toList(growable: false);

  List<Product> get _visible => ProductFilterEngine.resolveProducts(
        products: widget.products,
        state: _filter,
      );

  Future<void> _openFilter() {
    return ProductFilterBottomSheet.show(
      context: context,
      groups: _groups,
      initialState: _filter,
      previewCount: (draft) => ProductFilterEngine.resolveProducts(
        products: widget.products,
        state: draft,
      ).length,
      onApply: (next) => setState(() => _filter = next),
    );
  }

  Future<void> _openSort() {
    return ProductSortBottomSheet.show(
      context: context,
      initialSort: _filter.sortOption,
      onApply: (sort) => setState(
        () => _filter = _filter.copyWith(sortOption: sort),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Column(
      children: [
        Material(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: _SeeAllToolButton(
                    key: const ValueKey('see-all-filter'),
                    icon: Icons.tune_rounded,
                    label: _filter.hasActiveFilters
                        ? 'Filtrele (${_filter.activeFilterCount})'
                        : 'Filtrele',
                    onPressed: _groups.isEmpty ? null : _openFilter,
                  ),
                ),
                Expanded(
                  child: _SeeAllToolButton(
                    key: const ValueKey('see-all-sort'),
                    icon: Icons.swap_vert_rounded,
                    label: 'Sırala',
                    onPressed: _openSort,
                  ),
                ),
                Text(
                  '${visible.length} ürün',
                  key: const ValueKey('see-all-count'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? const Center(
                  child: Text(
                    'Bu filtrelere uyan ürün yok.',
                    style: TextStyle(color: Color(0xFF6B7280)),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    mainAxisExtent: ProductCard.homeRailCardHeight(context),
                  ),
                  itemCount: visible.length,
                  itemBuilder: (context, index) => Align(
                    alignment: Alignment.topCenter,
                    child: ProductCard(
                      product: visible[index],
                      homeRail: true,
                      margin: EdgeInsets.zero,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _StoreList extends StatelessWidget {
  const _StoreList({required this.stores});

  final List<MobileNearbyStore> stores;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: stores.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final store = stores[index];
        final meta = [
          if ((store.category ?? '').trim().isNotEmpty) store.category!.trim(),
          if (store.distanceKm != null) mobileDistanceLabel(store.distanceKm!),
        ].join(' • ');
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => IbulRouter.push(
              context,
              MarketplacePaths.store(store.id, slug: store.name),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if ((store.contextLine ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(store.contextLine!),
                  ],
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(meta, style: const TextStyle(color: Color(0xFF6B7280))),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MallList extends StatelessWidget {
  const _MallList({required this.malls});

  final List<MobileHomeMall> malls;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: malls.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final mall = malls[index];
        final place = [
          if ((mall.place ?? '').isNotEmpty) mall.place!,
          if (mall.distanceKm != null) mobileDistanceLabel(mall.distanceKm!),
        ].join(' • ');
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => IbulRouter.push(
              context,
              MarketplacePaths.mallProfile(mall.id),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mall.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (place.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(place, style: const TextStyle(color: Color(0xFF6B7280))),
                  ],
                  if (mall.storeCount != null) ...[
                    const SizedBox(height: 4),
                    Text('${mall.storeCount} mağaza'),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
