import '../../models/seller_product.dart';

const List<String> optionalProductColumns = <String>[
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
