import 'package:latlong2/latlong.dart';

import '../services/store/store_mapping_helpers.dart';

/// Single source of truth for a map pin (store/business).
class MapStoreMarker {
  const MapStoreMarker({
    required this.sellerId,
    required this.name,
    required this.location,
    this.category = 'other',
    this.storeCategory = '',
    this.city = '',
    this.district = '',
    this.logoUrl,
    this.source = 'unknown',
    this.fromCityFallback = false,
    this.raw = const {},
  });

  final String sellerId;
  final String name;
  final LatLng location;
  final String category;
  final String storeCategory;
  final String city;
  final String district;
  final String? logoUrl;
  final String source;
  final bool fromCityFallback;
  final Map<String, dynamic> raw;

  static MapStoreMarker? fromPipelineRow(
    Map<String, dynamic> row, {
    required int disambiguationIndex,
    required String source,
    String Function(String? category)? mapCategory,
  }) {
    final resolved = resolveStoreLatLngWithFallback(
      row,
      disambiguationIndex: disambiguationIndex,
    );
    if (resolved == null) return null;

    final sellerId =
        row['seller_id']?.toString() ??
        row['id']?.toString() ??
        'store-$disambiguationIndex';
    final name =
        row['business_name']?.toString() ??
        row['store_name']?.toString() ??
        row['name']?.toString() ??
        'Mağaza';

    final categoryRaw = row['category']?.toString();
    final category = mapCategory != null
        ? mapCategory(categoryRaw)
        : (categoryRaw ?? 'other');

    return MapStoreMarker(
      sellerId: sellerId,
      name: name,
      location: LatLng(resolved.lat, resolved.lng),
      category: category,
      storeCategory: categoryRaw ?? '',
      city: row['city']?.toString() ?? '',
      district: row['district']?.toString() ?? '',
      logoUrl: row['logo_url']?.toString(),
      source: source,
      fromCityFallback: resolved.fromCityFallback,
      raw: row,
    );
  }

  /// Legacy map popup record used by existing map_page UI.
  Map<String, dynamic> toBusinessRecord({int index = 0}) {
    final description = resolveMapStoreBio(raw);
    final addressLine = formatMapStoreAddress(
      address: raw['address']?.toString(),
      district: district,
      city: city,
    );
    final phone = raw['phone']?.toString().trim() ?? '';
    final email = raw['email']?.toString().trim() ?? '';
    final hasContactInfo = phone.isNotEmpty || email.isNotEmpty;
    final hasDescription = description.isNotEmpty;
    final hasCategory = category.isNotEmpty && category != 'other';
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;

    return {
      'id': sellerId,
      'seller_id': sellerId,
      'name': name,
      'distance': '-',
      'distance_km': null,
      'location': location,
      'category': category,
      'store_category': storeCategory.isNotEmpty
          ? storeCategory
          : (raw['category']?.toString() ?? ''),
      'description': description,
      'address': addressLine,
      'address_line': addressLine,
      'fromSupabase': source != 'home_ads' && source != 'products_synthetic',
      'logo_url': logoUrl,
      'gallery_images': raw['gallery_images'] is List
          ? List<String>.from(raw['gallery_images'] as List)
          : <String>[],
      'follower_count': (raw['follower_count'] as num?)?.toInt() ?? 0,
      'rating': (raw['rating'] as num?)?.toDouble() ?? 0.0,
      'created_at': raw['created_at']?.toString(),
      'city': city,
      'district': district,
      'has_contact_info': hasContactInfo,
      'profile_complete':
          hasLogo && hasDescription && hasCategory && hasContactInfo,
      'is_brand_verified': raw['is_brand_verified'] == true,
      'map_source': source,
      'map_index': index,
    };
  }
}
