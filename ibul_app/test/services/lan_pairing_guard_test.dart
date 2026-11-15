import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/lan_pairing_guard.dart';

void main() {
  test('pairing secret is single-use length and locks after five failures', () {
    final secret = newPairingSecret(Random(1));
    expect(secret, hasLength(32));
    expect(pairingSecretMatches(secret, secret), isTrue);
    expect(pairingSecretMatches(secret, '${secret.substring(0, 31)}0'), isFalse);
    final guard = PairingAttemptGuard();
    final now = DateTime.utc(2026, 11, 10, 12);
    for (var attempt = 0; attempt < 5; attempt++) {
      expect(guard.allow(now), isTrue);
      guard.recordFailure(now);
    }
    expect(guard.allow(now), isFalse);
    expect(guard.allow(now.add(const Duration(seconds: 31))), isTrue);
  });

  test('listen address, platform path, and web channel stay explicit', () {
    expect(decideLanListen(InternetAddress.anyIPv4).allowed, isFalse);
    expect(decideLanListen(InternetAddress.loopbackIPv4).allowed, isTrue);
    expect(
      decideLanListen(InternetAddress('192.168.1.20')).allowed,
      isTrue,
    );
    expect(decideLanListen(InternetAddress('8.8.8.8')).allowed, isFalse);
    expect(legacySha1DeviceId('ab' * 20), isTrue);
    expect(legacySha1DeviceId('ab' * 32), isFalse);
    expect(
      lanMaterialDirectory(
        operatingSystem: 'windows',
        environment: const <String, String>{'LOCALAPPDATA': r'C:\Users\A\AppData\Local'},
        restaurantId: 'rest',
      ),
      r'C:\Users\A\AppData\Local\IbulLan\rest',
    );
    expect(
      lanMaterialDirectory(
        operatingSystem: 'macos',
        environment: const <String, String>{'HOME': '/Users/a'},
        restaurantId: 'rest',
      ),
      '/Users/a/Library/Application Support/ibul-lan/rest',
    );
    expect(
      lanClientChannel(isWeb: true, operatingSystem: 'macos'),
      LanClientChannel.webBlocked,
    );
    expect(
      lanClientChannel(isWeb: false, operatingSystem: 'android'),
      LanClientChannel.mobileNative,
    );
    expect(
      lanClientChannel(isWeb: false, operatingSystem: 'macos'),
      LanClientChannel.desktop,
    );
  });
}
