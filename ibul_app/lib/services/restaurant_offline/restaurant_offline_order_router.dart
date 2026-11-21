import 'offline_catalog_pricing.dart';
import '../../features/seller/panel/helpers/restaurant_printer_eligibility.dart';
import '../bridge_print_dispatch_verification.dart';
import '../kitchen_routing_service.dart';
import '../order_print_job_service.dart';
import 'restaurant_connectivity_service.dart';
import 'restaurant_local_cache_service.dart';
import 'restaurant_local_order_queue_service.dart';
import 'restaurant_local_print_queue_service.dart';
import 'restaurant_lan_host.dart';
import 'paired_lan_transport.dart';
import 'restaurant_offline_models.dart';
import '../staff_login_policy.dart';

class RestaurantOfflineOrderRouter {
  RestaurantOfflineOrderRouter({
    RestaurantConnectivityService? connectivityService,
    RestaurantLocalCacheService? cacheService,
    RestaurantLocalOrderQueueService? orderQueueService,
    RestaurantLocalPrintQueueService? printQueueService,
    OrderPrintJobService? orderPrintJobService,
    DateTime Function()? clock,
  }) : _connectivity =
           connectivityService ?? RestaurantConnectivityService.instance,
       _cacheService = cacheService ?? RestaurantLocalCacheService(),
       _orderQueue = orderQueueService ?? RestaurantLocalOrderQueueService(),
       _printQueue = printQueueService ?? RestaurantLocalPrintQueueService(),
       _orderPrintJobService = orderPrintJobService,
       _clock = clock ?? DateTime.now;

  final RestaurantConnectivityService _connectivity;
  final RestaurantLocalCacheService _cacheService;
  final RestaurantLocalOrderQueueService _orderQueue;
  final RestaurantLocalPrintQueueService _printQueue;
  final OrderPrintJobService? _orderPrintJobService;
  DateTime? _routeHeldUntil;
  String? _heldRoute;
  final DateTime Function() _clock;

  OrderPrintJobService get _orderPrintJobServiceOrCreate =>
      _orderPrintJobService ?? OrderPrintJobService();

  Future<bool> shouldRouteOffline({
    required String restaurantId,
    required String? storeCategory,
    bool skipOfflineFallback = false,
    bool priorCloudFailure = false,
  }) async {
    if (skipOfflineFallback) return false;
    if (!canUseRestaurantPrinterSystem(storeCategory)) return false;
    await _connectivity.refresh(priorCloudFailure: priorCloudFailure);
    if (RestaurantLanPairing.transport != null &&
        !RestaurantLanPairing.centerReachable) {
      // The center may be back since it last failed to answer.
      try {
        await RestaurantLanPairing.recheck?.call();
      } catch (_) {}
    }
    _heldRoute = null;
    return _route(restaurantId) == 'lan';
  }

  /// Hot-path offline hint: last-known connectivity only (no refresh await).
  /// Call [shouldRouteOffline] / refresh in background when this returns false.
  Future<bool> shouldRouteOfflineFast({
    required String restaurantId,
    required String? storeCategory,
    bool skipOfflineFallback = false,
  }) async {
    if (skipOfflineFallback) return false;
    if (!canUseRestaurantPrinterSystem(storeCategory)) return false;
    return _route(restaurantId) == 'lan';
  }

  String _route(String restaurantId) {
    final now = _clock();
    if (_heldRoute != null &&
        _routeHeldUntil != null &&
        now.isBefore(_routeHeldUntil!)) {
      return _heldRoute!;
    }
    final host = RestaurantLanHostRegistry.current;
    final hostHere =
        host != null && host.listening && host.restaurantId == restaurantId;
    final hostReady = hostHere && host.lanIdentityVerified;
    final pairedTablet =
        RestaurantLanPairing.transport != null &&
        RestaurantLanPairing.centerReachable &&
        !hostHere;
    final route = restaurantOrderRoute(
      supabaseReachable:
          _connectivity.hasNetwork && _connectivity.supabaseReachable,
      lanReachable: hostReady || pairedTablet,
      lanIdentityVerified: hostReady || pairedTablet,
      pairedTablet: pairedTablet,
    );
    _heldRoute = route;
    _routeHeldUntil = now.add(const Duration(seconds: 2));
    return route;
  }

  Future<OrderPrintJobDispatchResult> dispatchOfflineOrder({
    required String restaurantId,
    required int tableNumber,
    required List<Map<String, dynamic>> items,
    String? waiterId,
    String? waiterName,
    String? waiterTitle,
    String? notes,
    String? tableName,
    String? storeCategory,
    String? localOrderId,
  }) async {
    final cache = await _cacheService.read(restaurantId);
    if (cache == null) {
      throw StateError(_cacheService.missingCacheMessage());
    }
    final category = (storeCategory ?? cache.storeCategory).trim();
    if (!canUseRestaurantPrinterSystem(category)) {
      throw StateError(restaurantPrinterIneligibleMessage);
    }

    _orderPrintJobServiceOrCreate.registerOfflineSnapshotCaches(
      restaurantId: restaurantId,
      stationNamesById: _stationNamesFromCache(cache),
      stationCodesById: _stationCodesFromCache(cache),
      productMappings: _productMappingsFromCache(cache),
    );

    final localOrderIdValue = localOrderId?.trim().isNotEmpty == true
        ? localOrderId!.trim()
        : newRestaurantLocalOrderId();
    final now = DateTime.now();
    final order = RestaurantLocalOrderRecord(
      localOrderId: localOrderIdValue,
      restaurantId: restaurantId,
      tableId: tableNumber.toString(),
      tableName: tableName?.trim().isNotEmpty == true
          ? tableName!.trim()
          : 'Masa $tableNumber',
      tableNumber: tableNumber,
      waiterId: waiterId?.trim() ?? '',
      waiterName: waiterName?.trim() ?? '',
      items: items,
      notes: notes?.trim() ?? '',
      total: _estimateTotal(items),
      stationGroups: const <Map<String, dynamic>>[],
      printStatus: 'pending',
      syncStatus: RestaurantLocalOrderSyncStatus.pendingSync,
      createdAt: now,
      updatedAt: now,
    );

    final host = RestaurantLanHostRegistry.current;
    final hostHere =
        host != null && host.listening && host.restaurantId == restaurantId;
    final transport = RestaurantLanPairing.transport;
    if (transport == null && !hostHere) {
      throw StateError('Yerel sunucu kapalı. Sipariş gönderilmedi.');
    }
    if (transport != null && !hostHere) {
      var saved = false;
      var reachable = true;
      try {
        saved = await transport.submit(order);
      } catch (error) {
        if (error.toString().contains('Ana bilgisayar kapalı') ||
            error.toString().contains('sertifikası doğrulanamadı')) {
          reachable = false;
        } else {
          rethrow;
        }
      }
      final decision = decideLanOrderSubmit(
        paired: true,
        hostReachable: reachable,
        hostSaved: saved,
      );
      if (!decision.showSuccess) {
        await _orderQueue.enqueue(order: order);
        throw StateError('Sipariş gönderilemedi. Cihazda bekliyor.');
      }
      await _orderQueue.enqueue(order: order);
      return OrderPrintJobDispatchResult(
        orderId: localOrderIdValue,
        orderNumber: localOrderIdValue,
        printJobCount: 0,
        printJobIds: const <String>[],
        raw: <String, dynamic>{
          'offline': true,
          'lan_host': true,
          'local_order_id': localOrderIdValue,
          'print_status': transport is PairedLanTransport
              ? transport.lastPrintStatus
              : null,
          'message': 'Sipariş ana bilgisayara kaydedildi.',
        },
        dispatchedJobCount: 0,
        failedJobCount: 0,
        physicallyDispatched: false,
        dispatchPath: 'lan_host',
        traceId: '',
      );
    }

    // A repeat of an order that is already in the local journal (double tap,
    // retry after a timeout) is answered from the journal: no second record
    // and no second kitchen ticket. Only a ticket that certainly did not
    // print ('failed') is tried again, under the same print key.
    final already = await _orderQueue.getByLocalId(
      restaurantId: restaurantId,
      localOrderId: localOrderIdValue,
    );
    if (already != null && already.printStatus != 'failed') {
      final printed = already.printStatus == 'printed';
      return OrderPrintJobDispatchResult(
        orderId: localOrderIdValue,
        orderNumber: localOrderIdValue,
        printJobCount: 0,
        printJobIds: const <String>[],
        raw: <String, dynamic>{
          'offline': true,
          'duplicate': true,
          'local_order_id': localOrderIdValue,
          'sync_status': already.syncStatus.name,
          'message':
              'Bu sipariş zaten yerel olarak kayıtlı. Yeniden yazdırılmadı.',
          'table_number': already.tableNumber,
          'table_name': already.tableName,
        },
        dispatchedJobCount: 0,
        failedJobCount: 0,
        physicallyDispatched: printed,
        dispatchPath: 'offline_local_queue_duplicate',
        traceId: '',
      );
    }

    // Merkezin kendi çevrimdışı siparişi: cihaz siparişleriyle AYNI katalog doğrulaması.
    // İstemci fiyatı güvenilmez; katalogda olmayan / fiyatı doğrulanamayan ürün
    // satılmaz ve hiçbir kayıt yazılmaz (sahte başarı yok).
    var lineItems = items;
    RestaurantLocalOrderRecord? pricedOrder;
    if (already == null) {
      final priced = priceLocalOfflineOrder(cache: cache, items: items);
      if (priced.error != null) {
        throw StateError('${priced.error} Sipariş kaydedilmedi.');
      }
      lineItems = priced.items;
      pricedOrder = order.copyWith(items: priced.items, total: priced.total);
    }

    final persisted =
        already ?? await _orderQueue.enqueue(order: pricedOrder ?? order);

    final immediate = await _orderPrintJobServiceOrCreate
        .dispatchGarsonKitchenImmediateFromItems(
          restaurantId: restaurantId,
          tableNumber: tableNumber,
          items: lineItems,
          waiterId: waiterId,
          waiterName: waiterName,
          waiterTitle: waiterTitle,
          canUseLocalPrintFastPath: true,
          tableAreaName: tableName,
          orderKey: localOrderIdValue,
        );

    final printStatus = localPrintStatusFromDispatch(
      physicallyDispatched: immediate.physicallyDispatched,
      error: immediate.error,
    );
    final localPrintJob = RestaurantLocalPrintJobRecord(
      localJobId: newRestaurantLocalPrintJobId(),
      restaurantId: restaurantId,
      localOrderId: localOrderIdValue,
      tableId: tableNumber.toString(),
      tableName: order.tableName,
      documentType: 'kitchen',
      role: 'mutfak',
      station: 'offline_dispatch',
      printerSnapshot: <String, dynamic>{
        'id': immediate.selectedPrinterId,
        'name': immediate.selectedPrinterId,
        'backend': 'offline_cache',
      },
      payloadSnapshot: <String, dynamic>{
        'table_number': tableNumber,
        'items': lineItems,
        'local_order_id': localOrderIdValue,
        'trace_id': immediate.traceId,
      },
      status: printStatus == 'printed'
          ? RestaurantLocalPrintJobStatus.printed
          : printStatus == 'uncertain'
          ? RestaurantLocalPrintJobStatus.dispatching
          : RestaurantLocalPrintJobStatus.failed,
      attempts: 1,
      lastError: immediate.physicallyDispatched
          ? null
          : (immediate.error ??
                (_connectivity.bridgeReachable
                    ? BridgePrintDispatchVerification
                          .dispatchNotDeliveredMessage
                    : 'Yazıcı köprüsü çalışmıyor. Yerel yazdırma yapılamaz.')),
      createdAt: now,
      printedAt: immediate.physicallyDispatched ? DateTime.now() : null,
    );
    await _printQueue.enqueue(job: localPrintJob);

    final updatedOrder = persisted.copyWith(
      printStatus: printStatus,
      updatedAt: DateTime.now(),
    );
    await _orderQueue.update(restaurantId: restaurantId, order: updatedOrder);

    return OrderPrintJobDispatchResult(
      orderId: localOrderIdValue,
      orderNumber: localOrderIdValue,
      printJobCount: 1,
      printJobIds: <String>[localPrintJob.localJobId],
      raw: <String, dynamic>{
        'offline': true,
        'local_order_id': localOrderIdValue,
        'sync_status': RestaurantLocalOrderSyncStatus.pendingSync.name,
        'message':
            'Sipariş yerel olarak kaydedildi. İnternet gelince senkronlanacak.',
        'table_number': tableNumber,
        'table_name': order.tableName,
      },
      dispatchedJobCount: immediate.physicallyDispatched ? 1 : 0,
      failedJobCount: immediate.physicallyDispatched ? 0 : 1,
      physicallyDispatched: immediate.physicallyDispatched,
      dispatchPath: immediate.dispatchPath.isEmpty
          ? 'offline_local_queue'
          : immediate.dispatchPath,
      printFailureMessage: immediate.physicallyDispatched
          ? null
          : localPrintJob.lastError,
      traceId: immediate.traceId,
    );
  }

  static Map<String, String> _stationNamesFromCache(
    RestaurantLocalCacheSnapshot cache,
  ) {
    final map = <String, String>{};
    for (final station in cache.stations) {
      final id = station['id']?.toString() ?? '';
      final name = station['name']?.toString() ?? '';
      if (id.isNotEmpty && name.isNotEmpty) {
        map[id] = name;
      }
    }
    return map;
  }

  static Map<String, String> _stationCodesFromCache(
    RestaurantLocalCacheSnapshot cache,
  ) {
    final map = <String, String>{};
    for (final station in cache.stations) {
      final id = station['id']?.toString() ?? '';
      final code = station['code']?.toString() ?? '';
      if (id.isNotEmpty && code.isNotEmpty) {
        map[id] = code;
      }
    }
    return map;
  }

  static Map<String, ProductStationMapping> _productMappingsFromCache(
    RestaurantLocalCacheSnapshot cache,
  ) {
    final map = <String, ProductStationMapping>{};
    for (final product in cache.products) {
      final productId = product['id']?.toString() ?? '';
      final stationId = product['station_id']?.toString() ?? '';
      if (productId.isEmpty || stationId.isEmpty) continue;
      map[productId] = ProductStationMapping(
        stationId: stationId,
        stationName: product['station_name']?.toString() ?? '',
        stationCode: product['station_code']?.toString() ?? '',
      );
    }
    return map;
  }

  static double _estimateTotal(List<Map<String, dynamic>> items) {
    var total = 0.0;
    for (final item in items) {
      final price = (item['price'] as num?)?.toDouble() ?? 0;
      final qty = (item['quantity'] as num?)?.toDouble() ?? 1;
      total += price * qty;
    }
    return total;
  }
}

/// Merkezin kendi çevrimdışı siparişi için güvenilir yerel katalogla fiyatlama.
/// Katalog boşsa (hiç senkronize edilmemiş) ürün sessizce istemci fiyatıyla satılmaz.
PricedOfflineItems priceLocalOfflineOrder({
  required RestaurantLocalCacheSnapshot cache,
  required List<Map<String, dynamic>> items,
}) {
  if (cache.products.isEmpty) {
    return const PricedOfflineItems(
      items: <Map<String, dynamic>>[],
      total: 0,
      error: 'Yerel ürün kataloğu hazır değil.',
    );
  }
  return pricedOfflineItems(
    items: items,
    catalog: cache.products,
    requestStationId: '',
  );
}
