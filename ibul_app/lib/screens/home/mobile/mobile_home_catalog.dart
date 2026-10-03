import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_state.dart';
import '../../../features/vehicle/domain/vehicle_catalog.dart';
import '../../../features/vehicle/models/vehicle_enums.dart';
import '../../../features/vehicle/models/vehicle_listing.dart';
import '../../../features/vehicle/navigation/vehicle_routes.dart';
import '../../../features/vehicle/widgets/vehicle_card.dart';
import '../../../models/product_model.dart';
import '../../../models/product_pricing.dart';
import '../../../widgets/optimized_image.dart';
import '../../../widgets/product_card.dart';
import 'mobile_home_chrome.dart';

class MobileHomeProductRails extends StatelessWidget {
  const MobileHomeProductRails({
    super.key,
    required this.products,
    required this.onSeeAllFeatured,
  });

  final List<Product> products;
  final VoidCallback onSeeAllFeatured;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    return MobileProductRail(
      title: 'Sana Özel',
      products: products,
      onSeeAll: onSeeAllFeatured,
    );
  }
}

class MobileHomeCategoryRails extends StatelessWidget {
  const MobileHomeCategoryRails({
    super.key,
    required this.products,
    required this.onSeeAllCategory,
  });

  final List<Product> products;
  final ValueChanged<String> onSeeAllCategory;

  @override
  Widget build(BuildContext context) {
    final rails = mobileCategoryRails(products);
    if (rails.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final rail in rails)
          MobileProductRail(
            title: rail.title,
            products: rail.products,
            onSeeAll: () => onSeeAllCategory(rail.title),
          ),
      ],
    );
  }
}

class MobileCategoryRail {
  const MobileCategoryRail({required this.title, required this.products});

  final String title;
  final List<Product> products;
}

List<MobileCategoryRail> mobileCategoryRails(List<Product> products) {
  final grouped = <String, List<Product>>{};
  final order = <String>[];
  void add(String raw, Product product) {
    final title = raw.trim();
    if (title.isEmpty) return;
    final bucket = grouped.putIfAbsent(title, () {
      order.add(title);
      return <Product>[];
    });
    final id = product.productId;
    if (id != null && bucket.any((item) => item.productId == id)) return;
    bucket.add(product);
  }

  for (final product in products) {
    final main = product.category ?? '';
    final sub = product.subCategory ?? '';
    if (main.trim().isNotEmpty) add(main, product);
    if (sub.trim().isNotEmpty &&
        sub.trim().toLowerCase() != main.trim().toLowerCase()) {
      add(sub, product);
    }
  }
  return [
    for (final title in order)
      if ((grouped[title] ?? const []).isNotEmpty)
        MobileCategoryRail(title: title, products: grouped[title]!),
  ];
}

class MobileProductRail extends StatelessWidget {
  const MobileProductRail({
    super.key,
    required this.title,
    required this.products,
    this.onSeeAll,
  });

  final String title;
  final List<Product> products;
  final VoidCallback? onSeeAll;

  static double cardWidthFor(double viewport) {
    final inner = viewport - 16;
    final width = (inner - 10) / 1.95;
    if (width < 156) return 156;
    if (width > 200) return 200;
    return width;
  }

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    final width = cardWidthFor(MediaQuery.sizeOf(context).width);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MobileHomeSectionTitle(title: title, onSeeAll: onSeeAll),
          SizedBox(
            key: ValueKey('mobile-product-rail-$title'),
            height: 312,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: products.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) => Align(
                alignment: Alignment.topCenter,
                child: ProductCard(
                  product: products[index],
                  width: width,
                  homeRail: true,
                  margin: EdgeInsets.zero,
                  imagePriority: OptimizedImagePriority.lazy,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MobileHomeDeals extends StatelessWidget {
  const MobileHomeDeals({super.key, required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final deals = products
        .where(productHasRecordedDiscount)
        .toList(growable: false);
    if (deals.isEmpty) return const SizedBox.shrink();
    return MobileProductRail(title: 'Bugünün Fırsatları', products: deals);
  }
}

bool productHasRecordedDiscount(Product product) {
  final current = ProductPriceCalculator.parsePriceValue(product.price);
  final old = ProductPriceCalculator.parsePriceValue(product.oldPrice ?? '');
  return old > current && current > 0;
}

class MobileHomeVehicles extends StatelessWidget {
  const MobileHomeVehicles({
    super.key,
    required this.listings,
    required this.onSeeAll,
  });

  final List<VehicleListing> listings;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (listings.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MobileHomeSectionTitle(
            title: 'Öne Çıkan Araçlar',
            onSeeAll: onSeeAll,
          ),
          SizedBox(
            key: const ValueKey('mobile-home-vehicles'),
            height: 214,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: listings.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) =>
                  _VehicleTile(listing: listings[index]),
            ),
          ),
        ],
      ),
    );
  }
}

String _vehicleOfferLine(VehicleListing listing, String place) {
  final rental = listing.listingType == VehicleListingType.rental;
  final price = rental
      ? (listing.rental == null
            ? ''
            : '${VehicleMoney.format(listing.rental!.dailyPrice)} / gün')
      : (listing.salePrice == null
            ? ''
            : VehicleMoney.format(listing.salePrice!));
  if (price.isEmpty) return place;
  if (place.isEmpty) return price;
  return '$price • $place';
}

class MobileHomeRecent extends StatelessWidget {
  const MobileHomeRecent({super.key});

  @override
  Widget build(BuildContext context) {
    final recent = context.select<AppState, List<Product>>(
      (state) => state.recentlyViewedProducts,
    );
    if (recent.isEmpty) return const SizedBox.shrink();
    return MobileProductRail(title: 'Son Baktıkların', products: recent);
  }
}

class _VehicleTile extends StatelessWidget {
  const _VehicleTile({required this.listing});

  final VehicleListing listing;

  @override
  Widget build(BuildContext context) {
    final image = listing.primaryImageUrl;
    final place = [
      listing.city,
      listing.district,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(', ');
    final km = listing.specs.mileageKm;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () =>
            VehicleRoutes.openDetail(context, listing.id, slug: listing.title),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 210,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: mobileHomeLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 78,
                  width: double.infinity,
                  child: image == null || image.isEmpty
                      ? const ColoredBox(
                          color: Color(0xFFF3F4F6),
                          child: Icon(
                            Icons.directions_car_outlined,
                            color: mobileHomeMuted,
                          ),
                        )
                      : OptimizedImage(
                          imageUrlOrPath: image,
                          fit: BoxFit.cover,
                          cacheWidth: 420,
                          cacheHeight: 220,
                          priority: OptimizedImagePriority.lazy,
                          errorWidget: const ColoredBox(
                            color: Color(0xFFF3F4F6),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                listing.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: mobileHomeInk,
                ),
              ),
              Text(
                '${listing.specs.year}${km == null ? '' : ' • $km km'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: mobileHomeMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _vehicleOfferLine(listing, place),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: mobileHomeInk,
                ),
              ),
              const SizedBox(height: 6),
              VehicleListingCta(listing: listing),
            ],
          ),
        ),
      ),
    );
  }
}
