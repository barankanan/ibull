import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/store/table_close_history_fallback.dart';

void main() {
  group('planTableCloseHistoryFallback', () {
    test(
      'does not insert duplicate fallback when table_orders rows are already archived',
      () {
        final plan = planTableCloseHistoryFallback(
          closedOrders: const [
            {
              'id': 'table-order-1',
              '_garson_source_table': 'table_orders',
              'grand_total': 200,
            },
            {
              'id': 'table-order-2',
              '_garson_source_table': 'table_orders',
              'grand_total': 300,
            },
          ],
          recentHistoryRows: const [
            {'original_order_id': 'table-order-1', 'grand_total': 200},
            {'original_order_id': 'table-order-2', 'grand_total': 300},
          ],
        );

        expect(plan.ordersToArchive, isEmpty);
        expect(plan.shouldInsert, isFalse);
      },
    );

    test(
      'keeps orders-source rows when recent history only covers table_orders rows',
      () {
        final plan = planTableCloseHistoryFallback(
          closedOrders: const [
            {
              'id': 'table-order-1',
              '_garson_source_table': 'table_orders',
              'grand_total': 200,
            },
            {
              'id': 'customer-order-9',
              '_garson_source_table': 'orders',
              'grand_total': 300,
            },
          ],
          recentHistoryRows: const [
            {'original_order_id': 'table-order-1', 'grand_total': 200},
          ],
        );

        expect(plan.ordersToArchive.length, 1);
        expect(plan.ordersToArchive.single['id'], 'customer-order-9');
        expect(plan.grandTotal, closeTo(300, 0.01));
        expect(plan.shouldInsert, isTrue);
      },
    );

    test(
      'does not reinsert orders rows already covered by archived_orders fallback',
      () {
        final plan = planTableCloseHistoryFallback(
          closedOrders: const [
            {
              'id': 'table-order-1',
              '_garson_source_table': 'table_orders',
              'grand_total': 200,
            },
            {
              'id': 'customer-order-9',
              '_garson_source_table': 'orders',
              'grand_total': 300,
            },
          ],
          recentHistoryRows: const [
            {
              'original_order_id': 'table-order-1',
              'grand_total': 500,
              'archived_orders': [
                {'id': 'table-order-1'},
                {'id': 'customer-order-9'},
              ],
            },
          ],
        );

        expect(plan.ordersToArchive, isEmpty);
        expect(plan.grandTotal, closeTo(0, 0.01));
        expect(plan.shouldInsert, isFalse);
      },
    );

    test(
      'does not suppress insert when only aggregate matches but order ids differ',
      () {
        final plan = planTableCloseHistoryFallback(
          closedOrders: const [
            {
              'id': 'customer-order-22',
              '_garson_source_table': 'orders',
              'grand_total': 300,
            },
          ],
          recentHistoryRows: const [
            {'original_order_id': 'customer-order-10', 'grand_total': 300},
          ],
        );

        expect(plan.ordersToArchive.length, 1);
        expect(plan.ordersToArchive.single['id'], 'customer-order-22');
        expect(plan.hasRecentAggregateMatch, isFalse);
        expect(plan.shouldInsert, isTrue);
      },
    );

    test('keeps legacy aggregate dedupe when order ids are unavailable', () {
      final plan = planTableCloseHistoryFallback(
        closedOrders: const [
          {'grand_total': 450},
        ],
        recentHistoryRows: const [
          {'grand_total': 450},
        ],
      );

      expect(plan.hasRecentAggregateMatch, isTrue);
      expect(plan.shouldInsert, isFalse);
    });
  });
}
