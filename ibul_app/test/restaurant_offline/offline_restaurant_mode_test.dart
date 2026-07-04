import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/helpers/restaurant_printer_eligibility.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_connectivity_service.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_local_cache_service.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_local_order_queue_service.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_local_print_queue_service.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_offline_models.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_offline_order_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    RestaurantConnectivityService.resetInstanceForTests();
    RestaurantLocalOrderQueueService.clearAllMemoryForTests();
    RestaurantLocalPrintQueueService.clearAllMemoryForTests();
  });

  group('RestaurantLocalCacheService', () {
    test('online snapshot cache writes and reads', () async {
      final cacheService = RestaurantLocalCacheService();
      await cacheService.upsertFromOnlineSnapshot(
        restaurantId: 'rest-1',
        restaurantName: 'Test Restoran',
        sellerId: 'rest-1',
        storeCategory: 'Yemek / Restoran',
        tables: <Map<String, dynamic>>[
          <String, dynamic>{'id': 't1', 'table_number': 1},
        ],
      );

      final snapshot = await cacheService.read('rest-1');
      expect(snapshot, isNotNull);
      expect(snapshot!.restaurantName, 'Test Restoran');
      expect(snapshot.tables.length, 1);
    });

    test('cache missing returns null and message', () async {
      final cacheService = RestaurantLocalCacheService();
      final snapshot = await cacheService.read('missing-restaurant');
      expect(snapshot, isNull);
      expect(
        cacheService.missingCacheMessage(),
        contains('çevrimdışı veri bulunamadı'),
      );
    });
  });

  group('RestaurantLocalOrderQueueService', () {
    test('offline order is written to local queue', () async {
      final queue = RestaurantLocalOrderQueueService();
      final order = RestaurantLocalOrderRecord(
        localOrderId: 'local-order-1',
        restaurantId: 'rest-1',
        tableId: '1',
        tableName: 'Masa 1',
        tableNumber: 1,
        waiterId: 'w1',
        waiterName: 'Ali',
        items: <Map<String, dynamic>>[
          <String, dynamic>{'name': 'Çorba', 'quantity': 1, 'price': 50},
        ],
        notes: '',
        total: 50,
        stationGroups: const <Map<String, dynamic>>[],
        printStatus: 'pending',
        syncStatus: RestaurantLocalOrderSyncStatus.pendingSync,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await queue.enqueue(order: order);
      final pending = await queue.pendingSyncCount('rest-1');
      expect(pending, 1);
    });

    test('duplicate local_order_id is idempotent', () async {
      final queue = RestaurantLocalOrderQueueService();
      final order = RestaurantLocalOrderRecord(
        localOrderId: 'local-order-dup',
        restaurantId: 'rest-1',
        tableId: '2',
        tableName: 'Masa 2',
        tableNumber: 2,
        waiterId: '',
        waiterName: '',
        items: const <Map<String, dynamic>>[],
        notes: '',
        total: 0,
        stationGroups: const <Map<String, dynamic>>[],
        printStatus: 'pending',
        syncStatus: RestaurantLocalOrderSyncStatus.pendingSync,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await queue.enqueue(order: order);
      await queue.enqueue(order: order);
      final orders = await queue.list('rest-1');
      expect(orders.length, 1);
    });
  });

  group('RestaurantLocalPrintQueueService', () {
    test('bridge fail marks local print job failed', () async {
      final queue = RestaurantLocalPrintQueueService();
      final job = RestaurantLocalPrintJobRecord(
        localJobId: 'local-print-1',
        restaurantId: 'rest-1',
        localOrderId: 'local-order-1',
        tableId: '1',
        tableName: 'Masa 1',
        documentType: 'kitchen',
        role: 'mutfak',
        station: 'Genel',
        printerSnapshot: <String, dynamic>{
          'id': 'printer-1',
          'name': 'Mutfak',
          'backend': 'tcp',
        },
        payloadSnapshot: <String, dynamic>{'table_number': 1},
        status: RestaurantLocalPrintJobStatus.created,
        attempts: 0,
        createdAt: DateTime.now(),
      );
      await queue.enqueue(job: job);
      final result = await queue.dispatchJob(
        job: job,
        bridgeReachable: false,
      );
      expect(result.status, RestaurantLocalPrintJobStatus.failed);
      expect(result.lastError, contains('Yazıcı köprüsü çalışmıyor'));
    });
  });

  group('RestaurantOfflineOrderRouter', () {
    test('non-food seller does not route offline', () async {
      final connectivity = RestaurantConnectivityService();
      connectivity.debugSkipNetworkProbes = true;
      connectivity.debugSetConnectivity(
        hasNetwork: false,
        supabaseReachable: false,
        bridgeReachable: true,
      );
      final router = RestaurantOfflineOrderRouter(
        connectivityService: connectivity,
      );
      final shouldRoute = await router.shouldRouteOffline(
        restaurantId: 'rest-1',
        storeCategory: 'Elektronik',
      );
      expect(shouldRoute, isFalse);
      expect(canUseRestaurantPrinterSystem('Elektronik'), isFalse);
    });

    test('offline routing requires existing cache', () async {
      final connectivity = RestaurantConnectivityService();
      connectivity.debugSkipNetworkProbes = true;
      connectivity.debugSetConnectivity(
        hasNetwork: false,
        supabaseReachable: false,
        bridgeReachable: true,
      );
      final router = RestaurantOfflineOrderRouter(
        connectivityService: connectivity,
      );
      final shouldRoute = await router.shouldRouteOffline(
        restaurantId: 'rest-without-cache',
        storeCategory: 'Restoran',
      );
      expect(shouldRoute, isFalse);
    });
  });

  group('RestaurantConnectivityService', () {
    test('pending sync visible when offline with cache', () async {
      final cacheService = RestaurantLocalCacheService();
      await cacheService.upsertFromOnlineSnapshot(
        restaurantId: 'rest-1',
        restaurantName: 'Rest',
        sellerId: 'rest-1',
        storeCategory: 'Restoran',
      );
      final queue = RestaurantLocalOrderQueueService();
      await queue.enqueue(
        order: RestaurantLocalOrderRecord(
          localOrderId: 'local-order-pending',
          restaurantId: 'rest-1',
          tableId: '3',
          tableName: 'Masa 3',
          tableNumber: 3,
          waiterId: '',
          waiterName: '',
          items: const <Map<String, dynamic>>[],
          notes: '',
          total: 0,
          stationGroups: const <Map<String, dynamic>>[],
          printStatus: 'pending',
          syncStatus: RestaurantLocalOrderSyncStatus.pendingSync,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final pending = await queue.pendingSyncCount('rest-1');
      expect(pending, 1);
    });
  });
}
