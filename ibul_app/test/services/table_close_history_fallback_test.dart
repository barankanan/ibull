import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/store/table_close_history_fallback.dart';

void main() {
  group('planTableCloseHistoryFallback', () {
    test('skips insert when same table closed within 3 minutes', () {
      final closedAt = DateTime(2026, 6, 13, 14, 0);
      final plan = planTableCloseHistoryFallback(
        tableNumber: 11,
        closedOrders: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'new-order-after-restore',
            'items': <Map<String, dynamic>>[
              <String, dynamic>{'name': 'Çay', 'quantity': 1, 'price': 20.0},
            ],
          },
        ],
        recentHistoryRows: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'rpc-history',
            'table_number': 11,
            'closed_at': closedAt.subtract(const Duration(seconds: 30)).toUtc().toIso8601String(),
          },
        ],
        closedAt: closedAt,
      );

      expect(plan.shouldInsert, isFalse);
    });

    test('inserts when same table closed outside 3-minute window', () {
      final closedAt = DateTime(2026, 6, 13, 14, 0);
      final plan = planTableCloseHistoryFallback(
        tableNumber: 11,
        closedOrders: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'order-2',
            'items': <Map<String, dynamic>>[
              <String, dynamic>{'name': 'Su', 'quantity': 1, 'price': 10.0},
            ],
          },
        ],
        recentHistoryRows: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'old-history',
            'table_number': 11,
            'closed_at': closedAt.subtract(const Duration(minutes: 5)).toUtc().toIso8601String(),
          },
        ],
        closedAt: closedAt,
      );

      expect(plan.shouldInsert, isTrue);
    });

    test('skips insert when archived order id already in recent history', () {
      final plan = planTableCloseHistoryFallback(
        tableNumber: 11,
        closedOrders: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'archived-1',
            'items': <Map<String, dynamic>>[
              <String, dynamic>{'name': 'Kahve', 'quantity': 1, 'price': 45.0},
            ],
          },
        ],
        recentHistoryRows: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'history-1',
            'table_number': 11,
            'archived_orders': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'archived-1'},
            ],
            'closed_at': DateTime.utc(2026, 6, 13, 12).toIso8601String(),
          },
        ],
      );

      expect(plan.shouldInsert, isFalse);
    });
  });
}
