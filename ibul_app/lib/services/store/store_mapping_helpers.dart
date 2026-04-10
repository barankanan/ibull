import '../../models/seller_product.dart';

const List<String> optionalProductColumns = <String>[
  'specifications',
  'preparation_time',
  'pricing_type',
  'portion_price',
  'price_per_kg',
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
    'subCategory': data['sub_category'],
    'price': data['price'],
    'pricing_type': data['pricing_type'],
    'portion_price': data['portion_price'],
    'price_per_kg': data['price_per_kg'],
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
