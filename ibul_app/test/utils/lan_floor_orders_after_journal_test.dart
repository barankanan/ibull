import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/utils/garson_board_state.dart';

Map<String, dynamic> _local(String id, {String name = 'Cay'}) =>
    lanFloorOrderFromRecord(
      localOrderId: id,
      tableNumber: 19,
      tableName: 'Bahçe 8',
      items: <Map<String, dynamic>>[
        <String, dynamic>{'name': name, 'quantity': 1, 'price': 25},
      ],
      total: 25,
      printStatus: 'printed',
      updatedAt: DateTime.utc(2026, 11, 18, 18),
    );

void main() {
  test('the card does not claim "sent to the kitchen" for an unprinted ticket', () {
    Map<String, dynamic> withStatus(String status) =>
        Map<String, dynamic>.from(_local('waiter-1'))..['print_status'] = status;
    expect(lanFloorPrintStatusLabel(withStatus('failed')), 'Kaydedildi · Fiş basılamadı');
    expect(lanFloorPrintStatusLabel(withStatus('uncertain')), 'Kaydedildi · Fiş belirsiz');
    expect(lanFloorPrintStatusLabel(withStatus('pending')), 'Kaydedildi · Fiş bekliyor');
    // Printed local orders and cloud orders keep the usual text.
    expect(lanFloorPrintStatusLabel(withStatus('printed')), isNull);
    expect(lanFloorPrintStatusLabel(withStatus('forwarded')), isNull);
    expect(
      lanFloorPrintStatusLabel(<String, dynamic>{'id': 'cloud-1', 'print_status': 'failed'}),
      isNull,
    );
    expect(lanFloorPrintStatusLabel(null), isNull);
  });

  test('a synced journal row is not shown beside its cloud order', () {
    // Two offline orders reached the cloud; the cloud returns them itself.
    final cloud = <Map<String, dynamic>>[
      <String, dynamic>{'id': 'cloud-1', 'table_number': 19},
      <String, dynamic>{'id': 'cloud-2', 'table_number': 19},
    ];
    final floor = lanFloorOrdersAfterJournal(
      current: <Map<String, dynamic>>[_local('waiter-1'), _local('waiter-2')],
      waiting: const <Map<String, dynamic>>[],
      syncedLocalOrderIds: <String>{'waiter-1', 'waiter-2'},
    );
    expect(floor, isEmpty);
    final board = reconcileLanFloorOrders(
      current: const GarsonBoardState().copyWith(orders: cloud),
      incoming: floor,
    );
    expect(board.orders, hasLength(2));
  });

  test('an order still waiting stays on the floor exactly once', () {
    final floor = lanFloorOrdersAfterJournal(
      current: <Map<String, dynamic>>[_local('waiter-1'), _local('waiter-2')],
      waiting: <Map<String, dynamic>>[_local('waiter-2', name: 'Su')],
      syncedLocalOrderIds: <String>{'waiter-1'},
    );
    expect(floor, hasLength(1));
    expect(floor.single['local_order_id'], 'waiter-2');
    expect((floor.single['items'] as List).single['name'], 'Su');
  });

  test('nothing waiting is dropped when nothing has synced', () {
    final floor = lanFloorOrdersAfterJournal(
      current: const <Map<String, dynamic>>[],
      waiting: <Map<String, dynamic>>[_local('waiter-1'), _local('waiter-2')],
      syncedLocalOrderIds: const <String>{},
    );
    expect(floor.map((order) => order['local_order_id']), <String>[
      'waiter-1',
      'waiter-2',
    ]);
  });
}
