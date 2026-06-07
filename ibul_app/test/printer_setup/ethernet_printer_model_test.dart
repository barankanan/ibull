// Ethernet / TCP printer model tests.
//
// These verify the Flutter side of the Ethernet printer wiring:
//   * ``ethernetPrinterId`` builds a stable ``tcp:HOST:PORT`` identifier
//   * ``isEthernetConnection`` detects network-saved rows
//   * ``ethernetHost`` / ``ethernetPort`` fall back to the parsed identifier
//   * ``toEthernetBridgePayload`` emits ``backend=tcp`` /
//     ``transportType=ethernet`` so the local bridge bypasses CUPS/USB
//   * USB/CUPS rows are NOT misclassified as Ethernet (regression guard).
//
// Keeping these in a dedicated file lets us run only Ethernet checks via:
//   flutter test test/printer_setup/ethernet_printer_model_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:ibul_app/models/printer_model.dart';

PrinterModel _buildPrinter({
  String? deviceIdentifier,
  String connectionType = 'network',
  String? ipAddress,
  int? port,
  int paperWidthMm = 80,
  bool supportsCut = true,
  List<PrinterRole> assignedRoles = const [PrinterRole.receipt],
}) {
  return PrinterModel(
    id: 'printer-1',
    restaurantId: 'r-1',
    name: 'NETUM Ethernet',
    code: 'eth_test',
    connectionType: connectionType,
    ipAddress: ipAddress,
    port: port,
    deviceIdentifier: deviceIdentifier,
    paperWidthMm: paperWidthMm,
    isActive: true,
    createdAt: DateTime.utc(2025, 1, 1),
    supportsCut: supportsCut,
    charset: PrinterCharset.cp857,
    assignedRoles: assignedRoles,
  );
}

void main() {
  group('PrinterModel.ethernetPrinterId', () {
    test('formats as tcp:host:port', () {
      expect(
        PrinterModel.ethernetPrinterId(host: '192.168.1.100', port: 9100),
        'tcp:192.168.1.100:9100',
      );
    });

    test('default port constant is 9100', () {
      expect(PrinterModel.ethernetDefaultPort, 9100);
    });

    test('bridge backend / transport constants match Python side', () {
      expect(PrinterModel.ethernetBridgeBackend, 'tcp');
      expect(PrinterModel.ethernetBridgeTransport, 'ethernet');
    });
  });

  group('isEthernetConnection', () {
    test('returns true when device_identifier starts with tcp:', () {
      final p = _buildPrinter(
        connectionType: 'network',
        deviceIdentifier: 'tcp:192.168.1.100:9100',
      );
      expect(p.isEthernetConnection, isTrue);
    });

    test('returns true when connection_type=network and ip set', () {
      final p = _buildPrinter(
        connectionType: 'network',
        ipAddress: '192.168.1.100',
        port: 9100,
      );
      expect(p.isEthernetConnection, isTrue);
    });

    test('returns false for loopback (local printer bridge)', () {
      final p = _buildPrinter(
        connectionType: 'local',
        ipAddress: '127.0.0.1',
        port: 3001,
      );
      expect(p.isEthernetConnection, isFalse);
    });

    test('returns false for USB printer', () {
      final p = _buildPrinter(
        connectionType: 'usb',
        deviceIdentifier: 'usb-0416:5011',
      );
      expect(p.isEthernetConnection, isFalse);
    });

    test('returns false for CUPS printer (no IP, no tcp identifier)', () {
      final p = _buildPrinter(
        connectionType: 'local',
        ipAddress: null,
        port: null,
        deviceIdentifier: 'POS-58',
      );
      expect(p.isEthernetConnection, isFalse);
    });
  });

  group('ethernetHost / ethernetPort getters', () {
    test('prefers explicit ipAddress + port', () {
      final p = _buildPrinter(
        ipAddress: '10.0.0.5',
        port: 9100,
      );
      expect(p.ethernetHost, '10.0.0.5');
      expect(p.ethernetPort, 9100);
    });

    test('falls back to parsing tcp:host:port deviceIdentifier', () {
      final p = _buildPrinter(
        deviceIdentifier: 'tcp:192.168.1.100:9100',
        ipAddress: null,
        port: null,
      );
      expect(p.ethernetHost, '192.168.1.100');
      expect(p.ethernetPort, 9100);
    });

    test('defaults to port 9100 when unset', () {
      final p = _buildPrinter(
        ipAddress: '192.168.1.100',
        port: null,
      );
      expect(p.ethernetPort, PrinterModel.ethernetDefaultPort);
    });
  });

  group('toEthernetBridgePayload', () {
    test('carries backend=tcp + transportType=ethernet + host/port', () {
      final p = _buildPrinter(
        deviceIdentifier: 'tcp:192.168.1.100:9100',
        ipAddress: '192.168.1.100',
        port: 9100,
        paperWidthMm: 80,
        supportsCut: true,
      );
      final payload = p.toEthernetBridgePayload(
        roleOverride: 'adisyon',
        documentType: 'receipt',
      );
      expect(payload['backend'], 'tcp');
      expect(payload['transportType'], 'ethernet');
      expect(payload['transport_type'], 'ethernet');
      expect(payload['connection_type'], 'network');
      expect(payload['host'], '192.168.1.100');
      expect(payload['ip_address'], '192.168.1.100');
      expect(payload['port'], 9100);
      expect(payload['paper_width_mm'], 80);
      expect(payload['auto_cut'], isTrue);
      expect(payload['printer_role'], 'adisyon');
      expect(payload['document_type'], 'receipt');
      expect(payload['id'], 'tcp:192.168.1.100:9100');
      expect(payload['printer_id'], 'tcp:192.168.1.100:9100');
    });
  });
}
