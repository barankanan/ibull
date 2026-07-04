import '../../models/seller_product.dart';

/// Never stripped from SELECT — vitrin/RLS ile uyumlu kalmalı.
const List<String> catalogRequiredProductColumns = <String>[
  'status',
  'approval_status',
  'admin_approval_status',
];

const List<String> optionalProductColumns = <String>[
  'approved_by',
  'sub_category_id',
  'pricing_mode',
  'base_price',
  'specifications',
  'preparation_time',
  'pricing_type',
  'portion_price',
  'price_per_kg',
  'size_options',
  'selected_size_name',
  'selected_size_price',
  'service_control_type',
  'min_portion',
  'max_portion',
  'portion_step',
  'default_weight_grams',
  'min_weight_grams',
  'weight_step_grams',
  'max_weight_grams',
  'additional_info',
  'faq',
  'accessories',
  'video_path',
  'video_public_url',
  'thumbnail_path',
  'thumbnail_public_url',
  'video_duration_seconds',
  'video_size_bytes',
  'thumbnail_size_bytes',
  'video_status',
  'variant_options',
  'variant_group_id',
  'variants',
  'sale_price',
  'updated_at',
  'store_id',
];

void stripOptionalProductColumns(Map<String, dynamic> data) {
  for (final column in optionalProductColumns) {
    data.remove(column);
  }
}

bool isOptionalProductColumnError(String message) {
  for (final column in optionalProductColumns) {
    if (message.contains(column)) return true;
  }
  return false;
}

const String mapStoreSelectMinimal =
    'seller_id, business_name, store_lat, store_lng, category, address, city, '
    'district, logo_url, phone, email, rating, created_at';

const String mapStoreSelectBase =
    'seller_id, business_name, store_lat, store_lng, category, address, city, '
    'district, logo_url, gallery_images, banners, follower_count, rating, '
    'created_at, phone, email';

const String mapStoreDescriptionColumn = 'description';

const String mapStoreBrandVerifiedColumn = 'is_brand_verified';

String mapStoreSelect({
  required bool includeBrandVerified,
  bool includeDescription = true,
}) {
  final parts = <String>[
    ...mapStoreSelectBase.split(',').map((part) => part.trim()),
    if (includeDescription) mapStoreDescriptionColumn,
    if (includeBrandVerified) mapStoreBrandVerifiedColumn,
  ];
  return parts.join(', ');
}

/// Harita popup ana metni — adres alanına düşmez.
String resolveMapStoreBio(Map<String, dynamic> store) {
  final description = store[mapStoreDescriptionColumn]?.toString().trim() ?? '';
  if (description.isNotEmpty) return description;

  final slogan = store['slogan']?.toString().trim() ?? '';
  if (slogan.isNotEmpty) return slogan;

  return '';
}

const String mapStoreBioFallback =
    'Bu mağaza yakındaki işletmeler arasında listeleniyor.';

/// Popup altındaki küçük adres satırı.
String formatMapStoreAddress({
  String? address,
  String? district,
  String? city,
}) {
  final parts = <String>[
    address?.trim() ?? '',
    district?.trim() ?? '',
    city?.trim() ?? '',
  ].where((part) => part.isNotEmpty).toList(growable: false);

  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts.first;

  final street = parts.first;
  final region = parts.sublist(1).join(', ');
  if (street.isEmpty) return region;
  if (region.isEmpty) return street;
  return '$street, $region';
}

String buildGoogleMapsNavigationUrl({
  required double latitude,
  required double longitude,
  double? originLatitude,
  double? originLongitude,
}) {
  final destination = '$latitude,$longitude';
  if (originLatitude != null && originLongitude != null) {
    return 'https://www.google.com/maps/dir/?api=1'
        '&origin=$originLatitude,$originLongitude'
        '&destination=$destination&travelmode=driving';
  }
  return 'https://www.google.com/maps/search/?api=1&query=$destination';
}

String buildAppleMapsNavigationUrl({
  required double latitude,
  required double longitude,
  bool directions = false,
}) {
  final coords = '$latitude,$longitude';
  if (directions) {
    return 'http://maps.apple.com/?daddr=$coords';
  }
  return 'http://maps.apple.com/?q=$coords';
}

bool isMissingDbColumnError(Object error, String column) {
  final message = error.toString().toLowerCase();
  final normalizedColumn = column.toLowerCase();
  if (!message.contains(normalizedColumn)) return false;
  return message.contains('does not exist') ||
      message.contains('could not find') ||
      message.contains('unknown column') ||
      (message.contains('column') && message.contains('not exist'));
}

List<Map<String, dynamic>> normalizeMapStoreRows(
  List<Map<String, dynamic>> rows, {
  required bool brandVerifiedAvailable,
}) {
  if (brandVerifiedAvailable) return rows;
  return rows
      .map((row) {
        final copy = Map<String, dynamic>.from(row);
        copy[mapStoreBrandVerifiedColumn] = false;
        return copy;
      })
      .toList(growable: false);
}

/// Column name aliases we try when reading a store's latitude, in priority
/// order. Different environments/migrations have used different names, so we
/// map all of them to `store_lat`/`store_lng` used by the map UI.
const List<String> mapStoreLatitudeAliases = <String>[
  'store_lat',
  'latitude',
  'lat',
  'location_lat',
  'store_latitude',
  'address_lat',
];

const List<String> mapStoreLongitudeAliases = <String>[
  'store_lng',
  'longitude',
  'lng',
  'location_lng',
  'store_longitude',
  'address_lng',
];

/// Parses a coordinate that may arrive as num, String ("36,2" or "36.2"),
/// or null. Returns null when it cannot be interpreted as a finite double.
double? parseStoreCoordinate(Object? raw) {
  if (raw == null) return null;
  if (raw is num) {
    final value = raw.toDouble();
    return value.isFinite ? value : null;
  }
  var text = raw.toString().trim();
  if (text.isEmpty) return null;
  // Some locales serialize decimals with a comma.
  if (text.contains(',') && !text.contains('.')) {
    text = text.replaceAll(',', '.');
  }
  final value = double.tryParse(text);
  if (value == null || !value.isFinite) return null;
  return value;
}

/// Resolves a store's latitude/longitude from any of the supported column
/// aliases, tolerating string values. Returns null when either is missing.
({double lat, double lng})? resolveStoreLatLng(Map<String, dynamic> store) {
  double? lat;
  for (final key in mapStoreLatitudeAliases) {
    if (store.containsKey(key)) {
      lat = parseStoreCoordinate(store[key]);
      if (lat != null) break;
    }
  }
  double? lng;
  for (final key in mapStoreLongitudeAliases) {
    if (store.containsKey(key)) {
      lng = parseStoreCoordinate(store[key]);
      if (lng != null) break;
    }
  }
  if (lat == null || lng == null) return null;
  // Reject obviously invalid coordinates (0,0 or out of range).
  if (lat.abs() > 90 || lng.abs() > 180) return null;
  if (lat == 0 && lng == 0) return null;
  return (lat: lat, lng: lng);
}

/// Known city/district centers for stores missing pin coordinates.
const Map<String, ({double lat, double lng})> mapCityCenterCoordinates =
    <String, ({double lat, double lng})>{
      'hatay': (lat: 36.2021, lng: 36.1606),
      'antakya': (lat: 36.2025, lng: 36.1605),
      'defne': (lat: 36.1967, lng: 36.1572),
      'iskenderun': (lat: 36.5872, lng: 36.1733),
      'samandag': (lat: 36.0851, lng: 35.9796),
      'istanbul': (lat: 41.0082, lng: 28.9784),
      'ankara': (lat: 39.9334, lng: 32.8597),
      'izmir': (lat: 38.4237, lng: 27.1428),
    };

String _normalizeMapLocationKey(String? value) {
  return (value ?? '')
      .trim()
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');
}

double _coordinateJitter(String seed, {required bool latitude}) {
  final hash = Object.hash(seed, latitude);
  return ((hash % 1000) / 1000.0 - 0.5) * 0.018;
}

/// Resolves coordinates from store fields, then city/district center fallback.
({double lat, double lng, bool fromCityFallback})? resolveStoreLatLngWithFallback(
  Map<String, dynamic> store, {
  int disambiguationIndex = 0,
}) {
  final direct = resolveStoreLatLng(store);
  if (direct != null) {
    return (lat: direct.lat, lng: direct.lng, fromCityFallback: false);
  }

  final district = _normalizeMapLocationKey(store['district']?.toString());
  final city = _normalizeMapLocationKey(store['city']?.toString());
  final seed =
      store['seller_id']?.toString() ??
      store['business_name']?.toString() ??
      '$disambiguationIndex';

  for (final key in <String>[district, city]) {
    if (key.isEmpty) continue;
    final center = mapCityCenterCoordinates[key];
    if (center == null) continue;
    return (
      lat: center.lat + _coordinateJitter('$seed|lat', latitude: true),
      lng: center.lng + _coordinateJitter('$seed|lng', latitude: false),
      fromCityFallback: true,
    );
  }

  // Default Antakya/Hatay region when store exists but has no geo metadata.
  return (
    lat: 36.2025 +
        _coordinateJitter('$seed|default-lat', latitude: true) +
        (disambiguationIndex * 0.0007),
    lng: 36.1605 +
        _coordinateJitter('$seed|default-lng', latitude: false) +
        (disambiguationIndex * 0.0007),
    fromCityFallback: true,
  );
}

Set<String> stripUnsupportedProductColumns(
  Map<String, dynamic> data,
  String message,
) {
  final removedColumns = <String>{};

  for (final column in optionalProductColumns) {
    if (message.contains(column) && data.containsKey(column)) {
      data.remove(column);
      removedColumns.add(column);
    }
  }

  if (removedColumns.isNotEmpty) {
    return removedColumns;
  }

  for (final column in optionalProductColumns) {
    if (data.containsKey(column)) {
      data.remove(column);
      removedColumns.add(column);
    }
  }

  return removedColumns;
}

SellerProduct mapSnakeCaseToProduct(Map<String, dynamic> data) {
  final map = {
    'id': data['id'],
    'name': data['name'],
    'brand': data['brand'],
    'store_name': data['store_name'],
    'mainCategory': data['main_category'],
    'subCategoryId': data['sub_category_id'],
    'subCategory': data['sub_category'],
    'price': data['price'],
    'pricing_mode': data['pricing_mode'],
    'base_price': data['base_price'],
    'pricing_type': data['pricing_type'],
    'portion_price': data['portion_price'],
    'price_per_kg': data['price_per_kg'],
    'size_options': data['size_options'],
    'selected_size_name': data['selected_size_name'],
    'selected_size_price': data['selected_size_price'],
    'service_control_type': data['service_control_type'],
    'min_portion': data['min_portion'],
    'max_portion': data['max_portion'],
    'portion_step': data['portion_step'],
    'default_weight_grams': data['default_weight_grams'],
    'min_weight_grams': data['min_weight_grams'],
    'weight_step_grams': data['weight_step_grams'],
    'max_weight_grams': data['max_weight_grams'],
    'discountPrice': data['discount_price'],
    'stock': data['stock'],
    'sku': data['sku'],
    'status': data['status'],
    'image_url': data['image_url'],
    'image_urls': data['image_urls'],
    'description': data['description'],
    'specifications': data['specifications'],
    'product_type': data['product_type'],
    'preparation_time': data['preparation_time'],
    'created_at': data['created_at'],
    'attributes': data['attributes'],
    'video_url': data['video_url'],
    'video_path': data['video_path'],
    'video_public_url': data['video_public_url'],
    'thumbnail_path': data['thumbnail_path'],
    'thumbnail_public_url': data['thumbnail_public_url'],
    'video_duration_seconds': data['video_duration_seconds'],
    'video_size_bytes': data['video_size_bytes'],
    'thumbnail_size_bytes': data['thumbnail_size_bytes'],
    'video_status': data['video_status'],
    'variants': data['variants'],
    'accessories': data['accessories'],
    'additional_info': data['additional_info'],
    'faq': data['faq'],
  };

  return SellerProduct.fromMap(map, data['id'].toString());
}
