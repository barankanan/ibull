import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/utils/garson_table_order_state.dart';

void main() {
  group('garsonTableNumbersForDisplay', () {
    test('does not render mock sequential tables while store snapshot loading', () {
      expect(
        garsonTableNumbersForDisplay(
          configuredTableNumbers: const <int>[],
          orderTableNumbers: const <int>[1, 2],
          storeTablesReady: false,
        ),
        isEmpty,
      );
    });

    test('uses configured tables when available', () {
      expect(
        garsonTableNumbersForDisplay(
          configuredTableNumbers: const <int>[3, 1, 5],
          orderTableNumbers: const <int>[2],
          storeTablesReady: true,
        ),
        [1, 3, 5],
      );
    });

    test('falls back to order table numbers only after store tables ready', () {
      expect(
        garsonTableNumbersForDisplay(
          configuredTableNumbers: const <int>[],
          orderTableNumbers: const <int>[4, 2, 4],
          storeTablesReady: true,
        ),
        [2, 4],
      );
    });
  });

  group('garsonOrderActivityAt / time label', () {
    test('revized order uses updated_at not created_at', () {
      final order = <String, dynamic>{
        'created_at': DateTime.now()
            .subtract(const Duration(days: 4))
            .toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      expect(garsonOrderTimeAgoLabel(order), 'Az önce');
    });
  });

  group('mergeGarsonTableOrders', () {
    test('stale server snapshot does not overwrite newer optimistic qty', () {
      const orderId = 'order-1';
      final server = <String, dynamic>{
        'id': orderId,
        'table_number': 5,
        'status': 'sent',
        'revision': 1,
        'created_at': '2026-01-01T10:00:00.000Z',
        'updated_at': '2026-01-01T10:00:00.000Z',
        'items': [
          <String, dynamic>{
            'name': 'Servis',
            'quantity': 1,
            'price': 100,
            'line_total': 100,
          },
        ],
      };
      final optimistic = <String, dynamic>{
        'id': orderId,
        'table_number': 5,
        'status': 'sent',
        'revision': 2,
        'created_at': '2026-01-01T10:00:00.000Z',
        'updated_at': DateTime.now().toIso8601String(),
        'items': [
          <String, dynamic>{
            'name': 'Servis',
            'quantity': 2,
            'price': 100,
            'line_total': 200,
          },
        ],
      };

      final merged = mergeGarsonTableOrders(
        <Map<String, dynamic>>[server, optimistic],
        fallbackTableNumber: 5,
      );
      expect(merged, hasLength(1));
      final items = garsonExtractOrderItems(merged.first['items']);
      expect(items.first['quantity'], 2);
    });
  });

  group('reconcileGarsonTableOrdersAfterSnapshot', () {
    test('keeps optimistic row when server revision is older', () {
      const orderId = 'order-2';
      final snapshot = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': orderId,
          'table_number': 3,
          'revision': 1,
          'updated_at': '2026-01-01T10:00:00.000Z',
          'items': [
            <String, dynamic>{'name': 'Çay', 'quantity': 1, 'price': 20, 'line_total': 20},
          ],
        },
      ];
      final optimistic = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': orderId,
          'table_number': 3,
          'revision': 3,
          'updated_at': DateTime.now().toIso8601String(),
          'items': [
            <String, dynamic>{'name': 'Çay', 'quantity': 2, 'price': 20, 'line_total': 40},
          ],
        },
      ];

      final result = reconcileGarsonTableOrdersAfterSnapshot(
        serverSnapshot: snapshot,
        optimisticOrders: optimistic,
        fallbackTableNumber: 3,
      );
      final items = garsonExtractOrderItems(result.hydrated.first['items']);
      expect(items.first['quantity'], 2);
      expect(result.optimisticRemaining, isNotEmpty);
    });
  });

  group('applyGarsonSubmittedOrderItems', () {
    test('forces submitted items over stale DB payload', () {
      final merged = applyGarsonSubmittedOrderItems(
        submittedOrder: <String, dynamic>{
          'id': 'x',
          'items': [
            <String, dynamic>{'name': 'Servis', 'quantity': 1, 'price': 10, 'line_total': 10},
          ],
        },
        items: [
          <String, dynamic>{'name': 'Servis', 'quantity': 2, 'price': 10, 'line_total': 20},
        ],
        revision: 4,
        updatedAt: DateTime.now().toIso8601String(),
      );
      final items = garsonExtractOrderItems(merged['items']);
      expect(items.first['quantity'], 2);
      expect(merged['revision'], 4);
    });
  });
}
