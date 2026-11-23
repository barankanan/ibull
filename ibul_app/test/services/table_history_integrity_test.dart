import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/restaurant_ops_models.dart';
import 'package:ibul_app/services/store/table_order_history_utils.dart';

// Üretimde gözlenen Bahçe 1 kaydı: başlık 0,00, archived_orders içinde kalem
// yok; order_items satırı unit_price=180, total_price=0, line_total=null.
Map<String, dynamic> _bahce1() => <String, dynamic>{
      'id': 'h1',
      'seller_id': 's',
      'table_number': 11,
      'table_name': 'Bahçe 1',
      'original_order_id': 'o1',
      'grand_total': '0.00',
      'waiter_name': 'ozcanduymaz',
      'closed_at': '2026-11-22T22:45:31Z',
      'created_at': '2026-11-22T22:32:17Z',
      'archived_orders': [
        {'id': 'o1', 'total_amount': '0.00'},
      ],
    };

void main() {
  test('kalemsiz + 0 TL kayıt "Ürün yok" değil, veri eksik olarak işaretlenir', () {
    final row = _bahce1();
    expect(TableOrderHistoryUtils.productSummary(row), 'Ürün bilgisi kayıtta yok');
    expect(TableOrderHistoryUtils.historyIntegrity(row),
        TableOrderHistoryUtils.integrityItemsMissing);
    final rec = TableOrderHistoryRecord.fromMap(row);
    expect(rec.integrityNote, TableOrderHistoryUtils.integrityItemsMissing);
    expect(rec.waiterName, 'ozcanduymaz');
  });

  test('order_items satırı eklenince KATI CACIK 1 x 180 kalemlerden türetilir', () {
    final row = TableOrderHistoryUtils.attachLiveLines(_bahce1(), [
      {
        'product_name': 'KATI CACIK',
        'quantity': 1,
        'unit_price': 180,
        'total_price': 0,
        'line_total': null,
      },
    ]);
    expect(TableOrderHistoryUtils.displayItems(row).single['name'], 'KATI CACIK');
    expect(TableOrderHistoryUtils.effectiveTotal(row), 180);
    expect(TableOrderHistoryUtils.historyIntegrity(row),
        TableOrderHistoryUtils.integrityTotalDerived);
    expect(TableOrderHistoryRecord.fromMap(row).grandTotal, 180);
  });

  test('kayıtlı toplam > 0 ise olduğu gibi güvenilir', () {
    final row = {
      ..._bahce1(),
      'grand_total': '640.00',
      'items': [
        {'name': 'ORDÖVR TABAĞI', 'quantity': 2, 'price': 320},
      ],
    };
    expect(TableOrderHistoryUtils.historyIntegrity(row), isNull);
    expect(TableOrderHistoryUtils.effectiveTotal(row), 640);
  });

  test('mevcut snapshot kalemi order_items ile ezilmez', () {
    final row = {
      ..._bahce1(),
      'items': [
        {'name': 'A', 'quantity': 1, 'price': 10},
      ],
    };
    final out = TableOrderHistoryUtils.attachLiveLines(row, [
      {'product_name': 'B', 'quantity': 1, 'unit_price': 99},
    ]);
    expect(TableOrderHistoryUtils.displayItems(out).single['name'], 'A');
  });

  test('sipariş kimliği hiç yoksa gerçek boş kayıt "Ürün yok" kalır', () {
    expect(
      TableOrderHistoryUtils.productSummary({'grand_total': 0}),
      'Ürün yok',
    );
  });
}
