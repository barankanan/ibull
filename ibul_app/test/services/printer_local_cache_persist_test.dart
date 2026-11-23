import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_local_cache_service.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_offline_snapshot_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('kayıtlı yazıcı yerel önbelleğe yazılır; boş liste onu silmez', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final cache = RestaurantLocalCacheService();
    final sync = RestaurantOfflineSnapshotSync(cacheService: cache);
    const id = '11111111-1111-1111-1111-111111111111';
    await sync.upsertFromSellerPanelState(
      restaurantId: id,
      storeName: 'x',
      sellerId: id,
      storeCategory: 'Restoran',
      printers: const [
        {'id': 'p1', 'name': 'aa', 'connection_type': 'ethernet', 'ip_address': '192.168.10.100', 'port': 9100},
      ],
    );
    expect((await cache.read(id))?.printers.single['name'], 'aa');
    await sync.upsertFromSellerPanelState(
      restaurantId: id,
      storeName: 'x',
      sellerId: id,
      storeCategory: 'Restoran',
    );
    expect((await cache.read(id))?.printers.single['name'], 'aa');
  });
}
