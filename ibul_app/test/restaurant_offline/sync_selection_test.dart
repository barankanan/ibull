import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_connectivity_service.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_local_order_queue_service.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_offline_models.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_offline_sync_service.dart';

final _now = DateTime(2026, 11, 22, 12);

RestaurantLocalOrderRecord _o(
  String id, {
  required RestaurantLocalOrderSyncStatus sync,
  required DateTime created,
  DateTime? updated,
}) => RestaurantLocalOrderRecord(
  localOrderId: id,
  restaurantId: 'r1',
  tableId: '1',
  tableName: 'Masa 1',
  tableNumber: 1,
  waiterId: 'w',
  waiterName: 'W',
  items: const [
    {'product_id': 'p', 'name': 'Ürün', 'quantity': 1, 'price': 10},
  ],
  notes: '',
  total: 10,
  stationGroups: const [],
  printStatus: 'printed',
  syncStatus: sync,
  createdAt: created,
  updatedAt: updated ?? created,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    RestaurantLocalOrderQueueService.clearAllMemoryForTests();
  });
  group('selectOrdersForSync', () {
    const suspect = 'local-order-1793736854400492-1173607028';

    test('karantina listesi yalnız şüpheli 3 Kasım kaydını içerir', () {
      expect(quarantinedLocalOrderIds, {suspect});
    });

    test('karantinadaki kimlik hiçbir durumda gönderilmez (otomatik, elle, '
        'durumu ne olursa olsun)', () {
      for (final status in RestaurantLocalOrderSyncStatus.values) {
        final r = selectOrdersForSync(
          [_o(suspect, sync: status, created: DateTime(2026, 11, 3, 23, 14))],
          now: _now,
          retryAfter: Duration.zero,
        );
        expect(r, isEmpty, reason: 'durum: $status');
      }
    });

    test('uzun süre çevrimdışı kalmış geçerli siparişler yaş yüzünden '
        'engellenmez; yalnız karantinadaki kimlik dışarıda kalır', () {
      final r = selectOrdersForSync([
        _o(
          suspect,
          sync: RestaurantLocalOrderSyncStatus.syncFailed,
          created: DateTime(2026, 11, 3, 23, 14),
        ),
        // Aynı gece alınmış, kimliği farklı geçerli sipariş.
        _o(
          'local-order-1793736854400493-1173607029',
          sync: RestaurantLocalOrderSyncStatus.syncFailed,
          created: DateTime(2026, 11, 3, 23, 15),
        ),
        _o(
          'otuz-gun',
          sync: RestaurantLocalOrderSyncStatus.pendingSync,
          created: _now.subtract(const Duration(days: 30)),
        ),
        _o(
          'kirk-dokuz-saat',
          sync: RestaurantLocalOrderSyncStatus.pendingSync,
          created: _now.subtract(const Duration(hours: 49)),
        ),
        _o(
          'dun',
          sync: RestaurantLocalOrderSyncStatus.pendingSync,
          created: _now.subtract(const Duration(hours: 20)),
        ),
      ], now: _now, retryAfter: Duration.zero);
      expect(r.map((o) => o.localOrderId), [
        'otuz-gun',
        'kirk-dokuz-saat',
        'dun',
        'local-order-1793736854400493-1173607029',
      ]);
    });

    test('karantina kümesi dışarıdan verilebilir (yeni şüpheli kayıt)', () {
      final r = selectOrdersForSync(
        [
          _o(
            'a',
            sync: RestaurantLocalOrderSyncStatus.pendingSync,
            created: _now,
          ),
          _o(
            'b',
            sync: RestaurantLocalOrderSyncStatus.pendingSync,
            created: _now,
          ),
        ],
        now: _now,
        quarantined: const {'a'},
      );
      expect(r.map((o) => o.localOrderId), ['b']);
    });

    test('hiç denenmemişler önce, en eski oluşturulan önce', () {
      final r = selectOrdersForSync([
        _o(
          'yeni',
          sync: RestaurantLocalOrderSyncStatus.pendingSync,
          created: _now.subtract(const Duration(minutes: 1)),
        ),
        _o(
          'eski',
          sync: RestaurantLocalOrderSyncStatus.pendingSync,
          created: _now.subtract(const Duration(minutes: 9)),
        ),
      ], now: _now);
      expect(r.map((o) => o.localOrderId), ['eski', 'yeni']);
    });

    test(
      'sürekli hata veren eski siparişler yenilerin önüne geçmez (açlık yok)',
      () {
        final failing = [
          for (var i = 0; i < 12; i++)
            _o(
              'hata$i',
              sync: RestaurantLocalOrderSyncStatus.syncFailed,
              created: _now.subtract(Duration(hours: 5 + i)),
              updated: _now.subtract(const Duration(minutes: 5)),
            ),
        ];
        final fresh = _o(
          'taze',
          sync: RestaurantLocalOrderSyncStatus.pendingSync,
          created: _now.subtract(const Duration(minutes: 1)),
        );
        final r = selectOrdersForSync(
          [...failing, fresh],
          now: _now,
          limit: 10,
        );
        expect(r.first.localOrderId, 'taze');
        expect(r.length, 10);
      },
    );

    test(
      'hata almış sipariş bekleme süresi dolmadan atlanır, dolunca en eski denenen önce',
      () {
        final justFailed = _o(
          'az-once',
          sync: RestaurantLocalOrderSyncStatus.syncFailed,
          created: _now.subtract(const Duration(hours: 1)),
          updated: _now.subtract(const Duration(seconds: 5)),
        );
        final oldFail = _o(
          'eski-hata',
          sync: RestaurantLocalOrderSyncStatus.syncFailed,
          created: _now.subtract(const Duration(hours: 1)),
          updated: _now.subtract(const Duration(minutes: 10)),
        );
        final mid = _o(
          'orta-hata',
          sync: RestaurantLocalOrderSyncStatus.syncFailed,
          created: _now.subtract(const Duration(hours: 1)),
          updated: _now.subtract(const Duration(minutes: 2)),
        );
        final r = selectOrdersForSync([justFailed, mid, oldFail], now: _now);
        expect(r.map((o) => o.localOrderId), ['eski-hata', 'orta-hata']);
        final forced = selectOrdersForSync(
          [justFailed, mid, oldFail],
          now: _now,
          retryAfter: Duration.zero,
        );
        expect(forced.map((o) => o.localOrderId), [
          'eski-hata',
          'orta-hata',
          'az-once',
        ]);
      },
    );

    test('limit uygulanır, boş liste boş döner', () {
      expect(selectOrdersForSync(const [], now: _now), isEmpty);
      final many = [
        for (var i = 0; i < 25; i++)
          _o(
            's$i',
            sync: RestaurantLocalOrderSyncStatus.pendingSync,
            created: _now.subtract(Duration(minutes: i)),
          ),
      ];
      expect(selectOrdersForSync(many, now: _now, limit: 10).length, 10);
    });
  });

  group('oturum yokken gönderim denenmez', () {
    test(
      'sipariş pendingSync kalır, hata işaretlenmez, sunucuya gidilmez',
      () async {
        final connectivity = RestaurantConnectivityService()
          ..debugSkipNetworkProbes = true
          ..debugSetConnectivity(
            hasNetwork: true,
            supabaseReachable: true,
            bridgeReachable: false,
          );
        final queue = RestaurantLocalOrderQueueService();
        await queue.enqueue(
          order: _o(
            'bekleyen',
            sync: RestaurantLocalOrderSyncStatus.pendingSync,
            created: _now,
          ),
        );
        final sync = RestaurantOfflineSyncService(
          orderQueue: queue,
          connectivityService: connectivity,
        )..hasCloudSession = () => false;
        expect(await sync.syncPendingOrders(restaurantId: 'r1'), 0);
        final after = await queue.getByLocalId(
          restaurantId: 'r1',
          localOrderId: 'bekleyen',
        );
        expect(after?.syncStatus, RestaurantLocalOrderSyncStatus.pendingSync);
        expect(after?.syncError, isNull);
      },
    );
  });

  group('karantina sayımı', () {
    const suspect = 'local-order-1793736854400492-1173607028';
    test('karantinadaki kayıt bekleyen sayılmaz; yeni bekleyen ayrı sayılır '
        've kayıtlar korunur', () async {
      final queue = RestaurantLocalOrderQueueService();
      await queue.enqueue(
        order: _o(
          suspect,
          sync: RestaurantLocalOrderSyncStatus.syncFailed,
          created: DateTime(2026, 11, 3),
        ),
      );
      final sync = RestaurantOfflineSyncService(orderQueue: queue);
      expect(await sync.quarantinedPendingCount('r1'), 1);
      expect((await sync.pendingOrders('r1')).length, 1);

      await queue.enqueue(
        order: _o(
          'yeni',
          sync: RestaurantLocalOrderSyncStatus.pendingSync,
          created: _now,
        ),
      );
      expect(await sync.quarantinedPendingCount('r1'), 1);
      expect((await sync.pendingOrders('r1')).length, 2);
      // Count is read-only: nothing was deleted or rewritten.
      final kept = await queue.getByLocalId(
        restaurantId: 'r1',
        localOrderId: suspect,
      );
      expect(kept?.syncStatus, RestaurantLocalOrderSyncStatus.syncFailed);
    });
  });
}
