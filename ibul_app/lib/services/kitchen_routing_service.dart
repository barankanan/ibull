import 'package:flutter/foundation.dart';

import '../models/mixed_service_order.dart';
import '../utils/garson_product_selection.dart';
import 'kitchen_print_trace_log.dart';

void kitchenRoutingLog(String stage, {Map<String, Object?>? extra}) {
  if (extra != null && extra.isNotEmpty) {
    kitchenTraceJsonLog('KitchenRouting', stage, extra);
    return;
  }
  if (!kDebugMode) return;
  debugPrint('[KitchenRouting] $stage');
}

void kitchenPrintPayloadLog(String stage, {Map<String, Object?>? extra}) {
  if (extra != null && extra.isNotEmpty) {
    kitchenTraceJsonLog('KitchenPrintPayload', stage, extra);
    return;
  }
  if (!kDebugMode) return;
  debugPrint('[KitchenPrintPayload] $stage');
}

/// Production station label used when no kitchen routing match exists.
const String kKitchenGeneralStationLabel = 'Genel';

void productStationMappingLog(String stage, {Map<String, Object?>? extra}) {
  if (extra != null && extra.isNotEmpty) {
    kitchenTraceJsonLog('ProductStationMapping', stage, extra);
    if (stage == 'loaded') {
      logProductStationMappingLoaded(
        productId: extra['productId']?.toString() ?? '',
        productName: extra['productName']?.toString() ?? '',
        stationId: extra['stationId']?.toString() ?? '',
        stationName: extra['stationName']?.toString() ?? '',
        stationCode: extra['stationCode']?.toString() ?? '',
        source: extra['source']?.toString() ?? 'unknown',
      );
    }
    return;
  }
  if (!kDebugMode) return;
  debugPrint('[ProductStationMapping] $stage');
}

void garsonOrderItemLog(String stage, {Map<String, Object?>? extra}) {
  if (extra != null && extra.isNotEmpty) {
    kitchenTraceJsonLog('GarsonOrderItem', stage, extra);
    return;
  }
  if (!kDebugMode) return;
  debugPrint('[GarsonOrderItem] $stage');
}

/// Ürün Eşleme ekranından gelen üretim alanı (Ocak / Fırın / Kasap).
class ProductStationMapping {
  const ProductStationMapping({
    required this.stationId,
    required this.stationName,
    this.stationCode = '',
  });

  final String stationId;
  /// Üretim alanı etiketi (fiş başlığı); tercihen station code (OCAK).
  final String stationName;
  final String stationCode;
}

extension ProductStationMappingHeader on ProductStationMapping {
  String get headerLabel => KitchenTicketHeaderResolver.productionHeaderLabel(
    stationName: stationName,
    stationCode: stationCode,
  );
}

/// Resolves mutfak fişi başlığı from item/payload metadata only — never masa alanı.
class KitchenTicketHeaderResolver {
  const KitchenTicketHeaderResolver._();

  static final Map<String, Map<String, ProductStationMapping>>
      _productMappingsByRestaurant = <String, Map<String, ProductStationMapping>>{};
  static final Map<String, Map<String, ProductStationMapping>>
      _productMappingsByNormalizedNameByRestaurant =
      <String, Map<String, ProductStationMapping>>{};
  static final Map<String, Map<String, String>> _stationNamesByRestaurant =
      <String, Map<String, String>>{};
  static final Map<String, Map<String, String>> _stationCodesByRestaurant =
      <String, Map<String, String>>{};

  static void registerRestaurantStationCaches({
    required String restaurantId,
    Map<String, String>? stationNamesById,
    Map<String, String>? stationCodesById,
  }) {
    final id = restaurantId.trim();
    if (id.isEmpty) return;
    if (stationNamesById != null && stationNamesById.isNotEmpty) {
      _stationNamesByRestaurant[id] = sanitizeStationNameMap(stationNamesById);
    }
    if (stationCodesById != null && stationCodesById.isNotEmpty) {
      _stationCodesByRestaurant[id] = Map<String, String>.from(
        stationCodesById.map(
          (key, value) => MapEntry(key, value.trim().toUpperCase()),
        ),
      );
    }
  }

  static Map<String, String>? stationNamesForRestaurant(String restaurantId) {
    final id = restaurantId.trim();
    if (id.isEmpty) return null;
    final cached = _stationNamesByRestaurant[id];
    if (cached == null || cached.isEmpty) return null;
    return Map<String, String>.from(cached);
  }

  static Map<String, String>? stationCodesForRestaurant(String restaurantId) {
    final id = restaurantId.trim();
    if (id.isEmpty) return null;
    final cached = _stationCodesByRestaurant[id];
    if (cached == null || cached.isEmpty) return null;
    return Map<String, String>.from(cached);
  }

  /// Ürün adı eşlemesi: trim, lower, Türkçe harf sadeleştirme.
  static String normalizeProductNameKey(String name) {
    var normalized = name.trim().toLowerCase();
    const turkishMap = <String, String>{
      'ı': 'i',
      'ğ': 'g',
      'ü': 'u',
      'ş': 's',
      'ö': 'o',
      'ç': 'c',
      'İ': 'i',
      'Ğ': 'g',
      'Ü': 'u',
      'Ş': 's',
      'Ö': 'o',
      'Ç': 'c',
    };
    final buffer = StringBuffer();
    for (final rune in normalized.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(turkishMap[char] ?? char);
    }
    normalized = buffer.toString();
    return normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static void registerRestaurantProductStationMappings(
    String restaurantId,
    Map<String, ProductStationMapping> mappings, {
    Map<String, String>? productNamesByProductId,
  }) {
    final id = restaurantId.trim();
    if (id.isEmpty) return;
    _productMappingsByRestaurant[id] = Map<String, ProductStationMapping>.from(
      mappings,
    );
    if (productNamesByProductId != null && productNamesByProductId.isNotEmpty) {
      final byName = Map<String, ProductStationMapping>.from(
        _productMappingsByNormalizedNameByRestaurant[id] ??
            const <String, ProductStationMapping>{},
      );
      for (final entry in productNamesByProductId.entries) {
        final mapping = mappings[entry.key];
        final nameKey = normalizeProductNameKey(entry.value);
        if (mapping != null && nameKey.isNotEmpty) {
          byName[nameKey] = mapping;
        }
      }
      _productMappingsByNormalizedNameByRestaurant[id] = byName;
    }
  }

  /// Bellek önbelleğindeki normalize ürün adı → istasyon eşlemelerini birleştirir.
  static void mergeProductNameMappings(
    String restaurantId,
    Map<String, ProductStationMapping> mappingsByNormalizedName,
  ) {
    final id = restaurantId.trim();
    if (id.isEmpty || mappingsByNormalizedName.isEmpty) return;
    final merged = Map<String, ProductStationMapping>.from(
      _productMappingsByNormalizedNameByRestaurant[id] ??
          const <String, ProductStationMapping>{},
    )..addAll(mappingsByNormalizedName);
    _productMappingsByNormalizedNameByRestaurant[id] = merged;
  }

  /// Tek ürün eşlemesi (Ürün Eşleme kaydı sonrası hub cache güncellemesi).
  static void registerSingleProductStationMapping({
    required String restaurantId,
    required String productId,
    required String productName,
    required ProductStationMapping mapping,
  }) {
    final id = restaurantId.trim();
    final pid = productId.trim();
    if (id.isEmpty || pid.isEmpty) return;
    final byId = Map<String, ProductStationMapping>.from(
      _productMappingsByRestaurant[id] ?? const <String, ProductStationMapping>{},
    )..[pid] = mapping;
    _productMappingsByRestaurant[id] = byId;
    final nameKey = normalizeProductNameKey(productName);
    if (nameKey.isNotEmpty) {
      final byName = Map<String, ProductStationMapping>.from(
        _productMappingsByNormalizedNameByRestaurant[id] ??
            const <String, ProductStationMapping>{},
      )..[nameKey] = mapping;
      _productMappingsByNormalizedNameByRestaurant[id] = byName;
    }
  }

  static ProductStationMapping? productMappingForHubItem({
    required String restaurantId,
    String? productId,
    String? productName,
  }) {
    final id = restaurantId.trim();
    if (id.isEmpty) return null;
    final pid = productId?.trim() ?? '';
    if (pid.isNotEmpty) {
      final fromId = _productMappingsByRestaurant[id]?[pid];
      if (fromId != null) return fromId;
    }
    final pname = productName?.trim() ?? '';
    if (pname.isEmpty) return null;
    final byName = _productMappingsByNormalizedNameByRestaurant[id];
    if (byName == null || byName.isEmpty) return null;

    return byName[normalizeProductNameKey(pname)];
  }

  static Map<String, ProductStationMapping>? productMappingsForRestaurant(
    String restaurantId,
  ) {
    final id = restaurantId.trim();
    if (id.isEmpty) return null;
    return _productMappingsByRestaurant[id];
  }

  static List<String> productNameKeysForRestaurant(String restaurantId) {
    final id = restaurantId.trim();
    final cached = _productMappingsByNormalizedNameByRestaurant[id];
    if (cached == null || cached.isEmpty) return const <String>[];
    final keys = cached.keys.toList()..sort();
    return keys;
  }

  /// print_jobs / garson item alanlarından ürün adı.
  static String extractKitchenItemProductName(Map<String, dynamic> item) {
    for (final key in <String>[
      'product_name',
      'name',
      'item_name',
      'display_name',
      'productName',
    ]) {
      final value = _text(item[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static bool isDiningAreaStationLabel(String name) {
    final lower = name.trim().toLowerCase();
    if (lower.isEmpty) return false;
    if (lower.contains('masa alan') ||
        lower == 'dining' ||
        lower == 'dining area') {
      return true;
    }
    const diningTokens = <String>[
      'salon',
      'bahçe',
      'bahce',
      'teras',
      'balkon',
      'veranda',
      'lounge',
      'cafe',
      'café',
      'iç mekan',
      'ic mekan',
      'dış mekan',
      'dis mekan',
    ];
    for (final token in diningTokens) {
      if (lower == token ||
          lower.startsWith('$token ') ||
          lower.endsWith(' $token') ||
          lower.contains(' $token ')) {
        return true;
      }
    }
    return false;
  }

  static String sanitizeProductionStationName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || isDiningAreaStationLabel(trimmed)) {
      return kKitchenGeneralStationLabel;
    }
    return trimmed;
  }

  /// Mutfak fişi üst başlığı: önce üretim kodu (OCAK), yoksa üretim adı.
  static String productionHeaderLabel({
    required String stationName,
    String stationCode = '',
  }) {
    final code = sanitizeProductionStationName(stationCode);
    if (code != kKitchenGeneralStationLabel) {
      return code.toUpperCase();
    }
    final name = sanitizeProductionStationName(stationName);
    if (name == kKitchenGeneralStationLabel) {
      return kKitchenGeneralStationLabel;
    }
    return name.toUpperCase();
  }

  static String _text(dynamic value) => value?.toString().trim() ?? '';

  /// "Salon 1" → "Salon" (yalnızca masa alanı; fiş başlığı değil).
  static String? diningAreaFromTableLabel(String? tableLabel) {
    final text = _text(tableLabel);
    if (text.isEmpty) return null;
    final first = text.split(RegExp(r'\s+')).first;
    return isDiningAreaStationLabel(first) ? first : null;
  }

  static List<Map<String, dynamic>> kitchenItemsFromPayload(
    Map<String, dynamic> payload,
  ) {
    final rawItems = payload['items'];
    if (rawItems is! List) return const <Map<String, dynamic>>[];
    return rawItems
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  /// Bridge [area_name] alanını üretim istasyonu ile doldurur; masa alanını asla kullanmaz.
  static Map<String, dynamic> stampProductionHeaderOnKitchenPayload(
    Map<String, dynamic> payload, {
    Map<String, String>? stationNamesById,
    Map<String, String>? stationCodesById,
    Map<String, ProductStationMapping>? productStationByProductId,
  }) {
    final out = Map<String, dynamic>.from(payload);
    final rawItems = kitchenItemsFromPayload(out);
    final stationId = _text(out['station_id']);
    final payloadStationCode = _text(out['station_code']);
    final payloadStationName = _text(out['station_name']);
    final legacyAreaName = _text(out['area_name']);

    if (isDiningAreaStationLabel(legacyAreaName)) {
      out.remove('area_name');
      kitchenPrintPayloadLog(
        'reject_table_area_header',
        extra: {
          'area': legacyAreaName,
          'reason': 'legacy_area_name_is_dining_not_production',
        },
      );
    }

    String? overrideHeader;
    if (payloadStationCode.isNotEmpty) {
      final fromCode = productionHeaderLabel(
        stationName: '',
        stationCode: payloadStationCode,
      );
      if (fromCode != kKitchenGeneralStationLabel) {
        overrideHeader = fromCode;
      }
    }
    if (overrideHeader == null &&
        payloadStationName.isNotEmpty &&
        !isDiningAreaStationLabel(payloadStationName)) {
      overrideHeader = productionHeaderLabel(stationName: payloadStationName);
    }

    final header = finalizeKitchenTicketHeader(
      overrideHeader: overrideHeader,
      rawItems: rawItems,
      payload: out,
      stationId: stationId,
      stationNamesById: stationNamesById,
      stationCodesById: stationCodesById,
      productStationByProductId: productStationByProductId,
      tableAreaName: _text(out['table_area_name']),
    );

    out['kitchen_ticket_header'] = header;
    out['station_name'] = header;
    out['area_name'] = header;
    kitchenPrintPayloadLog(
      'stamped_production_header',
      extra: {
        'header': header,
        'stationId': stationId.isEmpty ? '-' : stationId,
        'stationCode': payloadStationCode.isEmpty ? '-' : payloadStationCode,
        'itemCount': rawItems.length,
      },
    );
    return out;
  }

  /// Kesin mutfak başlığı: masa alanı asla dönmez.
  static String finalizeKitchenTicketHeader({
    String? overrideHeader,
    required List<Map<String, dynamic>> rawItems,
    Map<String, dynamic>? payload,
    String? stationId,
    Map<String, String>? stationNamesById,
    Map<String, String>? stationCodesById,
    Map<String, ProductStationMapping>? productStationByProductId,
    String? tableAreaName,
    String? restaurantId,
  }) {
    if (overrideHeader != null && overrideHeader.trim().isNotEmpty) {
      final fromOverride = productionHeaderLabel(stationName: overrideHeader);
      if (fromOverride != kKitchenGeneralStationLabel &&
          !isDiningAreaStationLabel(fromOverride)) {
        return fromOverride;
      }
    }

    var header = overrideHeader != null && overrideHeader.trim().isNotEmpty
        ? productionHeaderLabel(stationName: overrideHeader)
        : resolveKitchenTicketHeader(
            rawItems: rawItems,
            payload: payload,
            stationId: stationId,
            stationNamesById: stationNamesById,
            stationCodesById: stationCodesById,
            productStationByProductId: productStationByProductId,
            restaurantId: restaurantId,
          );

    final dining = sanitizeProductionStationName(tableAreaName ?? '');
    final headerLooksLikeTableArea = dining != kKitchenGeneralStationLabel &&
        header.toUpperCase() == dining.toUpperCase();

    if (isDiningAreaStationLabel(header) || headerLooksLikeTableArea) {
      header = kKitchenGeneralStationLabel;
      for (final item in rawItems) {
        ProductStationMapping? mapping;
        if (restaurantId != null && restaurantId.trim().isNotEmpty) {
          mapping = productMappingForHubItem(
            restaurantId: restaurantId,
            productId: _text(item['product_id']).isEmpty
                ? null
                : _text(item['product_id']),
            productName: extractKitchenItemProductName(item),
          );
        }
        mapping ??= productStationByProductId?[_text(item['product_id'])];
        if (mapping != null) {
          final mapped = mapping.headerLabel;
          if (mapped != kKitchenGeneralStationLabel) {
            header = mapped;
            break;
          }
        }
        final fromItem = _resolveFromProductMapping(
          item,
          productStationByProductId,
          restaurantId: restaurantId,
        );
        if (fromItem != null) {
          header = productionHeaderLabel(stationName: fromItem);
          break;
        }
      }
      if (stationId != null && stationId.trim().isNotEmpty) {
        final sid = stationId.trim();
        final fromId = productionHeaderLabel(
          stationName: stationNamesById?[sid] ?? '',
          stationCode: stationCodesById?[sid] ?? '',
        );
        if (fromId != kKitchenGeneralStationLabel &&
            !isDiningAreaStationLabel(fromId)) {
          header = fromId;
        }
      }
    }

    return header;
  }

  /// Priority: item.station_name → item.kitchen_station_name → cache(station_id)
  /// → product mapping → payload.kitchen_ticket_header → payload.station_name
  /// → [override] → Genel.
  static String resolveKitchenTicketHeader({
    required List<Map<String, dynamic>> rawItems,
    Map<String, dynamic>? payload,
    String? stationId,
    Map<String, String>? stationNamesById,
    Map<String, String>? stationCodesById,
    Map<String, ProductStationMapping>? productStationByProductId,
    String? overrideHeader,
    String? restaurantId,
  }) {
    if (overrideHeader != null && overrideHeader.trim().isNotEmpty) {
      return productionHeaderLabel(stationName: overrideHeader);
    }

    final tableAreaName = _text(payload?['table_area_name']);
    if (tableAreaName.isNotEmpty &&
        isDiningAreaStationLabel(tableAreaName)) {
      kitchenPrintPayloadLog(
        'reject_table_area_header',
        extra: {
          'area': tableAreaName,
          'reason': 'table_area_is_not_kitchen_station',
        },
      );
    }

    final payloadStationCode = _text(payload?['station_code']);
    if (payloadStationCode.isNotEmpty) {
      final fromPayloadCode = productionHeaderLabel(
        stationName: '',
        stationCode: payloadStationCode,
      );
      if (fromPayloadCode != kKitchenGeneralStationLabel) {
        return fromPayloadCode;
      }
    }

    for (final item in rawItems) {
      final fromItem = _resolveFromItemFields(
        item,
        stationNamesById,
        productStationByProductId: productStationByProductId,
        stationCodesById: stationCodesById,
        restaurantId: restaurantId,
      );
      if (fromItem != null) return fromItem;
    }

    final normalizedStationId = _text(stationId);
    if (normalizedStationId.isNotEmpty) {
      final fromPayloadStation = productionHeaderLabel(
        stationName: stationNamesById?[normalizedStationId] ?? '',
        stationCode: stationCodesById?[normalizedStationId] ?? '',
      );
      if (fromPayloadStation != kKitchenGeneralStationLabel) {
        return fromPayloadStation;
      }
    }

    for (final item in rawItems) {
      final sid = _text(item['station_id']);
      if (sid.isEmpty) continue;
      final mapped = sanitizeProductionStationName(
        stationNamesById?[sid] ?? '',
      );
      if (mapped != kKitchenGeneralStationLabel) {
        return mapped;
      }
    }

    for (final item in rawItems) {
      final fromProduct = _resolveFromProductMapping(
        item,
        productStationByProductId,
        restaurantId: restaurantId,
      );
      if (fromProduct != null) return fromProduct;
    }

    final payloadHeader = sanitizeProductionStationName(
      _text(payload?['kitchen_ticket_header']),
    );
    if (payloadHeader != kKitchenGeneralStationLabel) {
      return payloadHeader;
    }

    final payloadStation = sanitizeProductionStationName(
      _text(payload?['station_name']),
    );
    if (payloadStation != kKitchenGeneralStationLabel) {
      return payloadStation;
    }

    return kKitchenGeneralStationLabel;
  }

  static String? _resolveFromItemFields(
    Map<String, dynamic> item,
    Map<String, String>? stationNamesById, {
    Map<String, ProductStationMapping>? productStationByProductId,
    Map<String, String>? stationCodesById,
    String? restaurantId,
  }) {
    final itemCode = _text(item['station_code']);
    if (itemCode.isNotEmpty) {
      final fromCode = productionHeaderLabel(stationName: '', stationCode: itemCode);
      if (fromCode != kKitchenGeneralStationLabel) {
        return fromCode;
      }
    }
    for (final key in <String>['station_name', 'kitchen_station_name']) {
      final sanitized = sanitizeProductionStationName(_text(item[key]));
      if (sanitized != kKitchenGeneralStationLabel) {
        return sanitized;
      }
    }
    final sid = _text(item['station_id']);
    if (sid.isNotEmpty) {
      final fromId = productionHeaderLabel(
        stationName: stationNamesById?[sid] ?? '',
        stationCode: stationCodesById?[sid] ?? '',
      );
      if (fromId != kKitchenGeneralStationLabel) {
        return fromId;
      }
    }
    return _resolveFromProductMapping(
      item,
      productStationByProductId,
      restaurantId: restaurantId,
    );
  }

  static String? _resolveFromProductMapping(
    Map<String, dynamic> item,
    Map<String, ProductStationMapping>? productStationByProductId, {
    String? restaurantId,
  }) {
    final productId = _text(item['product_id']);
    final productName = extractKitchenItemProductName(item);
    ProductStationMapping? mapped;

    if (restaurantId != null && restaurantId.trim().isNotEmpty) {
      mapped = productMappingForHubItem(
        restaurantId: restaurantId,
        productId: productId.isEmpty ? null : productId,
        productName: productName.isEmpty ? null : productName,
      );
    }
    if (mapped == null &&
        productStationByProductId != null &&
        productId.isNotEmpty) {
      mapped = productStationByProductId[productId];
    }
    if (mapped == null) return null;
    final label = mapped.headerLabel;
    if (label == kKitchenGeneralStationLabel) return null;
    return label;
  }

  /// Gruplama / fiş başlığı için üretim alanı adı (masa alanı asla kullanılmaz).
  static String resolveProductionStationForItem({
    required Map<String, dynamic> item,
    required Map<String, String> stationNamesById,
    Map<String, ProductStationMapping>? productStationByProductId,
    Map<String, String>? stationCodesById,
  }) {
    final itemCode = _text(item['station_code']);
    if (itemCode.isNotEmpty) {
      final fromCode = productionHeaderLabel(stationName: '', stationCode: itemCode);
      if (fromCode != kKitchenGeneralStationLabel) {
        return fromCode;
      }
    }
    for (final key in <String>['station_name', 'kitchen_station_name']) {
      final sanitized = sanitizeProductionStationName(_text(item[key]));
      if (sanitized != kKitchenGeneralStationLabel) {
        return sanitized;
      }
    }
    final stationId = _text(item['station_id']);
    if (stationId.isNotEmpty) {
      final fromCache = productionHeaderLabel(
        stationName: stationNamesById[stationId] ?? '',
        stationCode: stationCodesById?[stationId] ?? '',
      );
      if (fromCache != kKitchenGeneralStationLabel) {
        return fromCache;
      }
    }
    final fromProduct = _resolveFromProductMapping(
      item,
      productStationByProductId,
    );
    if (fromProduct != null) {
      return productionHeaderLabel(stationName: fromProduct);
    }
    return kKitchenGeneralStationLabel;
  }

  /// Hub / print_jobs: cache-only üretim alanı çözümü (ağ yok).
  static HubItemProductionStationResolution resolveHubItemProductionStation({
    required String restaurantId,
    required String productId,
    required String productName,
    required Map<String, dynamic> item,
    String? jobStationId,
    required Map<String, String> stationNamesById,
    required Map<String, String> stationCodesById,
    required Map<String, ProductStationMapping> productMappings,
  }) {
    ProductStationMapping? mapping = productMappingForHubItem(
      restaurantId: restaurantId,
      productId: productId,
      productName: productName,
    );
    var source = 'none';
    if (mapping != null) {
      final foundById = productId.isNotEmpty &&
          (productMappings[productId] != null ||
              productMappingForHubItem(
                    restaurantId: restaurantId,
                    productId: productId,
                  ) !=
                  null);
      final foundByName = productName.isNotEmpty &&
          productMappingForHubItem(
                restaurantId: restaurantId,
                productName: productName,
              ) !=
              null;
      source = foundByName && !foundById
          ? 'product_name_mapping'
          : 'product_mapping_cache';
    }

    var stationId = item['station_id']?.toString().trim() ?? '';
    if (mapping != null && mapping.stationId.isNotEmpty) {
      stationId = mapping.stationId;
    } else if (stationId.isEmpty &&
        jobStationId != null &&
        jobStationId.trim().isNotEmpty) {
      stationId = jobStationId.trim();
      source = 'job_station_id';
    }

    if (mapping != null) {
      final label = mapping.headerLabel;
      if (label != kKitchenGeneralStationLabel) {
        return HubItemProductionStationResolution(
          stationId: stationId.isNotEmpty ? stationId : mapping.stationId,
          headerLabel: label,
          stationCode: mapping.stationCode.isNotEmpty
              ? mapping.stationCode
              : (stationCodesById[stationId] ?? label),
          source: source,
        );
      }
    }

    if (stationId.isNotEmpty) {
      final fromId = productionHeaderLabel(
        stationName: stationNamesById[stationId] ?? '',
        stationCode: stationCodesById[stationId] ?? '',
      );
      if (fromId != kKitchenGeneralStationLabel) {
        return HubItemProductionStationResolution(
          stationId: stationId,
          headerLabel: fromId,
          stationCode: stationCodesById[stationId] ?? fromId,
          source: source == 'none' ? 'item_station' : source,
        );
      }
    }

    final fromItem = resolveProductionStationForItem(
      item: item,
      stationNamesById: stationNamesById,
      productStationByProductId: productMappings,
      stationCodesById: stationCodesById,
    );
    if (fromItem != kKitchenGeneralStationLabel) {
      return HubItemProductionStationResolution(
        stationId: stationId,
        headerLabel: fromItem.toUpperCase(),
        stationCode:
            item['station_code']?.toString().trim().toUpperCase() ?? fromItem,
        source: 'item_station',
      );
    }

    return HubItemProductionStationResolution(
      stationId: stationId,
      headerLabel: kKitchenGeneralStationLabel,
      stationCode: kKitchenGeneralStationLabel,
      source: 'none',
    );
  }

  static String resolveProductionHeaderForItem({
    required Map<String, dynamic> item,
    required Map<String, String> stationNamesById,
    Map<String, String>? stationCodesById,
    Map<String, ProductStationMapping>? productStationByProductId,
  }) {
    final productId = _text(item['product_id']);
    final mapping =
        productId.isEmpty ? null : productStationByProductId?[productId];
    if (mapping != null) {
      final label = mapping.headerLabel;
      if (label != kKitchenGeneralStationLabel) {
        return label;
      }
    }
    final stationId = _text(item['station_id']);
    if (stationId.isNotEmpty) {
      final label = productionHeaderLabel(
        stationName: stationNamesById[stationId] ?? '',
        stationCode: stationCodesById?[stationId] ?? '',
      );
      if (label != kKitchenGeneralStationLabel) {
        return label;
      }
    }
    return resolveProductionStationForItem(
      item: item,
      stationNamesById: stationNamesById,
      productStationByProductId: productStationByProductId,
    ).toUpperCase();
  }

  static Map<String, String> sanitizeStationNameMap(
    Map<String, String> namesById,
  ) {
    return Map<String, String>.fromEntries(
      namesById.entries.map(
        (entry) => MapEntry(
          entry.key,
          sanitizeProductionStationName(entry.value),
        ),
      ),
    );
  }

  /// Fills [station_id] / [station_name] on order items from cache (no network).
  static List<Map<String, dynamic>> enrichItemsWithProductionStations({
    required List<Map<String, dynamic>> items,
    required Map<String, String> stationNamesById,
    Map<String, String>? stationCodesById,
    Map<String, String>? productStationIdByProductId,
    Map<String, ProductStationMapping>? productStationByProductId,
    String? tableAreaName,
    String? restaurantId,
  }) {
    final sanitizedCache = sanitizeStationNameMap(stationNamesById);
    final codesById = stationCodesById ?? const <String, String>{};
    final mappingByProduct = <String, ProductStationMapping>{
      if (productStationByProductId != null) ...productStationByProductId,
    };
    if (productStationIdByProductId != null) {
      for (final entry in productStationIdByProductId.entries) {
        final productId = entry.key.trim();
        final stationId = entry.value.trim();
        if (productId.isEmpty || stationId.isEmpty) continue;
        mappingByProduct.putIfAbsent(
          productId,
          () => ProductStationMapping(
            stationId: stationId,
            stationName: sanitizeProductionStationName(
              sanitizedCache[stationId] ?? '',
            ),
            stationCode: codesById[stationId] ?? '',
          ),
        );
      }
    }

    return items.map((raw) {
      final item = Map<String, dynamic>.from(raw);
      var stationId = _text(item['station_id']);
      final productId = _text(item['product_id']);
      var source = 'item';
      var productMapping =
          productId.isEmpty ? null : mappingByProduct[productId];
      if (productMapping == null &&
          restaurantId != null &&
          restaurantId.trim().isNotEmpty) {
        productMapping = productMappingForHubItem(
          restaurantId: restaurantId,
          productId: productId.isEmpty ? null : productId,
          productName: extractKitchenItemProductName(item),
        );
      }

      var stationName = sanitizeProductionStationName(
        _text(item['station_name']),
      );
      if (stationName == kKitchenGeneralStationLabel) {
        stationName = sanitizeProductionStationName(
          _text(item['kitchen_station_name']),
        );
      }

      if (stationId.isNotEmpty) {
        final cacheName = sanitizeProductionStationName(
          sanitizedCache[stationId] ?? '',
        );
        if (stationName == kKitchenGeneralStationLabel &&
            cacheName != kKitchenGeneralStationLabel) {
          stationName = cacheName;
          source = 'station_cache';
        } else if (isDiningAreaStationLabel(stationName) ||
            isDiningAreaStationLabel(cacheName)) {
          stationId = '';
          item.remove('station_id');
          stationName = kKitchenGeneralStationLabel;
          source = 'rejected_dining_station_id';
        }
      }

      if (productMapping != null && productMapping.stationId.isNotEmpty) {
        final mappedHeader = productMapping.headerLabel;
        final mappingIsProduction = mappedHeader != kKitchenGeneralStationLabel;
        final needsProductMapping = stationId.isEmpty ||
            stationName == kKitchenGeneralStationLabel ||
            isDiningAreaStationLabel(stationName) ||
            mappingIsProduction;
        if (needsProductMapping && mappingIsProduction) {
          stationId = productMapping.stationId;
          stationName = mappedHeader;
          source = 'product_mapping';
        } else if (needsProductMapping) {
          stationId = productMapping.stationId;
          stationName = productionHeaderLabel(
            stationName: sanitizedCache[stationId] ?? productMapping.stationName,
            stationCode: productMapping.stationCode,
          );
          if (stationName != kKitchenGeneralStationLabel) {
            source = 'product_mapping_cache';
          }
        }
      }

      if (stationId.isNotEmpty) {
        item['station_id'] = stationId;
      }
      if (stationName != kKitchenGeneralStationLabel) {
        item['station_name'] = stationName;
        item['kitchen_station_name'] = stationName;
      }
      final itemStationCode = productMapping?.stationCode ??
          codesById[stationId] ??
          _text(item['station_code']);
      if (itemStationCode.isNotEmpty) {
        item['station_code'] = itemStationCode.toUpperCase();
      }

      logKitchenRoutingGroupInput(item);
      kitchenRoutingLog(
        'product_station_resolved',
        extra: {
          'productId': productId,
          'productName': _text(item['name'] ?? item['item_name']),
          'stationId': stationId,
          'stationName': stationName,
          'stationCode': item['station_code'] ?? '',
          'source': source,
          'tableAreaName': tableAreaName ?? '',
        },
      );
      return item;
    }).toList(growable: false);
  }
}

class HubItemProductionStationResolution {
  const HubItemProductionStationResolution({
    required this.stationId,
    required this.headerLabel,
    required this.stationCode,
    required this.source,
  });

  final String stationId;
  final String headerLabel;
  final String stationCode;
  final String source;
}

class KitchenRoutingItem {
  const KitchenRoutingItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.baseProductName,
    this.stationId,
    this.stationName,
    this.stationCode,
    this.itemNote,
    this.amountLabel,
    this.plates = const [],
    this.serviceChildren = const [],
  });

  final String? productId;
  /// Bridge fiş satırı (`name`); gramaj/boyut dahil.
  final String productName;
  /// Ürün eşleme / routing için taban ad.
  final String? baseProductName;
  final int quantity;
  final double unitPrice;
    final String? stationId;
  final String? stationName;
  final String? stationCode;
  /// Plain user note + merged attributes (no plate structure).
  final String? itemNote;
  /// Weight / portion label, e.g. "500 g".
  final String? amountLabel;
  /// Structured plate groupings for mixed-service items.
  final List<Map<String, dynamic>> plates;
  /// Flat child list for non-plate-grouped service items.
  final List<Map<String, dynamic>> serviceChildren;

  Map<String, dynamic> toPayloadMap() {
    final baseName = baseProductName?.trim() ?? '';
    final map = <String, dynamic>{
      'product_id': productId,
      'name': productName,
      'display_label': productName,
      'quantity': quantity,
      'price': unitPrice,
      'station_id': stationId,
      if (baseName.isNotEmpty) 'product_name': baseName,
      if (stationName != null &&
          stationName!.isNotEmpty &&
          stationName != kKitchenGeneralStationLabel) ...<String, dynamic>{
        'station_name': stationName,
        'kitchen_station_name': stationName,
      },
      if (stationCode != null && stationCode!.trim().isNotEmpty)
        'station_code': stationCode!.trim().toUpperCase(),
      'notes': itemNote,
    };
    if (amountLabel != null && amountLabel!.isNotEmpty) {
      map['amount_label'] = amountLabel;
    }
    if (plates.isNotEmpty) {
      map['plates'] = plates;
    } else if (serviceChildren.isNotEmpty) {
      map['service_children'] = serviceChildren;
    }
    return map;
  }
}

class KitchenRoutingService {
  const KitchenRoutingService();

  List<KitchenRoutingItem> normalizeItems(List<Map<String, dynamic>> rawItems) {
    final results = <KitchenRoutingItem>[];
    for (final item in rawItems) {
          final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
          final unitPrice = _parsePrice(item['price']);
          final normalizedItem = MixedServiceOrder.normalizeOrderItem(item);
          final baseName = GarsonProductSelection.printItemBaseName(
            normalizedItem,
          );
          final printLabel = GarsonProductSelection.resolvePrintItemLabel(
            normalizedItem,
          );
          final name = baseName.isNotEmpty ? baseName : printLabel;

          final amountLabel = GarsonProductSelection.resolvePrintItemAmountLabel(
            normalizedItem,
          );

          final plates = MixedServiceOrder.buildKitchenPlates(normalizedItem);
          final serviceChildren = plates.isEmpty
              ? MixedServiceOrder.buildKitchenServiceChildren(normalizedItem)
              : const <Map<String, dynamic>>[];

          // Mixed-service items can contain children across multiple stations.
          // The SQL print RPC groups by station_id, so we must split such items
          // into per-station payload items, otherwise station_id=null will
          // produce no printer match (no kitchen ticket).
          if (MixedServiceOrder.isMixedService(normalizedItem)) {
            final children = MixedServiceOrder.normalizeChildItems(
              normalizedItem['child_items'],
            );
            final byStation = <String, List<Map<String, dynamic>>>{};
            for (final child in children) {
              final sid = (child['station_id']?.toString().trim() ?? '');
              byStation.putIfAbsent(sid, () => <Map<String, dynamic>>[]).add(child);
            }

            // If every child has the same non-empty station, keep as-is.
            final uniqueNonEmptyStations =
                byStation.keys.where((k) => k.isNotEmpty).toSet();
            if (uniqueNonEmptyStations.length == 1 && byStation.length == 1) {
              results.add(
                KitchenRoutingItem(
                  productId: normalizedItem['product_id']?.toString(),
                  productName: printLabel.isEmpty ? 'Ürün' : printLabel,
                  baseProductName: name.isEmpty ? null : name,
                  quantity: quantity <= 0 ? 1 : quantity,
                  unitPrice: unitPrice,
                  stationId: uniqueNonEmptyStations.first,
                  itemNote: MixedServiceOrder.buildKitchenNote(normalizedItem),
                  amountLabel: amountLabel.isEmpty ? null : amountLabel,
                  plates: plates,
                  serviceChildren: serviceChildren,
                ),
              );
              continue;
            }

            for (final entry in byStation.entries) {
              final stationId = entry.key.trim();
              final filteredItem = <String, dynamic>{
                ...normalizedItem,
                'station_id': stationId.isEmpty ? null : stationId,
                'child_items': entry.value,
              };
              final filteredPlates =
                  MixedServiceOrder.buildKitchenPlates(filteredItem);
              final filteredChildren = filteredPlates.isEmpty
                  ? MixedServiceOrder.buildKitchenServiceChildren(filteredItem)
                  : const <Map<String, dynamic>>[];
              final splitPrintLabel =
                  GarsonProductSelection.resolvePrintItemLabel(filteredItem);
              results.add(
                KitchenRoutingItem(
                  productId: filteredItem['product_id']?.toString(),
                  productName: splitPrintLabel.isEmpty ? 'Ürün' : splitPrintLabel,
                  baseProductName: name.isEmpty ? null : name,
                  quantity: 1,
                  unitPrice: 0, // mixed service uses child structure; total is informational
                  stationId: stationId.isEmpty ? null : stationId,
                  itemNote: MixedServiceOrder.buildKitchenNote(filteredItem),
                  amountLabel: null,
                  plates: filteredPlates,
                  serviceChildren: filteredChildren,
                ),
              );
            }
            continue;
          }

          final stationId = normalizedItem['station_id']?.toString();
          final stationName = KitchenTicketHeaderResolver.sanitizeProductionStationName(
            normalizedItem['station_name']?.toString() ??
                normalizedItem['kitchen_station_name']?.toString() ??
                '',
          );
          final stationCode =
              normalizedItem['station_code']?.toString().trim() ?? '';
          results.add(
            KitchenRoutingItem(
              productId: normalizedItem['product_id']?.toString(),
              productName: printLabel.isEmpty ? 'Ürün' : printLabel,
              baseProductName: name.isEmpty ? null : name,
              quantity: quantity <= 0 ? 1 : quantity,
              unitPrice: unitPrice,
              stationId: stationId,
              stationName: stationName == kKitchenGeneralStationLabel
                  ? null
                  : stationName,
              stationCode: stationCode.isEmpty ? null : stationCode,
              itemNote: MixedServiceOrder.buildKitchenNote(normalizedItem),
              amountLabel: amountLabel.isEmpty ? null : amountLabel,
              plates: plates,
              serviceChildren: serviceChildren,
            ),
          );
        }
    return results;
  }

  double _parsePrice(dynamic raw) {
    return MixedServiceOrder.parsePrice(raw);
  }
}
