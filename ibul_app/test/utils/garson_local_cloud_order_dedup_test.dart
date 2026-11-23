// Bahçe 4 (2026-11-23): one order was saved locally (id "waiter-…", 1.340 TL)
// and later synced to the cloud (uuid id, same local_order_id). The board kept
// both copies, so the table showed two orders and 2.680 TL although the
// database held exactly one order.
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/utils/garson_board_state.dart';
import 'package:ibul_app/utils/garson_table_order_state.dart';

const _localId = 'waiter-1795462175805918-7264153b';
const _cloudId = '78f5945f-3f16-4972-af3b-347ca9f9e420';

List<Map<String, dynamic>> _items() => <Map<String, dynamic>>[
  <String, dynamic>{'name': 'Zeytin Salatası', 'quantity': 1, 'price': 200.0},
  <String, dynamic>{'name': 'Peynir Tabağı', 'quantity': 1, 'price': 200.0},
  <String, dynamic>{'name': 'ORDÖVR TABAĞI', 'quantity': 1, 'price': 320.0},
  <String, dynamic>{'name': 'Tavuk Tava', 'quantity': 1, 'price': 300.0},
  <String, dynamic>{'name': 'Arap Tava', 'quantity': 1, 'price': 320.0},
];

Map<String, dynamic> _localCopy() => <String, dynamic>{
  'id': _localId,
  'local_order_id': _localId,
  'table_number': 10,
  'items': _items(),
  'status': 'sent',
  'created_at': '2026-11-23T19:29:35.826Z',
  'updated_at': '2026-11-23T19:30:36.124Z',
};

Map<String, dynamic> _cloudCopy({String? localOrderId = _localId}) =>
    <String, dynamic>{
      'id': _cloudId,
      if (localOrderId != null) 'local_order_id': localOrderId,
      'table_number': 10,
      'items': _items(),
      'status': 'sent',
      'created_at': '2026-11-23T19:30:35.765Z',
      'updated_at': '2026-11-23T19:30:35.765Z',
    };

void main() {
  group('local copy and its synced cloud order are one order', () {
    test('background snapshot merge keeps only the cloud order', () {
      final result = mergeGarsonVisibleOrdersSafely(
        currentVisibleOrders: <Map<String, dynamic>>[_localCopy()],
        incomingOrders: <Map<String, dynamic>>[_cloudCopy()],
        storeTables: const <Map<String, dynamic>>[],
        source: 'realtime',
        userInitiated: false,
      );
      expect(result.mergedOrders, hasLength(1));
      expect(result.mergedOrders.single['id'], _cloudId);
    });

    test('LAN floor reconcile does not add the local copy next to the '
        'cloud order', () {
      final board = reconcileLanFloorOrders(
        current: GarsonBoardState(
          orders: <Map<String, dynamic>>[_cloudCopy()],
        ),
        incoming: <Map<String, dynamic>>[_localCopy()],
      );
      expect(board.orders, hasLength(1));
      expect(board.orders.single['id'], _cloudId);
    });

    test('a second, deliberate order with the same items stays separate', () {
      final second = _cloudCopy(localOrderId: 'waiter-2-other')
        ..['id'] = 'aaaaaaaa-0000-4000-8000-000000000002';
      final result = mergeGarsonVisibleOrdersSafely(
        currentVisibleOrders: <Map<String, dynamic>>[_cloudCopy()],
        incomingOrders: <Map<String, dynamic>>[_cloudCopy(), second],
        storeTables: const <Map<String, dynamic>>[],
        source: 'realtime',
        userInitiated: false,
      );
      expect(result.mergedOrders, hasLength(2));
    });

    test('a local order that has not reached the cloud is kept', () {
      final other = _cloudCopy(localOrderId: null)
        ..['id'] = 'bbbbbbbb-0000-4000-8000-000000000003'
        ..['table_number'] = 11;
      final result = mergeGarsonVisibleOrdersSafely(
        currentVisibleOrders: <Map<String, dynamic>>[_localCopy()],
        incomingOrders: <Map<String, dynamic>>[other],
        storeTables: const <Map<String, dynamic>>[],
        source: 'realtime',
        userInitiated: false,
      );
      expect(result.mergedOrders, hasLength(2));
    });
  });
}
