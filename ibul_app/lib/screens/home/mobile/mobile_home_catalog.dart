import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_state.dart';
import '../../../core/auth/user_identity.dart';
import '../../../core/constants.dart';
import '../../../core/favorite_state.dart';
import '../../../features/vehicle/domain/vehicle_catalog.dart';
import '../../../features/vehicle/models/vehicle_enums.dart';
import '../../../features/vehicle/models/vehicle_listing.dart';
import '../../../features/vehicle/navigation/vehicle_routes.dart';
import '../../../features/vehicle/widgets/vehicle_card.dart';
import '../../../models/product_model.dart';
import '../../../models/product_pricing.dart';
import '../../../widgets/optimized_image.dart';
import '../../../widgets/product_card.dart';
import '../../favorites_page.dart';
import 'mobile_home_chrome.dart';
import 'mobile_home_see_all_page.dart';

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
    final user = context.select<AppState, Map<String, dynamic>?>(
      (state) => state.currentUser,
    );
    final title = mobilePersonalizedTitle(user);
    return MobileProductRail(
      title: title,
      heading: MobilePersonalizedHeading(title: title),
      sectionKey: 'mobile-product-rail-Sana Özel',
      products: products,
      onSeeAll: onSeeAllFeatured,
    );
  }
}

String mobilePersonalizedTitle(Map<String, dynamic>? user) {
  if (user == null || UserIdentity.isGuest(user)) return 'Sana Özel';
  const keys = ['display_name', 'displayName', 'name', 'fullName', 'full_name'];
  var raw = '';
  for (final key in keys) {
    final value = user[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) {
      raw = value;
      break;
    }
  }
  if (raw.isEmpty) return 'Sana Özel';
  final lowered = raw.toLowerCase();
  if (lowered == 'kullanıcı' ||
      lowered == 'misafir' ||
      lowered == 'misafir kullanıcı') {
    return 'Sana Özel';
  }
  final first = raw.split(RegExp(r'\s+')).first.trim();
  if (first.isEmpty || first.contains('@') || first.length < 2) {
    return 'Sana Özel';
  }
  return '$first Sana Özel';
}

class MobilePersonalizedHeading extends StatelessWidget {
  const MobilePersonalizedHeading({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    const style = MobileHomeTypography.sectionTitle;
    const suffix = ' Sana Özel';
    if (title == 'Sana Özel' || !title.endsWith(suffix)) {
      return const Text(
        'Sana Özel',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    final name = title.substring(0, title.length - suffix.length);
    return Row(
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style.copyWith(color: AppColors.primary),
        ),
        const SizedBox(width: 6),
        const Flexible(
          child: Text(
            'Sana Özel',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}

class MobileProductRail extends StatelessWidget {
  const MobileProductRail({
    super.key,
    required this.title,
    this.heading,
    required this.products,
    this.onSeeAll,
    this.sectionKey,
  });

  final String title;
  final Widget? heading;
  final List<Product> products;
  final VoidCallback? onSeeAll;
  final String? sectionKey;

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
          MobileHomeSectionTitle(
            title: title,
            heading: heading,
            onSeeAll: onSeeAll,
          ),
          SizedBox(
            key: ValueKey(sectionKey ?? 'mobile-product-rail-$title'),
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
    if (recent.isEmpty) {
      return const _HomeMemoryEmpty(
        title: 'Daha Önce Gezdiklerin',
        message: 'Gezdiğin ürünler burada görünecek.',
      );
    }
    return MobileProductRail(
      title: 'Daha Önce Gezdiklerin',
      products: recent.take(10).toList(growable: false),
      onSeeAll: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MobileHomeSeeAllPage.products(
              title: 'Daha Önce Gezdiklerin',
              products: recent,
            ),
          ),
        );
      },
    );
  }
}

class MobileHomeLiked extends StatelessWidget {
  const MobileHomeLiked({super.key});

  @override
  Widget build(BuildContext context) {
    final liked = context.select<FavoriteState, List<Product>>(
      (state) => state.favorites,
    );
    if (liked.isEmpty) {
      return const _HomeMemoryEmpty(
        title: 'Beğendiklerin',
        message: 'Beğendiğin ürünler burada görünecek.',
      );
    }
    return MobileProductRail(
      title: 'Beğendiklerin',
      products: liked.take(10).toList(growable: false),
      onSeeAll: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const FavoritesPage()),
        );
      },
    );
  }
}

class _HomeMemoryEmpty extends StatelessWidget {
  const _HomeMemoryEmpty({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MobileHomeSectionTitle(title: title),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: mobileHomeMuted,
              ),
            ),
          ),
        ],
      ),
    );
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
