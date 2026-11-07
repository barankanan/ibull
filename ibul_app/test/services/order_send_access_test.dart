import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/order_send_access.dart';

void main() {
  test('view-only order send names the required grant', () {
    expect(
      friendlyOrderSendRpcMessage(
        code: '42501',
        message: 'Bu restoran için sipariş gönderme yetkiniz yok.',
      ),
      'Sipariş gönderilemedi. Bu işlem için Siparişleri Yönet veya Tam Erişim yetkisi gerekir.',
    );
  });

  test('older restaurant permission error keeps the print guidance', () {
    expect(
      friendlyOrderSendRpcMessage(
        code: '42501',
        message: 'Bu restoran için işlem yetkiniz yok.',
      ),
      contains('email veya telefon eşleşmesi gerekli'),
    );
  });

  test('orders schema mismatch stays specific', () {
    expect(
      friendlyOrderSendRpcMessage(
        code: '42703',
        message:
            'column "table_number" of relation "orders" does not exist',
      ),
      contains('create_table_order_with_print_jobs_impl'),
    );
  });

  test('v_item alias failure stays specific', () {
    expect(
      friendlyOrderSendRpcMessage(
        code: '42P01',
        message: 'missing FROM-clause entry for table "v_item"',
      ),
      contains('v_item'),
    );
  });

  test('unrelated database text is returned unchanged', () {
    expect(
      friendlyOrderSendRpcMessage(
        code: '22023',
        message: 'Sipariş kalemleri boş olamaz.',
      ),
      'Sipariş kalemleri boş olamaz.',
    );
  });
}
