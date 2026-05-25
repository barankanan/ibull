import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/kitchen_routing_service.dart';

void main() {
  group('KitchenTicketHeaderResolver', () {
    test('product mapping Ocak wins over table_area Salon', () {
      final mappings = <String, ProductStationMapping>{
        'ciger': const ProductStationMapping(
          stationId: 'ocak-id',
          stationName: 'Ocak',
          stationCode: 'OCAK',
        ),
      };
      final header = KitchenTicketHeaderResolver.finalizeKitchenTicketHeader(
        rawItems: <Map<String, dynamic>>[
          <String, dynamic>{
            'product_id': 'ciger',
            'station_name': 'Salon',
          },
        ],
        payload: <String, dynamic>{
          'table_area_name': 'Salon',
          'area_name': 'Salon',
          'station_name': 'Salon',
        },
        productStationByProductId: mappings,
        tableAreaName: 'Salon',
      );
      expect(header, 'OCAK');
    });

    test('stamp replaces legacy area_name Salon with station_code OCAK', () {
      final stamped = KitchenTicketHeaderResolver.stampProductionHeaderOnKitchenPayload(
        <String, dynamic>{
          'area_name': 'Salon',
          'table_area_name': 'Salon',
          'station_name': 'Ocak',
          'station_code': 'OCAK',
          'items': <Map<String, dynamic>>[
            <String, dynamic>{'product_name': 'Ciğer', 'quantity': 1},
          ],
        },
      );
      expect(stamped['area_name'], 'OCAK');
      expect(stamped['station_name'], 'OCAK');
    });

    test('table_area Salon without mapping yields GENEL not Salon', () {
      final header = KitchenTicketHeaderResolver.finalizeKitchenTicketHeader(
        rawItems: <Map<String, dynamic>>[
          <String, dynamic>{'product_id': 'p1', 'name': 'Ciğer'},
        ],
        payload: <String, dynamic>{
          'table_area_name': 'Salon',
          'station_name': 'Salon',
        },
        tableAreaName: 'Salon',
      );
      expect(header, kKitchenGeneralStationLabel);
    });

    test('Teras table with Ocak product mapping yields OCAK', () {
      final enriched =
          KitchenTicketHeaderResolver.enrichItemsWithProductionStations(
        items: <Map<String, dynamic>>[
          <String, dynamic>{'product_id': 'ciger', 'name': 'Ciğer Servis'},
        ],
        stationNamesById: const <String, String>{},
        productStationByProductId: <String, ProductStationMapping>{
          'ciger': const ProductStationMapping(
            stationId: 'ocak-id',
            stationName: 'Ocak',
            stationCode: 'OCAK',
          ),
        },
        tableAreaName: 'Teras',
      );
      expect(enriched.single['station_id'], 'ocak-id');
      expect(enriched.single['station_name'], 'OCAK');
    });

    test('Ocak and Fırın items produce two station groups', () {
      final cache = <String, String>{
        'ocak': 'Ocak',
        'firin': 'Fırın',
      };
      final codes = <String, String>{
        'ocak': 'OCAK',
        'firin': 'FIRIN',
      };
      final items = <Map<String, dynamic>>[
        <String, dynamic>{'product_id': 'ciger', 'station_id': 'ocak'},
        <String, dynamic>{'product_id': 'lahmacun', 'station_id': 'firin'},
      ];
      final enriched =
          KitchenTicketHeaderResolver.enrichItemsWithProductionStations(
        items: items,
        stationNamesById: cache,
        stationCodesById: codes,
      );
      final stationIds = enriched
          .map((item) => item['station_id']?.toString())
          .whereType<String>()
          .toSet();
      expect(stationIds, containsAll(<String>['ocak', 'firin']));
    });

    test('station code used for header label', () {
      expect(
        KitchenTicketHeaderResolver.productionHeaderLabel(
          stationName: 'Ocak',
          stationCode: 'OCAK',
        ),
        'OCAK',
      );
    });

    test('payload station_code OCAK wins over dining area_name Salon', () {
      final stamped = KitchenTicketHeaderResolver.stampProductionHeaderOnKitchenPayload(
        <String, dynamic>{
          'area_name': 'Salon',
          'table_area_name': 'Salon',
          'station_code': 'OCAK',
          'items': <Map<String, dynamic>>[
            <String, dynamic>{'product_id': 'ciger', 'name': 'Ciğer Servis'},
          ],
        },
      );
      expect(stamped['area_name'], 'OCAK');
      expect(stamped['kitchen_ticket_header'], 'OCAK');
    });

    test('reject_table_area_header logs area=Salon', () {
      final header = KitchenTicketHeaderResolver.finalizeKitchenTicketHeader(
        rawItems: <Map<String, dynamic>>[
          <String, dynamic>{'product_id': 'p1'},
        ],
        payload: <String, dynamic>{'table_area_name': 'Salon'},
        tableAreaName: 'Salon',
      );
      expect(header, kKitchenGeneralStationLabel);
    });
  });
}
