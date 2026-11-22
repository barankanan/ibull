import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sellerPanelFile = File('lib/screens/seller_panel_page.dart');
  final storeServiceFile = File('lib/services/store_service.dart');

  test('seller panel persists and restores resolved restaurant owner id', () {
    final source = sellerPanelFile.readAsStringSync();
    expect(source, contains('_sellerDataOwnerPrefKey'));
    expect(source, contains('_restorePersistedSellerDataOwnerIdWithReload('));
    expect(source, contains('_rememberSellerDataOwnerId('));
    expect(source, contains('_bestSellerDataOwnerIdCandidate('));
  });

  test('seller panel resolves owner id from backend before auth fallback', () {
    final source = sellerPanelFile.readAsStringSync();
    // Biçimlendirici çağrıyı satıra bölebilir; boşluktan bağımsız eşleştir.
    expect(
      source,
      contains(
        RegExp(r'_storeService\s*\.resolveStoreOwnerIdForCurrentUser\(\)'),
      ),
    );
    expect(source, contains("source: '_loadStoreProfile'"));
    expect(source, contains("source: '_loadDashboardClosedHistory'"));
    expect(source, contains("source: '_loadStoreTables'"));
  });

  test('store service can resolve waiter/sub-admin owner mapping', () {
    final source = storeServiceFile.readAsStringSync();
    expect(
      source,
      contains('Future<String?> resolveStoreOwnerIdForCurrentUser()'),
    );
    expect(source, contains(".from('store_sub_admins')"));
    expect(source, contains('getStoreProfileForSellerId'));
  });

  test('a failed owner lookup is unknown, never the signed-in user', () {
    final source = storeServiceFile.readAsStringSync();
    expect(source, contains('return lookupFailed ? null : userId;'));
    expect(RegExp(r'lookupFailed = true;').allMatches(source).length, 2);
  });
}
