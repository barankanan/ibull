import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/store/table_merge_plan.dart';
import 'package:ibul_app/services/store/table_payment_guard.dart';

RecordedTablePayment _payment({
  required String id,
  required int tableNumber,
  required double amount,
  required DateTime createdAt,
}) {
  return RecordedTablePayment(
    id: id,
    tableNumber: tableNumber,
    amountKurus: moneyToKurus(amount),
    createdAt: createdAt.toUtc(),
    raw: <String, dynamic>{'id': id, 'amount': amount},
  );
}

void main() {
  final opened = DateTime.utc(2026, 11, 7, 12);

  test('kısmi ödemeler tek kalan hesapta birleşir ve kopyalanmaz', () {
    final remaining = mergedTableRemainingKurus(
      sourceOrders: [
        {
          'id': 'source',
          'status': 'sent',
          'created_at': opened.toIso8601String(),
          'items': [
            {
              'name': 'Corba',
              'quantity': 2,
              'unit_price_snapshot': 40,
              'note': 'az tuz',
            },
          ],
        },
      ],
      targetOrders: [
        {
          'id': 'target',
          'status': 'sent',
          'created_at': opened.add(const Duration(minutes: 5)).toIso8601String(),
          'items': [
            {
              'name': 'Salata',
              'quantity': 1,
              'unit_price_snapshot': 30,
              'note': 'limon',
            },
          ],
        },
      ],
      sourcePayments: [
        _payment(
          id: 'pay-1',
          tableNumber: 2,
          amount: 10,
          createdAt: opened.add(const Duration(minutes: 10)),
        ),
      ],
      targetPayments: [
        _payment(
          id: 'pay-2',
          tableNumber: 3,
          amount: 15,
          createdAt: opened.add(const Duration(minutes: 12)),
        ),
      ],
    );

    expect(remaining, 8500);
    expect(openTableBillIds(const [
      {'id': 'source', 'status': 'sent'},
      {'id': 'anchor', 'status': 'print_anchor'},
      {'id': 'closed', 'status': 'closed'},
    ]), ['source']);
  });

  test('önceki ziyaretin ödemesi açık hesaba eklenmez', () {
    final remaining = mergedTableRemainingKurus(
      sourceOrders: [
        {
          'id': 'source',
          'status': 'sent',
          'created_at': opened.toIso8601String(),
          'items': [
            {'name': 'Corba', 'quantity': 1, 'price': 40},
          ],
        },
      ],
      targetOrders: const <Map<String, dynamic>>[],
      sourcePayments: [
        _payment(
          id: 'old',
          tableNumber: 2,
          amount: 40,
          createdAt: opened.subtract(const Duration(hours: 5)),
        ),
      ],
      targetPayments: const <RecordedTablePayment>[],
    );

    expect(remaining, 4000);
  });
}
