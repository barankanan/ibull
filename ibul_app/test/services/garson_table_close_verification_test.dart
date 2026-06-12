import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Garson Table Close Verification Logic', () {
    void verifyClose(List<Map<String, dynamic>> remainingActiveOrders) {
      if (remainingActiveOrders.isNotEmpty) {
        final allFromOrders = remainingActiveOrders.every(
          (o) => o['_garson_source_table'] == 'orders',
        );

        if (allFromOrders) {
          throw Exception(
            'Masa kapatma tamamlanamadı. Müşteri siparişleri hâlâ açık görünüyor.',
          );
        } else {
          throw Exception(
            'Masa kapatma tamamlanamadı. '
            '${remainingActiveOrders.length} aktif kayıt hâlâ açık görünüyor.',
          );
        }
      }
    }

    test('success when remainingActiveOrders is empty', () {
      expect(() => verifyClose([]), returnsNormally);
    });

    test('throws when remainingActiveOrders has table_orders', () {
      final snapshot = [
        {'_garson_source_table': 'table_orders', 'id': 't1'},
      ];
      expect(() => verifyClose(snapshot), throwsException);
    });

    test('throws when remainingActiveOrders has mixed sources', () {
      final snapshot = [
        {'_garson_source_table': 'table_orders', 'id': 't1'},
        {'_garson_source_table': 'orders', 'id': 'o1'},
      ];
      expect(() => verifyClose(snapshot), throwsException);
    });

    test('throws when remainingActiveOrders ONLY has orders', () {
      final snapshot = [
        {'_garson_source_table': 'orders', 'id': 'o1'},
        {'_garson_source_table': 'orders', 'id': 'o2'},
      ];
      expect(() => verifyClose(snapshot), throwsException);
    });
  });
}
