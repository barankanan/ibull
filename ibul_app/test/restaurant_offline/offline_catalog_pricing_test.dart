import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/offline_catalog_pricing.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_offline_models.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_offline_order_router.dart';

const _catalog = <Map<String, dynamic>>[
  <String, dynamic>{
    'id': 'corba',
    'name': 'Çorba',
    'price': 40,
    'station_id': 'ocak',
  },
  <String, dynamic>{
    'id': 'ayran',
    'name': 'Ayran',
    'price': 15,
    'station_id': 'bar',
  },
];

RestaurantLocalCacheSnapshot _snapshot(List<Map<String, dynamic>> products) =>
    RestaurantLocalCacheSnapshot(
      restaurantId: 'r1',
      restaurantName: 'Test',
      sellerId: 'r1',
      storeCategory: 'Restoran',
      tables: const [],
      tableOrderSnapshots: const [],
      products: products,
      stations: const [],
      printers: const [],
      stationPrinters: const [],
      printerRoles: const {},
      printerProfiles: const {},
      productStationMappings: const {},
      discoveredPrinters: const [],
      lastSetupSnapshot: const {},
      cachedAt: DateTime(2026, 11, 22),
    );

void main() {
  group('pricedOfflineItems (tek fiyat sözleşmesi)', () {
    PricedOfflineItems price(List<Map<String, dynamic>> items) =>
        pricedOfflineItems(
          items: items,
          catalog: _catalog,
          requestStationId: '',
        );

    test('katalog fiyatı kullanılır, toplam ve satır toplamı hesaplanır', () {
      final r = price([
        {'product_id': 'corba', 'name': 'Çorba', 'quantity': 2, 'price': 40},
        {'product_id': 'ayran', 'name': 'Ayran', 'quantity': 1},
      ]);
      expect(r.error, isNull);
      expect(r.total, 95);
      expect(r.items.first['line_total'], 80.0);
      expect(r.items.last['price'], 15);
    });

    test('katalogda olmayan ürün satılmaz', () {
      final r = price([
        {'product_id': 'yok', 'name': 'Bilinmeyen', 'quantity': 1, 'price': 10},
      ]);
      expect(r.error, contains('katalogda yok'));
      expect(r.items, isEmpty);
    });

    test('istemci fiyatı katalogla uyuşmuyorsa reddedilir', () {
      final r = price([
        {'product_id': 'corba', 'name': 'Çorba', 'quantity': 1, 'price': 1},
      ]);
      expect(r.error, contains('uyuşmuyor'));
    });

    test('boş sipariş ve geçersiz adet reddedilir', () {
      expect(price(const []).error, isNotNull);
      expect(
        price([
          {'product_id': 'corba', 'name': 'Çorba', 'quantity': 0},
        ]).error,
        contains('adedi geçersiz'),
      );
    });

    test('ürünün istasyonu ile kalemin istasyonu çelişirse reddedilir', () {
      final r = price([
        {
          'product_id': 'corba',
          'name': 'Çorba',
          'quantity': 1,
          'station_id': 'bar',
        },
      ]);
      expect(r.error, contains('istasyona ait değil'));
    });
  });

  group('merkezin kendi çevrimdışı siparişi (priceLocalOfflineOrder)', () {
    final line = <Map<String, dynamic>>[
      {'product_id': 'corba', 'name': 'Çorba', 'quantity': 1, 'price': 40},
    ];

    test('katalog hiç senkronize edilmediyse sipariş fiyatlanmaz', () {
      final r = priceLocalOfflineOrder(cache: _snapshot(const []), items: line);
      expect(r.error, 'Yerel ürün kataloğu hazır değil.');
      expect(r.items, isEmpty);
    });

    test('katalogdaki ürün katalog fiyatıyla kabul edilir', () {
      final r = priceLocalOfflineOrder(cache: _snapshot(_catalog), items: line);
      expect(r.error, isNull);
      expect(r.total, 40);
    });

    test(
      'istemci fiyatı farklıysa reddedilir, katalog fiyatı geçerli kalır',
      () {
        final r = priceLocalOfflineOrder(
          cache: _snapshot(_catalog),
          items: [
            {'product_id': 'corba', 'name': 'Çorba', 'quantity': 1, 'price': 1},
          ],
        );
        expect(r.error, contains('uyuşmuyor'));
      },
    );
  });
}
