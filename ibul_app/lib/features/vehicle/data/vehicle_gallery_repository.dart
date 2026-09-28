import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/vehicle_listing.dart';

class VehicleGalleryRepository {
  VehicleGalleryRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Canonical `stores` columns. Brand-badge extras are optional and omitted.
  static const storeSelect =
      'seller_id, business_name, logo_url, cover_url, address, city, district, '
      'phone, support_phone, store_lat, store_lng, is_verified, description, '
      'working_hours, rating';

  static const storeSelectMinimal =
      'seller_id, business_name, logo_url, cover_url, address, city, district, '
      'phone, is_verified, rating';

  Future<VehicleGallerySummary?> getBySellerId(String sellerId) async {
    try {
      final store = await _fetchStore(sellerId);
      if (store == null) return null;
      final gallery = await _client
          .from('vehicle_galleries')
          .select(
            'seller_id, about, verified_gallery, appointment_enabled, '
            'rental_enabled, sale_enabled',
          )
          .eq('seller_id', sellerId)
          .maybeSingle();
      var vehicleCount = 0;
      try {
        vehicleCount = await _client
            .from('vehicle_listings')
            .count(CountOption.exact)
            .eq('seller_id', sellerId)
            .inFilter('status', ['active', 'reserved', 'rented']);
      } catch (error) {
        debugPrint('[vehicle] gallery count skipped: $error');
      }
      return VehicleGallerySummary.fromMap({
        ...store,
        if (gallery != null) ...gallery,
        'vehicle_count': vehicleCount,
      });
    } catch (error, stack) {
      debugPrint(
        '[vehicle] store enrichment skipped sellerId=$sellerId: $error\n$stack',
      );
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchStore(String sellerId) async {
    try {
      return await _client
          .from('stores')
          .select(storeSelect)
          .eq('seller_id', sellerId)
          .maybeSingle();
    } on PostgrestException catch (error) {
      if (error.code != '42703') rethrow;
      debugPrint('[vehicle] store select fallback: ${error.message}');
      return await _client
          .from('stores')
          .select(storeSelectMinimal)
          .eq('seller_id', sellerId)
          .maybeSingle();
    }
  }

  Future<List<VehicleGallerySummary>> nearby({
    required double lat,
    required double lng,
    double radiusKm = 25,
  }) async {
    final raw = await _client.rpc(
      'nearby_vehicle_galleries',
      params: {
        'p_lat': lat,
        'p_lng': lng,
        'p_radius_km': radiusKm,
        'p_limit': 40,
      },
    );
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (row) =>
              VehicleGallerySummary.fromMap(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }
}
