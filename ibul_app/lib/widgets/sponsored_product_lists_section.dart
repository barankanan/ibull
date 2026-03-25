import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../ads/ads.dart';
import '../core/app_state.dart';
import '../core/constants.dart';
import '../models/product_list_model.dart';
import 'optimized_image.dart';
import 'premium_interactions.dart';
import '../screens/list_detail_page.dart';
import 'skeleton_loading.dart';
import '../services/product_list_service.dart';

class SponsoredProductListsSection extends StatefulWidget {
  const SponsoredProductListsSection({
    required this.title,
    required this.placement,
    this.subtitle,
    this.categoryFilter,
    this.maxItems = 6,
    super.key,
  });

  final String title;
  final String? subtitle;
  final AdPlacement placement;
  final String? categoryFilter;
  final int maxItems;

  @override
  State<SponsoredProductListsSection> createState() =>
      _SponsoredProductListsSectionState();
}

class _SponsoredProductListsSectionState
    extends State<SponsoredProductListsSection> {
  final AdsService _adsService = AdsService();
  final ProductListService _productListService = ProductListService.instance;
  final AppState _appState = AppState();

  late Future<List<ProductList>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadLists();
  }

  @override
  void didUpdateWidget(covariant SponsoredProductListsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placement != widget.placement ||
        oldWidget.categoryFilter != widget.categoryFilter ||
        oldWidget.maxItems != widget.maxItems) {
      _future = _loadLists();
    }
  }

  String _normalize(String? value) => (value ?? '').trim().toLowerCase();

  bool _matchesCategory(ProductList list) {
    final filter = _normalize(widget.categoryFilter);
    if (filter.isEmpty) return true;
    final listCategory = _normalize(list.category);
    final listSubCategory = _normalize(list.subCategory);
    return listCategory == filter || listSubCategory == filter;
  }

  Future<List<ProductList>> _loadLists() async {
    try {
      final sponsored = await _adsService.getSponsoredCollections(
        placement: widget.placement,
        limit: widget.maxItems * 2,
      );
      final ids = sponsored
          .map((item) => item.collectionId.trim())
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
      if (ids.isEmpty) return const [];

      final lists = await _productListService.getListsByIds(ids);
      final byId = {for (final list in lists) list.id: list};
      return ids
          .map((id) => byId[id])
          .whereType<ProductList>()
          .where(_matchesCategory)
          .take(widget.maxItems)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProductList>>(
      future: _future,
      builder: (context, snapshot) {
        final lists = snapshot.data ?? const <ProductList>[];
        if (snapshot.connectionState == ConnectionState.waiting &&
            lists.isEmpty) {
          return _SponsoredProductListsSkeleton(
            title: widget.title,
            hasSubtitle: (widget.subtitle ?? '').trim().isNotEmpty,
          );
        }
        if (lists.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if ((widget.subtitle ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle!,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Sponsorlu',
                      style: TextStyle(
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 252,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                  },
                ),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: lists.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 14),
                  itemBuilder: (context, index) => SizedBox(
                    width: 250,
                    child: _SponsoredListCard(
                      list: lists[index],
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (routeContext) => ListDetailPage(
                              listData: _appState.productListToMap(
                                lists[index],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SponsoredListCard extends StatelessWidget {
  const _SponsoredListCard({required this.list, required this.onTap});

  final ProductList list;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cover = (list.iconUrl ?? '').trim();
    final previewProducts = list.products.take(3).toList(growable: false);

    return RepaintBoundary(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: PremiumPressable(
          hoverLift: 2,
          hoverScale: 1.008,
          pressedScale: 0.982,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Ink(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D0F172A),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RepaintBoundary(
                    child: Container(
                      height: 120,
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(22),
                        ),
                        color: Color(0xFFF8FAFC),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: cover.isNotEmpty
                          ? OptimizedImage(
                              imageUrlOrPath: cover,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              cacheWidth: 640,
                              cacheHeight: 320,
                              errorWidget: _buildCoverFallback(),
                            )
                          : _buildCoverFallback(),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            list.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            (list.description ?? '').trim().isEmpty
                                ? '${list.productCount} ürün'
                                : list.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                              height: 1.45,
                            ),
                          ),
                          const Spacer(),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _MetaChip(
                                icon: Icons.inventory_2_outlined,
                                label: '${list.productCount} ürün',
                              ),
                              if ((list.category ?? '').trim().isNotEmpty)
                                _MetaChip(
                                  icon: Icons.category_outlined,
                                  label: list.category!,
                                ),
                            ],
                          ),
                          if (previewProducts.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              previewProducts
                                  .map((product) => product.name)
                                  .join(' • '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF334155),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: const [
                              Text(
                                'Listeyi aç',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverFallback() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF8FAFC),
      child: const Center(
        child: Icon(
          Icons.collections_bookmark_outlined,
          color: Color(0xFF64748B),
          size: 36,
        ),
      ),
    );
  }
}

class _SponsoredProductListsSkeleton extends StatelessWidget {
  const _SponsoredProductListsSkeleton({
    required this.title,
    required this.hasSubtitle,
  });

  final String title;
  final bool hasSubtitle;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cardWidth = width >= 1100 ? 250.0 : 232.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLoading(
                      width: title.length > 20 ? 210 : 170,
                      height: 20,
                      borderRadius: 8,
                    ),
                    if (hasSubtitle) ...[
                      const SizedBox(height: 6),
                      const SkeletonLoading(
                        width: 240,
                        height: 12,
                        borderRadius: 6,
                      ),
                    ],
                  ],
                ),
              ),
              const SkeletonLoading(width: 76, height: 28, borderRadius: 999),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 252,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: width >= 1100 ? 4 : 3,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) =>
                _SponsoredListCardSkeleton(width: cardWidth),
          ),
        ),
      ],
    );
  }
}

class _SponsoredListCardSkeleton extends StatelessWidget {
  const _SponsoredListCardSkeleton({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SkeletonLoading(
              width: double.infinity,
              height: 106,
              borderRadius: 16,
            ),
            SizedBox(height: 14),
            SkeletonLoading(width: 150, height: 16, borderRadius: 8),
            SizedBox(height: 8),
            SkeletonLoading(
              width: double.infinity,
              height: 12,
              borderRadius: 6,
            ),
            SizedBox(height: 6),
            SkeletonLoading(width: 132, height: 12, borderRadius: 6),
            Spacer(),
            Row(
              children: [
                SkeletonLoading(width: 82, height: 26, borderRadius: 999),
                SizedBox(width: 8),
                SkeletonLoading(width: 92, height: 26, borderRadius: 999),
              ],
            ),
            SizedBox(height: 12),
            SkeletonLoading(
              width: double.infinity,
              height: 12,
              borderRadius: 6,
            ),
            SizedBox(height: 6),
            SkeletonLoading(width: 112, height: 12, borderRadius: 6),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF475569)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}
