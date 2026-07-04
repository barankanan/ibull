import '../../core/secure_local_store.dart';
import '../../features/seller/panel/helpers/restaurant_printer_eligibility.dart';
import '../../models/seller_product.dart';
import 'restaurant_offline_models.dart';

class RestaurantLocalCacheService {
  RestaurantLocalCacheService({SecureLocalStore? store})
    : _store = store ?? SecureLocalStore.instance;

  final SecureLocalStore _store;

  static String storageKey(String restaurantId) =>
      'restaurant_offline_cache_v1_${restaurantId.trim()}';

  Future<RestaurantLocalCacheSnapshot?> read(String restaurantId) async {
    final id = restaurantId.trim();
    if (id.isEmpty) return null;
    final raw = await _store.readJson(storageKey(id));
    if (raw is! Map) return null;
    return RestaurantLocalCacheSnapshot.fromJson(
      Map<String, dynamic>.from(raw),
    );
  }

  Future<void> write(RestaurantLocalCacheSnapshot snapshot) async {
    final id = snapshot.restaurantId.trim();
    if (id.isEmpty) return;
    if (!canUseRestaurantPrinterSystem(snapshot.storeCategory)) return;
    await _store.writeJson(storageKey(id), snapshot.toJson());
  }

  Future<void> delete(String restaurantId) async {
    final id = restaurantId.trim();
    if (id.isEmpty) return;
    await _store.delete(storageKey(id));
  }

  Future<bool> hasCache(String restaurantId) async {
    final snapshot = await read(restaurantId);
    return snapshot != null && snapshot.restaurantId.isNotEmpty;
  }

  Future<void> upsertFromOnlineSnapshot({
    required String restaurantId,
    required String restaurantName,
    required String sellerId,
    required String storeCategory,
    List<Map<String, dynamic>> tables = const <Map<String, dynamic>>[],
    List<Map<String, dynamic>> tableOrderSnapshots =
        const <Map<String, dynamic>>[],
    Iterable<SellerProduct> products = const <SellerProduct>[],
    List<Map<String, dynamic>> stations = const <Map<String, dynamic>>[],
    List<Map<String, dynamic>> printers = const <Map<String, dynamic>>[],
    List<Map<String, dynamic>> stationPrinters =
        const <Map<String, dynamic>>[],
    Map<String, dynamic> printerRoles = const <String, dynamic>{},
    Map<String, dynamic> printerProfiles = const <String, dynamic>{},
    Map<String, dynamic> productStationMappings =
        const <String, dynamic>{},
    List<Map<String, dynamic>> discoveredPrinters =
        const <Map<String, dynamic>>[],
    Map<String, dynamic> lastSetupSnapshot = const <String, dynamic>{},
  }) async {
    if (!canUseRestaurantPrinterSystem(storeCategory)) return;
    final existing = await read(restaurantId);
    final snapshot = RestaurantLocalCacheSnapshot(
      restaurantId: restaurantId.trim(),
      restaurantName: restaurantName.trim().isNotEmpty
          ? restaurantName.trim()
          : (existing?.restaurantName ?? ''),
      sellerId: sellerId.trim().isNotEmpty
          ? sellerId.trim()
          : (existing?.sellerId ?? restaurantId.trim()),
      storeCategory: storeCategory.trim().isNotEmpty
          ? storeCategory.trim()
          : (existing?.storeCategory ?? ''),
      tables: tables.isNotEmpty ? tables : (existing?.tables ?? tables),
      tableOrderSnapshots: tableOrderSnapshots.isNotEmpty
          ? tableOrderSnapshots
          : (existing?.tableOrderSnapshots ?? tableOrderSnapshots),
      products: products.isNotEmpty
          ? products
                .map(_productToCacheMap)
                .toList(growable: false)
          : (existing?.products ?? const <Map<String, dynamic>>[]),
      stations: stations.isNotEmpty
          ? stations
          : (existing?.stations ?? stations),
      printers: printers.isNotEmpty
          ? printers
          : (existing?.printers ?? printers),
      stationPrinters: stationPrinters.isNotEmpty
          ? stationPrinters
          : (existing?.stationPrinters ?? stationPrinters),
      printerRoles: printerRoles.isNotEmpty
          ? printerRoles
          : (existing?.printerRoles ?? printerRoles),
      printerProfiles: printerProfiles.isNotEmpty
          ? printerProfiles
          : (existing?.printerProfiles ?? printerProfiles),
      productStationMappings: productStationMappings.isNotEmpty
          ? productStationMappings
          : (existing?.productStationMappings ?? productStationMappings),
      discoveredPrinters: discoveredPrinters.isNotEmpty
          ? discoveredPrinters
          : (existing?.discoveredPrinters ?? discoveredPrinters),
      lastSetupSnapshot: lastSetupSnapshot.isNotEmpty
          ? lastSetupSnapshot
          : (existing?.lastSetupSnapshot ?? lastSetupSnapshot),
      cachedAt: DateTime.now(),
    );
    await write(snapshot);
  }

  String formatCachedAt(DateTime? cachedAt) {
    if (cachedAt == null) return '-';
    final local = cachedAt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  String missingCacheMessage() =>
      'Bu restoran için çevrimdışı veri bulunamadı. İlk kurulum için internete bağlanın.';

  String staleCacheMessage(DateTime cachedAt) =>
      'Son yerel veri: ${formatCachedAt(cachedAt)}';

  static Map<String, dynamic> _productToCacheMap(SellerProduct product) {
    return <String, dynamic>{
      'id': product.id,
      'name': product.name,
      'price': product.price,
      'station_id': product.stationId,
      'station_name': product.stationName,
      'station_code': product.stationCode,
      'printer_routing_enabled': product.printerRoutingEnabled,
      'status': product.status,
    };
  }
}
