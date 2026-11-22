import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/lan_advertiser.dart';
import 'package:ibul_app/services/restaurant_offline/lan_interface.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_lan_host.dart';
import 'package:ibul_app/services/restaurant_offline/seller_lan_center.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SilentAdvertiser implements LanAdvertiser {
  @override
  Future<void> start({
    required String instanceName,
    required int port,
    required String restaurantId,
    required String machineId,
    required String fingerprint,
  }) async {}

  @override
  Future<void> stop() async {}
}

/// Binds the center to this computer's real LAN address for a moment. It
/// runs only when IBUL_LAN_REAL_IFACE=1 because it needs a private network
/// and a free port; nothing leaves this machine.
void main() {
  final enabled = Platform.environment['IBUL_LAN_REAL_IFACE'] == '1';
  final port = int.tryParse(Platform.environment['IBUL_LAN_PORT'] ?? '') ?? 18773;

  test(
    'the center listens on the LAN address, survives a relaunch, and obeys the operator',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      SellerLanCenter.advertiser = _SilentAdvertiser();
      SellerLanCenter.accessReader = null;
      final temp = await Directory.systemTemp.createTemp('ibul-lan-real-');
      final material = Directory('${temp.path}/lan');
      addTearDown(() async {
        await SellerLanCenter.stop();
        await temp.delete(recursive: true);
      });
      Future<Map<String, dynamic>?> membership(String _) async => null;

      // First start is an operator decision.
      final first = await SellerLanCenter.start(
        restaurantId: 'rid-real',
        readMembership: membership,
        operatorConfirmed: true,
        materialDirectory: material,
        deviceStore: MemoryLanEnrollmentStore(),
        port: port,
      );
      expect(first.state, SellerLanCenterState.running, reason: first.message);
      final address = first.address!;
      expect(address, isNot('127.0.0.1'));
      expect(address.startsWith('192.168.') || address.startsWith('10.') || address.startsWith('172.'), isTrue);
      expect(first.port, port);
      // Reachable on the LAN address, not only on localhost.
      final socket = await Socket.connect(address, port, timeout: const Duration(seconds: 3));
      await socket.close();
      expect(await SellerLanCenter.isOwned('rid-real'), isTrue);
      // ignore: avoid_print
      print('LAN_CENTER_LISTENING $address:$port');

      // The app closes (not an operator stop) and opens again.
      await SellerLanCenter.stop(byOperator: false);
      expect(RestaurantLanHostRegistry.current?.listening ?? false, isFalse);
      final resumed = await SellerLanCenter.resumeOwned(
        restaurantId: 'rid-real',
        readMembership: membership,
        materialDirectory: material,
        deviceStore: MemoryLanEnrollmentStore(),
        port: port,
      );
      expect(resumed, isNotNull);
      expect(resumed!.state, SellerLanCenterState.running, reason: resumed.message);
      expect(resumed.address, address);
      final again = await Socket.connect(address, port, timeout: const Duration(seconds: 3));
      await again.close();

      // A changed network address is not followed automatically.
      await SellerLanCenter.stop(byOperator: false);
      final moved = await SellerLanCenter.resumeOwned(
        restaurantId: 'rid-real',
        readMembership: membership,
        materialDirectory: material,
        interfaces: const <LanInterfaceChoice>[
          LanInterfaceChoice(name: 'en9', address: '192.168.77.7'),
        ],
        deviceStore: MemoryLanEnrollmentStore(),
        port: port,
      );
      expect(moved!.state, SellerLanCenterState.needsConfirmation);
      expect(RestaurantLanHostRegistry.current?.listening ?? false, isFalse);

      // An operator stop forgets the ownership: no silent reopen.
      await SellerLanCenter.resumeOwned(
        restaurantId: 'rid-real',
        readMembership: membership,
        materialDirectory: material,
        deviceStore: MemoryLanEnrollmentStore(),
        port: port,
      );
      await SellerLanCenter.stop();
      expect(await SellerLanCenter.isOwned('rid-real'), isFalse);
      expect(
        await SellerLanCenter.resumeOwned(
          restaurantId: 'rid-real',
          readMembership: membership,
          materialDirectory: material,
          deviceStore: MemoryLanEnrollmentStore(),
          port: port,
        ),
        isNull,
      );
    },
    skip: enabled ? false : 'set IBUL_LAN_REAL_IFACE=1 to bind the real LAN address',
  );
}
