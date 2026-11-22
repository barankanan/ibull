import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/printer_center/printer_registry_status.dart';
import 'package:ibul_app/models/printer_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

PrinterModel _printer(String id, String ip, {String connection = 'network'}) =>
    PrinterModel.fromMap(<String, dynamic>{
      'id': id,
      'restaurant_id': 'rest-1',
      'name': 'Yazıcı $id',
      'code': 'c-$id',
      'connection_type': connection,
      'ip_address': connection == 'network' ? ip : null,
      'port': 9100,
      'device_identifier': connection == 'network' ? 'tcp:$ip:9100' : 'usb:$id',
      'is_active': true,
      'created_at': '2026-11-20T10:00:00Z',
    });

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  final ocak = _printer('p1', '192.168.10.100');
  final firin = _printer('p2', '192.168.10.101');

  group('registration and reachability are separate', () {
    test('a printer that does not answer is still registered', () async {
      final up = <String, bool>{'192.168.10.100': true, '192.168.10.101': false};
      final monitor = PrinterReachabilityMonitor(
        restaurantId: 'rest-1',
        retryDelay: Duration.zero,
        probe: (host, port) async => up[host],
      );
      await monitor.checkNow(<PrinterModel>[ocak, firin]);
      expect(monitor.statusOf('p1').label, 'Kayıtlı · bağlı');
      expect(monitor.statusOf('p2').label, 'Kayıtlı fakat ulaşılamıyor');
      // Both are still in the summary as registered.
      final summary = buildPrinterCenterSummary(
        printers: <PrinterModel>[ocak, firin],
        statuses: monitor.statuses,
        stationNamesById: const <String, String>{'s1': 'Ocak', 's2': 'Fırın'},
        assignedStationIds: const <String>{'s1', 's2'},
      );
      expect(summary.registered, 2);
      expect(summary.connected, 1);
      expect(summary.unreachableNames, <String>['Yazıcı p2']);
      monitor.dispose();
    });

    test('a printer that comes back is used again without being re-added', () async {
      var on = false;
      final monitor = PrinterReachabilityMonitor(
        restaurantId: 'rest-1',
        retryDelay: Duration.zero,
        probe: (host, port) async => on,
      );
      await monitor.checkNow(<PrinterModel>[ocak]);
      expect(monitor.statusOf('p1').link, RegisteredPrinterLink.unreachable);
      on = true; // switched back on
      await monitor.checkNow(<PrinterModel>[ocak]);
      expect(monitor.statusOf('p1').link, RegisteredPrinterLink.reachable);
      expect(monitor.statusOf('p1').lastReachableAt, isNotNull);
      monitor.dispose();
    });

    test('when the print service cannot be asked nothing is claimed', () async {
      final monitor = PrinterReachabilityMonitor(
        restaurantId: 'rest-1',
        retryDelay: Duration.zero,
        probe: (host, port) async => null,
      );
      await monitor.checkNow(<PrinterModel>[ocak]);
      expect(monitor.statusOf('p1').link, RegisteredPrinterLink.unknown);
      expect(monitor.statusOf('p1').label, 'Kayıtlı');
      monitor.dispose();
    });

    test('a failing probe does not throw and does not mark unreachable', () async {
      final monitor = PrinterReachabilityMonitor(
        restaurantId: 'rest-1',
        retryDelay: Duration.zero,
        probe: (host, port) async => throw StateError('bridge down'),
      );
      await monitor.checkNow(<PrinterModel>[ocak]);
      expect(monitor.statusOf('p1').link, RegisteredPrinterLink.unknown);
      monitor.dispose();
    });

    test('a USB / system queue printer is not probed', () async {
      var probes = 0;
      final monitor = PrinterReachabilityMonitor(
        restaurantId: 'rest-1',
        retryDelay: Duration.zero,
        probe: (host, port) async {
          probes++;
          return true;
        },
      );
      await monitor.checkNow(<PrinterModel>[_printer('u1', '', connection: 'usb')]);
      expect(probes, 0);
      expect(monitor.statusOf('u1').link, RegisteredPrinterLink.notProbed);
      monitor.dispose();
    });

    test('the last time it answered survives an app restart', () async {
      final at = DateTime.utc(2026, 11, 23, 9, 30);
      final first = PrinterReachabilityMonitor(
        restaurantId: 'rest-1',
        retryDelay: Duration.zero,
        probe: (host, port) async => true,
        clock: () => at,
      );
      await first.checkNow(<PrinterModel>[ocak]);
      first.dispose();

      final second = PrinterReachabilityMonitor(
        restaurantId: 'rest-1',
        retryDelay: Duration.zero,
        probe: (host, port) async => false, // off after the restart
      );
      await second.checkNow(<PrinterModel>[ocak]);
      expect(second.statusOf('p1').link, RegisteredPrinterLink.unreachable);
      expect(second.statusOf('p1').lastReachableAt, at);
      second.dispose();
    });
  });

  test('one failed attempt on a quiet network is not shown as unreachable', () async {
    var attempts = 0;
    final monitor = PrinterReachabilityMonitor(
      restaurantId: 'rest-1',
      retryDelay: Duration.zero,
      probe: (host, port) async => ++attempts > 1,
    );
    await monitor.checkNow(<PrinterModel>[ocak]);
    expect(attempts, 2);
    expect(monitor.statusOf('p1').link, RegisteredPrinterLink.reachable);
    monitor.dispose();
  });

  group('ready to print', () {
    const reachable = RegisteredPrinterStatus(link: RegisteredPrinterLink.reachable);

    test('needs the service open, the printer switched on and an answer', () {
      expect(reachable.readyToPrint(serviceOpen: true, printerActive: true), isTrue);
      expect(reachable.readyToPrint(serviceOpen: false, printerActive: true), isFalse);
      expect(reachable.readyToPrint(serviceOpen: true, printerActive: false), isFalse);
    });

    test('an unchecked or unreachable printer is never called ready', () {
      for (final link in <RegisteredPrinterLink>[
        RegisteredPrinterLink.unknown,
        RegisteredPrinterLink.checking,
        RegisteredPrinterLink.unreachable,
        RegisteredPrinterLink.notProbed,
      ]) {
        expect(
          RegisteredPrinterStatus(link: link)
              .readyToPrint(serviceOpen: true, printerActive: true),
          isFalse,
          reason: link.name,
        );
      }
    });
  });

  group('summary', () {
    test('names the stations that have no printer', () {
      final summary = buildPrinterCenterSummary(
        printers: <PrinterModel>[ocak],
        statuses: const <String, RegisteredPrinterStatus>{},
        stationNamesById: const <String, String>{'s1': 'Ocak', 's2': 'Fırın'},
        assignedStationIds: const <String>{'s1'},
      );
      expect(summary.connectedLabel, 'Kontrol edilmedi');
      expect(summary.stationLabel, '1 / 2 alan eşleşti · eşleşmeyen: Fırın');
      expect(summary.unreachableLabel, 'Yok');
    });

    test('with no printers says so instead of counting', () {
      final summary = buildPrinterCenterSummary(
        printers: const <PrinterModel>[],
        statuses: const <String, RegisteredPrinterStatus>{},
        stationNamesById: const <String, String>{},
        assignedStationIds: const <String>{},
      );
      expect(summary.registeredLabel, 'Yazıcı eklenmedi');
      expect(summary.stationLabel, 'Alan tanımlı değil');
    });

    test('the advice for an unreachable printer never says to add it again', () {
      expect(unreachablePrinterAdvice, contains('yeniden eklemeniz gerekmez'));
      expect(unreachablePrinterAdvice, contains('DHCP rezervasyonu'));
    });
  });
}
