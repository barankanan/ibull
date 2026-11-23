import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/dashboard/widgets/seller_dashboard_primitives.dart';

void main() {
  test('6 kart 5 sütuna sığarsa 3+3 olur, tek başına kart kalmaz', () {
    expect(balancedGridColumns(6, 5), 3);
  });
  test('sığan sayı yeterliyse değişmez', () {
    expect(balancedGridColumns(4, 4), 4);
    expect(balancedGridColumns(3, 5), 3);
    expect(balancedGridColumns(5, 5), 5);
  });
  test('tek sütun ve boş liste güvenli', () {
    expect(balancedGridColumns(6, 1), 1);
    expect(balancedGridColumns(0, 4), 1);
  });
  test('dar genişlikte satır sayısı korunur', () {
    expect(balancedGridColumns(6, 4), 3); // 2 satır
    expect(balancedGridColumns(7, 4), 4); // 2 satır, 4+3
  });
}
