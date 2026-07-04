import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/utils/garson_flow_cache.dart';

void main() {
  group('reprint performance helpers', () {
    test('reprint existing kitchen jobs per station seçilir', () {
      final jobs = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'job-old',
          'station_id': 'station-a',
          'created_at': '2026-01-01T10:00:00.000Z',
          'payload': <String, dynamic>{
            'document_type': 'kitchen',
            'station_name': 'Izgara',
            'items': <Map<String, dynamic>>[
              <String, dynamic>{'name': 'Köfte', 'quantity': 1},
            ],
          },
        },
        <String, dynamic>{
          'id': 'job-new',
          'station_id': 'station-a',
          'created_at': '2026-01-01T11:00:00.000Z',
          'payload': <String, dynamic>{
            'document_type': 'kitchen',
            'station_name': 'Izgara',
            'items': <Map<String, dynamic>>[
              <String, dynamic>{'name': 'Köfte', 'quantity': 2},
            ],
          },
        },
        <String, dynamic>{
          'id': 'job-receipt',
          'station_id': null,
          'created_at': '2026-01-01T12:00:00.000Z',
          'payload': <String, dynamic>{
            'document_type': 'receipt',
            'items': <Map<String, dynamic>>[],
          },
        },
      ];

      final picked = pickLatestKitchenPrintJobsForReprint(jobs);
      expect(picked, hasLength(1));
      expect(picked.first['id'], 'job-new');
    });

    test('duplicate reprint guard key aynı masa için üretilir', () {
      final a = reprintInFlightKey(
        restaurantId: 'seller-1',
        tableNumber: 4,
      );
      final b = reprintInFlightKey(
        restaurantId: 'seller-1',
        tableNumber: 4,
      );
      expect(a, b);
    });

    test('kitchen payload algısı mutfak rolünü tanır', () {
      expect(
        isKitchenPrintJobPayload(<String, dynamic>{'printer_role': 'mutfak'}),
        isTrue,
      );
      expect(
        isKitchenPrintJobPayload(<String, dynamic>{'document_type': 'receipt'}),
        isFalse,
      );
    });
  });
}
