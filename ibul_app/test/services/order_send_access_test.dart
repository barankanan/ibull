import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/order_send_access.dart';
import 'package:ibul_app/utils/garson_active_orders_fetch.dart';
import 'package:ibul_app/utils/order_status_constants.dart';

void main() {
  test('idempotency key is sent only when present', () {
    final withKey = buildCreateTableOrderRpcParams(
      restaurantId: 'rest',
      tableNumber: 4,
      items: const [
        {'name': 'Çorba'},
      ],
      notes: 'trace note',
      idempotencyKey: 'send-1',
    );
    expect(withKey['p_idempotency_key'], 'send-1');
    expect(withKey['p_order_type'], 'table');

    final withoutKey = buildCreateTableOrderRpcParams(
      restaurantId: 'rest',
      tableNumber: 4,
      items: const [
        {'name': 'Çorba'},
      ],
      idempotencyKey: '   ',
    );
    expect(withoutKey.containsKey('p_idempotency_key'), isFalse);
  });

  test('print anchor is terminal and is not a cancellation', () {
    expect(OrderStatusConstants.isTerminalStatus('print_anchor'), isTrue);
    expect(OrderStatusConstants.isCancelledStatus('print_anchor'), isFalse);
    expect(isGarsonActiveOrderStatus('print_anchor'), isFalse);
  });

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
