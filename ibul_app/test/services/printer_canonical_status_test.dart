import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/printer_link_status.dart';

void main() {
  tearDown(PhysicalPrintGate.resetForTests);

  test('bridge up, printer up, permission off is service closed', () {
    final status = describeCanonicalPrinterStatus(
      bridgeUp: true,
      printerReachable: true,
      serviceEnabled: false,
      stationConsumerEnabled: false,
    );
    expect(status.label, 'Yazıcı servisi kapalı');
    expect(status.label.contains('Yanıt yok'), isFalse);
    expect(status.label.contains('arızalı'), isFalse);
    expect(status.detail, contains('tüketicisi kapalı'));
  });

  test('permission on and printer down is unreachable, not service off', () {
    final status = describeCanonicalPrinterStatus(
      bridgeUp: true,
      printerReachable: false,
      serviceEnabled: true,
      stationConsumerEnabled: true,
    );
    expect(status.label, 'Yazıcıya ulaşılamıyor');
  });

  test('unknown permission stays closed', () {
    final status = describeCanonicalPrinterStatus(
      bridgeUp: true,
      printerReachable: true,
      serviceEnabled: null,
    );
    expect(status.label, 'Yazıcı servisi durumu bilinmiyor');
    expect(PhysicalPrintGate.allowsSend, isFalse);
  });

  test('health enabled flag is not the station consumer flag', () {
    expect(
      printSystemEnabledFromHealth(<String, dynamic>{
        'print_station': <String, dynamic>{
          'enabled': false,
          'print_system_enabled': true,
        },
      }),
      isTrue,
    );
    expect(
      printStationConsumerEnabledFromHealth(<String, dynamic>{
        'print_station': <String, dynamic>{'enabled': false},
      }),
      isFalse,
    );
    expect(
      printSystemEnabledFromHealth(<String, dynamic>{
        'print_station': <String, dynamic>{'enabled': true},
      }),
      isNull,
    );
  });

  test('jobs created while closed are not auto dispatched after open', () {
    final closedAt = DateTime.utc(2026, 11, 12, 10);
    final openedAt = DateTime.utc(2026, 11, 12, 10, 5);
    PhysicalPrintGate.observe(false, now: closedAt);
    PhysicalPrintGate.observe(true, now: openedAt);
    expect(
      PhysicalPrintGate.shouldAutoDispatch(
        createdAt: DateTime.utc(2026, 11, 12, 10, 1),
      ),
      isFalse,
    );
    expect(
      PhysicalPrintGate.shouldAutoDispatch(
        createdAt: DateTime.utc(2026, 11, 12, 10, 6),
      ),
      isTrue,
    );
    expect(PhysicalPrintGate.shouldAutoDispatch(createdAt: null), isFalse);
  });

  test('later health keeps the last printer probe on every screen', () {
    PhysicalPrintGate.publish(
      bridgeUp: true,
      printerReachable: false,
      serviceEnabled: true,
      probedPrinter: true,
    );
    PhysicalPrintGate.publish(
      bridgeUp: true,
      serviceEnabled: true,
      stationConsumerEnabled: false,
      probedPrinter: false,
    );
    expect(PhysicalPrintGate.published?.printerReachable, isFalse);
    expect(PhysicalPrintGate.published?.label, 'Yazıcıya ulaşılamıyor');
    expect(PhysicalPrintGate.published?.stationConsumerEnabled, isFalse);
  });

  test('cloud on does not reopen a local off switch', () {
    PhysicalPrintGate.observe(false);
    PhysicalPrintGate.noteAuthoritative(true);
    expect(PhysicalPrintGate.allowsSend, isFalse);
    PhysicalPrintGate.noteAuthoritative(false);
    expect(PhysicalPrintGate.cloudEnabled, isFalse);
  });
}
