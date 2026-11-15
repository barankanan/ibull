import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/offline_test_guard.dart';

void main() {
  test('a test launch cannot use the seller bundle, keychain, or production', () {
    final blocked = evaluateOfflineTestLaunch(
      testMode: true,
      bundleId: sellerDesktopBundleId,
      keychainAccount: sellerKeychainAccount,
      supabaseUrl: 'https://ihmixxzqnpamcwmrfibx.supabase.co',
      lanHome: '/Users/seller/Library/Application Support/ibul-lan',
      printBridgePort: '3001',
    );
    expect(blocked.allowed, isFalse);
    expect(blocked.failures.length, greaterThanOrEqualTo(5));

    final isolated = evaluateOfflineTestLaunch(
      testMode: true,
      bundleId: offlineTestBundleId,
      keychainAccount: offlineTestKeychainAccount,
      supabaseUrl: 'http://127.0.0.1:55499',
      lanHome: '/tmp/ibul-lan-test',
      printBridgePort: '18773',
    );
    expect(isolated.allowed, isTrue);
    expect(isolated.failures, isEmpty);
    expect(offlineTestBundleId, isNot(sellerDesktopBundleId));
    expect(offlineTestKeychainAccount, isNot(sellerKeychainAccount));
  });

  test('the shipping app is not forced through the test gate', () {
    final shipping = evaluateOfflineTestLaunch(
      testMode: false,
      bundleId: sellerDesktopBundleId,
      keychainAccount: sellerKeychainAccount,
      supabaseUrl: 'https://ihmixxzqnpamcwmrfibx.supabase.co',
      lanHome: '',
      printBridgePort: '3001',
    );
    expect(shipping.allowed, isTrue);
  });

  test('bundle id is read from the launched app plist', () async {
    final root = await Directory.systemTemp.createTemp('ibul-bundle');
    addTearDown(() => root.delete(recursive: true));
    final plist = File('${root.path}/Contents/Info.plist');
    await plist.parent.create(recursive: true);
    await Directory('${root.path}/Contents/MacOS').create(recursive: true);
    await plist.writeAsString('''
<key>CFBundleIdentifier</key>
<string>com.ibul.sellerdesktop.offlinetest</string>
''');
    expect(
      readMacBundleIdentifier('${root.path}/Contents/MacOS/Test'),
      offlineTestBundleId,
    );
  });
}
