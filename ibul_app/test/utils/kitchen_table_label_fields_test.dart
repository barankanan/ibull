import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/utils/kitchen_print_dedup.dart';

void main() {
  test('the chosen table label is carried on every header key', () {
    final fields = kitchenTableLabelFields(' Bahçe 1 ');
    expect(fields['table_name'], 'Bahçe 1');
    expect(fields['display_table_label'], 'Bahçe 1');
    expect(fields['table_display_name'], 'Bahçe 1');
  });

  test('tables with the same number in different areas stay apart', () {
    expect(
      kitchenTableLabelFields('Bahçe 1')['table_name'],
      isNot(kitchenTableLabelFields('Salon 1')['table_name']),
    );
  });

  test('no label adds nothing, so the "Masa N" fallback still applies', () {
    expect(kitchenTableLabelFields(null), isEmpty);
    expect(kitchenTableLabelFields('   '), isEmpty);
  });
}
