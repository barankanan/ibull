import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/app/customer_routes.dart';
import 'package:ibul_app/features/seller/auth/seller_recovery_codes.dart';

void main() {
  test('normalizes and accepts store recovery code format', () {
    expect(SellerRecoveryCodes.looksLikeCode('abcd-efgh'), isTrue);
    expect(SellerRecoveryCodes.looksLikeCode('ABCD-EFGH'), isTrue);
    expect(SellerRecoveryCodes.looksLikeCode('ABCD-0I1O'), isFalse);
    expect(SellerRecoveryCodes.normalizeCode(' abcd-efgh '), 'ABCD-EFGH');
    expect(SellerRecoveryCodes.codeCount, 5);
  });

  test('email and phone identifiers are distinguished', () {
    expect(SellerRecoveryCodes.looksLikeEmail('galeri@gmail.com'), isTrue);
    expect(SellerRecoveryCodes.looksLikePhone('05551234567'), isTrue);
    expect(
      SellerRecoveryCodes.normalizePhone('+90 555 123 45 67'),
      '905551234567',
    );
  });

  test('seller login exposes forgot password and recovery SQL exists', () {
    final login = File('lib/screens/seller_login_page.dart').readAsStringSync();
    expect(login, contains('Şifremi unuttum'));
    expect(login, contains('SellerForgotPasswordPage.open'));

    final page = File(
      'lib/screens/seller/seller_forgot_password_page.dart',
    ).readAsStringSync();
    expect(page, contains('Şifrenizi sıfırlayın'));
    expect(page, contains('SellerForgotMethodCard'));
    expect(parseSellerForgotPasswordEmail({'email': ' a@b.com '}), 'a@b.com');
    expect(parseSellerForgotPasswordEmail('magaza@ornek.com'), 'magaza@ornek.com');

    final sql = File(
      'supabase/migrations/20260909_seller_store_recovery_codes.sql',
    ).readAsStringSync();
    expect(sql.contains('admin_issue_store_recovery_codes'), isTrue);
    expect(sql.contains('seller_reset_password_with_recovery_code'), isTrue);
    expect(sql.contains('encrypted_password'), isTrue);
    expect(sql.contains(r'$fn_reset$'), isTrue);
    expect(sql.contains(r'$fn_issue$'), isTrue);
  });
}
