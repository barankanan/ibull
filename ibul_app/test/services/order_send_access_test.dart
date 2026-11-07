import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/order_send_access.dart';
import 'package:ibul_app/utils/garson_active_orders_fetch.dart';
import 'package:ibul_app/utils/order_status_constants.dart';

void main() {
  test('the same action keeps one key until it succeeds', () {
    final ledger = OrderSendKeyLedger();
    const fingerprint = 'rest|4|new_order|soup';
    final first = resolveOrderSendKey(
      ledger: ledger,
      fingerprint: fingerprint,
    );
    final retry = resolveOrderSendKey(
      ledger: ledger,
      fingerprint: fingerprint,
    );
    expect(retry, first);
    ledger.complete(fingerprint);
    final nextOrder = resolveOrderSendKey(
      ledger: ledger,
      fingerprint: fingerprint,
    );
    expect(nextOrder, isNot(first));
  });

  test('a restarted ledger keeps the original key', () async {
    final saved = <String, String>{};
    final first = OrderSendKeyLedger();
    first.sink = (keys) async {
      saved
        ..clear()
        ..addAll(keys);
    };
    final key = resolveOrderSendKey(
      ledger: first,
      fingerprint: 'action',
      requestedKey: 'send-stable',
    );
    await first.flush();

    final restarted = OrderSendKeyLedger(restored: saved);
    expect(
      resolveOrderSendKey(
        ledger: restarted,
        fingerprint: 'action',
        requestedKey: 'send-after-restart',
      ),
      key,
    );
    restarted.complete('action');
    expect(
      resolveOrderSendKey(ledger: restarted, fingerprint: 'action'),
      isNot(key),
    );
  });

  test('a requested key is reused for the same action', () {
    final ledger = OrderSendKeyLedger();
    final key = resolveOrderSendKey(
      ledger: ledger,
      fingerprint: 'action',
      requestedKey: 'send-stable',
    );
    expect(
      resolveOrderSendKey(ledger: ledger, fingerprint: 'action'),
      key,
    );
  });

  test('missing idempotent RPC is a hard stop', () {
    expect(
      friendlyOrderSendRpcMessage(
        code: 'PGRST202',
        message:
            'Could not find the function public.send_table_order_idempotent in the schema cache',
      ),
      contains('Gönderim durduruldu'),
    );
  });

  test('same key with a different order is reported', () {
    expect(
      friendlyOrderSendRpcMessage(
        code: 'P0001',
        message: 'Bu işlem kimliği farklı bir siparişle kullanılmış.',
      ),
      contains('başka bir siparişle kullanılmış'),
    );
  });

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
