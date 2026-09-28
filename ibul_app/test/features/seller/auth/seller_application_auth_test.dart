import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/auth/seller_application_auth.dart';

void main() {
  test('detects already-registered auth errors', () {
    expect(
      SellerApplicationAuth.isAlreadyRegistered(
        Exception('User already registered'),
      ),
      isTrue,
    );
    expect(
      SellerApplicationAuth.isAlreadyRegistered(
        Exception('email_exists'),
      ),
      isTrue,
    );
    expect(
      SellerApplicationAuth.isAlreadyRegistered(Exception('invalid_credentials')),
      isFalse,
    );
  });

  test('become seller always persists the typed password', () {
    final page = File('lib/screens/become_seller_page.dart').readAsStringSync();
    expect(page, contains('SellerApplicationAuth.ensureAccount'));
    expect(page, isNot(contains('if (authService.currentUser == null)')));
  });

  test('seller application does not attach to an admin account', () {
    final auth = File(
      'lib/features/seller/auth/seller_application_auth.dart',
    ).readAsStringSync();
    expect(auth, contains('isAdminRole'));
    expect(auth, contains('Admin hesabıyla satıcı başvurusu yapılamaz'));
  });

  test('submitSellerApplication marks pending seller without admin overwrite', () {
    final auth = File('lib/services/auth_service.dart').readAsStringSync();
    expect(auth, contains('pendingSellerUserPatch'));
    expect(auth, contains("diagnosticContext == 'seller_login'"));
    expect(auth, contains('ownedStoreIsApproved'));
    expect(auth, contains('restore_own_admin_role'));
  });
}
