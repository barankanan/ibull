import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/order_print_job_service.dart';

void main() {
  prefetchTests();
  final items = <Map<String, dynamic>>[
    {'product_id': 'a', 'quantity': 2, 'price': 40},
  ];

  test('aynı kayıt ve kalemler aynı anahtarı üretir', () {
    expect(
      tableOrderSendIdempotencyKey('t1', items),
      tableOrderSendIdempotencyKey('t1', [
        {'product_id': 'a', 'quantity': 2, 'price': 40},
      ]),
    );
  });

  test('kalem veya kayıt değişince anahtar değişir', () {
    final base = tableOrderSendIdempotencyKey('t1', items);
    expect(
      tableOrderSendIdempotencyKey('t1', [
        {'product_id': 'a', 'quantity': 3, 'price': 40},
      ]),
      isNot(base),
    );
    expect(tableOrderSendIdempotencyKey('t2', items), isNot(base));
  });
}

void prefetchTests() {
  group('garsonFastJobsFromPrefetch', () {
    final a = <String, dynamic>{'id': 'a', 'payload': <String, dynamic>{}};
    final b = <String, dynamic>{'id': 'b', 'payload': <String, dynamic>{}};

    test('tam kapsama: istenen sırayla döner', () {
      final r = garsonFastJobsFromPrefetch(
        printJobIds: ['b', 'a'],
        prefetchedJobsById: {'a': a, 'b': b},
      );
      expect(r, [b, a]);
    });

    test('eksik iş veya boş yük: null (yeniden sorgu)', () {
      expect(
        garsonFastJobsFromPrefetch(
          printJobIds: ['a', 'c'],
          prefetchedJobsById: {'a': a},
        ),
        isNull,
      );
      expect(
        garsonFastJobsFromPrefetch(
          printJobIds: ['a'],
          prefetchedJobsById: {'a': {'id': 'a'}},
        ),
        isNull,
      );
      expect(
        garsonFastJobsFromPrefetch(printJobIds: ['a'], prefetchedJobsById: null),
        isNull,
      );
    });
  });
}
