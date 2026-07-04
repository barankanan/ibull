import '../../features/seller/panel/helpers/restaurant_printer_eligibility.dart';
import '../../models/seller_product.dart';
import 'restaurant_local_cache_service.dart';

/// Builds offline restaurant cache snapshots from in-memory seller panel data.
class RestaurantOfflineSnapshotSync {
  RestaurantOfflineSnapshotSync({RestaurantLocalCacheService? cacheService})
    : _cacheService = cacheService ?? RestaurantLocalCacheService();

  final RestaurantLocalCacheService _cacheService;

  Future<void> upsertFromSellerPanelState({
    required String restaurantId,
    required String storeName,
    required String sellerId,
    required String storeCategory,
    List<Map<String, dynamic>> tables = const <Map<String, dynamic>>[],
    List<SellerProduct> products = const <SellerProduct>[],
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
    await _cacheService.upsertFromOnlineSnapshot(
      restaurantId: restaurantId,
      restaurantName: storeName,
      sellerId: sellerId,
      storeCategory: storeCategory,
      tables: tables,
      products: products,
      stations: stations,
      printers: printers,
      stationPrinters: stationPrinters,
      printerRoles: printerRoles,
      printerProfiles: printerProfiles,
      productStationMappings: productStationMappings,
      discoveredPrinters: discoveredPrinters,
      lastSetupSnapshot: lastSetupSnapshot,
    );
  }
}
