import '../../features/vehicle/models/vehicle_listing.dart';
import '../../models/db_product.dart';

enum HomeDiscoveryContentType { product, vehicle, property }

class HomeDiscoveryItem {
  const HomeDiscoveryItem({
    required this.id,
    required this.type,
    required this.title,
    required this.imageUrl,
    this.price,
    this.subtitle,
    this.distanceKm,
    this.product,
    this.vehicle,
  });

  final String id;
  final HomeDiscoveryContentType type;
  final String title;
  final String imageUrl;
  final double? price;
  final String? subtitle;
  final double? distanceKm;
  final DBProduct? product;
  final VehicleListing? vehicle;

  String get typeBadge => switch (type) {
    HomeDiscoveryContentType.product => 'Ürün',
    HomeDiscoveryContentType.vehicle => 'Araç',
    HomeDiscoveryContentType.property => 'Emlak',
  };
}

/// Mixes ecommerce products and vehicle listings for home rails.
abstract final class HomeDiscoveryResolver {
  static List<HomeDiscoveryItem> nearby({
    required List<DBProduct> products,
    required List<VehicleListing> vehicles,
    Map<String, double> distanceBySeller = const {},
    int limit = 12,
  }) {
    final items = <HomeDiscoveryItem>[
      for (final product in products)
        HomeDiscoveryItem(
          id: product.id ?? '',
          type: HomeDiscoveryContentType.product,
          title: product.name,
          imageUrl: product.imageUrl,
          price: double.tryParse(product.price.replaceAll(',', '.')),
          subtitle: product.store,
          distanceKm: _distance(distanceBySeller, product.sellerId),
          product: product,
        ),
      for (final vehicle in vehicles.where((row) => row.isLivePublished))
        HomeDiscoveryItem(
          id: vehicle.id,
          type: HomeDiscoveryContentType.vehicle,
          title: vehicle.title,
          imageUrl: vehicle.coverUrl ?? '',
          price: vehicle.salePrice ?? vehicle.rental?.dailyPrice,
          subtitle: [
            if (vehicle.specs.year > 0) '${vehicle.specs.year}',
            if (vehicle.city != null) vehicle.city,
          ].join(' · '),
          distanceKm: _distance(distanceBySeller, vehicle.sellerId),
          vehicle: vehicle,
        ),
    ]..sort((a, b) {
      final da = a.distanceKm ?? 1e9;
      final db = b.distanceKm ?? 1e9;
      final cmp = da.compareTo(db);
      if (cmp != 0) return cmp;
      return a.title.compareTo(b.title);
    });
    return items.where((item) => item.id.isNotEmpty).take(limit).toList();
  }

  static List<VehicleListing> publicVehicles(
    List<VehicleListing> listings, {
    int limit = 12,
  }) {
    final live = listings.where((row) => row.isLivePublished).toList();
    live.sort((a, b) {
      final aAt = a.publishedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bAt = b.publishedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bAt.compareTo(aAt);
    });
    return live.take(limit).toList(growable: false);
  }

  static double? _distance(Map<String, double> bySeller, String? sellerId) {
    if (sellerId == null || sellerId.isEmpty) return null;
    return bySeller[sellerId];
  }
}
