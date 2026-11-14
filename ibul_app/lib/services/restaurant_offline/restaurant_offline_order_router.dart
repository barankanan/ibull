import '../../features/seller/panel/helpers/restaurant_printer_eligibility.dart';
import '../bridge_print_dispatch_verification.dart';
import '../kitchen_routing_service.dart';
import '../order_print_job_service.dart';
import 'restaurant_connectivity_service.dart';
import 'restaurant_local_cache_service.dart';
import 'restaurant_local_order_queue_service.dart';
import 'restaurant_local_print_queue_service.dart';
import 'restaurant_lan_host.dart';
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
  }) : _connectivity = connectivityService ?? RestaurantConnectivityService.instance,
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
  }) async {
    if (skipOfflineFallback) return false;
    if (!canUseRestaurantPrinterSystem(storeCategory)) return false;
    await _connectivity.refresh();
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
    final hostHere = host != null &&
        host.listening &&
        host.restaurantId == restaurantId;
    final hostReady = hostHere && host.lanIdentityVerified;
    final pairedTablet =
        RestaurantLanPairing.transport != null && !hostHere;
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
    final hostHere = host != null &&
        host.listening &&
        host.restaurantId == restaurantId;
    final transport = RestaurantLanPairing.transport;
    if (transport == null && !hostHere) {
      throw StateError(
        'Yerel sunucu kapalı. Sipariş gönderilmedi.',
      );
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
          'message': 'Sipariş ana bilgisayara kaydedildi.',
        },
        dispatchedJobCount: 0,
        failedJobCount: 0,
        physicallyDispatched: false,
        dispatchPath: 'lan_host',
        traceId: '',
      );
    }

    final persisted = await _orderQueue.enqueue(order: order);

    final immediate = await _orderPrintJobServiceOrCreate
        .dispatchGarsonKitchenImmediateFromItems(
          restaurantId: restaurantId,
          tableNumber: tableNumber,
          items: items,
          waiterId: waiterId,
          waiterName: waiterName,
          waiterTitle: waiterTitle,
          canUseLocalPrintFastPath: true,
          tableAreaName: tableName,
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
        'items': items,
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
                    ? BridgePrintDispatchVerification.dispatchNotDeliveredMessage
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
