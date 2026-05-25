import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/kitchen_hub_payload_stamp.dart';
import 'package:ibul_app/services/kitchen_product_mapping_cache_store.dart';
import 'package:ibul_app/services/kitchen_routing_service.dart';

void main() {
  setUp(() {
    KitchenTicketHeaderResolver.registerRestaurantProductStationMappings(
      'rest-1',
      <String, ProductStationMapping>{
        'ciger-id': const ProductStationMapping(
          stationId: 'ocak-id',
          stationName: 'Ocak',
          stationCode: 'OCAK',
        ),
      },
      productNamesByProductId: <String, String>{
        'ciger-id': 'Ciğer Servis',
      },
    );
    KitchenTicketHeaderResolver.registerRestaurantStationCaches(
      restaurantId: 'rest-1',
      stationNamesById: <String, String>{'ocak-id': 'Ocak'},
      stationCodesById: <String, String>{'ocak-id': 'OCAK'},
    );
  });

  test('isHubKitchenPrintJob accepts SQL items with name only', () {
    expect(
      isHubKitchenPrintJob(
        <String, dynamic>{
          'items': <Map<String, dynamic>>[
            <String, dynamic>{'name': 'Ciğer Servis', 'quantity': 1},
          ],
        },
        <String, dynamic>{'job_type': 'new_order'},
      ),
      isTrue,
    );
  });

  test('hub stamp replaces Salon area_name with OCAK from product name', () {
    final stamped = stampHubKitchenPrintPayload(
      restaurantId: 'rest-1',
      payload: <String, dynamic>{
        'area_name': 'Salon',
        'station_name': 'Genel',
        'station_code': 'GENEL',
        'table_area_name': 'Salon',
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'product_name': 'Ciğer Servis',
            'quantity': 1,
          },
        ],
      },
    );

    expect(stamped['area_name'], 'OCAK');
    expect(stamped['station_name'], 'OCAK');
    expect(stamped['kitchen_ticket_header'], 'OCAK');
    expect(stamped['table_area_name'], 'Salon');
    final items = stamped['items'] as List;
    expect(items.first['station_name'], 'OCAK');
    expect(items.first['station_code'], 'OCAK');
  });

  test('hub stamp resolves Turkish product name with folded cache key', () {
    KitchenTicketHeaderResolver.registerRestaurantProductStationMappings(
      'rest-2',
      <String, ProductStationMapping>{
        'ciger-id': const ProductStationMapping(
          stationId: 'ocak-id',
          stationName: 'Ocak',
          stationCode: 'OCAK',
        ),
      },
      productNamesByProductId: <String, String>{
        'ciger-id': 'Ciğer Servis',
      },
    );
    final stamped = stampHubKitchenPrintPayload(
      restaurantId: 'rest-2',
      payload: <String, dynamic>{
        'area_name': 'Salon',
        'table_area_name': 'Salon',
        'items': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'ciger servis', 'quantity': 1},
        ],
      },
    );
    expect(stamped['area_name'], 'OCAK');
  });

  test('hub stamp resolves via KitchenProductMappingCacheStore name index', () {
    KitchenProductMappingCacheStore.upsertProductSync(
      restaurantId: 'rest-cache',
      productId: 'ciger-id',
      productName: 'Ciğer Servis',
      mapping: const ProductStationMapping(
        stationId: 'ocak-id',
        stationName: 'Ocak',
        stationCode: 'OCAK',
      ),
      source: 'test',
    );
    KitchenTicketHeaderResolver.registerRestaurantStationCaches(
      restaurantId: 'rest-cache',
      stationNamesById: <String, String>{'ocak-id': 'Ocak'},
      stationCodesById: <String, String>{'ocak-id': 'OCAK'},
    );
    final stamped = stampHubKitchenPrintPayload(
      restaurantId: 'rest-cache',
      payload: <String, dynamic>{
        'area_name': 'Salon',
        'table_area_name': 'Salon',
        'items': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'Ciğer Servis', 'quantity': 1},
        ],
      },
    );
    expect(stamped['area_name'], 'OCAK');
    expect(
      KitchenProductMappingCacheStore.diagnostics('rest-cache')['mappingCount'],
      greaterThan(0),
    );
  });

  test('hub stamp without mapping yields GENEL not Salon', () {
    final stamped = stampHubKitchenPrintPayload(
      restaurantId: 'rest-empty',
      payload: <String, dynamic>{
        'area_name': 'Salon',
        'table_area_name': 'Salon',
        'items': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'Bilinmeyen Ürün', 'quantity': 1},
        ],
      },
    );
    expect(stamped['area_name'], 'GENEL');
    expect(stamped['table_area_name'], 'Salon');
  });
}
