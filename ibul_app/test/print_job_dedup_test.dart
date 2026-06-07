import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/utils/kitchen_print_dedup.dart';

void main() {
  group('kitchen print idempotency', () {
    test('same order station revision yields stable key', () {
      final items = <Map<String, dynamic>>[
        <String, dynamic>{
          'product_id': 'p-1',
          'name': 'Ciğer Şiş',
          'quantity': 1,
          'station_id': 'ocak',
          'station_name': 'Ocak',
        },
        <String, dynamic>{
          'product_id': 'p-2',
          'name': 'Kuzu Pirzola',
          'quantity': 2,
          'station_id': 'ocak',
          'station_name': 'Ocak',
        },
      ];
      final keyA = buildKitchenPrintIdempotencyKey(
        restaurantId: 'rest-1',
        orderId: 'order-1',
        stationId: 'station-ocak',
        stationName: 'Ocak',
        revision: 3,
        items: items,
      );
      final keyB = buildKitchenPrintIdempotencyKey(
        restaurantId: 'rest-1',
        orderId: 'order-1',
        stationId: 'station-ocak',
        stationName: 'Ocak',
        revision: 3,
        items: items.reversed.toList(growable: false),
      );
      expect(keyA, keyB);
    });

    test('revision change changes key', () {
      final baseItems = <Map<String, dynamic>>[
        <String, dynamic>{
          'product_id': 'p-1',
          'name': 'Ciğer Şiş',
          'quantity': 1,
          'station_id': 'ocak',
          'station_name': 'Ocak',
        },
      ];
      final firstRevision = buildKitchenPrintIdempotencyKey(
        restaurantId: 'rest-1',
        orderId: 'order-1',
        stationId: 'station-ocak',
        stationName: 'Ocak',
        revision: 1,
        items: baseItems,
      );
      final secondRevision = buildKitchenPrintIdempotencyKey(
        restaurantId: 'rest-1',
        orderId: 'order-1',
        stationId: 'station-ocak',
        stationName: 'Ocak',
        revision: 2,
        items: baseItems,
      );
      expect(firstRevision, isNot(secondRevision));
    });

    test(
      'dedupe keeps first job id for duplicate same order station revision',
      () {
        final firstKey = buildKitchenPrintIdempotencyKey(
          restaurantId: 'rest-1',
          orderId: 'order-42',
          stationId: 'station-ocak',
          stationName: 'Ocak',
          revision: 5,
          items: const <Map<String, dynamic>>[
            <String, dynamic>{
              'product_id': 'p-1',
              'name': 'Adana',
              'quantity': 1,
              'station_id': 'station-ocak',
              'station_name': 'Ocak',
            },
          ],
        );
        final deduped = dedupeKitchenJobIdsByKey(<String, String>{
          'job-1': firstKey,
          'job-2': firstKey,
          'job-3': '$firstKey|different',
        });

        expect(deduped.primaryJobIds, <String>['job-1', 'job-3']);
        expect(deduped.duplicateOfByJobId, <String, String>{'job-2': 'job-1'});
      },
    );
  });
}
