import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/lan_interface.dart';

void main() {
  const wifi = LanInterfaceChoice(name: 'en0', address: '192.168.10.67');
  const other = LanInterfaceChoice(name: 'en1', address: '10.0.0.5');

  test('keeps the hub while its address is still on this machine', () {
    final d = decideLanRebind(
      boundAddress: '192.168.10.67',
      current: const [wifi, other],
    );
    expect(d.shouldRebind, isFalse);
  });

  test('moves to the new address when the bound one is gone', () {
    final d = decideLanRebind(boundAddress: '172.20.10.2', current: const [other, wifi]);
    expect(d.shouldRebind, isTrue);
    expect(d.target!.address, '192.168.10.67'); // en0 is preferred
  });

  test('keeps the hub when no valid LAN address exists', () {
    expect(
      decideLanRebind(boundAddress: '172.20.10.2', current: const []).shouldRebind,
      isFalse,
    );
    expect(decideLanRebind(boundAddress: null, current: const [wifi]).shouldRebind, isFalse);
    expect(decideLanRebind(boundAddress: ' ', current: const [wifi]).shouldRebind, isFalse);
  });

  test('loopback, link-local, VPN and public addresses never become the target', () {
    final trusted = trustedLanInterfaces(<LanRawInterfaceAddress>[
      LanRawInterfaceAddress(name: 'lo0', address: InternetAddress('127.0.0.1')),
      LanRawInterfaceAddress(name: 'en0', address: InternetAddress('169.254.3.4')),
      LanRawInterfaceAddress(name: 'utun3', address: InternetAddress('10.8.0.2')),
      LanRawInterfaceAddress(name: 'en2', address: InternetAddress('8.8.4.4')),
    ]);
    expect(trusted, isEmpty);
    expect(
      decideLanRebind(boundAddress: '172.20.10.2', current: trusted).shouldRebind,
      isFalse,
    );
  });
}
