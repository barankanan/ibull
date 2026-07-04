import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/printer_center/printer_assignment_state.dart';
import 'package:ibul_app/models/desktop_printer_setup_models.dart';
import 'package:ibul_app/models/discovered_printer.dart';
import 'package:ibul_app/models/printer_model.dart';

PrinterModel _savedEthernetPrinter({
  required String id,
  String? ip,
  String? deviceIdentifier,
}) {
  return PrinterModel.fromMap(<String, dynamic>{
    'id': id,
    'restaurant_id': 'rest-1',
    'name': 'yenisi 80mm',
    'code': id,
    'connection_type': PrinterModel.networkConnectionType,
    'ip_address': ip,
    'port': 9100,
    'device_identifier': deviceIdentifier,
    'paper_width_mm': 80,
    'printer_profile_id': 'pos80',
    'is_active': true,
    'assigned_roles': const <String>['kitchen'],
    'created_at': DateTime(2026, 6, 1).toIso8601String(),
  });
}

UnifiedPrinterModel _tcpUnifiedFromSaved(PrinterModel model) {
  return UnifiedPrinterModel.fromBridgeMap(
    <String, dynamic>{
      ...model.toEthernetBridgePayload(roleOverride: 'kitchen'),
      'printer_record_id': model.id,
      'printerRecordId': model.id,
    },
    os: DesktopPrinterOs.macos,
  );
}

void main() {
  group('Restaurant kitchen role persistence', () {
    test('mutfak printer seç → save id → reload → persisted', () {
      const savedId = 'db-kitchen-80mm';
      final resolved = PrinterAssignmentState.coercePersistedSelectionId(
        snapshotSelectedId: savedId,
        bridgePrinters: const <Map<String, dynamic>>[],
      );
      expect(resolved, savedId);
    });

    test('live scan boş → persisted kitchen printer dropdown’da kalır', () {
      final all = <PrinterModel>[
        _savedEthernetPrinter(
          id: 'db-kitchen-80mm',
          deviceIdentifier: 'tcp:192.168.10.100:9100',
        ),
      ];
      final merged = PrinterAssignmentState.mergePrinterOptions(
        activePrinters: const <PrinterModel>[],
        allPrinters: all,
        extraPrinterIds: const <String>['db-kitchen-80mm'],
      );
      expect(merged.map((p) => p.id), contains('db-kitchen-80mm'));
      final normalized = PrinterAssignmentState.normalizeSelectedPrinterId(
        printers: merged,
        selectedPrinterId: 'db-kitchen-80mm',
        bridgePrinters: const <Map<String, dynamic>>[],
      );
      expect(normalized, 'db-kitchen-80mm');
    });

    test('save fail → dirty state temizlenmez', () {
      expect(
        PrinterAssignmentState.roleMappingsDirty(
          selectedReceiptPrinterId: '',
          selectedKitchenPrinterId: 'kitchen-1',
          persistedReceiptPrinterId: '',
          persistedKitchenPrinterId: null,
        ),
        isTrue,
      );
    });

    test('coerce prefers DB record id over bridge tcp id', () {
      final coerced = PrinterAssignmentState.coercePersistedSelectionId(
        snapshotSelectedId: 'db-kitchen-80mm',
        bridgePrinters: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'tcp:192.168.10.100:9100',
            'printerRecordId': 'db-kitchen-80mm',
            'selectionId': 'tcp:192.168.10.100:9100',
          },
        ],
      );
      expect(coerced, 'db-kitchen-80mm');
    });

    test('kitchen_general canonical: mutfak role printer assignable via tcp device id', () {
      final model = _savedEthernetPrinter(
        id: 'db-kitchen-80mm',
        ip: '',
        deviceIdentifier: 'tcp:192.168.10.100:9100',
      );
      final unified = _tcpUnifiedFromSaved(model);
      expect(isAssignableRolePrinter(unified), isTrue);
      final endpoint = DiscoveredPrinter.endpointFromUnifiedPrinter(unified);
      expect(endpoint.ip, '192.168.10.100');
      expect(endpoint.port, 9100);
    });
  });
}
