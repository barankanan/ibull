// Regression tests for Bug 1:
// _closeGarsonTable() previously cleared _garsonBoardState.orders via
// removeClosedTableOrdersFromBoardState() but left _garsonManualTableOrders
// untouched. The route-pop finally block's
// _publishGarsonVisibleSnapshotFromCurrentState() read _garsonManualTableOrders,
// called applyRoutePopped with the stale snapshot, and re-inserted the closed
// table's orders back into board state — causing the flip-flop / "masa tekrar
// açık görünüyor" symptom.
//
// Fix applied in seller_panel_page.dart:
//  • _closeGarsonTable: purge _garsonManualTableOrders after board state purge
//  • onTableClosed callback: same purge for the mobile payment path
//
// These tests exercise the pure utility layer that the fix relies on.
// They do NOT mount the full SellerPanelPage widget (no Supabase needed).
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/helpers/seller_panel_module_helpers.dart';
import 'package:ibul_app/utils/garson_board_state.dart';
import 'package:ibul_app/utils/garson_table_order_state.dart';

// ---------------------------------------------------------------------------
// Pure helper that mirrors the purge block added to _closeGarsonTable /
// onTableClosed. Using this helper lets us test the decision logic without
// mounting the widget.
// ---------------------------------------------------------------------------
List<Map<String, dynamic>> _simulateManualOrdersPurge({
  required List<Map<String, dynamic>> manualOrders,
  required int tableNumber,
}) {
  return manualOrders.where((o) {
    final n = o['table_number'];
    final parsed =
        n is num ? n.toInt() : int.tryParse(n?.toString() ?? '') ?? 0;
    return parsed != tableNumber;
  }).toList(growable: false);
}

void main() {
  // ── Shared fixtures ───────────────────────────────────────────────────────
  final orderTable1 = <String, dynamic>{
    'id': 'order-t1',
    'table_number': 1,
    'status': 'sent',
    'items': <Map<String, dynamic>>[],
    'created_at': '2026-01-01T10:00:00.000Z',
    'updated_at': '2026-01-01T10:05:00.000Z',
    'revision': 1,
  };
  final orderTable5 = <String, dynamic>{
    'id': 'order-t5',
    'table_number': 5,
    'status': 'preparing',
    'items': <Map<String, dynamic>>[],
    'created_at': '2026-01-01T10:00:00.000Z',
    'updated_at': '2026-01-01T10:05:00.000Z',
    'revision': 1,
  };

  // ── Group 1: purge helper correctness ─────────────────────────────────────
  group('_simulateManualOrdersPurge', () {
    test('removes exactly the closed table orders', () {
      final purged = _simulateManualOrdersPurge(
        manualOrders: <Map<String, dynamic>>[orderTable1, orderTable5],
        tableNumber: 1,
      );
      expect(purged, hasLength(1));
      expect(purged.first['id'], 'order-t5');
    });

    test('is a no-op when closed table has no orders in manual list', () {
      final purged = _simulateManualOrdersPurge(
        manualOrders: <Map<String, dynamic>>[orderTable5],
        tableNumber: 1,
      );
      expect(purged, hasLength(1));
      expect(purged.first['id'], 'order-t5');
    });

    test('results in empty list when only the closed table had orders', () {
      final purged = _simulateManualOrdersPurge(
        manualOrders: <Map<String, dynamic>>[orderTable1],
        tableNumber: 1,
      );
      expect(purged, isEmpty);
    });

    test('handles table_number as String', () {
      final orderStringNum = Map<String, dynamic>.from(orderTable1)
        ..['table_number'] = '1';
      final purged = _simulateManualOrdersPurge(
        manualOrders: <Map<String, dynamic>>[orderStringNum, orderTable5],
        tableNumber: 1,
      );
      expect(purged, hasLength(1));
      expect(purged.first['id'], 'order-t5');
    });
  });

  // ── Group 2: signature update after purge ─────────────────────────────────
  group('tableOrdersListSignature after purge', () {
    test('signature changes after purge (different from pre-purge)', () {
      final before = tableOrdersListSignature(
        <Map<String, dynamic>>[orderTable1, orderTable5],
      );
      final purged = _simulateManualOrdersPurge(
        manualOrders: <Map<String, dynamic>>[orderTable1, orderTable5],
        tableNumber: 1,
      );
      final after = tableOrdersListSignature(purged);
      expect(before, isNot(equals(after)));
    });

    test('signature is non-empty after purge when other orders remain', () {
      final purged = _simulateManualOrdersPurge(
        manualOrders: <Map<String, dynamic>>[orderTable1, orderTable5],
        tableNumber: 1,
      );
      expect(tableOrdersListSignature(purged), isNot('empty'));
    });
  });

  // ── Group 3: merge behavior AFTER purge ───────────────────────────────────
  group('mergeGarsonVisibleOrdersSafely after manual purge', () {
    test(
        'purged current + empty incoming → closed table absent from merged result',
        () {
      // After fix: _garsonManualTableOrders has no order-t1.
      final purgedCurrent = _simulateManualOrdersPurge(
        manualOrders: <Map<String, dynamic>>[orderTable1, orderTable5],
        tableNumber: 1,
      );

      final result = mergeGarsonVisibleOrdersSafely(
        currentVisibleOrders: purgedCurrent,
        incomingOrders: const <Map<String, dynamic>>[],
        storeTables: const <Map<String, dynamic>>[],
        source: 'garson_table_route_popped',
        userInitiated: false,
      );

      final tableNums = result.mergedOrders
          .map((o) {
            final n = o['table_number'];
            return n is num
                ? n.toInt()
                : int.tryParse(n?.toString() ?? '') ?? 0;
          })
          .toSet();
      expect(
        tableNums.contains(1),
        isFalse,
        reason: 'closed table must not reappear after manual purge',
      );
      expect(
        tableNums.contains(5),
        isTrue,
        reason: 'other tables must be preserved',
      );
    });

    test(
        'REGRESSION PROOF: unpurged current + empty incoming re-inserts stale order',
        () {
      // Demonstrates the bug that existed BEFORE the fix.
      // _garsonManualTableOrders still had order-t1 → merge kept it.
      final result = mergeGarsonVisibleOrdersSafely(
        currentVisibleOrders: <Map<String, dynamic>>[orderTable1, orderTable5],
        incomingOrders: const <Map<String, dynamic>>[],
        storeTables: const <Map<String, dynamic>>[],
        source: 'garson_table_route_popped',
        userInitiated: false,
      );
      final tableNums = result.mergedOrders
          .map((o) {
            final n = o['table_number'];
            return n is num
                ? n.toInt()
                : int.tryParse(n?.toString() ?? '') ?? 0;
          })
          .toSet();
      expect(
        tableNums.contains(1),
        isTrue,
        reason:
            'REGRESSION PROOF: without purge, stale order IS re-inserted — '
            'this confirms why the fix was necessary',
      );
    });
  });

  // ── Group 4: applyRoutePopped with purged snapshot ────────────────────────
  group('applyRoutePopped with purged manual orders snapshot', () {
    test('does not re-add closed table orders to board state', () {
      final stateAfterBoardPurge = GarsonBoardState(
        tables: const <Map<String, dynamic>>[
          <String, dynamic>{'id': 'tbl-1', 'table_number': 1},
          <String, dynamic>{'id': 'tbl-5', 'table_number': 5},
        ],
        orders: <Map<String, dynamic>>[orderTable5], // board already purged
        lastGoodOrders: <Map<String, dynamic>>[orderTable5],
      );

      // Fix: manual orders are purged before applyRoutePopped is called
      final purgedSnapshot = _simulateManualOrdersPurge(
        manualOrders: <Map<String, dynamic>>[orderTable1, orderTable5],
        tableNumber: 1,
      );

      final afterPop = applyRoutePopped(
        current: stateAfterBoardPurge,
        orders: purgedSnapshot,
        source: 'garson_table_route_popped',
      );

      final tableNums = afterPop.orders
          .map((o) {
            final n = o['table_number'];
            return n is num
                ? n.toInt()
                : int.tryParse(n?.toString() ?? '') ?? 0;
          })
          .toSet();
      expect(
        tableNums.contains(1),
        isFalse,
        reason: 'applyRoutePopped must not re-insert closed table orders',
      );
      expect(tableNums.contains(5), isTrue);
    });

    test(
        'REGRESSION PROOF: applyRoutePopped with un-purged snapshot reverts board purge',
        () {
      // stateAfterBoardPurge already has order-t1 removed
      final stateAfterBoardPurge = GarsonBoardState(
        orders: <Map<String, dynamic>>[orderTable5],
        lastGoodOrders: <Map<String, dynamic>>[orderTable5],
      );
      // Bug: _garsonManualTableOrders still contains orderTable1
      final stalSnapshot = <Map<String, dynamic>>[orderTable1, orderTable5];
      final afterPop = applyRoutePopped(
        current: stateAfterBoardPurge,
        orders: stalSnapshot,
        source: 'garson_table_route_popped',
      );
      final tableNums = afterPop.orders
          .map((o) {
            final n = o['table_number'];
            return n is num
                ? n.toInt()
                : int.tryParse(n?.toString() ?? '') ?? 0;
          })
          .toSet();
      expect(
        tableNums.contains(1),
        isTrue,
        reason:
            'REGRESSION PROOF: stale snapshot causes board state revert — '
            'confirms the fix was needed',
      );
    });
  });

  // ── Group 5: shouldPreserveGarsonVisibleDataOnIncomingEmpty ──────────────
  group('shouldPreserveGarsonVisibleDataOnIncomingEmpty', () {
    test(
        'user_close_table source: returns false when server sends tables but '
        'empty orders (close confirmed by backend)', () {
      // The source-specific no-preserve branch only runs when:
      // hasIncomingTables=true (server tables arrived) AND
      // hasIncomingOrders=false (server confirmed table is empty).
      // When hasIncomingTables=false the first guard always returns true
      // (tables preservation is unconditional).
      expect(
        shouldPreserveGarsonVisibleDataOnIncomingEmpty(
          source: 'user_close_table',
          hasVisibleTables: true,
          hasVisibleOrders: true,
          hasIncomingTables: true, // tables came from server
          hasIncomingOrders: false, // server reports 0 orders (close confirmed)
        ),
        isFalse,
        reason: 'explicit close with server ack must not be preserved',
      );
    });

    test(
        'garson_table_route_popped returns true — harmless after upstream purge',
        () {
      // preserve=true is the correct behaviour here.
      // The fix works upstream: _garsonManualTableOrders is purged BEFORE
      // mergeGarsonVisibleOrdersSafely runs, so the "current" that gets
      // preserved no longer includes the closed table's orders.
      expect(
        shouldPreserveGarsonVisibleDataOnIncomingEmpty(
          source: 'garson_table_route_popped',
          hasVisibleTables: true,
          hasVisibleOrders: true,
          hasIncomingTables: false,
          hasIncomingOrders: false,
        ),
        isTrue,
        reason:
            'preserve=true is expected; fix works upstream by purging '
            '_garsonManualTableOrders before this code path runs',
      );
    });

    test(
        'payment_complete source: returns false when server confirms empty orders',
        () {
      expect(
        shouldPreserveGarsonVisibleDataOnIncomingEmpty(
          source: 'payment_complete',
          hasVisibleTables: true,
          hasVisibleOrders: true,
          hasIncomingTables: true, // tables came from server
          hasIncomingOrders: false, // server confirmed 0 orders
        ),
        isFalse,
      );
    });

    test('table_orders_stream source: returns true (background stream blocked)',
        () {
      // Background stream updates arriving empty should be preserved;
      // they're also blocked upstream by shouldBlockGarsonBackgroundPublish.
      expect(
        shouldPreserveGarsonVisibleDataOnIncomingEmpty(
          source: 'table_orders_stream',
          hasVisibleTables: true,
          hasVisibleOrders: true,
          hasIncomingTables: false,
          hasIncomingOrders: false,
        ),
        isTrue,
      );
    });
  });

  // ── Group 6: removeClosedTableOrdersFromBoardState + manual purge combined ─
  group('board state + manual orders purge — full close table flow', () {
    test('both layers clean after close: no stale order survives', () {
      final initialManual = <Map<String, dynamic>>[orderTable1, orderTable5];
      final state = GarsonBoardState(
        orders: <Map<String, dynamic>>[orderTable1, orderTable5],
        lastGoodOrders: <Map<String, dynamic>>[orderTable1, orderTable5],
      );

      // Step 1: board state purge (existing logic)
      final boardAfterClose = removeClosedTableOrdersFromBoardState(
        current: state,
        tableNumber: 1,
        closedOrderId: 'order-t1',
      );

      // Step 2: manual orders purge (the fix)
      final manualAfterPurge = _simulateManualOrdersPurge(
        manualOrders: initialManual,
        tableNumber: 1,
      );

      // Step 3: applyRoutePopped using purged manual snapshot
      final afterPop = applyRoutePopped(
        current: boardAfterClose,
        orders: manualAfterPurge,
        source: 'garson_table_route_popped',
      );

      // Both board orders and lastGoodOrders must be clean
      final boardTableNums = afterPop.orders
          .map((o) {
            final n = o['table_number'];
            return n is num
                ? n.toInt()
                : int.tryParse(n?.toString() ?? '') ?? 0;
          })
          .toSet();
      final lastGoodTableNums = afterPop.lastGoodOrders
          .map((o) {
            final n = o['table_number'];
            return n is num
                ? n.toInt()
                : int.tryParse(n?.toString() ?? '') ?? 0;
          })
          .toSet();

      expect(boardTableNums.contains(1), isFalse);
      expect(lastGoodTableNums.contains(1), isFalse);
      expect(boardTableNums.contains(5), isTrue);
    });
  });
}
