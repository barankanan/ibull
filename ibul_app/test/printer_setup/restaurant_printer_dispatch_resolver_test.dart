import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/desktop_printer_setup_models.dart';
import 'package:ibul_app/models/discovered_printer.dart';
import 'package:ibul_app/models/printer_model.dart';
import 'package:ibul_app/services/restaurant_printer_dispatch_resolver.dart';

void main() {
  group('RestaurantPrinterDispatchResolver', () {
    UnifiedPrinterModel ethernetPrinter({
      required String recordId,
      required String host,
      int port = 9100,
    }) {
      return UnifiedPrinterModel.fromBridgeMap(<String, dynamic>{
        'id': recordId,
        'name': 'Mutfak Ethernet',
        'queue': 'Mutfak Ethernet',
        'backend': 'tcp',
        'host': host,
        'ip_address': host,
        'port': port,
        'device_identifier': DiscoveredPrinter.buildTcpDeviceId(host, port),
        'connection_type': PrinterModel.networkConnectionType,
        'printerRecordId': recordId,
        'isAvailable': true,
        'canPrint': true,
      }, os: DesktopPrinterOs.macos);
    }

    UnifiedPrinterModel cupsPrinter({required String recordId}) {
      return UnifiedPrinterModel.fromBridgeMap(<String, dynamic>{
        'id': recordId,
        'name': 'Adisyon CUPS',
        'queue': 'Thermal58',
        'backend': 'cups',
        'printerRecordId': recordId,
        'isAvailable': true,
        'canPrint': true,
      }, os: DesktopPrinterOs.macos);
    }

    test('adisyon role snapshot includes backend and queue', () {
      final printer = cupsPrinter(recordId: 'adisyon-1');
      final resolution = RestaurantPrinterDispatchResolver.fromPrinter(
        printer: printer,
        resolutionSource: 'role_selection',
        role: PrinterSetupRole.adisyon,
        documentType: 'test_receipt',
      );

      expect(resolution.ok, isTrue);
      expect(resolution.backend, DesktopPrinterBackend.cups);
      expect(resolution.queueName, 'Thermal58');
      expect(resolution.printerSnapshot['document_type'], 'test_receipt');
      expect(resolution.printerSnapshot['role'], 'adisyon');
    });

    test('kitchen_general role snapshot includes tcp target', () {
      final printer = ethernetPrinter(recordId: 'kitchen-1', host: '192.168.1.10');
      final resolution = RestaurantPrinterDispatchResolver.fromPrinter(
        printer: printer,
        resolutionSource: 'kitchen_db_mapping',
        role: PrinterSetupRole.mutfak,
        documentType: 'kitchen_ticket_test',
      );

      expect(resolution.ok, isTrue);
      expect(resolution.backend, DesktopPrinterBackend.tcp);
      expect(resolution.ip, '192.168.1.10');
      expect(resolution.port, 9100);
      expect(resolution.deviceId, 'tcp:192.168.1.10:9100');
    });

    test('station printer snapshot keeps station metadata', () {
      final printer = ethernetPrinter(recordId: 'ocak-1', host: '192.168.1.20');
      final resolution = RestaurantPrinterDispatchResolver.fromPrinter(
        printer: printer,
        resolutionSource: 'station_mapping',
        role: PrinterSetupRole.mutfak,
        stationId: 'station-ocak',
        stationName: 'Ocak',
        documentType: 'kitchen_ticket_test',
      );

      expect(resolution.stationId, 'station-ocak');
      expect(resolution.stationName, 'Ocak');
      expect(resolution.printerSnapshot['station_id'], 'station-ocak');
      expect(resolution.printerSnapshot['station_name'], 'Ocak');
    });

    test('missing role printer returns hard fail message', () {
      final resolution = RestaurantPrinterDispatchResolver.failure(
        resolutionSource: 'failed',
        errorMessage:
            RestaurantPrinterDispatchResolution.missingRolePrinterMessage,
        role: PrinterSetupRole.adisyon,
      );

      expect(resolution.ok, isFalse);
      expect(
        resolution.errorMessage,
        contains('Bu rol için yazıcı seçilmemiş'),
      );
    });

    test('backend ethernet requires host', () {
      final printer = UnifiedPrinterModel.fromBridgeMap(<String, dynamic>{
        'id': 'eth-empty',
        'name': 'Broken Ethernet',
        'queue': 'Broken Ethernet',
        'backend': 'tcp',
        'printerRecordId': 'eth-empty',
        'isAvailable': true,
        'canPrint': true,
      }, os: DesktopPrinterOs.macos);
      final resolution = RestaurantPrinterDispatchResolver.fromPrinter(
        printer: printer,
        resolutionSource: 'role_selection',
        role: PrinterSetupRole.mutfak,
      );

      expect(resolution.ok, isFalse);
      expect(
        resolution.errorMessage,
        RestaurantPrinterDispatchResolution.tcpUnreachableMessage,
      );
    });

    test('backend cups requires queue_name', () {
      final printer = UnifiedPrinterModel.fromBridgeMap(<String, dynamic>{
        'id': 'cups-empty',
        'name': 'Broken CUPS',
        'queue': '',
        'backend': 'cups',
        'printerRecordId': 'cups-empty',
        'isAvailable': true,
        'canPrint': true,
      }, os: DesktopPrinterOs.macos);
      final resolution = RestaurantPrinterDispatchResolver.fromPrinter(
        printer: printer,
        resolutionSource: 'role_selection',
        role: PrinterSetupRole.adisyon,
      );

      expect(resolution.ok, isFalse);
      expect(resolution.errorMessage, contains('kuyruk adı eksik'));
    });

    test('backend mismatch message is defined for tests', () {
      expect(
        RestaurantPrinterDispatchResolution.backendMismatchMessage,
        contains('farklı bağlantı yoluna'),
      );
    });
  });
}
