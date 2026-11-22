import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/staff_login_policy.dart';

void main() {
  test('the server reason is named, never a success', () {
    expect(
      partialPaymentFailureMessage('Exception: Ödeme kaydı yapılamadı: Ödeme kalan bakiyeyi aşıyor.'),
      contains('kalan hesabı aşıyor'),
    );
    expect(
      partialPaymentFailureMessage('Yetki politikası (RLS) bu işlemi engelliyor.'),
      contains('yetkisi yok'),
    );
    expect(
      partialPaymentFailureMessage('invalid input syntax for type numeric: "₺544"'),
      contains('eski bir sipariş satırı'),
    );
    for (final raw in ['x', 'Ödeme kalan bakiyeyi aşıyor.', '']) {
      expect(partialPaymentFailureMessage(raw), contains('Tahsilat yapılmadı'));
    }
  });
}
