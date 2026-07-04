import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/discovered_printer.dart';
import 'package:ibul_app/models/printer_model.dart';
import 'package:ibul_app/services/restaurant_printer_dispatch_resolver.dart';

void main() {
  group('Ethernet IP drift', () {
    test('configured_ip != last_seen_ip => hasDrift true', () {
      final drift = EthernetIpDriftInfo.fromLegacyMap(<String, dynamic>{
        'printerRecordId': 'printer-1',
        'name': 'Mutfak Ethernet',
        'configuredIp': '192.168.1.45',
        'lastSeenIp': '192.168.1.60',
        'port': 9100,
        'device_identifier': 'tcp:192.168.1.45:9100',
      });

      expect(drift, isNotNull);
      expect(drift!.hasDrift, isTrue);
      expect(drift.title, contains('kayıtlı IP'));
      expect(drift.detail, contains('192.168.1.45'));
      expect(drift.detail, contains('192.168.1.60'));
    });

    test('same configured and last seen => no drift', () {
      final drift = EthernetIpDriftInfo.fromLegacyMap(<String, dynamic>{
        'printerRecordId': 'printer-1',
        'configuredIp': '192.168.1.45',
        'lastSeenIp': '192.168.1.45',
        'port': 9100,
      });

      expect(drift, isNull);
    });

    test('update ip builds tcp device id with default port 9100', () {
      const ip = '192.168.1.75';
      const port = PrinterModel.ethernetDefaultPort;
      final deviceId = DiscoveredPrinter.buildTcpDeviceId(ip, port);

      expect(deviceId, 'tcp:192.168.1.75:9100');
    });

    test('device identifier sync uses tcp:newIp:port format', () {
      final deviceId = PrinterModel.ethernetPrinterId(
        host: '192.168.1.75',
        port: 9100,
      );
      expect(deviceId, 'tcp:192.168.1.75:9100');
    });
  });
}
