import '../models/seller_product.dart';
import '../services/restaurant_offline/restaurant_local_cache_service.dart';
import '../services/restaurant_offline/restaurant_offline_models.dart';

const garsonProductsCacheTtl = Duration(minutes: 3);

class GarsonProductsCacheEntry {
  const GarsonProductsCacheEntry({
    required this.products,
    required this.cachedAt,
  });

  final List<SellerProduct> products;
  final DateTime cachedAt;

  bool isFresh({Duration ttl = garsonProductsCacheTtl}) {
    return DateTime.now().difference(cachedAt) <= ttl;
  }
}

/// In-memory TTL cache for garson menu/products per restaurant.
class GarsonProductsCache {
  GarsonProductsCache._();

  static final GarsonProductsCache instance = GarsonProductsCache._();

  final Map<String, GarsonProductsCacheEntry> _byRestaurant =
      <String, GarsonProductsCacheEntry>{};

  GarsonProductsCacheEntry? read(String restaurantId) {
    final id = restaurantId.trim();
    if (id.isEmpty) return null;
    return _byRestaurant[id];
  }

  void write(String restaurantId, List<SellerProduct> products) {
    final id = restaurantId.trim();
    if (id.isEmpty || products.isEmpty) return;
    _byRestaurant[id] = GarsonProductsCacheEntry(
      products: List<SellerProduct>.from(products),
      cachedAt: DateTime.now(),
    );
  }

  void invalidate(String restaurantId) {
    _byRestaurant.remove(restaurantId.trim());
  }
}

bool shouldUseGarsonProductsCache({
  required List<SellerProduct> parentProducts,
  GarsonProductsCacheEntry? cacheEntry,
}) {
  if (parentProducts.isNotEmpty) return true;
  return cacheEntry?.isFresh() ?? false;
}

List<SellerProduct> resolveGarsonProductsForOpen({
  required List<SellerProduct> parentProducts,
  GarsonProductsCacheEntry? cacheEntry,
}) {
  if (parentProducts.isNotEmpty) {
    return List<SellerProduct>.from(parentProducts);
  }
  if (cacheEntry != null && cacheEntry.isFresh()) {
    return List<SellerProduct>.from(cacheEntry.products);
  }
  return const <SellerProduct>[];
}

int garsonTableNumberFromOrder(Map<String, dynamic> order) {
  final raw = order['table_number'];
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}

List<Map<String, dynamic>> garsonOrdersForTableNumber({
  required List<Map<String, dynamic>> orders,
  required int tableNumber,
}) {
  if (tableNumber <= 0) return const <Map<String, dynamic>>[];
  return orders
      .where((order) => garsonTableNumberFromOrder(order) == tableNumber)
      .map((order) => Map<String, dynamic>.from(order))
      .toList(growable: false);
}

bool isKitchenPrintJobPayload(Map<String, dynamic> payload) {
  final documentType =
      payload['document_type']?.toString().trim().toLowerCase() ?? '';
  if (documentType == 'kitchen' ||
      documentType == 'kitchen_ticket' ||
      documentType.contains('kitchen')) {
    return true;
  }
  final role = payload['printer_role']?.toString().trim().toLowerCase() ?? '';
  return role == 'mutfak' || role == 'kitchen';
}

String kitchenPrintJobStationKey(Map<String, dynamic> job) {
  final stationId = job['station_id']?.toString().trim() ?? '';
  if (stationId.isNotEmpty) return stationId;
  final payload = job['payload'];
  if (payload is Map) {
    final fromPayload = payload['station_id']?.toString().trim() ?? '';
    if (fromPayload.isNotEmpty) return fromPayload;
    final header = payload['kitchen_ticket_header']?.toString().trim() ?? '';
    if (header.isNotEmpty) return header;
    final stationName = payload['station_name']?.toString().trim() ?? '';
    if (stationName.isNotEmpty) return stationName;
  }
  return '__general__';
}

DateTime? _readJobCreatedAt(Map<String, dynamic> job) {
  return DateTime.tryParse(job['created_at']?.toString() ?? '');
}

/// Keeps the newest kitchen print job per station for reprint fast-path.
List<Map<String, dynamic>> pickLatestKitchenPrintJobsForReprint(
  List<Map<String, dynamic>> jobs,
) {
  final latestByStation = <String, Map<String, dynamic>>{};
  for (final job in jobs) {
    final payloadRaw = job['payload'];
    final payload = payloadRaw is Map
        ? Map<String, dynamic>.from(payloadRaw)
        : const <String, dynamic>{};
    if (!isKitchenPrintJobPayload(payload)) continue;
    final stationKey = kitchenPrintJobStationKey(job);
    final existing = latestByStation[stationKey];
    if (existing == null) {
      latestByStation[stationKey] = job;
      continue;
    }
    final existingAt = _readJobCreatedAt(existing);
    final candidateAt = _readJobCreatedAt(job);
    if (candidateAt != null &&
        (existingAt == null || candidateAt.isAfter(existingAt))) {
      latestByStation[stationKey] = job;
    }
  }
  return latestByStation.values.toList(growable: false);
}

class GarsonOfflineHydrateResult {
  const GarsonOfflineHydrateResult({
    required this.applied,
    required this.tablesCount,
    required this.ordersCount,
    required this.productsCount,
    this.cachedAt,
  });

  final bool applied;
  final int tablesCount;
  final int ordersCount;
  final int productsCount;
  final DateTime? cachedAt;
}

Future<GarsonOfflineHydrateResult> hydrateGarsonBoardFromOfflineCache({
  required String restaurantId,
  RestaurantLocalCacheService? cacheService,
}) async {
  final id = restaurantId.trim();
  if (id.isEmpty) {
    return const GarsonOfflineHydrateResult(
      applied: false,
      tablesCount: 0,
      ordersCount: 0,
      productsCount: 0,
    );
  }
  final snapshot =
      await (cacheService ?? RestaurantLocalCacheService()).read(id);
  if (snapshot == null || snapshot.restaurantId.isEmpty) {
    return const GarsonOfflineHydrateResult(
      applied: false,
      tablesCount: 0,
      ordersCount: 0,
      productsCount: 0,
    );
  }
  return GarsonOfflineHydrateResult(
    applied: snapshot.tables.isNotEmpty ||
        snapshot.tableOrderSnapshots.isNotEmpty ||
        snapshot.products.isNotEmpty,
    tablesCount: snapshot.tables.length,
    ordersCount: snapshot.tableOrderSnapshots.length,
    productsCount: snapshot.products.length,
    cachedAt: snapshot.cachedAt,
  );
}

List<SellerProduct> sellerProductsFromOfflineSnapshot(
  RestaurantLocalCacheSnapshot snapshot,
) {
  return snapshot.products
      .map((row) {
        final map = Map<String, dynamic>.from(row);
        final id = map['id']?.toString() ?? '';
        return SellerProduct.fromMap(map, id);
      })
      .where((product) => product.id.trim().isNotEmpty)
      .toList(growable: false);
}

String reprintInFlightKey({
  required String restaurantId,
  required int tableNumber,
  String? orderId,
  String? stationKey,
}) {
  return '${restaurantId.trim()}|$tableNumber|${orderId ?? '*'}|${stationKey ?? '*'}';
}
