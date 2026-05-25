import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'kitchen_print_trace_log.dart';
import 'kitchen_routing_service.dart';

/// Hub + Ürün Eşleme için ürün→istasyon önbelleği (bellek + SharedPreferences).
class KitchenProductMappingCacheStore {
  KitchenProductMappingCacheStore._();

  static final Map<String, Map<String, ProductStationMapping>> _memoryByProductId =
      <String, Map<String, ProductStationMapping>>{};
  static final Map<String, Map<String, ProductStationMapping>> _memoryByProductName =
      <String, Map<String, ProductStationMapping>>{};
  static final Map<String, Map<String, String>> _memoryProductNamesById =
      <String, Map<String, String>>{};
  static final Map<String, bool> _hydrateCompleted = <String, bool>{};

  static String _storageKey(String restaurantId) =>
      'kitchen_hub_product_mappings_v1_${restaurantId.trim()}';

  static Map<String, Object?> diagnostics(String restaurantId) {
    final id = restaurantId.trim();
    applyMemoryToResolver(id);
    final byId = <String, ProductStationMapping>{
      ...?KitchenTicketHeaderResolver.productMappingsForRestaurant(id),
      ...?_memoryByProductId[id],
    };
    final nameKeys = productNameKeys(id);
    final idKeys = byId.keys.toList()..sort();
    return <String, Object?>{
      'restaurantId': id,
      'mappingCount': byId.length,
      'productNameKeyCount': nameKeys.length,
      'productNameKeys': nameKeys,
      'productIdKeys': idKeys,
    };
  }

  /// Bellek → resolver (senkron, hub stamp öncesi).
  static void applyMemoryToResolver(String restaurantId) {
    final id = restaurantId.trim();
    if (id.isEmpty) return;
    final byId = _memoryByProductId[id];
    if (byId == null || byId.isEmpty) return;
    KitchenTicketHeaderResolver.registerRestaurantProductStationMappings(
      id,
      Map<String, ProductStationMapping>.from(byId),
      productNamesByProductId: Map<String, String>.from(
        _memoryProductNamesById[id] ?? const <String, String>{},
      ),
    );
    final byName = _memoryByProductName[id];
    if (byName != null && byName.isNotEmpty) {
      KitchenTicketHeaderResolver.mergeProductNameMappings(id, byName);
    }
  }

  static List<String> productNameKeys(String restaurantId) {
    final id = restaurantId.trim();
    final merged = <String>{
      ...KitchenTicketHeaderResolver.productNameKeysForRestaurant(id),
      ...?_memoryByProductName[id]?.keys,
    };
    final keys = merged.toList()..sort();
    return keys;
  }

  /// İlk hub baskısından önce diskten yükle (tek okuma / restoran).
  static Future<void> ensureHydrated(String restaurantId) async {
    final id = restaurantId.trim();
    if (id.isEmpty) return;
    applyMemoryToResolver(id);
    if (_hydrateCompleted[id] == true) {
      return;
    }
    await hydrateResolver(id);
    _hydrateCompleted[id] = true;
    applyMemoryToResolver(id);
  }

  /// Ürün Eşleme UI: tüm kartların güncel seçimini belleğe + diske yazar.
  static void syncProductRoutingUi({
    required String restaurantId,
    required Iterable<({String productId, String productName, String? stationId})>
        rows,
    required Map<String, ({String name, String code})> stationById,
  }) {
    final id = restaurantId.trim();
    if (id.isEmpty) return;
    for (final row in rows) {
      final stationId = row.stationId?.trim() ?? '';
      if (stationId.isEmpty) continue;
      final station = stationById[stationId];
      if (station == null) continue;
      final header = KitchenTicketHeaderResolver.productionHeaderLabel(
        stationName: station.name,
        stationCode: station.code,
      );
      upsertProductSync(
        restaurantId: id,
        productId: row.productId,
        productName: row.productName,
        mapping: ProductStationMapping(
          stationId: stationId,
          stationName: header == kKitchenGeneralStationLabel
              ? station.name
              : header,
          stationCode: station.code.toUpperCase(),
        ),
        source: 'product_routing_ui_sync',
      );
    }
    applyMemoryToResolver(id);
    unawaited(_persistRestaurantToDisk(id));
  }

  /// Tek ürün — dropdown değişince veya Kaydet sonrası.
  static void upsertProductSync({
    required String restaurantId,
    required String productId,
    required String productName,
    required ProductStationMapping mapping,
    String source = 'cache_write',
    bool logWrite = true,
  }) {
    final id = restaurantId.trim();
    final pid = productId.trim();
    if (id.isEmpty || pid.isEmpty || mapping.stationId.isEmpty) return;

    final byId = _memoryByProductId.putIfAbsent(id, () => <String, ProductStationMapping>{});
    final byName =
        _memoryByProductName.putIfAbsent(id, () => <String, ProductStationMapping>{});
    final namesById =
        _memoryProductNamesById.putIfAbsent(id, () => <String, String>{});

    byId[pid] = mapping;
    namesById[pid] = productName;

    for (final nameKey in _productNameKeysFor(productName)) {
      if (nameKey.isNotEmpty) {
        byName[nameKey] = mapping;
      }
    }

    KitchenTicketHeaderResolver.registerSingleProductStationMapping(
      restaurantId: id,
      productId: pid,
      productName: productName,
      mapping: mapping,
    );

    final normalizedName = KitchenTicketHeaderResolver.normalizeProductNameKey(
      productName,
    );
    if (logWrite) {
      logProductStationMappingCacheWrite(
        productId: pid,
        productName: productName,
        normalizedName: normalizedName,
        stationId: mapping.stationId,
        stationName: mapping.headerLabel,
        stationCode: mapping.stationCode,
        source: source,
      );
    }
  }

  static Set<String> _productNameKeysFor(String productName) {
    final trimmed = productName.trim();
    if (trimmed.isEmpty) return const <String>{};
    return <String>{
      KitchenTicketHeaderResolver.normalizeProductNameKey(trimmed),
      trimmed.toLowerCase(),
    };
  }

  static Future<void> persistMappings({
    required String restaurantId,
    required Map<String, ProductStationMapping> mappingsByProductId,
    Map<String, String>? productNamesByProductId,
  }) async {
    final id = restaurantId.trim();
    if (id.isEmpty) return;
    for (final entry in mappingsByProductId.entries) {
      final stationId = entry.value.stationId;
      if (stationId.isEmpty) continue;
      upsertProductSync(
        restaurantId: id,
        productId: entry.key,
        productName: productNamesByProductId?[entry.key] ?? '',
        mapping: entry.value,
        source: 'batch_persist',
      );
    }
    await _persistRestaurantToDisk(id);
  }

  static Future<void> persistSingleProduct({
    required String restaurantId,
    required String productId,
    required String productName,
    required ProductStationMapping mapping,
  }) async {
    upsertProductSync(
      restaurantId: restaurantId,
      productId: productId,
      productName: productName,
      mapping: mapping,
      source: 'save_button',
    );
    await _persistRestaurantToDisk(restaurantId.trim());
  }

  static Future<void> hydrateResolver(String restaurantId) async {
    final id = restaurantId.trim();
    if (id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey(id));
    if (raw == null || raw.trim().isEmpty) {
      logProductStationMappingCacheHydrate(
        restaurantId: id,
        mappingCount: _memoryByProductId[id]?.length ?? 0,
        productNameKeys: productNameKeys(id),
        productIdKeys: _memoryByProductId[id]?.keys.toList() ?? const <String>[],
        fromDisk: false,
      );
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List || decoded.isEmpty) return;
      for (final row in decoded) {
        if (row is! Map) continue;
        final productId = row['productId']?.toString().trim() ?? '';
        final productName = row['productName']?.toString().trim() ?? '';
        final stationId = row['stationId']?.toString().trim() ?? '';
        if (productId.isEmpty || stationId.isEmpty) continue;
        final stationName = row['stationName']?.toString().trim() ?? '';
        final stationCode = row['stationCode']?.toString().trim() ?? '';
        upsertProductSync(
          restaurantId: id,
          productId: productId,
          productName: productName,
          mapping: ProductStationMapping(
            stationId: stationId,
            stationName: stationName.isEmpty ? stationCode : stationName,
            stationCode: stationCode,
          ),
          source: 'disk_hydrate',
          logWrite: false,
        );
      }
      applyMemoryToResolver(id);
      logProductStationMappingCacheHydrate(
        restaurantId: id,
        mappingCount: _memoryByProductId[id]?.length ?? 0,
        productNameKeys: productNameKeys(id),
        productIdKeys: _memoryByProductId[id]?.keys.toList() ?? const <String>[],
        fromDisk: true,
      );
    } catch (_) {
      logProductStationMappingCacheHydrate(
        restaurantId: id,
        mappingCount: 0,
        productNameKeys: const <String>[],
        productIdKeys: const <String>[],
        fromDisk: false,
        error: 'decode_failed',
      );
    }
  }

  static Future<void> _persistRestaurantToDisk(String restaurantId) async {
    final id = restaurantId.trim();
    final byId = _memoryByProductId[id];
    if (byId == null || byId.isEmpty) return;
    final namesById = _memoryProductNamesById[id] ?? const <String, String>{};
    final rows = <Map<String, String>>[];
    for (final entry in byId.entries) {
      final mapping = entry.value;
      rows.add(<String, String>{
        'productId': entry.key,
        'productName': namesById[entry.key] ?? '',
        'stationId': mapping.stationId,
        'stationName': mapping.stationName,
        'stationCode': mapping.stationCode,
      });
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey(id), jsonEncode(rows));
  }
}
