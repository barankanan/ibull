import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/desktop_print_hub.dart';
import 'package:ibul_app/services/print_service_start_gate.dart';
import 'package:ibul_app/services/printer_link_status.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_center_auto_start.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The hub is the one place the saved printers are asked. These tests drive
/// the hub's own publishing step with a fake printer.
void main() {
  late DesktopPrintHub hub;
  late List<String> asked;
  late bool printerAnswers;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // Never contacted: the publishing step under test makes no cloud call.
    await Supabase.initialize(url: 'http://127.0.0.1:9', anonKey: 'test-anon');
  });

  setUp(() {
    PhysicalPrintGate.resetForTests();
    PrintServiceStartGate.resetForTests();
    RestaurantCenterAutoStart.resetForTests();
    asked = <String>[];
    printerAnswers = true;
    hub = DesktopPrintHub()
      ..printerProbe = (host, port) async {
        asked.add('$host:$port');
        return printerAnswers;
      }
      ..savedPrinterTargetsForTest = const <({String host, int port})>[
        (host: '192.168.10.100', port: 9100),
      ];
  });

  tearDown(() {
    hub.dispose();
    PhysicalPrintGate.resetForTests();
    PrintServiceStartGate.resetForTests();
    RestaurantCenterAutoStart.resetForTests();
  });

  test('a health check asks the SAVED printer and publishes its answer for '
      'every screen, without the Garson page', () async {
    PhysicalPrintGate.observe(true);
    await hub.publishReadiness(online: true);
    expect(asked, <String>['192.168.10.100:9100']);
    expect(PhysicalPrintGate.published!.printerReachable, isTrue);
    expect(PhysicalPrintGate.published!.label, 'Yazıcı servisi açık');
  });

  test('a saved printer that does not answer is published as unreachable and '
      'the chip is told', () async {
    PhysicalPrintGate.observe(true);
    await hub.publishReadiness(online: true);
    var notified = 0;
    hub.addListener(() => notified += 1);
    printerAnswers = false;
    hub.savedPrinterTargetsForTest = const <({String host, int port})>[
      (host: '192.168.10.200', port: 9100),
    ];
    await hub.publishReadiness(online: true, shownBefore: 'Yazıcı Hazır');
    expect(PhysicalPrintGate.published!.printerReachable, isFalse);
    expect(PhysicalPrintGate.published!.label, 'Yazıcıya ulaşılamıyor');
    expect(notified, 1);
  });

  test('the printer is asked at a slow pace, not on every health check',
      () async {
    PhysicalPrintGate.observe(true);
    await hub.publishReadiness(online: true);
    await hub.publishReadiness(online: true);
    await hub.publishReadiness(online: true);
    expect(asked, hasLength(1));
  });

  test('a bridge that does not answer is a connection fault, the printer is '
      'not asked and nothing is restarted while the center is closed',
      () async {
    PhysicalPrintGate.observe(true);
    var revives = 0;
    RestaurantCenterAutoStart.reviveBridge = () async {
      revives += 1;
      return true;
    };
    await hub.publishReadiness(online: false);
    expect(asked, isEmpty);
    expect(PhysicalPrintGate.published!.label, 'Yazıcı köprüsüne ulaşılamıyor');
    expect(PhysicalPrintGate.published!.label, isNot(contains('kapalı')));
    expect(revives, 0);
  });

  test('service switched off by the operator stays "kapalı" even when the '
      'bridge is gone', () {
    final status = describeCanonicalPrinterStatus(
      bridgeUp: false,
      serviceEnabled: false,
    );
    expect(status.label, 'Yazıcı servisi kapalı');
  });
}
