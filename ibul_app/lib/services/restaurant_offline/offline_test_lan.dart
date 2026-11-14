import 'dart:io';

import 'package:flutter/foundation.dart';

import '../staff_login_policy.dart';
import 'lan_cert_material.dart';
import 'lan_interface.dart';
import 'lan_pairing_guard.dart';
import 'lan_tls.dart';
import 'offline_test_guard.dart';
import 'restaurant_lan_host.dart';
import 'restaurant_local_order_queue_service.dart';
import 'restaurant_local_print_queue_service.dart';

const offlineTestRestaurantId = 'offline-test-restaurant';

/// Starts the existing host for the offline-test app only.
/// Ports 18772 and 3001 are refused.
Future<void> startOfflineTestLanHost() async {
  final port = int.tryParse(Platform.environment['IBUL_LAN_PORT'] ?? '') ?? 18773;
  if (port == 18772 || port == 3001 || port <= 0) {
    throw StateError('Test LAN portu 18772 veya 3001 olamaz.');
  }
  final home = (Platform.environment['IBUL_LAN_HOME'] ?? '').trim();
  if (home.isEmpty || home.contains(sellerLanDirectoryName)) {
    throw StateError('IBUL_LAN_HOME satıcı klasörünün dışında olmalı.');
  }
  final directory = Directory(
    lanMaterialDirectory(
      operatingSystem: Platform.operatingSystem,
      environment: Platform.environment,
      restaurantId: offlineTestRestaurantId,
    ),
  );
  final bind = await _offlineTestBindAddress();
  if (!await _opensslReady() && !File('${directory.path}/server.pem').existsSync()) {
    await writeDartTlsMaterial(directory, sanIps: <String>[bind.address]);
    for (final name in const <String>['ca.key', 'server.key', 'operator.key', 'evidence.key']) {
      final key = File('${directory.path}/$name');
      if (key.existsSync()) {
        await Process.run('chmod', <String>['600', key.path]);
      }
    }
  }
  await LanTlsMaterial.open(directory);
  if (await _opensslReady()) {
    await LanTlsMaterial.ensureServerAddress(directory, bind.address);
  }
  final material = await LanTlsMaterial.open(directory);
  final host = RestaurantLanHost(
    restaurantId: offlineTestRestaurantId,
    operatorFingerprint: material.operatorFingerprint,
    certificateDirectory: material.directory.path,
    machineId: 'offline-test-mac',
    orders: RestaurantLocalOrderQueueService(journalDirectory: directory),
    printQueue: RestaurantLocalPrintQueueService(),
    staffStillAuthorized: (_) async => const StaffProbe(StaffProbeKind.active),
    deviceStore: MemoryLanEnrollmentStore(),
    stationsOverride: const <Map<String, dynamic>>[
      <String, dynamic>{'id': 'ocak', 'name': 'Ocak'},
    ],
    tablesOverride: const <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'bahce-3',
        'name': 'Bahçe 3',
        'display_label': 'Bahçe 3',
        'number': 3,
      },
    ],
    productsOverride: const <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'corba',
        'name': 'Çorba',
        'station_id': 'ocak',
        'price': 40,
      },
    ],
  );
  final orders = RestaurantLocalOrderQueueService(journalDirectory: directory);
  await host.start(
    address: bind,
    port: port,
    securityContext: material.serverContext,
  );
  await orders.list(offlineTestRestaurantId);
  await File('${directory.path}/listen-address.txt').writeAsString(
    '${bind.address}\n$port\n',
  );
  debugPrint('[OfflineTest] LAN host dinliyor ${bind.address}:$port');
}

Future<bool> _opensslReady() async {
  try {
    final result = await Process.run(lanOpenSslExecutable(), <String>['version']);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

Future<InternetAddress> _offlineTestBindAddress() async {
  final override = (Platform.environment['IBUL_LAN_BIND'] ?? '').trim();
  if (override.isNotEmpty) {
    final address = InternetAddress(override);
    final decision = decideLanListen(address);
    if (!decision.allowed || address.isLoopback) {
      throw StateError(
        decision.error ?? 'Test LAN adresi güvenilir bir yerel arayüz değil.',
      );
    }
    return address;
  }
  final raw = <LanRawInterfaceAddress>[];
  final interfaces = await NetworkInterface.list(
    includeLoopback: false,
    type: InternetAddressType.IPv4,
  );
  for (final interface in interfaces) {
    for (final address in interface.addresses) {
      raw.add(LanRawInterfaceAddress(name: interface.name, address: address));
    }
  }
  final choice = preferredTrustedLanInterface(trustedLanInterfaces(raw));
  if (choice == null) {
    throw StateError('Güvenilir yerel ağ arayüzü yok. Host açılmadı.');
  }
  return InternetAddress(choice.address);
}
