import 'package:flutter/material.dart';

import '../../../app/ibul_router.dart';
import '../../../app/marketplace_paths.dart';
import '../../../core/constants.dart';
import '../../../widgets/optimized_image.dart';
import 'mobile_home_chrome.dart';
import 'mobile_home_models.dart';

class MobileHomeNearbyStores extends StatelessWidget {
  const MobileHomeNearbyStores({super.key, required this.stores, required this.onSeeAll});

  final List<MobileNearbyStore> stores;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final visible = stores.where((store) => store.name.trim().isNotEmpty).toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        MobileHomeSectionTitle(title: 'Yakınındaki Mağazalar', onSeeAll: onSeeAll),
        SizedBox(
          key: const ValueKey('mobile-home-nearby'),
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: visible.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) => _StoreCard(store: visible[index]),
          ),
        ),
      ]),
    );
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.store});

  final MobileNearbyStore store;

  @override
  Widget build(BuildContext context) {
    if (store.name.trim().isEmpty) return const SizedBox.shrink();
    final meta = [
      if ((store.category ?? '').trim().isNotEmpty) store.category!.trim(),
      if (store.distanceKm != null) mobileDistanceLabel(store.distanceKm!),
    ].join(' • ');
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: ValueKey('mobile-home-store-${store.id}'),
        onTap: () => IbulRouter.push(context, MarketplacePaths.store(store.id, slug: store.name)),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: mobileHomeLine),
          ),
          child: Row(children: [
            _Logo(name: store.name, url: store.logoUrl),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(store.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: mobileHomeInk)),
                if ((store.contextLine ?? '').isNotEmpty)
                  Text(store.contextLine!, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: mobileHomeMuted, fontWeight: FontWeight.w600)),
                if (meta.isNotEmpty)
                  Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: mobileHomeMuted, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
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
