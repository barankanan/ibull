import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/desktop_printer_setup_models.dart';
import 'package:ibul_app/services/bridge_print_dispatch_verification.dart';
import 'package:ibul_app/services/restaurant_printer_dispatch_resolver.dart';

void main() {
  group('Print job completion hardening', () {
    UnifiedPrinterModel tcpPrinter() {
      return UnifiedPrinterModel.fromBridgeMap(<String, dynamic>{
        'id': 'tcp:192.168.1.10:9100',
        'name': 'Kitchen Ethernet',
        'queue': 'Kitchen Ethernet',
        'backend': 'tcp',
        'host': '192.168.1.10',
        'port': 9100,
        'printerRecordId': 'kitchen-eth',
        'isAvailable': true,
        'canPrint': true,
      }, os: DesktopPrinterOs.macos);
    }

    UnifiedPrinterModel cupsPrinter() {
      return UnifiedPrinterModel.fromBridgeMap(<String, dynamic>{
        'id': 'cups:Thermal58',
        'name': 'Thermal58',
        'queue': 'Thermal58',
        'backend': 'cups',
        'printerRecordId': 'cups-1',
        'isAvailable': true,
        'canPrint': true,
      }, os: DesktopPrinterOs.macos);
    }

    test('ok=true + used_fallback=true is not job completed', () {
      final verification = BridgePrintDispatchVerification.verify(
        response: <String, dynamic>{
          'ok': true,
          'used_fallback': true,
          'actual_backend': 'cups',
          'selected_backend': 'tcp',
        },
        printer: tcpPrinter(),
      );

      expect(verification.ok, isFalse);
      expect(verification.countsAsJobCompleted, isFalse);
      expect(verification.usedFallback, isTrue);
    });

    test('backend mismatch fails completion', () {
      final verification = BridgePrintDispatchVerification.verify(
        response: <String, dynamic>{
          'ok': true,
          'actual_backend': 'cups',
          'selected_backend': 'tcp',
          'bytes_sent': 120,
        },
        printer: tcpPrinter(),
      );

      expect(verification.ok, isFalse);
      expect(verification.backendMismatch, isTrue);
    });

    test('ethernet ok=true + bytes_sent>0 completes', () {
      final verification = BridgePrintDispatchVerification.verify(
        response: <String, dynamic>{
          'ok': true,
          'actual_backend': 'tcp',
          'bytes_sent': 256,
          'physical_confirmation': true,
        },
        printer: tcpPrinter(),
      );

      expect(verification.ok, isTrue);
      expect(verification.countsAsJobCompleted, isTrue);
    });

    test('bridge offline maps to net error', () {
      final verification = BridgePrintDispatchVerification.verify(
        response: <String, dynamic>{
          'ok': false,
          'error_code': 'bridge_not_running',
        },
        printer: tcpPrinter(),
      );

      expect(verification.ok, isFalse);
      expect(
        verification.message,
        RestaurantPrinterDispatchResolution.bridgeOfflineMessage,
      );
    });

    test('CUPS ready_unverified is not completed', () {
      final verification = BridgePrintDispatchVerification.verify(
        response: <String, dynamic>{
          'ok': true,
          'actual_backend': 'cups',
          'physical_confirmation': false,
          'confirmation_status': 'cups_accepted_unverified',
        },
        printer: cupsPrinter(),
      );

      expect(verification.ok, isFalse);
      expect(verification.cupsUnverified, isTrue);
      expect(verification.status, 'ready_unverified');
      expect(
        verification.message,
        BridgePrintDispatchVerification.cupsUnverifiedMessage,
      );
    });

    test('bytes_sent=0 fails with dispatch not delivered message', () {
      final verification = BridgePrintDispatchVerification.verify(
        response: <String, dynamic>{
          'ok': true,
          'actual_backend': 'tcp',
          'bytes_sent': 0,
        },
        printer: tcpPrinter(),
      );

      expect(verification.ok, isFalse);
      expect(
        verification.message,
        BridgePrintDispatchVerification.dispatchNotDeliveredMessage,
      );
    });
  });
}
