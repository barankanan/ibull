import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/screens/admin/store_application_identity.dart';

void main() {
  test('KEP never falls back to a regular email', () {
    final application = {
      'business_name': 'baran motors',
      'tax_number': '12121212121',
      'email': 'denemek@gmail.com',
      'user_email': 'denemek@gmail.com',
      'kep_address': 'denemek@gmail.com',
    };

    expect(StoreApplicationIdentity.kepAddress(application), '-');
    expect(
      StoreApplicationIdentity.email(application),
      'denemek@gmail.com',
    );
    expect(StoreApplicationIdentity.taxNumber(application), '12121212121');
  });

  test('KEP is shown only for kep.tr addresses', () {
    final application = {
      'kep_address': 'baranmotors@hs01.kep.tr',
      'email': 'denemek@gmail.com',
    };

    expect(
      StoreApplicationIdentity.kepAddress(application),
      'baranmotors@hs01.kep.tr',
    );
    expect(
      StoreApplicationIdentity.email(application),
      'denemek@gmail.com',
    );
  });

  test('empty identity fields render as dash', () {
    expect(StoreApplicationIdentity.legalTitle(const {}), '-');
    expect(StoreApplicationIdentity.website(const {}), '-');
    expect(StoreApplicationIdentity.phone({'phone': '  '}), '-');
    expect(StoreApplicationIdentity.iban(const {}), '-');
  });

  test('looksLikeKepAddress rejects gmail and accepts kep.tr', () {
    expect(
      StoreApplicationIdentity.looksLikeKepAddress('denemek@gmail.com'),
      isFalse,
    );
    expect(
      StoreApplicationIdentity.looksLikeKepAddress('firma@hs02.kep.tr'),
      isTrue,
    );
    expect(StoreApplicationIdentity.looksLikeKepAddress('not-an-email'), isFalse);
  });
}
