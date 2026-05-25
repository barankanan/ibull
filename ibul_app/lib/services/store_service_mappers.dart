import 'dart:convert';

class StoreServiceMappers {
  const StoreServiceMappers._();

  static dynamic _serializeSpecifications(Object? specifications) {
    if (specifications == null) return null;
    if (specifications is Map || specifications is List) {
      return specifications;
    }
    final text = specifications.toString().trim();
    if (text.isEmpty) return null;
    try {
      return jsonDecode(text);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> storeToCamelCase(Map<String, dynamic> data) {
    return {
      'storeName': data['business_name'],
      'storeUrl': data['website'],
      'description': data['description'],
      'slogan': data['slogan'],
      'phone': data['phone'],
      'email': data['email'],
      'whatsapp': data['whatsapp'],
      'supportPhone': data['support_phone'],
      'address': data['address'],
      'postalCode': data['postal_code'],
      'taxNumber': data['tax_number'],
      'taxOffice': null,
      'companyName': data['business_name'],
      'instagram': data['instagram'],
      'facebook': data['facebook'],
      'twitter': data['twitter'],
      'website': data['website'],
      'city': data['city'],
      'district': data['district'],
      'companyType': data['business_type'],
      'workingHours': data['working_hours'],
      'isStoreOpen': data['is_store_open'],
      'acceptNewOrders': data['accept_new_orders'],
      'allowMessaging': data['allow_messaging'],
      'isHolidayMode': data['is_holiday_mode'],
      'logoUrl': data['logo_url'],
      'coverUrl': data['cover_url'],
      'galleryImages': data['gallery_images'],
      'banners': data['banners'],
      'sellerVideos': data['seller_videos'],
      'storeLat': data['store_lat'],
      'storeLng': data['store_lng'],
      'category': data['category'],
      'rating': (data['rating'] as num?)?.toDouble() ?? 0.0,
      'isVerified': data['is_verified'] == true,
    };
  }

  static Map<String, dynamic> storeToSnakeCase(Map<String, dynamic> data) {
    final map = <String, dynamic>{
      'business_name': data['storeName'] ?? data['companyName'],
      'description': data['description'],
      'slogan': data['slogan'],
      'phone': data['phone'],
      'email': data['email'],
      'whatsapp': data['whatsapp'],
      'support_phone': data['supportPhone'],
      'address': data['address'],
      'postal_code': data['postalCode'],
      'tax_number': data['taxNumber'],
      'instagram': data['instagram'],
      'facebook': data['facebook'],
      'twitter': data['twitter'],
      'website': data['website'],
      'city': data['city'],
      'district': data['district'],
      'business_type': data['companyType'],
      'working_hours': data['workingHours'],
      'is_store_open': data['isStoreOpen'],
      'accept_new_orders': data['acceptNewOrders'],
      'allow_messaging': data['allowMessaging'],
      'is_holiday_mode': data['isHolidayMode'],
      'logo_url': data['logoUrl'],
      'cover_url': data['coverUrl'],
      'gallery_images': data['galleryImages'],
      'banners': data['banners'],
      'seller_videos': data['sellerVideos'],
    };
    if (data['storeLat'] != null) {
      map['store_lat'] = data['storeLat'];
    }
    if (data['storeLng'] != null) {
      map['store_lng'] = data['storeLng'];
    }
    if (data['category'] != null) {
      map['category'] = data['category'];
    }
    return map;
  }

  static Map<String, dynamic> productToSnakeCase(Map<String, dynamic> data) {
    return {
      'id': data['id'],
      'name': data['name'],
      'brand': data['brand'],
      'main_category': data['mainCategory'],
      'sub_category': data['subCategory'],
      'price': data['price'],
      'pricing_mode': data['pricingMode'],
      'base_price': data['basePrice'] ?? data['portionPrice'],
      'pricing_type': data['pricingType'],
      'portion_price': data['portionPrice'],
      'price_per_kg': data['pricePerKg'],
      'size_options': data['sizeOptions'],
      'selected_size_name': data['selectedSizeName'],
      'selected_size_price': data['selectedSizePrice'],
      'service_control_type': data['serviceControlType'],
      'min_portion': data['minPortion'],
      'max_portion': data['maxPortion'],
      'portion_step': data['portionStep'],
      'default_weight_grams': data['defaultWeightGrams'],
      'min_weight_grams': data['minWeightGrams'],
      'weight_step_grams': data['weightStepGrams'],
      'max_weight_grams': data['maxWeightGrams'],
      'discount_price': data['discountPrice'],
      'stock': data['stock'],
      'sku': data['sku'],
      'status': data['status'],
      'image_url': data['imageUrl'],
      'image_urls': data['imageUrls'],
      'description': data['description'],
      'specifications': _serializeSpecifications(data['specifications']),
      if (data['productType'] != null)
        'product_type': data['productType'],
      'preparation_time': data['preparationTime'],
      'created_at': DateTime.now().toIso8601String(),
      'attributes': data['attributes'] ?? [],
      'video_url': data['videoPublicUrl'] ?? data['videoUrl'],
      'video_path': data['videoPath'],
      'video_public_url': data['videoPublicUrl'],
      'thumbnail_path': data['thumbnailPath'],
      'thumbnail_public_url': data['thumbnailPublicUrl'],
      'video_duration_seconds': data['videoDurationSeconds'],
      'video_size_bytes': data['videoSizeBytes'],
      'thumbnail_size_bytes': data['thumbnailSizeBytes'],
      'video_status': data['videoStatus'],
      'variants': data['variants'],
      'accessories': data['accessories'],
      'additional_info': data['additionalInfoItems'] ?? data['additional_info'],
      'faq': data['faq'],
      'station_id': data['stationId'],
      'printer_routing_enabled': data['printerRoutingEnabled'] ?? true,
    };
  }
}
