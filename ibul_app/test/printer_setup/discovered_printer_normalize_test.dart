import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/desktop_printer_setup_models.dart';
import 'package:ibul_app/models/discovered_printer.dart';
import 'package:ibul_app/models/printer_model.dart';
import 'package:ibul_app/services/discovered_printer_normalize.dart';

void main() {
  group('DiscoveredPrinter normalize', () {
    test('USB bridge printer maps to usb_direct backend', () {
      final discovered = DiscoveredPrinter.fromBridgeMap(<String, dynamic>{
        'id': 'usb:pos58',
        'name': 'POS58 USB',
        'queue': 'POS58_USB',
        'backend': 'usb-direct',
        'vendorId': '0x0416',
        'productId': '0x5011',
        'source': 'bridge',
      });

      expect(discovered.backend, DiscoveredPrinterBackend.usbDirect);
      expect(discovered.source, DiscoveredPrinterSource.bridge);
      expect(discovered.deviceId, 'usb:pos58');
    });

    test('CUPS bridge printer maps to cups backend', () {
      final discovered = DiscoveredPrinter.fromBridgeMap(<String, dynamic>{
        'id': 'cups:Thermal58',
        'name': 'Thermal58',
        'queue': 'Thermal58',
        'backend': 'cups',
      });

      expect(discovered.backend, DiscoveredPrinterBackend.cups);
      expect(discovered.deviceId, 'cups:Thermal58');
    });

    test('Windows printer maps to windows_spooler backend', () {
      final discovered = DiscoveredPrinter.fromBridgeMap(<String, dynamic>{
        'id': 'windows:POS-58',
        'name': 'POS-58',
        'queue': 'POS-58',
        'backend': 'windows-spool',
      });

      expect(discovered.backend, DiscoveredPrinterBackend.windowsSpooler);
    });

    test('saved DB ethernet printer uses saved_registry source and tcp device id', () {
      final model = PrinterModel(
        id: 'db-eth-1',
        restaurantId: 'rest-1',
        name: 'Mutfak Ethernet',
        code: 'ETH1',
        connectionType: PrinterModel.networkConnectionType,
        ipAddress: '192.168.1.100',
        port: 9100,
        deviceIdentifier: 'tcp:192.168.1.100:9100',
        paperWidthMm: 80,
        isActive: true,
        createdAt: DateTime(2026, 6, 1),
      );

      final discovered = DiscoveredPrinter.fromPrinterModel(model);

      expect(discovered.backend, DiscoveredPrinterBackend.ethernetTcp);
      expect(discovered.source, DiscoveredPrinterSource.savedRegistry);
      expect(discovered.deviceId, 'tcp:192.168.1.100:9100');
      expect(discovered.ip, '192.168.1.100');
      expect(discovered.port, 9100);
    });

    test('trims IP and defaults port to 9100', () {
      final endpoint = DiscoveredPrinter.normalizeEthernetEndpoint(
        ipAddress: ' 192.168.1.50 ',
        port: null,
        deviceIdentifier: null,
      );

      expect(endpoint.ip, '192.168.1.50');
      expect(endpoint.port, 9100);
    });

    test('merge deduplicates same tcp ip port from scan and saved registry', () {
      final bridge = DiscoveredPrinter.fromBridgeMap(<String, dynamic>{
        'id': 'tcp:192.168.1.100:9100',
        'name': 'NETUM',
        'backend': 'tcp',
        'host': '192.168.1.100',
        'port': 9100,
        'source': 'bridge',
      });
      final saved = DiscoveredPrinter.fromPrinterModel(
        PrinterModel(
          id: 'db-eth-1',
          restaurantId: 'rest-1',
          name: 'NETUM Kayıtlı',
          code: 'ETH1',
          connectionType: PrinterModel.networkConnectionType,
          ipAddress: '192.168.1.100',
          port: 9100,
          deviceIdentifier: 'tcp:192.168.1.100:9100',
          paperWidthMm: 80,
          isActive: true,
          createdAt: DateTime(2026, 6, 1),
        ),
      );

      final merged = DiscoveredPrinterCatalog.merge(
        bridgePrinters: <DiscoveredPrinter>[bridge],
        savedPrinters: <DiscoveredPrinter>[saved],
      );

      expect(merged, hasLength(1));
      expect(merged.first.source, DiscoveredPrinterSource.bridge);
      expect(merged.first.dbPrinterId, 'db-eth-1');
    });

    test('merge flags IP mismatch for same device id with different configured IP', () {
      final saved = DiscoveredPrinter(
        backend: DiscoveredPrinterBackend.ethernetTcp,
        deviceId: 'tcp:192.168.1.100:9100',
        displayName: 'NETUM Kayıtlı',
        ip: '192.168.1.45',
        port: 9100,
        source: DiscoveredPrinterSource.savedRegistry,
        configuredIp: '192.168.1.45',
        dbPrinterId: 'db-eth-1',
        isStaleSavedMapping: true,
      );
      final bridge = DiscoveredPrinter(
        backend: DiscoveredPrinterBackend.ethernetTcp,
        deviceId: 'tcp:192.168.1.100:9100',
        displayName: 'NETUM',
        ip: '192.168.1.60',
        port: 9100,
        source: DiscoveredPrinterSource.bridge,
        isOnline: true,
      );

      final merged = DiscoveredPrinterCatalog.merge(
        bridgePrinters: <DiscoveredPrinter>[bridge],
        savedPrinters: <DiscoveredPrinter>[saved],
      );

      expect(merged, hasLength(1));
      expect(merged.first.hasIpMismatch, isTrue);
      expect(merged.first.configuredIp, '192.168.1.45');
      expect(merged.first.lastSeenIp, '192.168.1.60');
    });

    test('detects USB and CUPS duplicate candidate', () {
      final printers = <UnifiedPrinterModel>[
        UnifiedPrinterModel.fromBridgeMap(<String, dynamic>{
          'id': 'usb:pos58',
          'name': 'POS58 USB',
          'queue': 'POS58_USB',
          'backend': 'usb-direct',
          'vendorId': '0x0416',
          'productId': '0x5011',
          'source': 'bridge',
        }, os: DesktopPrinterOs.macos),
        UnifiedPrinterModel.fromBridgeMap(<String, dynamic>{
          'id': 'cups:pos58',
          'name': 'POS58 CUPS',
          'queue': 'POS58',
          'backend': 'cups',
          'source': 'bridge',
        }, os: DesktopPrinterOs.macos),
      ];

      expect(
        DiscoveredPrinterCatalog.hasUsbCupsDuplicateConflict(printers),
        isTrue,
      );
    });
  });
}
