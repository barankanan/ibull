import '../models/vehicle_commerce.dart';
import '../models/vehicle_listing.dart';
import '../services/vehicle_service.dart';

class VehicleMapSearchHit {
  const VehicleMapSearchHit({
    required this.listings,
    required this.sellerIds,
    required this.matchLabel,
  });

  final List<VehicleListing> listings;
  final Set<String> sellerIds;
  final String matchLabel;
}

abstract final class VehicleMapSearch {
  static Future<VehicleMapSearchHit> search({
    required String query,
    String? brand,
    String? model,
    double? nearLat,
    double? nearLng,
  }) async {
    final listings = VehicleService.instance.listings;
    final brandName = (brand ?? '').trim();
    final modelName = (model ?? '').trim();
    final text = query.trim();
    final radius = nearLat == null ? null : 50.0;

    var ranked = <VehicleListing>[];
    var label = 'arama';

    if (brandName.isNotEmpty && modelName.isNotEmpty) {
      ranked = await listings.search(
        VehicleSearchQuery(
          brand: brandName,
          model: modelName,
          text: text.isEmpty ? '$brandName $modelName' : text,
          nearLat: nearLat,
          nearLng: nearLng,
          nearRadiusKm: radius,
          limit: 40,
        ),
      );
      if (ranked.isNotEmpty) label = 'aynı marka + model';
    }

    if (ranked.length < 3 && brandName.isNotEmpty) {
      final brandHits = await listings.search(
        VehicleSearchQuery(
          brand: brandName,
          text: text,
          nearLat: nearLat,
          nearLng: nearLng,
          nearRadiusKm: radius,
          limit: 40,
        ),
      );
      ranked = _merge(ranked, brandHits);
      if (ranked.isNotEmpty && label != 'aynı marka + model') {
        label = 'aynı marka';
      }
    }

    if (ranked.length < 3 && text.isNotEmpty) {
      final textHits = await listings.search(
        VehicleSearchQuery(
          text: text,
          nearLat: nearLat,
          nearLng: nearLng,
          nearRadiusKm: radius,
          limit: 40,
        ),
      );
      ranked = _merge(ranked, textHits);
      if (ranked.isNotEmpty && label == 'arama') label = 'benzer araçlar';
    }

    return VehicleMapSearchHit(
      listings: ranked,
      sellerIds: {
        for (final item in ranked)
          if (item.sellerId.trim().isNotEmpty) item.sellerId.trim(),
      },
      matchLabel: label,
    );
  }

  static List<VehicleListing> _merge(
    List<VehicleListing> primary,
    List<VehicleListing> extra,
  ) {
    final seen = {for (final item in primary) item.id};
    return [
      ...primary,
      for (final item in extra)
        if (seen.add(item.id)) item,
    ];
  }
}
