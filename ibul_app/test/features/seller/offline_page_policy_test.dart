import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/helpers/offline_overview.dart';
import 'package:ibul_app/features/seller/panel/helpers/offline_page_policy.dart';
import 'package:ibul_app/features/seller/panel/models/seller_panel_types.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_offline_models.dart';

RestaurantLocalOrderRecord _order(
  String id, {
  required int table,
  required double total,
  RestaurantLocalOrderSyncStatus sync =
      RestaurantLocalOrderSyncStatus.pendingSync,
  String print = 'printed',
}) => RestaurantLocalOrderRecord(
  localOrderId: id,
  restaurantId: 'r1',
  tableId: '$table',
  tableName: 'Masa $table',
  tableNumber: table,
  waiterId: 'w',
  waiterName: 'W',
  items: const [],
  notes: '',
  total: total,
  stationGroups: const [],
  printStatus: print,
  syncStatus: sync,
  createdAt: DateTime(2026, 11, 22),
  updatedAt: DateTime(2026, 11, 22),
);

void main() {
  group('çevrimdışı sayfa politikası', () {
    test('yalnız Genel Bakış, Garson ve Sistem çevrimdışı çalışır', () {
      expect(offlineAvailableModules, {
        SellerModule.dashboard,
        SellerModule.garson,
        SellerModule.system,
      });
      for (final m in SellerModule.values) {
        final blocked = moduleBlockedByOffline(module: m, offline: true);
        expect(blocked, !offlineAvailableModules.contains(m), reason: m.name);
        expect(moduleBlockedByOffline(module: m, offline: false), isFalse);
      }
    });

    test(
      'engelli sayfadan dönüş yalnız hesabın zaten sahip olduğu sayfaya',
      () {
        expect(
          offlineFallbackModule([SellerModule.products, SellerModule.system]),
          SellerModule.system,
        );
        expect(offlineFallbackModule([SellerModule.products]), isNull);
        expect(
          openableModules(
            permitted: [SellerModule.finance, SellerModule.garson],
            offline: true,
          ),
          [SellerModule.garson],
        );
        expect(
          openableModules(
            permitted: [SellerModule.finance, SellerModule.garson],
            offline: false,
          ),
          [SellerModule.finance, SellerModule.garson],
        );
      },
    );

    test('açıklama metni sabit', () {
      expect(offlineRequiresInternetMessage, 'İnternet bağlantısı gerektirir');
    });
  });

  group('çevrimdışı Genel Bakış verisi', () {
    final tables = [
      for (final n in [1, 2, 3, 4]) <String, dynamic>{'table_number': n},
    ];

    test('masalar: bulut anlık görüntüsü + yerel siparişler dolu sayılır', () {
      final data = buildOfflineOverview(
        tables: tables,
        cloudTableOrders: [
          {
            'table_number': 1,
            'status': 'sent',
            'items': [
              {'price': 40, 'quantity': 2},
            ],
          },
          {'table_number': 2, 'status': 'closed', 'items': []},
        ],
        localOrders: [_order('a', table: 3, total: 100)],
        cachedAt: DateTime(2026, 11, 22, 10),
      );
      expect(data.totalTables, 4);
      expect(data.occupiedTables, 2); // masa 1 (bulut) + masa 3 (yerel)
      expect(data.freeTables, 2);
      expect(data.cloudOpenOrders, 1);
      expect(data.cloudOpenBillTotal, 80);
      expect(data.localProvisionalTotal, 100);
      expect(data.pendingSync, 1);
      expect(data.tablesKnown, isTrue);
    });

    test('senkronize edilmiş yerel sipariş geçici toplama girmez', () {
      final data = buildOfflineOverview(
        tables: tables,
        cloudTableOrders: const [],
        localOrders: [
          _order(
            's',
            table: 1,
            total: 50,
            sync: RestaurantLocalOrderSyncStatus.synced,
          ),
          _order('p', table: 2, total: 30),
          _order(
            'f',
            table: 3,
            total: 20,
            sync: RestaurantLocalOrderSyncStatus.syncFailed,
          ),
        ],
        cachedAt: null,
      );
      expect(data.localOrders, 2);
      expect(data.localProvisionalTotal, 50);
      expect(data.pendingSync, 1);
      expect(data.syncFailed, 1);
      expect(data.lastCloudSnapshotAt, isNull);
    });

    test(
      'baskı durumları ayrı sayılır; belirsiz/başarısız "iletildi" sayılmaz',
      () {
        final data = buildOfflineOverview(
          tables: tables,
          cloudTableOrders: const [],
          localOrders: [
            _order('a', table: 1, total: 1, print: 'printed'),
            _order('b', table: 2, total: 1, print: 'pending'),
            _order('c', table: 3, total: 1, print: 'uncertain'),
            _order('d', table: 4, total: 1, print: 'failed'),
          ],
          cachedAt: null,
        );
        expect(data.localKitchenSent, 1);
        expect(data.localPrintWaiting, 1);
        expect(data.localPrintUnverified, 2);
      },
    );

    test(
      'masa listesi hiç yoksa masalar bilinmiyor ve boş masa uydurulmaz',
      () {
        final data = buildOfflineOverview(
          tables: const [],
          cloudTableOrders: const [],
          localOrders: [_order('a', table: 7, total: 10)],
          cachedAt: null,
        );
        expect(data.tablesKnown, isFalse);
        expect(data.totalTables, 0);
        expect(data.freeTables, 0);
      },
    );
  });
}
