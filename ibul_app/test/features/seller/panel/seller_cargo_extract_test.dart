import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/cargo/seller_cargo_geo_data.dart';
import 'package:ibul_app/features/seller/panel/cargo/seller_cargo_geocode.dart';

void main() {
  test('seller cargo geo data lives outside the panel god file', () {
    final panel = File('lib/screens/seller_panel_page.dart').readAsStringSync();
    expect(panel, contains('SellerCargoEntryArea('));
    expect(panel, isNot(contains('_cargoProvinceOptions')));
    expect(panel, isNot(contains('SellerCargoGeoData.provinces')));
    expect(SellerCargoGeoData.provinces, contains('İstanbul'));
    expect(SellerCargoGeoData.defaultDistrict('İstanbul'), isNotEmpty);
  });

  test('cargo create error mapper stays fail-closed for wallet', () {
    expect(
      SellerCargoGeocode.mapCreateError(Exception('insufficient_wallet_balance')),
      contains('cüzdan'),
    );
  });

  test('external cargo dialog is extracted from the panel god file', () {
    final panel = File('lib/screens/seller_panel_page.dart').readAsStringSync();
    expect(panel, contains('SellerExternalCargoDialog.show'));
    expect(panel, contains('StoreLocationChangeDialog('));
    expect(panel, isNot(contains('class _StoreLocationChangeDialog')));
    expect(panel, isNot(contains('Kargo Cik Alani')));
    expect(panel, isNot(contains('lookupAddressSuggestions')));

    final dialog = File(
      'lib/features/seller/panel/cargo/seller_cargo_dialog.dart',
    ).readAsStringSync();
    expect(dialog, contains('class SellerExternalCargoDialog'));
    expect(dialog, isNot(contains('part of \'seller_panel_page.dart\'')));
  });
}
