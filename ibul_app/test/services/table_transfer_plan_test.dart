import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/store/table_transfer_plan.dart';

void main() {
  final orders = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'order-1',
      'table_number': 4,
      'status': 'sent',
      'items': <Map<String, dynamic>>[
        <String, dynamic>{'name': 'Çay', 'quantity': 2, 'price': 20},
        <String, dynamic>{'name': 'Su', 'quantity': 1, 'price': 10},
      ],
    },
    <String, dynamic>{
      'id': 'order-closed',
      'table_number': 4,
      'status': 'closed',
      'items': <Map<String, dynamic>>[
        <String, dynamic>{'name': 'Eski', 'quantity': 1, 'price': 50},
      ],
    },
  ];

  test('partial transfer keeps unmatched lines on the source order', () {
    final plan = planTableTransfer(
      orders: orders,
      toTable: 7,
      transferType: 'partial',
      selectedLineIds: const <String>['order-1#0'],
    );

    expect(plan.hasChanges, isTrue);
    expect(plan.movedLineIds, <String>['order-1#0']);
    expect(plan.mutations, hasLength(1));
    final mutation = plan.mutations.single;
    expect(mutation.nextTableNumber, isNull);
    expect(mutation.nextItems.single['name'], 'Su');
    expect(mutation.destinationItems, isNotNull);
    expect(mutation.destinationItems!.single['name'], 'Çay');
    expect(mutation.destinationStatus, 'sent');
  });

  test('selecting every line moves the existing row and does not split', () {
    final plan = planTableTransfer(
      orders: orders,
      toTable: 7,
      transferType: 'customerBased',
      selectedLineIds: const <String>['order-1#0', 'order-1#1'],
    );

    expect(plan.transferType, 'customer');
    final mutation = plan.mutations.single;
    expect(mutation.splitsOrder, isFalse);
    expect(mutation.nextTableNumber, 7);
    expect(mutation.nextItems, hasLength(2));
  });

  test('full transfer ignores selected ids and skips closed orders', () {
    final plan = planTableTransfer(
      orders: orders,
      toTable: 9,
      transferType: 'full',
      selectedLineIds: const <String>['order-1#0'],
    );

    expect(plan.mutations, hasLength(1));
    expect(plan.mutations.single.orderId, 'order-1');
    expect(plan.mutations.single.nextTableNumber, 9);
    expect(plan.movedLineIds, isNot(contains('order-closed#0')));
  });

  test('unknown selection does not move the table', () {
    final plan = planTableTransfer(
      orders: orders,
      toTable: 9,
      transferType: 'partial',
      selectedLineIds: const <String>['missing'],
    );

    expect(plan.hasChanges, isFalse);
    expect(plan.mutations, isEmpty);
  });

  test('flattenOrdersForTransfer stamps the same ids the plan matches', () {
    final flat = flattenOrdersForTransfer(orders);
    final plan = planTableTransfer(
      orders: orders,
      toTable: 2,
      transferType: 'partial',
      selectedLineIds: <String>[flat.first['transfer_line_id'].toString()],
    );

    expect(flat.first['transfer_line_id'], 'order-1#0');
    expect(plan.movedLineIds, <String>['order-1#0']);
    expect(plan.mutations.single.destinationItems!.single['name'], 'Çay');
  });

  test('full transfer clears the source bill', () {
    final plan = planTableTransfer(
      orders: orders,
      toTable: 9,
      transferType: 'full',
    );

    expect(transferClearsSourceTable(plan: plan, orders: orders), isTrue);
  });

  test('a line left on the source does not clear the kitchen row', () {
    final plan = planTableTransfer(
      orders: orders,
      toTable: 9,
      transferType: 'partial',
      selectedLineIds: const <String>['order-1#0'],
    );

    expect(transferClearsSourceTable(plan: plan, orders: orders), isFalse);
    expect(
      RestaurantOrderLeftOnSourceException.message,
      contains('yeniden göndermeyin'),
    );
  });

  test('moving every selected line clears the source bill', () {
    final plan = planTableTransfer(
      orders: orders,
      toTable: 9,
      transferType: 'partial',
      selectedLineIds: const <String>['order-1#0', 'order-1#1'],
    );

    expect(transferClearsSourceTable(plan: plan, orders: orders), isTrue);
  });
}
