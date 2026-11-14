import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/secure_local_store.dart';
import 'package:ibul_app/services/restaurant_offline/offline_test_guard.dart';

void main() {
  test('customer and seller macOS identities stay separate', () {
    final seller = File(
      '../macos/Runner/Configs/AppInfo.xcconfig',
    ).readAsStringSync();
    final customer = File(
      '../macos/Runner/Configs/Customer.xcconfig',
    ).readAsStringSync();
    final offline = File(
      '../macos/Runner/Configs/OfflineTest.xcconfig',
    ).readAsStringSync();

    expect(seller, contains('PRODUCT_NAME = IbulSellerDesktop'));
    expect(seller, contains('PRODUCT_BUNDLE_IDENTIFIER = com.ibul.sellerdesktop'));
    expect(seller, contains('APP_DISPLAY_NAME = İBUL Satıcı'));
    expect(seller, isNot(contains('com.ibul.customer')));

    expect(customer, contains('PRODUCT_NAME = IBUL'));
    expect(customer, contains('PRODUCT_BUNDLE_IDENTIFIER = com.ibul.customer'));
    expect(customer, contains('APP_DISPLAY_NAME = İBUL'));
    expect(customer, isNot(contains('com.ibul.sellerdesktop\n')));

    expect(offline, contains('com.ibul.sellerdesktop.offlinetest'));
    expect(offline, contains('IbulSellerOfflineTest'));

    expect(
      SecureLocalStore.customerMacOsSecureAccount,
      isNot(SecureLocalStore.sellerMacOsSecureAccount),
    );
    expect(
      SecureLocalStore.customerMacOsSecureAccount,
      isNot(offlineTestKeychainAccount),
    );
    expect(
      SecureLocalStore.offlineTestMacOsSecureAccount,
      offlineTestKeychainAccount,
    );
    expect(sellerDesktopBundleId, 'com.ibul.sellerdesktop');
    expect(offlineTestBundleId, isNot(sellerDesktopBundleId));
    expect(offlineTestBundleId, isNot('com.ibul.customer'));
  });

  test('customer entry selects its own secure account before opening it', () {
    expect(
      SecureLocalStore.macOsAccountName,
      SecureLocalStore.sellerMacOsSecureAccount,
    );
    SecureLocalStore.useCustomerMacOsAccount();
    expect(
      SecureLocalStore.macOsAccountName,
      SecureLocalStore.customerMacOsSecureAccount,
    );

    final customerMain = File('../lib/main.dart').readAsStringSync();
    final sellerMain = File('../lib/main_seller.dart').readAsStringSync();
    expect(customerMain, contains('SecureLocalStore.useCustomerMacOsAccount()'));
    expect(sellerMain, contains('const SellerLoginPage()'));
    expect(sellerMain, contains("title: 'İbul Satıcı'"));
    expect(sellerMain, isNot(contains('useCustomerMacOsAccount')));
  });

  test('customer screens no longer offer the seller login doors', () {
    final footer = File('lib/widgets/web_footer.dart').readAsStringSync();
    final account = File('lib/screens/account_page.dart').readAsStringSync();
    expect(footer, isNot(contains('Satıcı Girişi')));
    expect(footer, isNot(contains('Admin Paneli')));
    expect(footer, isNot(contains('SellerLoginPage')));
    expect(footer, contains('Satıcı Ol'));
    expect(account, isNot(contains('Satıcı Girişi')));
    expect(account, isNot(contains('SellerLoginPage')));
    expect(File('lib/screens/seller_panel_page.dart').existsSync(), isTrue);
    expect(File('lib/screens/seller_login_page.dart').existsSync(), isTrue);
    expect(
      File('lib/services/restaurant_offline/restaurant_lan_host.dart')
          .existsSync(),
      isTrue,
    );
  });

  test('macos entry guard blocks crossed bundles', () async {
    final root = await Directory.systemTemp.createTemp('ibul-guard');
    addTearDown(() => root.delete(recursive: true));
    final generated = File('${root.path}/Generated.xcconfig');

    Future<int> run(String bundle, String target) async {
      await generated.writeAsString('FLUTTER_TARGET=$target\n');
      final result = await Process.run('sh', [
        '../scripts/macos_entry_guard.sh',
      ], environment: {
        'IBUL_GENERATED_XCCONFIG': generated.path,
        'PRODUCT_BUNDLE_IDENTIFIER': bundle,
      });
      return result.exitCode;
    }

    expect(await run('com.ibul.sellerdesktop', 'lib/main.dart'), 1);
    expect(await run('com.ibul.sellerdesktop', 'lib/main_seller.dart'), 0);
    expect(await run('com.ibul.customer', 'lib/main.dart'), 0);
    expect(await run('com.ibul.customer', 'lib/main_seller.dart'), 1);
    expect(
      await run('com.ibul.sellerdesktop.offlinetest', 'lib/main_seller.dart'),
      0,
    );
    expect(
      await run('com.ibul.sellerdesktop.offlinetest', 'lib/main.dart'),
      1,
    );
  });
}
