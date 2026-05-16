import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/utils/table_labels.dart';

void main() {
  test('table payload for waiter requests includes printable labels', () {
    final row = <String, dynamic>{
      'display_label': 'Bahçe 2',
      'area_name': 'Bahçe',
      'area_table_number': 2,
      'table_number': 5,
    };
    final payload = resolvePrintableTablePayloadFields(
      tableRow: row,
      tableNumber: 5,
    );
    expect(payload['display_table_label'], 'Bahçe 2');
    expect(payload['table_area_name'], 'Bahçe');
  });
}
