import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/lan_center_discovery.dart';

LanCenterRecord _center({
  String host = '192.168.10.158',
  String restaurantId = 'rest-1',
  String machineId = 'machine-a',
  String fingerprint = 'aabb',
}) {
  return LanCenterRecord(
    host: host,
    port: lanOrderPort,
    restaurantId: restaurantId,
    machineId: machineId,
    fingerprint: fingerprint,
  );
}

void main() {
  test('mdns alone cannot select an unpaired center', () {
    final decision = chooseLanCenter(
      restaurantId: 'rest-1',
      found: <LanCenterRecord>[_center()],
      fromQr: false,
    );
    expect(decision.choice, LanCenterChoice.needsQr);
    expect(decision.record, isNull);
  });

  test('qr selects one center and rejects loopback and another restaurant', () {
    final record = _center();
    final qr = encodeLanQr(record);
    expect(decodeLanQr(qr)!.host, '192.168.10.158');
    expect(decodeLanQr('ibul-lan://pair?v=1&host=127.0.0.1&port=$lanOrderPort&restaurant=rest-1&machine=machine-a&fingerprint=aabb'), isNull);
    final selected = chooseLanCenter(
      restaurantId: 'rest-1',
      found: <LanCenterRecord>[decodeLanQr(qr)!],
      fromQr: true,
    );
    expect(selected.choice, LanCenterChoice.selected);
    final other = chooseLanCenter(
      restaurantId: 'rest-1',
      found: <LanCenterRecord>[_center(restaurantId: 'rest-2')],
      fromQr: true,
    );
    expect(other.choice, LanCenterChoice.wrongRestaurant);
  });

  test('saved identity follows a new address and rejects a fake fingerprint', () {
    const trusted = SavedLanCenter(
      restaurantId: 'rest-1',
      machineId: 'machine-a',
      fingerprint: 'AA:BB',
    );
    final moved = chooseLanCenter(
      restaurantId: 'rest-1',
      found: <LanCenterRecord>[_center(host: '192.168.10.40', fingerprint: 'aabb')],
      trusted: trusted,
      fromQr: false,
    );
    expect(moved.choice, LanCenterChoice.selected);
    expect(moved.record!.host, '192.168.10.40');
    final fake = chooseLanCenter(
      restaurantId: 'rest-1',
      found: <LanCenterRecord>[_center(fingerprint: 'cccc')],
      trusted: trusted,
      fromQr: false,
    );
    expect(fake.choice, LanCenterChoice.fakeCenter);
  });

  test('two matching centers are not chosen', () {
    final decision = chooseLanCenter(
      restaurantId: 'rest-1',
      found: <LanCenterRecord>[
        _center(host: '192.168.10.158'),
        _center(host: '192.168.10.159'),
      ],
      trusted: const SavedLanCenter(
        restaurantId: 'rest-1',
        machineId: 'machine-a',
        fingerprint: 'aabb',
      ),
      fromQr: false,
    );
    expect(decision.choice, LanCenterChoice.ambiguous);
  });

  test('lookup text and web message stay explicit', () {
    final parsed = parseLanLookup(
      'can be reached at Mac.local.:18772\n'
      'svc=ibul-lan rid=rest-1 mid=machine-a fp=aabb',
    );
    expect(parsed!.port, lanOrderPort);
    expect(parsed.restaurantId, 'rest-1');
    final announced = chooseLanCenter(
      restaurantId: 'rest-1',
      found: <LanCenterRecord>[
        parseLanLookup(
          'IBUL-selftest._ibul-lan._tcp.local. can be reached at Baran-MacBook-Air.local.:18772\n'
          'svc=ibul-lan rid=rest-1 mid=machine-a fp=aabb',
        )!,
      ],
      trusted: const SavedLanCenter(
        restaurantId: 'rest-1',
        machineId: 'machine-a',
        fingerprint: 'aabb',
      ),
      fromQr: false,
    );
    expect(announced.choice, LanCenterChoice.selected);
    expect(announced.record!.host, 'Baran-MacBook-Air.local');
    expect(
      lanDiscoveryUnavailableMessage(isWeb: true, operatingSystem: 'macos'),
      contains('Tarayıcı'),
    );
  });
}
