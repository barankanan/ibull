import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/store/table_payment_guard.dart';

RecordedTablePayment _payment({
  required String id,
  required double amount,
  required DateTime createdAt,
  int tableNumber = 4,
  String? idempotencyKey,
}) {
  return RecordedTablePayment(
    id: id,
    tableNumber: tableNumber,
    amountKurus: moneyToKurus(amount),
    createdAt: createdAt.toUtc(),
    idempotencyKey: idempotencyKey,
    raw: <String, dynamic>{
      'id': id,
      'table_number': tableNumber,
      'amount': amount,
      'created_at': createdAt.toUtc().toIso8601String(),
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
    },
  );
}

void main() {
  final openedAt = DateTime.utc(2026, 11, 7, 12);

  group('planTablePayment', () {
    test('kısmi tahsilat kalanın içindeyse kabul edilir', () {
      final plan = planTablePayment(
        tableNumber: 4,
        billKurus: 10000,
        amount: 40,
        idempotencyKey: 'pay-1',
        openBillPayments: const <RecordedTablePayment>[],
        idempotencyCandidates: const <RecordedTablePayment>[],
      );

      expect(plan.isAccept, isTrue);
    });

    test('kalan tutarın 1 kuruş üstü reddedilir', () {
      final alreadyPaid = _payment(
        id: 'p1',
        amount: 60,
        createdAt: openedAt.add(const Duration(minutes: 5)),
      );
      final plan = planTablePayment(
        tableNumber: 4,
        billKurus: 10000,
        amount: 40.01,
        idempotencyKey: 'pay-2',
        openBillPayments: <RecordedTablePayment>[alreadyPaid],
        idempotencyCandidates: <RecordedTablePayment>[alreadyPaid],
      );

      expect(plan.code, TablePaymentPlanCode.overpay);
      expect(plan.message, contains('40,00'));
    });

    test('sıfır ve geçersiz tutar reddedilir', () {
      final zero = planTablePayment(
        tableNumber: 4,
        billKurus: 10000,
        amount: 0,
        idempotencyKey: 'pay-zero',
        openBillPayments: const <RecordedTablePayment>[],
        idempotencyCandidates: const <RecordedTablePayment>[],
      );
      final invalid = planTablePayment(
        tableNumber: 4,
        billKurus: 10000,
        amount: double.nan,
        idempotencyKey: 'pay-nan',
        openBillPayments: const <RecordedTablePayment>[],
        idempotencyCandidates: const <RecordedTablePayment>[],
      );

      expect(zero.code, TablePaymentPlanCode.amount);
      expect(invalid.code, TablePaymentPlanCode.amount);
    });

    test('aynı işlem anahtarı ikinci kez yazılmaz', () {
      final original = _payment(
        id: 'p1',
        amount: 25,
        createdAt: openedAt,
        idempotencyKey: 'pay-same',
      );
      final plan = planTablePayment(
        tableNumber: 4,
        billKurus: 0,
        amount: 80,
        idempotencyKey: 'pay-same',
        openBillPayments: const <RecordedTablePayment>[],
        idempotencyCandidates: <RecordedTablePayment>[original],
      );

      expect(plan.isReplay, isTrue);
      expect(plan.existing?.id, 'p1');
    });

    test('başka masanın işlem anahtarı yeniden kullanılamaz', () {
      final original = _payment(
        id: 'p1',
        amount: 25,
        createdAt: openedAt,
        tableNumber: 8,
        idempotencyKey: 'pay-other-table',
      );
      final plan = planTablePayment(
        tableNumber: 4,
        billKurus: 5000,
        amount: 10,
        idempotencyKey: 'pay-other-table',
        openBillPayments: const <RecordedTablePayment>[],
        idempotencyCandidates: <RecordedTablePayment>[original],
      );

      expect(plan.code, TablePaymentPlanCode.idempotency);
    });

    test('açılıştan önceki tahsilat yeni hesabı düşürmez', () {
      final previousVisit = _payment(
        id: 'old',
        amount: 100,
        createdAt: openedAt.subtract(const Duration(minutes: 1)),
      );
      final openPayments = paymentsInOpenBill(
        payments: <RecordedTablePayment>[previousVisit],
        openedAt: openedAt,
        now: openedAt.add(const Duration(hours: 1)),
        hasOpenOrders: true,
      );
      final plan = planTablePayment(
        tableNumber: 4,
        billKurus: 10000,
        amount: 100,
        idempotencyKey: 'pay-new-visit',
        openBillPayments: openPayments,
        idempotencyCandidates: <RecordedTablePayment>[previousVisit],
      );

      expect(openPayments, isEmpty);
      expect(plan.isAccept, isTrue);
    });

    test('aynı açık hesabın ara ödemesi kalanı düşer', () {
      final partial = _payment(
        id: 'partial',
        amount: 30,
        createdAt: openedAt.add(const Duration(minutes: 10)),
      );
      final openPayments = paymentsInOpenBill(
        payments: <RecordedTablePayment>[partial],
        openedAt: openedAt,
        now: openedAt.add(const Duration(hours: 1)),
        hasOpenOrders: true,
      );
      final plan = planTablePayment(
        tableNumber: 4,
        billKurus: 10000,
        amount: 70.01,
        idempotencyKey: 'pay-too-much',
        openBillPayments: openPayments,
        idempotencyCandidates: openPayments,
      );

      expect(openPayments, hasLength(1));
      expect(plan.code, TablePaymentPlanCode.overpay);
    });
  });

  group('açık hesap tutarı', () {
    test('ekrandaki hesap birim fiyat çarpı adettir', () {
      final kurus = billKurusForOrders(<Map<String, dynamic>>[
        <String, dynamic>{
          'created_at': openedAt.toIso8601String(),
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'Çorba',
              'price': 12.5,
              'unit_price_snapshot': 12.5,
              'quantity': 2,
              'line_total': 1,
            },
          ],
        },
      ]);

      expect(kurus, 2500);
      expect(
        earliestOrderOpenedAt(<Map<String, dynamic>>[
          <String, dynamic>{'created_at': openedAt.toIso8601String()},
        ]),
        openedAt,
      );
    });
  });

  test('aynı masa tahsilatları sıraya girer', () async {
    final turnstile = TablePaymentTurnstile();
    final order = <int>[];
    final first = turnstile.run('seller:4', () async {
      order.add(1);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      order.add(2);
    });
    final second = turnstile.run('seller:4', () async {
      order.add(3);
    });

    await Future.wait(<Future<void>>[first, second]);

    expect(order, <int>[1, 2, 3]);
  });
}
