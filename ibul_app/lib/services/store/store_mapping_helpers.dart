import '../../models/seller_product.dart';

void stripOptionalProductColumns(Map<String, dynamic> data) {
  const optionalColumns = <String>[
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
  for (final column in optionalColumns) {
    data.remove(column);
  }
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
    'discountPrice': data['discount_price'],
    'stock': data['stock'],
    'sku': data['sku'],
    'status': data['status'],
    'image_url': data['image_url'],
    'image_urls': data['image_urls'],
    'description': data['description'],
    'specifications': data['specifications'],
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
