import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../app/ibul_router.dart';
import '../../../app/marketplace_paths.dart';
import '../../../core/constants.dart';
import '../../../models/product_model.dart';
import '../../../widgets/optimized_image.dart';
import 'mobile_home_chrome.dart';
import 'mobile_home_models.dart';
import 'mobile_home_store_previews.dart';

class MobileHomeNearbyStores extends StatefulWidget {
  const MobileHomeNearbyStores({
    super.key,
    required this.stores,
    required this.onSeeAll,
    this.generation = 0,
    this.previews,
  });

  final List<MobileNearbyStore> stores;
  final VoidCallback onSeeAll;
  final int generation;
  final MobileStorePreviewLoader? previews;

  @override
  State<MobileHomeNearbyStores> createState() => _MobileHomeNearbyStoresState();
}

class _MobileHomeNearbyStoresState extends State<MobileHomeNearbyStores> {
  ScrollPosition? _position;
  Map<String, List<Product>> _previews = const {};
  var _started = false;
  var _ticket = 0;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant MobileHomeNearbyStores oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.generation != widget.generation) {
      _started = false;
      _ticket++;
      _schedule();
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_onScroll);
    super.dispose();
  }

  void _schedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bind();
      _onScroll();
    });
  }

  void _bind() {
    final position = Scrollable.maybeOf(context)?.position;
    if (identical(position, _position)) return;
    _position?.removeListener(_onScroll);
    _position = position;
    _position?.addListener(_onScroll);
  }

  void _onScroll() {
    if (_started || !mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return;
    final position = _position;
    if (position == null || !position.hasContentDimensions) {
      _start();
      return;
    }
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) {
      _start();
      return;
    }
    final target = viewport.getOffsetToReveal(box, 0).offset;
    if (target - position.pixels < position.viewportDimension * 1.25) {
      _start();
    }
  }

  void _start() {
    if (_started) return;
    _started = true;
    final ticket = ++_ticket;
    final loader = widget.previews ?? MobileStorePreviewLoader.instance;
    unawaited(() async {
      final previews = await loader.load(widget.stores);
      if (!mounted || ticket != _ticket) return;
      setState(() => _previews = previews);
    }());
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.stores
        .where((store) => store.name.trim().isNotEmpty)
        .toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();
    final cardWidth = MediaQuery.sizeOf(context).width - 56;
    final hasPreview = _previews.values.any((items) => items.isNotEmpty);
    final listHeight = hasPreview ? 150.0 : 88.0;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        MobileHomeSectionTitle(title: 'Yakınındaki Mağazalar', onSeeAll: widget.onSeeAll),
        SizedBox(
          key: const ValueKey('mobile-home-nearby'),
          height: listHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: visible.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final store = visible[index];
              return _StoreCard(
                store: store,
                width: cardWidth,
                previews: _previews[store.id] ?? const [],
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({
    required this.store,
    required this.width,
    required this.previews,
  });

  final MobileNearbyStore store;
  final double width;
  final List<Product> previews;

  @override
  Widget build(BuildContext context) {
    if (store.name.trim().isEmpty) return const SizedBox.shrink();
    final meta = [
      if ((store.category ?? '').trim().isNotEmpty) store.category!.trim(),
      if (store.distanceKm != null) mobileDistanceLabel(store.distanceKm!),
    ].join(' • ');
    final fit = MobileStorePreviewFit.measure(
      innerWidth: width - 24,
      available: previews.length.clamp(0, mobileStorePreviewLimit),
    );
    final thumbs = previews.take(fit.visible).toList(growable: false);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: ValueKey('mobile-home-store-${store.id}'),
        onTap: () => IbulRouter.push(context, MarketplacePaths.store(store.id, slug: store.name)),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: width,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: mobileHomeLine),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _Logo(name: store.name, url: store.logoUrl),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(store.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: mobileHomeInk)),
                    if ((store.contextLine ?? '').isNotEmpty)
                      Text(store.contextLine!, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: mobileHomeMuted, fontWeight: FontWeight.w600)),
                    if (meta.isNotEmpty)
                      Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: mobileHomeMuted, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ]),
              if (thumbs.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (var i = 0; i < thumbs.length; i++) ...[
                      if (i > 0) const SizedBox(width: mobileStorePreviewGap),
                      _StorePreviewThumb(
                        product: thumbs[i],
                        size: mobileStorePreviewThumb,
                      ),
                    ],
                    if (fit.hidden > 0) ...[
                      const SizedBox(width: mobileStorePreviewGap),
                      _PreviewOverflow(count: fit.hidden),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewOverflow extends StatelessWidget {
  const _PreviewOverflow({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: mobileStorePreviewBadge,
      height: mobileStorePreviewThumb,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '+$count',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: mobileHomeMuted,
        ),
      ),
    );
  }
}

class _StorePreviewThumb extends StatelessWidget {
  const _StorePreviewThumb({required this.product, required this.size});

  final Product product;
  final double size;

  @override
  Widget build(BuildContext context) {
    final raw = product.images.isNotEmpty
        ? product.images.first.trim()
        : (product.thumbnailPublicUrl?.trim() ?? '');
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cache = (size * dpr).round().clamp(64, 160);
    const fallback = ColoredBox(
      color: Color(0xFFF3F4F6),
      child: Icon(Icons.image_not_supported, color: Color(0xFF9CA3AF), size: 18),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: raw.isEmpty
            ? fallback
            : OptimizedImage(
                imageUrlOrPath: raw,
                fit: BoxFit.cover,
                cacheWidth: cache,
                cacheHeight: cache,
                priority: OptimizedImagePriority.lazy,
                errorWidget: fallback,
              ),
      ),
    );
  }
}

class MobileHomeMalls extends StatelessWidget {
  const MobileHomeMalls({super.key, required this.malls, required this.onSeeAll});

  final List<MobileHomeMall> malls;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final visible = malls.where((mall) => mall.name.trim().isNotEmpty).toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        MobileHomeSectionTitle(title: 'Yakınındaki AVM\'ler', onSeeAll: onSeeAll),
        SizedBox(
          key: const ValueKey('mobile-home-malls'),
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: visible.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) => _MallCard(mall: visible[index]),
          ),
        ),
      ]),
    );
  }
}

class _MallCard extends StatelessWidget {
  const _MallCard({required this.mall});

  final MobileHomeMall mall;

  @override
  Widget build(BuildContext context) {
    final summary = [
      if ((mall.place ?? '').isNotEmpty) mall.place!,
      if (mall.storeCount != null) '${mall.storeCount} mağaza',
      if (mall.distanceKm != null) mobileDistanceLabel(mall.distanceKm!),
    ].join(' • ');
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: ValueKey('mobile-home-mall-${mall.id}'),
        onTap: () => IbulRouter.push(context, MarketplacePaths.mallProfile(mall.id)),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 240,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: mobileHomeLine),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _Logo(name: mall.name, url: mall.logoUrl, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Text(mall.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: mobileHomeInk)),
              ),
            ]),
            if (summary.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: mobileHomeMuted, fontWeight: FontWeight.w600)),
            ],
            const Spacer(),
            const Text('AVM\'yi Aç', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.name, this.url, this.size = 44});

  final String name;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? 'M' : name.trim().substring(0, 1).toUpperCase();
    final fallback = ColoredBox(
      color: const Color(0xFFF3F4F6),
      child: Center(child: Text(letter, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary))),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        height: size,
        child: url == null
            ? fallback
            : OptimizedImage(
                imageUrlOrPath: url!,
                fit: BoxFit.cover,
                cacheWidth: 120,
                cacheHeight: 120,
                priority: OptimizedImagePriority.lazy,
                errorWidget: fallback,
              ),
      ),
    );
  }
}
