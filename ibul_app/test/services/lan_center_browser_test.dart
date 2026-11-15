import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/lan_center_browser.dart';
import 'package:ibul_app/services/restaurant_offline/lan_center_discovery.dart';

void main() {
  test('platform records ignore a service that is not ibul-lan', () {
    final records = recordsFromDiscoveryMaps(<Map<String, Object?>>[
      <String, Object?>{
        'host': '192.168.10.158',
        'port': 18772,
        'restaurant_id': 'rest-1',
        'machine_id': 'machine-a',
        'fingerprint': 'aabb',
        'service': 'ibul-lan',
      },
      <String, Object?>{
        'host': '192.168.10.50',
        'port': 18772,
        'service': 'other',
      },
    ]);
    expect(records, hasLength(1));
    expect(records.single.restaurantId, 'rest-1');
  });

  test('browse text yields the instance name', () {
    const sample = '''
Timestamp     A/R Flags if Domain Service Type Instance Name
22:47:39.032  Add        2   1 local. _ibul-lan._tcp. IBUL-selftest
''';
    expect(instanceNamesFromBrowse(sample), <String>['IBUL-selftest']);
  });

  test('flutter discovery finds the live Bonjour record on this Mac', () async {
    final process = await Process.start('dns-sd', <String>[
      '-R',
      'IBUL-flutter',
      '_ibul-lan._tcp',
      'local',
      '18772',
      'svc=ibul-lan',
      'rid=rest-1',
      'mid=machine-a',
      'fp=aabb',
    ]);
    addTearDown(process.kill);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    final found = await browseWithDnsSd(budget: const Duration(seconds: 2));
    final decision = chooseLanCenter(
      restaurantId: 'rest-1',
      found: found,
      trusted: const SavedLanCenter(
        restaurantId: 'rest-1',
        machineId: 'machine-a',
        fingerprint: 'aabb',
      ),
      fromQr: false,
    );
    expect(decision.choice, LanCenterChoice.selected);
    expect(decision.record!.port, lanOrderPort);
  });
}
