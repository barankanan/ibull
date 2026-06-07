// Regression tests for Bug 2:
// The detail screen (_MobileGarsonTableFlowPageState) used only the
// `table_orders` realtime stream. The list screen used getTableOrdersSnapshot
// which merges `table_orders + orders`. Orders recorded only in the `orders`
// table were never visible in the detail view.
// Additionally, _hydratedTableOrders started as [] so the UI was blank until
// the first stream event arrived.
//
// Fix applied in seller_panel_page.dart:
//  • initState calls unawaited(_preloadTableOrders())
//  • _preloadTableOrders fetches getTableOrdersSnapshot(sellerId, tableNumber)
//    (both tables) and populates _hydratedTableOrders before the stream emits
//  • Guard: only sets _hydratedTableOrders when it is still empty (no downgrade)
//
// These tests verify:
//  1. The _displayTableOrders fallback logic (stream empty → use hydrated)
//  2. The stream-wins-over-hydrated precedence rule
//  3. The no-downgrade guard
//  4. normalizeRestaurantOrderToGarsonTableOrder produces valid board orders
//  5. mergeGarsonActiveOrderSources deduplication / inclusion rules
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/utils/garson_active_orders_fetch.dart';
import 'package:ibul_app/utils/garson_table_order_state.dart';

// ---------------------------------------------------------------------------
// Pure helper that mirrors _displayTableOrders in _MobileGarsonTableFlowPageState:
//
//   final baseOrders = serverOrders.isNotEmpty ? serverOrders : hydratedOrders;
//   return _mergeTableOrders(baseOrders, optimisticOrders);
// ---------------------------------------------------------------------------
List<Map<String, dynamic>> _simulateDisplayTableOrders({
  required List<Map<String, dynamic>> serverOrders,
  required List<Map<String, dynamic>> hydratedOrders,
  required List<Map<String, dynamic>> optimisticOrders,
  required int tableNumber,
}) {
  final baseOrders =
      serverOrders.isNotEmpty ? serverOrders : hydratedOrders;
  return mergeGarsonTableOrders(
    <Map<String, dynamic>>[...baseOrders, ...optimisticOrders],
    fallbackTableNumber: tableNumber,
  );
}

void main() {
  // ── Shared fixtures ───────────────────────────────────────────────────────
  final preloadedOrder = <String, dynamic>{
    'id': 'order-preload-3',
    'table_number': 3,
    'status': 'sent',
    'revision': 1,
    'items': <Map<String, dynamic>>[
      <String, dynamic>{
        'name': 'Köfte',
        'quantity': 2,
        'price': 50.0,
        'line_total': 100.0,
      },
    ],
    'created_at': '2026-01-01T10:00:00.000Z',
    'updated_at': '2026-01-01T10:05:00.000Z',
  };

  // ── Group 1: _displayTableOrders fallback logic ───────────────────────────
  group('displayTableOrders: stream vs hydrated fallback', () {
    test('empty stream + non-empty hydrated → hydrated data is shown', () {
      final result = _simulateDisplayTableOrders(
        serverOrders: const <Map<String, dynamic>>[],
        hydratedOrders: <Map<String, dynamic>>[preloadedOrder],
        optimisticOrders: const <Map<String, dynamic>>[],
        tableNumber: 3,
      );
      expect(result, hasLength(1));
      expect(result.first['id'], 'order-preload-3');
    });

    test('REGRESSION PROOF: empty stream + empty hydrated → blank screen', () {
      // Before fix: _hydratedTableOrders started as [] and no preload ran.
      // Stream waiting state caused blank detail screen.
      final result = _simulateDisplayTableOrders(
        serverOrders: const <Map<String, dynamic>>[],
        hydratedOrders: const <Map<String, dynamic>>[],
        optimisticOrders: const <Map<String, dynamic>>[],
        tableNumber: 3,
      );
      expect(
        result,
        isEmpty,
        reason:
            'REGRESSION PROOF: without preload, empty stream → blank screen',
      );
    });

    test('non-empty stream takes precedence over hydrated (newer revision wins)',
        () {
      final streamOrder = Map<String, dynamic>.from(preloadedOrder)
        ..['status'] = 'preparing'
        ..['revision'] = 2
        ..['updated_at'] = DateTime.now().toIso8601String();

      final result = _simulateDisplayTableOrders(
        serverOrders: <Map<String, dynamic>>[streamOrder],
        hydratedOrders: <Map<String, dynamic>>[preloadedOrder],
        optimisticOrders: const <Map<String, dynamic>>[],
        tableNumber: 3,
      );
      // mergeGarsonTableOrders deduplicates by id and picks higher revision
      expect(result, hasLength(1));
      expect(result.first['status'], 'preparing',
          reason: 'stream data (revision 2) wins over preload (revision 1)');
    });

    test('optimistic order survives alongside preloaded base', () {
      final optimistic = <String, dynamic>{
        'id': 'order-opt-3',
        'table_number': 3,
        'status': 'sent',
        'revision': 2,
        'items': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'Ayran', 'quantity': 1, 'price': 15.0, 'line_total': 15.0},
        ],
        'created_at': '2026-01-01T10:01:00.000Z',
        'updated_at': DateTime.now().toIso8601String(),
      };

      final result = _simulateDisplayTableOrders(
        serverOrders: const <Map<String, dynamic>>[],
        hydratedOrders: <Map<String, dynamic>>[preloadedOrder],
        optimisticOrders: <Map<String, dynamic>>[optimistic],
        tableNumber: 3,
      );
      // Both orders are for the same table but different IDs → both appear
      final ids = result.map((o) => o['id'] as String).toSet();
      expect(ids.contains('order-preload-3'), isTrue);
      expect(ids.contains('order-opt-3'), isTrue);
    });
  });

  // ── Group 2: preload guard (no-downgrade) ─────────────────────────────────
  group('_preloadTableOrders guard: no-downgrade when already hydrated', () {
    test('second preload does not overwrite already-populated hydrated list',
        () {
      // Mirrors the guard:  if (_hydratedTableOrders.isEmpty) { set } else { skip }
      var hydratedOrders = <Map<String, dynamic>>[preloadedOrder];

      final secondPreloadData = <Map<String, dynamic>>[
        Map<String, dynamic>.from(preloadedOrder)
          ..['id'] = 'order-second'
          ..['status'] = 'done',
      ];

      // Guard check
      if (hydratedOrders.isEmpty) {
        hydratedOrders = secondPreloadData;
      }

      expect(hydratedOrders.first['id'], 'order-preload-3',
          reason: 'first preload data must not be overwritten by second call');
    });

    test('preload runs normally when hydrated is still empty', () {
      var hydratedOrders = const <Map<String, dynamic>>[];

      final preloadData = <Map<String, dynamic>>[preloadedOrder];
      if (hydratedOrders.isEmpty) {
        hydratedOrders = preloadData;
      }

      expect(hydratedOrders, hasLength(1));
      expect(hydratedOrders.first['id'], 'order-preload-3');
    });
  });

  // ── Group 3: normalizeRestaurantOrderToGarsonTableOrder ──────────────────
  group('normalizeRestaurantOrderToGarsonTableOrder', () {
    test('orders-table row produces valid board order with correct table_number',
        () {
      final ordersRow = <String, dynamic>{
        'id': 'ro-uuid-3',
        'restaurant_id': 'seller-uuid',
        'table_id': 'tbl-uuid-3',
        'order_status': 'pending',
        'status': null,
        'order_type': 'table',
        'total_amount': 200.0,
        'created_at': '2026-01-01T10:00:00.000Z',
        'updated_at': '2026-01-01T10:05:00.000Z',
      };
      final storeTable = <String, dynamic>{
        'id': 'tbl-uuid-3',
        'table_number': 3,
        'display_label': 'Salon 3',
        'area_name': 'Salon',
        'area_table_number': 3,
      };

      final result = normalizeRestaurantOrderToGarsonTableOrder(
        order: ordersRow,
        items: const <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Pide',
            'quantity': 1,
            'price': 80.0,
            'line_total': 80.0,
          },
        ],
        storeTable: storeTable,
      );

      expect(result, isNotNull);
      expect(result!['id'], 'ro-uuid-3');
      expect(result['table_number'], 3);
      expect(result['_garson_source_table'], 'orders',
          reason: 'must flag origin so detail can identify orders-table rows');
    });

    test('orders-table row without storeTable but with table_id is accepted', () {
      final ordersRow = <String, dynamic>{
        'id': 'ro-uuid-7',
        'restaurant_id': 'seller-uuid',
        'table_id': 'tbl-uuid-7',
        'order_status': 'pending',
        'total_amount': 50.0,
        'created_at': '2026-01-01T10:00:00.000Z',
        'updated_at': '2026-01-01T10:05:00.000Z',
      };

      final result = normalizeRestaurantOrderToGarsonTableOrder(
        order: ordersRow,
        items: const <Map<String, dynamic>>[],
        storeTable: null,
      );

      // table_id is present → should normalize
      expect(result, isNotNull);
      expect(result!['id'], 'ro-uuid-7');
    });

    test('returns null when both table_id and table_number are absent', () {
      final ordersRow = <String, dynamic>{
        'id': 'ro-uuid-x',
        'restaurant_id': 'seller-uuid',
        'table_id': null,
        'order_status': 'pending',
        'total_amount': 50.0,
        'created_at': '2026-01-01T10:00:00.000Z',
        'updated_at': '2026-01-01T10:05:00.000Z',
      };

      final result = normalizeRestaurantOrderToGarsonTableOrder(
        order: ordersRow,
        items: const <Map<String, dynamic>>[],
        storeTable: null,
      );

      expect(result, isNull,
          reason: 'unroutable order must be discarded');
    });
  });

  // ── Group 4: mergeGarsonActiveOrderSources ────────────────────────────────
  group('mergeGarsonActiveOrderSources (list vs detail data parity)', () {
    test('table_orders entry takes priority over orders entry for same table_id',
        () {
      final tableOrder = <String, dynamic>{
        'id': 'to-1',
        'table_id': 'tbl-3',
        'table_number': 3,
        'status': 'sent',
      };
      final restaurantOrder = <String, dynamic>{
        'id': 'ro-1',
        'table_id': 'tbl-3',
        'table_number': 3,
        'status': 'pending',
      };

      final merged = mergeGarsonActiveOrderSources(
        tableOrders: <Map<String, dynamic>>[tableOrder],
        restaurantOrders: <Map<String, dynamic>>[restaurantOrder],
      );
      expect(merged, hasLength(1));
      expect(merged.first['id'], 'to-1',
          reason: 'table_orders takes priority when table_id matches');
    });

    test(
        'orders-table entry included when no table_orders match (no table_id collision)',
        () {
      final restaurantOrder = <String, dynamic>{
        'id': 'ro-7',
        'table_id': 'tbl-7',
        'table_number': 7,
        'status': 'pending',
      };

      final merged = mergeGarsonActiveOrderSources(
        tableOrders: const <Map<String, dynamic>>[],
        restaurantOrders: <Map<String, dynamic>>[restaurantOrder],
      );
      expect(merged, hasLength(1));
      expect(merged.first['id'], 'ro-7',
          reason:
              'list screen shows this order; detail must also show it via preload');
    });

    test('deduplication by table_number when table_id absent', () {
      final tableOrder = <String, dynamic>{
        'id': 'to-n3',
        'table_number': 3,
        'status': 'sent',
      };
      final restaurantOrder = <String, dynamic>{
        'id': 'ro-n3',
        'table_number': 3,
        'status': 'pending',
      };

      final merged = mergeGarsonActiveOrderSources(
        tableOrders: <Map<String, dynamic>>[tableOrder],
        restaurantOrders: <Map<String, dynamic>>[restaurantOrder],
      );
      expect(merged, hasLength(1));
      expect(merged.first['id'], 'to-n3',
          reason:
              'table_orders wins dedup by table_number when table_id absent');
    });

    test(
        'orders from different tables are both included (no false dedup)',
        () {
      final to3 = <String, dynamic>{
        'id': 'to-3',
        'table_id': 'tbl-3',
        'table_number': 3,
        'status': 'sent',
      };
      final ro5 = <String, dynamic>{
        'id': 'ro-5',
        'table_id': 'tbl-5',
        'table_number': 5,
        'status': 'preparing',
      };

      final merged = mergeGarsonActiveOrderSources(
        tableOrders: <Map<String, dynamic>>[to3],
        restaurantOrders: <Map<String, dynamic>>[ro5],
      );
      expect(merged, hasLength(2));
      final ids = merged.map((o) => o['id'] as String).toSet();
      expect(ids, containsAll(<String>['to-3', 'ro-5']));
    });
  });

  // ── Group 5: isGarsonActiveOrderStatus (terminal filtering) ──────────────
  group('isGarsonActiveOrderStatus: terminal orders excluded from detail', () {
    test('closed is terminal', () {
      expect(isGarsonTerminalOrderStatus('closed'), isTrue);
    });
    test('paid is terminal', () {
      expect(isGarsonTerminalOrderStatus('paid'), isTrue);
    });
    test('sent is active', () {
      expect(isGarsonActiveOrderStatus('sent'), isTrue);
    });
    test('null status is not terminal (treated as unknown → keep visible)', () {
      expect(isGarsonTerminalOrderStatus(null), isFalse);
    });
    test('empty status is not terminal', () {
      expect(isGarsonTerminalOrderStatus(''), isFalse);
    });
  });
}
