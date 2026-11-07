import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/store/split_bill_plan.dart';
import 'package:ibul_app/services/store/table_payment_guard.dart';

void main() {
  final openedAt = DateTime.utc(2026, 11, 7, 12);

  group('planEqualSplit', () {
    test('kalan kuruş son kişiye kalır ve toplam tutar', () {
      final plan = planEqualSplit(
        remainingKurus: 10000,
        personCount: 3,
        idempotencyPrefix: 'split:oturum:ab',
      );

      expect(plan.isReady, isTrue);
      expect(plan.shares.map((share) => share.amountKurus).toList(), <int>[
        3333,
        3333,
        3334,
      ]);
      expect(
        plan.shares.fold<int>(0, (sum, share) => sum + share.amountKurus),
        10000,
      );
      expect(
        plan.shares.map((share) => share.idempotencyKey).toSet(),
        hasLength(3),
      );
      expect(plan.shares.first.idempotencyKey, 'split:oturum:ab:1');
      expect(plan.shares.first.note, 'Bölünmüş ödeme 1/3');
    });

    test('eşit bölünen hesapta paylar aynıdır', () {
      final plan = planEqualSplit(
        remainingKurus: 1000,
        personCount: 2,
        idempotencyPrefix: 'split:oturum:cd',
      );

      expect(plan.shares.map((share) => share.amountKurus).toList(), <int>[
        500,
        500,
      ]);
    });

    test('kalan yoksa ve sıfır pay oluşacaksa tahsilat planı yoktur', () {
      final empty = planEqualSplit(
        remainingKurus: 0,
        personCount: 2,
        idempotencyPrefix: 'split:oturum:ef',
      );
      final tiny = planEqualSplit(
        remainingKurus: 1,
        personCount: 2,
        idempotencyPrefix: 'split:oturum:ef',
      );
      final onePerson = planEqualSplit(
        remainingKurus: 1000,
        personCount: 1,
        idempotencyPrefix: 'split:oturum:ef',
      );

      expect(empty.code, SplitBillCode.noBalance);
      expect(tiny.code, SplitBillCode.zeroShare);
      expect(onePerson.code, SplitBillCode.count);
      expect(empty.shares, isEmpty);
      expect(tiny.shares, isEmpty);
    });

    test('uzun oturum anahtarı 120 karakteri aşmaz', () {
      final prefix = newSplitIdempotencyPrefix('s' * 200);
      final plan = planEqualSplit(
        remainingKurus: 200,
        personCount: 2,
        idempotencyPrefix: prefix,
      );

      expect(plan.isReady, isTrue);
      expect(
        plan.shares.every(
          (share) =>
              share.idempotencyKey.length <=
              tablePaymentIdempotencyKeyMaxLength,
        ),
        isTrue,
      );
    });
  });

  test('başka ziyaretin ödemesi kalanı düşürmez', () {
    final orders = <Map<String, dynamic>>[
      <String, dynamic>{
        'status': 'sent',
        'visit_id': 'visit-open',
        'created_at': openedAt.toIso8601String(),
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Çorba',
            'unit_price_snapshot': 50,
            'quantity': 2,
          },
        ],
      },
    ];
    final current = RecordedTablePayment(
      id: 'current',
      tableNumber: 4,
      amountKurus: 4000,
      createdAt: openedAt.add(const Duration(minutes: 5)),
      visitId: 'visit-open',
      raw: const <String, dynamic>{},
    );
    final previous = RecordedTablePayment(
      id: 'previous',
      tableNumber: 4,
      amountKurus: 9000,
      createdAt: openedAt.add(const Duration(minutes: 6)),
      visitId: 'visit-old',
      raw: const <String, dynamic>{},
    );

    expect(
      openTableRemainingKurus(
        orders: orders,
        payments: <RecordedTablePayment>[current, previous],
        now: openedAt.add(const Duration(hours: 1)),
      ),
      6000,
    );
  });
}
