import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/secure_local_store.dart';
import 'package:ibul_app/services/bridge_manager.dart';
import 'package:ibul_app/services/desktop_print_hub.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Keychain account for a Debug build on the real backend', () {
    String resolve({bool offline = false, String override = ''}) =>
        SecureLocalStore.resolveMacOsAccountName(
          offlineTest: offline,
          override: override,
        );

    test('a named account keeps the Debug session apart from production', () {
      expect(resolve(override: 'ibul.sellerdesktop.debug'), 'ibul.sellerdesktop.debug');
      expect(resolve(override: '  ibul.sellerdesktop.debug  '), 'ibul.sellerdesktop.debug');
    });

    test('it can never name the production seller or customer account', () {
      for (final protected in <String>[
        SecureLocalStore.sellerMacOsSecureAccount,
        SecureLocalStore.customerMacOsSecureAccount,
      ]) {
        final chosen = resolve(override: protected);
        expect(chosen, isNot(protected), reason: protected);
        expect(chosen, SecureLocalStore.offlineTestMacOsSecureAccount);
      }
    });

    test('without an override the existing choices are unchanged', () {
      expect(resolve(), SecureLocalStore.sellerMacOsSecureAccount);
      expect(resolve(offline: true), SecureLocalStore.offlineTestMacOsSecureAccount);
    });
  });

  group('print start switch', () {
    setUpAll(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await Supabase.initialize(url: 'http://127.0.0.1:9', anonKey: 'test-anon');
    });

    tearDown(() => BridgeManager.debugPrintStartDisabled = null);

    test('the hub never runs when automatic printing is switched off', () async {
      final hub = DesktopPrintHub();
      await hub.start('restaurant-1', printStartDisabled: true);
      expect(hub.isRunning, isFalse);
      expect(hub.restaurantId, isNull);
      hub.dispose();
    });

    test('the bridge manager refuses to start a bridge and says why', () async {
      BridgeManager.debugPrintStartDisabled = true;
      final result = await BridgeManager.ensureReady();
      expect(result.ok, isFalse);
      expect(result.message, contains('yazıcı servisi kapalı'));
      expect(result.details?['printStartDisabled'], isTrue);
    });
  });
}
