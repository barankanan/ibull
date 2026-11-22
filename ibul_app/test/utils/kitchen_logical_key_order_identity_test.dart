import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/utils/kitchen_print_dedup.dart';

const _items = [
  {'product_id': 'p1', 'name': 'Adana', 'quantity': 1},
];

String _key(String orderKey) => buildKitchenLogicalPrintKey(
  restaurantId: 'r1',
  tableNumber: '11',
  stationId: 'st1',
  stationName: 'Ocak',
  revision: 1,
  items: _items,
  orderKey: orderKey,
);

void main() {
  test('different orders with the same table and products differ', () {
    expect(_key('order-a'), isNot(_key('order-b')));
  });

  test('one order keeps one key across retries', () {
    expect(_key('order-a'), _key('order-a'));
  });

  test('the print after the save and the queued job share the key', () {
    // What the server stamps on the job payload for the same order.
    final fromJob = buildKitchenLogicalPrintKeyFromPayload(
      restaurantId: 'r1',
      payload: {
        'table_number': 11,
        'station_id': 'st1',
        'station_name': 'Ocak',
        'items': _items,
        'local_order_id': 'local-9',
        'order_id': 'cloud-uuid',
      },
      job: {'station_id': 'st1', 'order_id': 'cloud-uuid'},
    );
    final afterSave = _key(
      kitchenOrderKeyForPrint(localOrderId: 'local-9', orderId: 'cloud-uuid'),
    );
    expect(fromJob, afterSave);
  });

  test('without a local id the saved order id is the identity', () {
    expect(kitchenOrderKeyForPrint(orderId: 'cloud-1'), 'cloud-1');
    expect(kitchenOrderKeyForPrint(localOrderId: ' ', orderId: 'cloud-1'), 'cloud-1');
    expect(kitchenOrderKeyForPrint(), '');
  });

  test('two add-item tickets of one order differ by their revision key', () {
    final a = kitchenOrderKeyForPrint(orderId: 'o1', revisionKey: 'rev-1');
    final b = kitchenOrderKeyForPrint(orderId: 'o1', revisionKey: 'rev-2');
    expect(a, isNot(b));
  });

  test('a payload with no order identity keeps the old key form', () {
    final legacy = buildKitchenLogicalPrintKeyFromPayload(
      restaurantId: 'r1',
      payload: {'table_number': 11, 'station_id': 'st1', 'items': _items},
    );
    expect(legacy, _key(''));
  });
}
