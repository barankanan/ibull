import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/printer_repository.dart';
import 'package:ibul_app/services/restaurant_offline/lan_staff_probe.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_connectivity_service.dart';
import 'package:ibul_app/services/staff_login_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Measured 2026-11-24 with the WAN cut: a LAN order was recorded ~45 s late and
// its kitchen ticket ~43 s late, because (1) the staff-authority cloud call
// ran before the save without a budget and (2) every one of the ~10 printer
// cloud reads waited its own 4 s.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    RestaurantCloudGate.resetForTests();
  });
  tearDown(RestaurantCloudGate.resetForTests);

  test('hanging staff cloud call ends as unreachable inside its budget', () async {
    final probe = lanStaffProbe(
      (_) => Completer<Map<String, dynamic>?>().future,
      restaurantId: 'r1',
    );
    final watch = Stopwatch()..start();
    final result = await probe('staff-1');
    watch.stop();
    expect(result.kind, StaffProbeKind.unreachable);
    expect(
      watch.elapsed,
      lessThan(lanStaffProbeBudget + const Duration(seconds: 2)),
    );
  });

  test('cloud marked down: a hanging printer read falls back at once', () async {
    RestaurantCloudGate.noteFailure();
    final watch = Stopwatch()..start();
    final printer = await PrinterRepository.printerByIdFrom(
      printerId: 'p1',
      read: () => Completer<dynamic>().future,
    );
    watch.stop();
    expect(printer, isNull); // no last-good copy stored in this test
    expect(watch.elapsed, lessThan(const Duration(seconds: 1)));
  });

  test('a printer read that answers clears the down mark', () async {
    RestaurantCloudGate.noteFailure();
    expect(RestaurantCloudGate.shouldFailFast, isTrue);
    await PrinterRepository.printerByIdFrom(
      printerId: 'p1',
      read: () async => <String, dynamic>{
        'id': 'p1',
        'restaurant_id': 'r1',
        'name': 'aa',
        'ip_address': '192.168.10.100',
        'port': 9100,
      },
      timeout: const Duration(seconds: 2),
    );
    expect(RestaurantCloudGate.shouldFailFast, isFalse);
  });

  test('a read that times out marks the cloud down for later reads', () async {
    expect(RestaurantCloudGate.shouldFailFast, isFalse);
    await PrinterRepository.printerByIdFrom(
      printerId: 'p1',
      read: () => Completer<dynamic>().future,
      timeout: const Duration(milliseconds: 50),
    );
    expect(RestaurantCloudGate.shouldFailFast, isTrue);
  });
}
