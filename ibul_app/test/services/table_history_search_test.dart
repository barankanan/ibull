import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/store/table_order_history_utils.dart';

void main() {
  final rows = <Map<String, dynamic>>[
    {
      'table_number': 5,
      'display_table_label': 'Bahçe 5',
      'waiter_name': 'Ayşe',
      'items': [
        {'name': 'Adana Kebap'},
      ],
    },
    {
      'table_number': 12,
      'display_table_label': 'Salon 2',
      'waiter_name': 'Çağrı',
      'items': [
        {'name': 'Künefe'},
      ],
    },
  ];
  List<Map<String, dynamic>> search(String q) =>
      filterTableHistoryRecords<Map<String, dynamic>>(rows, q, toMap: (r) => r);

  test('an empty query keeps every record', () {
    expect(search('  '), hasLength(2));
  });

  test('matches table label, number, waiter and product, Turkish-insensitive', () {
    expect(search('bahce').single['table_number'], 5);
    expect(search('BAHÇE 5').single['table_number'], 5);
    expect(search('masa 12').single['table_number'], 12);
    expect(search('cagri').single['table_number'], 12);
    expect(search('KUNEFE').single['table_number'], 12);
  });

  test('no match returns nothing, never a wrong table', () {
    expect(search('teras'), isEmpty);
  });
}
