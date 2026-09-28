import '../models/vehicle_listing.dart';

abstract final class VehicleNearbyQuery {
  static String fromListing(VehicleListing listing) {
    final brand = listing.specs.brand.trim();
    final model = listing.specs.model.trim();
    final version = (listing.specs.version ?? '').trim();
    final parts = [
      if (brand.isNotEmpty) brand,
      if (model.isNotEmpty) model,
      if (brand.isNotEmpty && model.isNotEmpty && version.isNotEmpty) version,
    ];
    if (parts.isNotEmpty) return parts.join(' ');
    final title = listing.title.trim();
    return title.isEmpty ? 'Araç' : title;
  }
}
