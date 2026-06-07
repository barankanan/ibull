// ignore_for_file: prefer_const_constructors
//
// BUG-FIX (Reopen Bug + schema-aware close) — guardrail tests.
//
// CONTEXT (live DB schema, verified by migration
// 20260607_fix_create_table_order_with_print_jobs_impl_orders_schema.sql):
//
//   public.orders columns relevant to the garson board:
//     • id            uuid
//     • restaurant_id uuid   (canonical seller identity)
//     • table_id      uuid   (FK to store_tables.id — the ONLY canonical
//                            link between an order and a logical table)
//     • user_id       uuid   (auth.uid() at insert time — NOT the seller)
//     • order_type    text   ('table' for waiter-created orders)
//     • delivery_type text   ('table' for QR/customer-self-order)
//     • status        text   (always populated by canonical insert)
//     • order_status  text   (nullable, legacy mirror — must NOT be
//                            used as a NOT-IN filter at DB level because
//                            NULL NOT IN (...) → NULL → row hidden)
//
//   public.orders does NOT have a `table_number` column.
//
// These tests pin the behavioural contracts that the schema-aware fix
// depends on, so a future regression that re-introduces the `table_number`
// or `seller_id == user_id` assumption is caught immediately.

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/utils/garson_active_orders_fetch.dart';

void main() {
  group('resolveGarsonOrderStatusField — dual-source consistency', () {
    test('terminal `status` beats non-terminal `order_status`', () {
      // Customer flow wrote status='closed' but legacy field still says
      // order_status='pending'.  This used to bypass the active-status filter.
      final order = <String, dynamic>{
        'order_status': 'pending',
        'status': 'closed',
      };
      expect(resolveGarsonOrderStatusField(order), 'closed');
      expect(isGarsonActiveOrderStatus('closed'), isFalse);
    });

    test('terminal `order_status` beats non-terminal `status`', () {
      final order = <String, dynamic>{
        'order_status': 'completed',
        'status': 'active',
      };
      expect(resolveGarsonOrderStatusField(order), 'completed');
      expect(isGarsonActiveOrderStatus('completed'), isFalse);
    });

    test('both terminal → either is fine, never active', () {
      final order = <String, dynamic>{
        'order_status': 'paid',
        'status': 'archived',
      };
      final resolved = resolveGarsonOrderStatusField(order);
      expect(['paid', 'archived'], contains(resolved));
      expect(isGarsonActiveOrderStatus(resolved), isFalse);
    });

    test('both non-terminal → first non-empty wins, active', () {
      final order = <String, dynamic>{
        'order_status': 'pending',
        'status': 'new',
      };
      expect(resolveGarsonOrderStatusField(order), 'pending');
      expect(isGarsonActiveOrderStatus('pending'), isTrue);
    });

    test('empty order_status falls back to status', () {
      final order = <String, dynamic>{
        'order_status': '',
        'status': 'kitchen_sent',
      };
      expect(resolveGarsonOrderStatusField(order), 'kitchen_sent');
    });

    test('terminal status alone (legacy row without order_status)', () {
      final order = <String, dynamic>{
        'status': 'archived',
      };
      expect(resolveGarsonOrderStatusField(order), 'archived');
      expect(isGarsonActiveOrderStatus('archived'), isFalse);
    });
  });

  group('mergeGarsonActiveOrderSources — close-then-merge invariants', () {
    test('after close, empty table_orders + lingering customer order is '
        'still surfaced — until DB-level filter removes it', () {
      // This is the failure mode the bug exhibited: after close,
      // table_orders=[], orders=[stale active row] → merged keeps it.
      // The DB-level filter introduced in store_table_service.dart should
      // prevent this list from ever containing the stale row.
      final merged = mergeGarsonActiveOrderSources(
        tableOrders: const <Map<String, dynamic>>[],
        restaurantOrders: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'cust-1',
            'table_number': 14,
            'status': 'closed', // already terminal — should never have been fetched
          },
        ],
      );
      // The merge function itself does NOT filter terminal — that's the
      // fetch layer's responsibility.  This test documents that contract.
      expect(merged.length, 1);
      expect(resolveGarsonOrderStatusField(merged.first), 'closed');
      expect(
        isGarsonActiveOrderStatus(resolveGarsonOrderStatusField(merged.first)),
        isFalse,
        reason:
            'isGarsonActiveOrderStatus must catch terminal rows that slipped '
            'past the DB filter — defense in depth.',
      );
    });

    test('non-terminal customer order surfaces when no table_orders exist '
        '(legitimate case: QR-only customer order pre-close)', () {
      final merged = mergeGarsonActiveOrderSources(
        tableOrders: const <Map<String, dynamic>>[],
        restaurantOrders: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'cust-2',
            'table_number': 7,
            'status': 'new',
          },
        ],
      );
      expect(merged.length, 1);
      expect(merged.first['id'], 'cust-2');
    });

    test('table_orders row dedups matching customer order (pre-close state)',
        () {
      final merged = mergeGarsonActiveOrderSources(
        tableOrders: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'garson-1',
            'table_number': 5,
            'status': 'open',
          },
        ],
        restaurantOrders: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'cust-3',
            'table_number': 5,
            'status': 'new',
          },
        ],
      );
      expect(merged.length, 1);
      expect(merged.first['id'], 'garson-1');
    });
  });

  group('schema-aware normalization (orders has no table_number column)', () {
    test('orders row WITHOUT table_number key is still normalisable when '
        'a store_tables row is provided via the table_id join', () {
      // Simulates the canonical insert path: orders.table_id is set but
      // `table_number` is absent.  The fetch path uses _loadStoreTablesById
      // and feeds the joined row into normalizeRestaurantOrderToGarsonTableOrder
      // so the GarsonBoardOrderModel ends up with a positive tableNumber.
      final order = <String, dynamic>{
        'id': 'order-uuid-1',
        'restaurant_id': 'seller-uuid',
        'table_id': 'store-table-uuid-7',
        'order_type': 'table',
        'delivery_type': 'table',
        'status': 'confirmed',
        'order_status': 'sent',
        'total_amount': 0,
        'created_at': '2026-06-07T00:00:00Z',
        'order_items': <Map<String, dynamic>>[],
      };
      final storeTable = <String, dynamic>{
        'id': 'store-table-uuid-7',
        'seller_id': 'seller-uuid',
        'table_number': 7,
        'display_label': 'Salon 7',
      };
      final mapped = normalizeRestaurantOrderToGarsonTableOrder(
        order: order,
        items: const <Map<String, dynamic>>[],
        storeTable: storeTable,
      );
      expect(mapped, isNotNull);
      expect(mapped!['table_number'], 7);
      expect(mapped['table_id'], 'store-table-uuid-7');
    });

    test('orders row WITHOUT table_id AND WITHOUT table_number is dropped',
        () {
      // Total identity vacuum: the row has neither a UUID FK nor an
      // integer label.  It cannot be rendered on any physical table —
      // dropping is the only safe outcome.
      final order = <String, dynamic>{
        'id': 'order-uuid-2',
        'restaurant_id': 'seller-uuid',
        'order_type': 'table',
        'status': 'confirmed',
        'total_amount': 0,
        'created_at': '2026-06-07T00:00:00Z',
        'order_items': <Map<String, dynamic>>[],
      };
      final mapped = normalizeRestaurantOrderToGarsonTableOrder(
        order: order,
        items: const <Map<String, dynamic>>[],
        storeTable: null,
      );
      expect(mapped, isNull,
          reason: 'no table_id and no table_number → must drop, never '
              'render under a guessed table_number=0');
    });

    test('orders row with table_id but no store_table join (orphan) keeps '
        'the row — UI handles via table_id alone', () {
      // Identity drift: the order references a table_id that no longer
      // resolves in the current seller_id scope (the [GARSON_IDENTITY_MISMATCH]
      // beacon will fire in `_loadStoreTablesById`).  The row still has a
      // valid UUID FK so the merge layer can attempt table_id-only dedup.
      final order = <String, dynamic>{
        'id': 'order-uuid-3',
        'restaurant_id': 'seller-uuid',
        'table_id': 'orphan-table-uuid',
        'order_type': 'table',
        'status': 'confirmed',
        'order_status': 'sent',
        'total_amount': 0,
        'created_at': '2026-06-07T00:00:00Z',
        'order_items': <Map<String, dynamic>>[],
      };
      final mapped = normalizeRestaurantOrderToGarsonTableOrder(
        order: order,
        items: const <Map<String, dynamic>>[],
        storeTable: null,
      );
      expect(mapped, isNotNull,
          reason: 'table_id alone is sufficient identity — render layer '
              'will still group by it');
      expect(mapped!['table_id'], 'orphan-table-uuid');
    });

    test('mergeGarsonActiveOrderSources dedups by table_id when both '
        'sources have positive table_number', () {
      // Both sources should converge on the same physical table when
      // table_id resolution is consistent across `orders` and `table_orders`.
      final merged = mergeGarsonActiveOrderSources(
        tableOrders: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'garson-row',
            'table_id': 'store-table-uuid-7',
            'table_number': 7,
            'status': 'open',
          },
        ],
        restaurantOrders: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'cust-row',
            'table_id': 'store-table-uuid-7',
            'table_number': 7,
            'status': 'new',
          },
        ],
      );
      expect(merged.length, 1,
          reason: 'same table_id from both sources must dedup to a single '
              'garson card');
    });
  });
}
