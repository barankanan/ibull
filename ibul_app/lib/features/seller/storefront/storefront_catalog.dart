import '../../vehicle/models/vehicle_enums.dart';
import '../../vehicle/models/vehicle_listing.dart';
import '../../vehicle/services/vehicle_service.dart';
import '../domain/store_vertical.dart';

/// Data-layer catalog for the shared storefront. UI chrome stays in
/// [BusinessDetailPage]; this adapter only loads and filters items.
abstract final class StorefrontCatalog {
  static Future<List<VehicleListing>> loadVehicles(String sellerId) {
    return VehicleService.instance.listings.listPublicBySeller(sellerId);
  }

  static bool matchesVehicle(VehicleListing listing, String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return true;
    final haystack = [
      listing.title,
      listing.specs.brand,
      listing.specs.model,
      listing.specs.version ?? '',
      listing.vehicleClass,
      listing.city ?? '',
      listing.district ?? '',
    ].join(' ').toLowerCase();
    return haystack.contains(query);
  }

  static List<VehicleListing> filterVehicles(
    List<VehicleListing> items, {
    required String query,
    String? category,
    required String saleLabel,
    required String rentalLabel,
  }) {
    var rows = items.where((row) => matchesVehicle(row, query)).toList();
    final selected = (category ?? '').trim();
    if (selected.isEmpty || selected == 'Tümü') return rows;
    if (selected == saleLabel) {
      return rows.where((row) => row.listingType.allowsSale).toList();
    }
    if (selected == rentalLabel) {
      return rows.where((row) => row.listingType.allowsRental).toList();
    }
    return rows;
  }

  static List<String> vehicleCategories({
    required List<VehicleListing> items,
    required String saleLabel,
    required String rentalLabel,
  }) {
    final categories = <String>['Tümü'];
    if (items.any((row) => row.listingType.allowsSale)) {
      categories.add(saleLabel);
    }
    if (items.any((row) => row.listingType.allowsRental)) {
      categories.add(rentalLabel);
    }
    return categories;
  }

  static bool usesVehicleCatalog(StoreVertical vertical) {
    return vertical == StoreVertical.gallery;
  }
}
