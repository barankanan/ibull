import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/printer_center/printer_assignment_state.dart';
import 'package:ibul_app/features/seller/panel/printer_center/printer_station_test_guard.dart';
import 'package:ibul_app/models/printer_model.dart';
import 'package:ibul_app/models/printer_profile.dart';
import 'package:ibul_app/models/station_model.dart';
import 'package:ibul_app/models/station_printer_model.dart';

PrinterModel _printer({
  required String id,
  required String name,
  bool active = true,
  int paperWidth = 80,
  String? profileId,
}) {
  return PrinterModel.fromMap(<String, dynamic>{
    'id': id,
    'restaurant_id': 'rest-1',
    'name': name,
    'code': id,
    'connection_type': PrinterModel.networkConnectionType,
    'ip_address': '192.168.1.100',
    'port': 9100,
    'device_identifier': 'tcp:192.168.1.100:9100',
    'paper_width_mm': paperWidth,
    'printer_profile_id': profileId ?? 'pos80',
    'is_active': active,
    'assigned_roles': const <String>['kitchen'],
    'created_at': DateTime(2026, 5, 1).toIso8601String(),
  });
}

void main() {
  group('PrinterCenter hardening', () {
    test('mutfak role mapping persists across reload when scan empty', () {
      const savedId = 'db-kitchen-80';
      final resolved = PrinterAssignmentState.coercePersistedSelectionId(
        snapshotSelectedId: savedId,
        bridgePrinters: const <Map<String, dynamic>>[],
      );
      expect(resolved, savedId);
    });

    test('persisted role printer stays in dropdown options', () {
      final active = <PrinterModel>[_printer(id: 'live-1', name: 'Live')];
      final all = <PrinterModel>[
        ...active,
        _printer(id: 'db-kitchen-80', name: 'yenisi 80mm'),
      ];
      final merged = PrinterAssignmentState.mergePrinterOptions(
        activePrinters: active,
        allPrinters: all,
        extraPrinterIds: const <String>['db-kitchen-80'],
      );
      expect(merged.map((p) => p.id), contains('db-kitchen-80'));
    });

    test('dirty state only when selection differs from persisted', () {
      expect(
        PrinterAssignmentState.roleMappingsDirty(
          selectedReceiptPrinterId: 'a',
          selectedKitchenPrinterId: 'k1',
          persistedReceiptPrinterId: 'a',
          persistedKitchenPrinterId: 'k2',
        ),
        isTrue,
      );
      expect(
        PrinterAssignmentState.roleMappingsDirty(
          selectedReceiptPrinterId: 'a',
          selectedKitchenPrinterId: 'k1',
          persistedReceiptPrinterId: 'a',
          persistedKitchenPrinterId: 'k1',
        ),
        isFalse,
      );
    });

    test('station test guard blocks missing mapping explicitly', () {
      final station = StationModel.fromMap(<String, dynamic>{
        'id': 'st-ocak',
        'restaurant_id': 'rest-1',
        'name': 'Ocak',
        'code': 'ocak',
        'is_active': true,
      });
      final message = PrinterStationTestGuard.validate(
        station: station,
        primaryMapping: null,
        mappedPrinter: null,
        printSystemEnabledLoaded: true,
        printSystemEnabled: true,
        queueRuntimeDisabled: false,
        bridgeReachable: true,
        testInFlight: false,
      );
      expect(message, contains('Ocak'));
      expect(message, contains('eşleştirmesi yok'));
    });

    test('station test guard allows mapped active ethernet printer', () {
      final station = StationModel.fromMap(<String, dynamic>{
        'id': 'st-kasap',
        'restaurant_id': 'rest-1',
        'name': 'Kasap',
        'code': 'kasap',
        'is_active': true,
      });
      final printer = _printer(id: 'db-kasap', name: 'Kasap 80mm');
      final mapping = StationPrinterModel.fromMap(<String, dynamic>{
        'id': 'map-1',
        'station_id': 'st-kasap',
        'printer_id': 'db-kasap',
        'is_primary': true,
        'station_name': 'Kasap',
        'printer_name': 'Kasap 80mm',
      });
      expect(
        PrinterStationTestGuard.validate(
          station: station,
          primaryMapping: mapping,
          mappedPrinter: printer,
          printSystemEnabledLoaded: true,
          printSystemEnabled: true,
          queueRuntimeDisabled: false,
          bridgeReachable: true,
          testInFlight: false,
        ),
        isNull,
      );
    });

    test('profile metadata inconsistency normalizes pos58 + 80mm', () {
      final profile = PrinterProfile.resolveConsistentProfile(
        profileId: 'pos58',
        paperWidthMm: 80,
        displayName: 'yenisi 80mm',
      );
      expect(profile.id, 'pos80');
      expect(profile.paperWidthMm, 80);
      expect(profile.rasterWidthPx, 576);
    });
  });
}
