import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/offline_test_guard.dart';
import 'package:ibul_app/services/restaurant_offline/offline_test_lan.dart';

// Seller-entry hook for the isolated LAN host. No host, port or file is
// touched: `start` is a counter.
void main() {
  const localSupabase = 'http://127.0.0.1:54321';

  Future<OfflineTestLaunch?> launch({
    bool testMode = true,
    String bundleId = offlineTestBundleId,
    String keychainAccount = offlineTestKeychainAccount,
    String supabaseUrl = localSupabase,
    String lanHome = '/tmp/ibul-offline-test-lan',
    String printBridgePort = '9',
    required Future<void> Function() start,
  }) {
    return maybeStartOfflineTestLanHost(
      testMode: testMode,
      bundleId: bundleId,
      keychainAccount: keychainAccount,
      supabaseUrl: supabaseUrl,
      lanHome: lanHome,
      printBridgePort: printBridgePort,
      start: start,
    );
  }

  test('a normal seller build never starts the host', () async {
    var started = 0;
    final result = await launch(testMode: false, start: () async => started++);
    expect(result, isNull);
    expect(started, 0);
  });

  test('a valid offline-test launch starts the host once', () async {
    var started = 0;
    final result = await launch(start: () async => started++);
    expect(result?.allowed, isTrue);
    expect(started, 1);
  });

  test('the production bundle, Keychain account or Supabase address stop the host', () async {
    for (final scenario in <String, Future<OfflineTestLaunch?> Function(Future<void> Function())>{
      'production bundle': (s) => launch(bundleId: sellerDesktopBundleId, start: s),
      'production keychain': (s) => launch(keychainAccount: sellerKeychainAccount, start: s),
      'production supabase': (s) => launch(
            supabaseUrl: 'https://$productionSupabaseMarker.supabase.co',
            start: s,
          ),
    }.entries) {
      var started = 0;
      final result = await scenario.value(() async => started++);
      expect(result?.allowed, isFalse, reason: scenario.key);
      expect(started, 0, reason: scenario.key);
    }
  });

  test('the seller LAN folder and the live bridge port stop the host', () async {
    var started = 0;
    final home = await launch(
      lanHome: '/Users/x/$sellerLanDirectoryName',
      start: () async => started++,
    );
    expect(home?.allowed, isFalse);
    final port = await launch(printBridgePort: '3001', start: () async => started++);
    expect(port?.allowed, isFalse);
    final empty = await launch(lanHome: '', start: () async => started++);
    expect(empty?.allowed, isFalse);
    expect(started, 0);
  });

  test('a failing host start is swallowed and does not stop the app', () async {
    final result = await launch(
      start: () async => throw StateError('openssl yok'),
    );
    expect(result?.allowed, isTrue);
  });
}
