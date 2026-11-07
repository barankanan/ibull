import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/bill_edit_access.dart';

void main() {
  test('bill item denial names the required grant', () {
    expect(
      friendlyBillItemEditMessage(
        code: '42501',
        message: 'Bu restoran için adisyon düzenleme yetkiniz yok.',
      ),
      'Adisyon düzenlenemedi. Bu işlem için Siparişleri Yönet veya Tam Erişim yetkisi gerekir.',
    );
  });

  test('bill item denial is not rewritten as a generic RLS error', () {
    final error = tableOrderMutationException(
      action: 'Sipariş güncelleme',
      code: '42501',
      message: 'Bu restoran için adisyon düzenleme yetkiniz yok.',
    );
    expect(
      error.toString(),
      contains('Siparişleri Yönet veya Tam Erişim'),
    );
    expect(error.toString(), isNot(contains('Yetki politikası')));
  });

  test('older permission errors keep the RLS sentence', () {
    final error = tableOrderMutationException(
      action: 'Sipariş güncelleme',
      code: '42501',
      message: 'permission denied for table table_orders',
    );
    expect(
      error.toString(),
      'Exception: Sipariş güncelleme yapılamadı. Yetki politikası (RLS) bu işlemi engelliyor.',
    );
  });

  test('unrelated update errors keep the server text', () {
    final error = tableOrderMutationException(
      action: 'Sipariş güncelleme',
      code: '23514',
      message: 'new row violates check constraint',
    );
    expect(
      error.toString(),
      'Exception: Sipariş güncelleme yapılamadı: new row violates check constraint',
    );
  });

  test('waiter request denial names the required grant', () {
    expect(
      friendlyWaiterRequestDecisionMessage(
        code: '42501',
        message: 'Bu restoran için sipariş onaylama yetkiniz yok.',
        details: 'İstek reddedilemedi',
      ),
      'İstek onaylanamadı. Bu işlem için Siparişleri Yönet veya Tam Erişim yetkisi gerekir.',
    );
  });

  test('other waiter request errors stay unchanged', () {
    expect(
      friendlyWaiterRequestDecisionMessage(
        code: '22023',
        message: 'Bu istek onay için uygun değil.',
      ),
      isNull,
    );
  });
}
