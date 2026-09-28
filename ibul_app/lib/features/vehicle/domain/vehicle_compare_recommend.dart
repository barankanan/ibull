import '../models/vehicle_enums.dart';
import '../models/vehicle_listing.dart';

abstract final class VehicleCompareRecommend {
  static String vehicleClassOf(VehicleListing listing) {
    return (listing.extras['vehicle_class'] ?? 'automobile').toString().trim();
  }

  static int score(VehicleListing current, VehicleListing other) {
    if (current.id == other.id) return -1;
    var n = 0;
    final currentClass = vehicleClassOf(current);
    final otherClass = vehicleClassOf(other);
    if (currentClass.isNotEmpty && currentClass == otherClass) n += 50;
    final sameBrand =
        current.specs.brand.trim().toLowerCase() ==
        other.specs.brand.trim().toLowerCase();
    final sameModel =
        current.specs.model.trim().toLowerCase() ==
        other.specs.model.trim().toLowerCase();
    if (sameBrand && sameModel) {
      n += 40;
    } else if (sameBrand) {
      n += 20;
    }
    final currentBody = (current.specs.bodyType ?? '').trim().toLowerCase();
    final otherBody = (other.specs.bodyType ?? '').trim().toLowerCase();
    if (currentBody.isNotEmpty && currentBody == otherBody) n += 15;
    n += _priceScore(current, other);
    n += _yearScore(current, other);
    return n;
  }

  static List<VehicleListing> rank({
    required VehicleListing current,
    required Iterable<VehicleListing> candidates,
    int limit = 12,
  }) {
    final ranked = candidates
        .where(
          (listing) =>
              listing.id != current.id && listing.status.isPubliclyVisible,
        )
        .toList();
    ranked.sort((a, b) => score(current, b).compareTo(score(current, a)));
    if (ranked.length <= limit) return ranked;
    return ranked.sublist(0, limit);
  }

  static int _priceScore(VehicleListing current, VehicleListing other) {
    final a = _price(current);
    final b = _price(other);
    if (a == null || b == null || a <= 0 || b <= 0) return 0;
    final ratio = a > b ? b / a : a / b;
    if (ratio >= 0.8) return 10;
    if (ratio >= 0.5) return 5;
    return 0;
  }

  static int _yearScore(VehicleListing current, VehicleListing other) {
    if (current.specs.year <= 0 || other.specs.year <= 0) return 0;
    final delta = (current.specs.year - other.specs.year).abs();
    if (delta <= 2) return 10;
    if (delta <= 5) return 5;
    return 0;
  }

  static double? _price(VehicleListing listing) {
    if (listing.listingType.allowsSale &&
        listing.salePrice != null &&
        listing.salePrice! > 0) {
      return listing.salePrice;
    }
    if (listing.rental != null && listing.rental!.dailyPrice > 0) {
      return listing.rental!.dailyPrice;
    }
    return null;
  }
}
