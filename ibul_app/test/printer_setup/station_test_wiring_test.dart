import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/desktop_printer_setup_models.dart';
import 'package:ibul_app/models/discovered_printer.dart';
import 'package:ibul_app/services/bridge_print_dispatch_verification.dart';
import 'package:ibul_app/services/restaurant_printer_dispatch_resolver.dart';

void main() {
  group('Station test wiring', () {
    UnifiedPrinterModel stationPrinter({
      required String stationId,
      required String stationName,
    }) {
      return UnifiedPrinterModel.fromBridgeMap(<String, dynamic>{
        'id': 'tcp:192.168.1.20:9100',
        'name': '$stationName Ethernet',
        'queue': '$stationName Ethernet',
        'backend': 'tcp',
        'host': '192.168.1.20',
        'port': 9100,
        'printerRecordId': 'printer-$stationId',
        'isAvailable': true,
        'canPrint': true,
      }, os: DesktopPrinterOs.macos);
    }

    test('ocak station snapshot includes station metadata', () {
      final printer = stationPrinter(stationId: 'ocak', stationName: 'Ocak');
      final resolution = RestaurantPrinterDispatchResolver.fromPrinter(
        printer: printer,
        resolutionSource: 'station_mapping',
        role: PrinterSetupRole.mutfak,
        stationId: 'station-ocak',
        stationName: 'Ocak',
        documentType: 'kitchen_ticket_test',
      );

      expect(resolution.ok, isTrue);
      expect(resolution.stationId, 'station-ocak');
      expect(resolution.stationName, 'Ocak');
      expect(resolution.printerSnapshot['station_id'], 'station-ocak');
      expect(resolution.printerSnapshot['document_type'], 'kitchen_ticket_test');
      expect(resolution.deviceId, 'tcp:192.168.1.20:9100');
    });

    test('adisyon test snapshot uses adisyon role', () {
      final printer = UnifiedPrinterModel.fromBridgeMap(<String, dynamic>{
        'id': 'cups:Adisyon',
        'name': 'Adisyon',
        'queue': 'Adisyon',
        'backend': 'cups',
        'printerRecordId': 'adisyon-1',
        'isAvailable': true,
        'canPrint': true,
      }, os: DesktopPrinterOs.macos);
      final resolution = RestaurantPrinterDispatchResolver.fromPrinter(
        printer: printer,
        resolutionSource: 'role_selection',
        role: PrinterSetupRole.adisyon,
        documentType: 'test_receipt',
      );

      expect(resolution.role, PrinterSetupRole.adisyon);
      expect(resolution.printerSnapshot['role'], 'adisyon');
    });

    test('station printer missing returns hard fail message', () {
      final resolution = RestaurantPrinterDispatchResolver.failure(
        resolutionSource: 'failed',
        errorMessage:
            RestaurantPrinterDispatchResolution.stationMissingPrinterMessage,
        role: PrinterSetupRole.mutfak,
        stationId: 'station-bar',
        stationName: 'Bar',
      );

      expect(resolution.ok, isFalse);
      expect(
        resolution.errorMessage,
        contains('Bu alan için yazıcı seçilmemiş'),
      );
    });

    test('kitchen general fallback warning is explicit', () {
      final warning = BridgePrintDispatchVerification.kitchenGeneralFallbackWarning(
        'Ocak',
      );
      expect(warning, contains('Ocak'));
      expect(warning, contains('Mutfak genel'));
    });

    test('station test payload keeps tcp backend target', () {
      final printer = stationPrinter(stationId: 'firin', stationName: 'Fırın');
      final snapshot = RestaurantPrinterDispatchResolver.buildPrinterSnapshot(
        printer,
        role: PrinterSetupRole.mutfak,
        stationId: 'station-firin',
        stationName: 'Fırın',
        documentType: 'kitchen_ticket_test',
      );

      expect(snapshot['backend'], 'tcp');
      expect(snapshot['host'], '192.168.1.20');
      expect(snapshot['port'], 9100);
      expect(
        snapshot['device_id'],
        DiscoveredPrinter.buildTcpDeviceId('192.168.1.20', 9100),
      );
    });
  });
}
