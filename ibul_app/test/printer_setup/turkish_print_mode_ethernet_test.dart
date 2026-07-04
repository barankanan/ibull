import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/desktop_printer_setup_models.dart';
import 'package:ibul_app/models/discovered_printer.dart';
import 'package:ibul_app/models/printer_model.dart';

UnifiedPrinterModel _ethernetPrinter({
  String? ip,
  String? deviceIdentifier,
  int? port,
}) {
  final model = PrinterModel.fromMap(<String, dynamic>{
    'id': 'db-eth-1',
    'restaurant_id': 'rest-1',
    'name': 'yenisi 80mm',
    'code': 'ETH1',
    'connection_type': PrinterModel.networkConnectionType,
    'ip_address': ip,
    'port': port,
    'device_identifier': deviceIdentifier,
    'paper_width_mm': 80,
    'printer_profile_id': 'pos80',
    'is_active': true,
    'created_at': DateTime(2026, 6, 1).toIso8601String(),
  });
  final unified = UnifiedPrinterModel.fromBridgeMap(
    <String, dynamic>{
      ...model.toEthernetBridgePayload(),
      'printer_record_id': model.id,
      'printerRecordId': model.id,
    },
    os: DesktopPrinterOs.macos,
  );
  return unified;
}

void main() {
  group('Turkish print mode Ethernet IP parse', () {
    test('ip boş, device_identifier=tcp:192.168.10.100:9100 → IP parse edilir', () {
      final endpoint = DiscoveredPrinter.normalizeEthernetEndpoint(
        ipAddress: null,
        port: null,
        deviceIdentifier: 'tcp:192.168.10.100:9100',
      );
      expect(endpoint.ip, '192.168.10.100');
      expect(endpoint.port, 9100);
    });

    test('port boş → 9100 default', () {
      final endpoint = DiscoveredPrinter.normalizeEthernetEndpoint(
        ipAddress: '192.168.10.100',
        port: null,
        deviceIdentifier: 'tcp:192.168.10.100',
      );
      expect(endpoint.port, 9100);
    });

    test('device id yok → endpoint ip boş', () {
      final endpoint = DiscoveredPrinter.normalizeEthernetEndpoint(
        ipAddress: null,
        port: null,
        deviceIdentifier: null,
      );
      expect(endpoint.ip, isEmpty);
    });

    test('unified printer endpoint resolves from device_identifier only', () {
      final printer = _ethernetPrinter(
        ip: '',
        deviceIdentifier: 'tcp:192.168.10.100:9100',
      );
      final endpoint = DiscoveredPrinter.endpointFromUnifiedPrinter(printer);
      expect(endpoint.ip, '192.168.10.100');
      expect(endpoint.port, 9100);
      expect(isAssignableRolePrinter(printer), isTrue);
    });

    test('queue_name içinde tcp parse (device id fallback)', () {
      final endpoint = DiscoveredPrinter.normalizeEthernetEndpoint(
        ipAddress: null,
        port: null,
        deviceIdentifier: 'tcp:10.0.0.5:9100',
      );
      expect(endpoint.ip, '10.0.0.5');
      expect(endpoint.port, 9100);
    });
  });
}
