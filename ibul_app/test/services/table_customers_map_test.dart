import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/store/store_customer_directory.dart';

void main() {
  test('selection rows become a table-number map; bad rows are skipped', () {
    final map = tableCustomersFromRows([
      {
        'table_number': 5,
        'store_customers': {'id': 'c1', 'display_name': 'Ahmet Yılmaz', 'phone': ''},
      },
      {'table_number': 6, 'store_customers': null},
      {
        'table_number': 0,
        'store_customers': {'id': 'c2', 'display_name': 'X', 'phone': ''},
      },
      {
        'table_number': 7,
        'store_customers': {'id': 'c3', 'display_name': '  ', 'phone': ''},
      },
    ]);
    expect(map.keys, [5]);
    expect(map[5]!.name, 'Ahmet Yılmaz');
  });

  test('quick entry builds one clean display name', () {
    expect(quickCustomerDisplayName(' Ahmet ', ' Yılmaz '), 'Ahmet Yılmaz');
    expect(quickCustomerDisplayName('Ahmet', ''), 'Ahmet');
    expect(quickCustomerDisplayName('', '  '), '');
  });
}
