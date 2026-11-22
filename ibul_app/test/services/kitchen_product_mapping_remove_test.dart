import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/kitchen_product_mapping_cache_store.dart';
import 'package:ibul_app/services/kitchen_routing_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a cleared product mapping leaves the cache and the disk copy', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const restaurant = 'rest-remove-1';
    const mapping = ProductStationMapping(
      stationId: 'st-1',
      stationName: 'Ocak',
      stationCode: 'OCAK',
    );
    await KitchenProductMappingCacheStore.persistSingleProduct(
      restaurantId: restaurant,
      productId: 'p-1',
      productName: 'Adana Kebap',
      mapping: mapping,
    );
    await KitchenProductMappingCacheStore.persistSingleProduct(
      restaurantId: restaurant,
      productId: 'p-2',
      productName: 'Lahmacun',
      mapping: mapping,
    );
    expect(
      KitchenProductMappingCacheStore.productNameKeys(restaurant),
      isNotEmpty,
    );

    await KitchenProductMappingCacheStore.removeProduct(
      restaurantId: restaurant,
      productId: 'p-1',
      productName: 'Adana Kebap',
    );

    final diag = KitchenProductMappingCacheStore.diagnostics(restaurant);
    expect(diag.toString(), isNot(contains('p-1')));
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getKeys().map(prefs.get).join('|');
    expect(stored, isNot(contains('p-1')));
    expect(stored, contains('p-2'));
  });
}
