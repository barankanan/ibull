/// Supabase / JSON map alanlarını güvenli okumak için küçük yardımcılar.
library;

String readString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }
  if (value is num || value is bool) {
    return value.toString();
  }
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

String? readNullableString(dynamic value) {
  if (value == null) return null;
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (value is num || value is bool) {
    return value.toString();
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int readInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double readDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

List<String> readStringList(dynamic value) {
  if (value == null) return const [];
  if (value is List) {
    return value
        .map((entry) => readNullableString(entry))
        .whereType<String>()
        .toList(growable: false);
  }
  final single = readNullableString(value);
  return single == null ? const [] : [single];
}

Map<String, String> readStringMap(dynamic value) {
  if (value is! Map) return const {};
  return value.map(
    (key, entryValue) => MapEntry(key.toString(), readString(entryValue)),
  );
}

Map<String, dynamic> normalizeProductCartItem(Map<String, dynamic> row) {
  final normalized = Map<String, dynamic>.from(row);
  const nullableStringKeys = <String>[
    'oldPrice',
    'old_price',
    'store',
    'store_name',
    'category',
    'main_category',
    'subCategory',
    'sub_category',
    'variantOptions',
    'variant_options',
    'variantGroupId',
    'variant_group_id',
    'description',
    'additional_info',
    'video_status',
    'shortDescription',
    'short_description',
    'preparationTime',
    'preparation_time',
    'cookingTime',
    'cooking_time',
  ];

  normalized['name'] = readString(normalized['name']);
  normalized['brand'] = readString(normalized['brand']);
  normalized['price'] = readString(
    normalized['price'] ?? normalized['portion_price'],
    fallback: '0',
  );

  for (final key in nullableStringKeys) {
    if (!normalized.containsKey(key)) continue;
    normalized[key] = readNullableString(normalized[key]);
  }

  return normalized;
}

bool looksLikeTechnicalOrderToken(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return true;

  final upper = trimmed.toUpperCase();
  if (upper.startsWith('TBL-')) return true;

  final uuidLike = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
  if (uuidLike.hasMatch(trimmed)) return true;

  if (RegExp(r'^[0-9a-f-]{20,}$', caseSensitive: false).hasMatch(trimmed)) {
    return true;
  }

  return false;
}

String resolveOrderProductTitle({
  Map<String, dynamic>? primaryItem,
  Map<String, dynamic>? order,
  Iterable<Map<String, dynamic>> extraItems = const [],
  String fallback = 'Sipariş',
}) {
  final names = <String>[];

  void addName(dynamic raw) {
    final name = readNullableString(raw);
    if (name == null || looksLikeTechnicalOrderToken(name)) return;
    if (!names.contains(name)) {
      names.add(name);
    }
  }

  addName(primaryItem?['product_name']);
  addName(order?['product_name']);
  for (final item in extraItems) {
    addName(item['product_name']);
  }

  if (names.isEmpty) return fallback;
  return names.first;
}

Map<String, dynamic> normalizeOrderIdentityFields(
  Map<String, dynamic> row,
) {
  final normalized = Map<String, dynamic>.from(row);
  const stringKeys = <String>{
    'id',
    'order_id',
    'seller_id',
    'customer_id',
    'product_id',
    'order_number',
    'tracking_number',
    'product_code',
    'product_name',
    'secondary_product_name',
    'third_product_name',
    'cargo_company',
    'delivery_type',
    'delivery_slot',
    'order_type',
    'restaurant_id',
    'table_id',
    'waiter_id',
    'store_name',
    'product_image_url',
    'customer_name',
    'customer_email',
    'customer_phone',
    'status',
    'order_status',
    'shipment_step',
    'order_created_at',
    'created_at',
  };

  for (final key in stringKeys) {
    if (!normalized.containsKey(key)) continue;
    final value = normalized[key];
    if (value == null) continue;
    normalized[key] = readNullableString(value);
  }

  if (normalized.containsKey('quantity')) {
    normalized['quantity'] = readInt(normalized['quantity'], fallback: 1);
  }
  if (normalized.containsKey('item_count')) {
    normalized['item_count'] = readInt(normalized['item_count'], fallback: 1);
  }
  for (final amountKey in ['total_price', 'unit_price', 'order_total_amount']) {
    if (normalized.containsKey(amountKey)) {
      normalized[amountKey] = readDouble(normalized[amountKey]);
    }
  }

  return normalized;
}

/// [OrderDetailPage] expects `orderData['rawOrder']`; Siparişlerim listesi bu
/// sarmalayıcıyı `_mapRealOrderForUi` ile üretir.
Map<String, dynamic> wrapOrderForDetailPage(Map<String, dynamic> rawOrder) {
  return {'rawOrder': rawOrder};
}

/// Supabase `users` satırını uygulama içi profil map'ine normalize eder.
Map<String, dynamic> normalizeUserProfileForApp(Map<String, dynamic>? raw) {
  if (raw == null || raw.isEmpty) return const {};

  final profile = Map<String, dynamic>.from(raw);
  final photoUrl = readNullableString(
    profile['photo_url'] ?? profile['photoURL'],
  );
  if (photoUrl != null) {
    profile['photo_url'] = photoUrl;
    profile['photoURL'] = photoUrl;
  }

  final birthDate = readNullableString(
    profile['birth_date'] ?? profile['birthDate'],
  );
  if (birthDate != null) {
    profile['birth_date'] = birthDate;
    profile['birthDate'] = birthDate;
  }

  final displayName = readNullableString(
    profile['display_name'] ?? profile['displayName'] ?? profile['name'],
  );
  if (displayName != null) {
    profile['display_name'] = displayName;
    profile['displayName'] = displayName;
    profile['name'] = displayName;
  }

  final phone = readNullableString(profile['phone']);
  if (phone != null) {
    profile['phone'] = phone;
  }

  for (final key in ['gender', 'style', 'address']) {
    final value = readNullableString(profile[key]);
    if (value != null) {
      profile[key] = value;
    }
  }

  if (profile['height'] != null) {
    profile['height'] = readDouble(profile['height']);
  }
  if (profile['weight'] != null) {
    profile['weight'] = readDouble(profile['weight']);
  }

  return profile;
}
