import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/printer_model.dart';
import 'package:ibul_app/models/printer_profile.dart';
import 'package:ibul_app/services/restaurant_printer_dispatch_resolver.dart';
import 'package:ibul_app/models/desktop_printer_setup_models.dart';

PrinterModel _legacy80Printer() {
  return PrinterModel.fromMap(<String, dynamic>{
    'id': 'db-yenisi-80',
    'restaurant_id': 'rest-1',
    'name': 'yenisi 80mm',
    'code': 'yenisi-80',
    'connection_type': PrinterModel.networkConnectionType,
    'ip_address': '192.168.1.50',
    'port': 9100,
    'device_identifier': 'tcp:192.168.1.50:9100',
    'paper_width_mm': 80,
    'printer_profile_id': 'pos58',
    'is_active': true,
    'assigned_roles': const <String>['kitchen'],
    'created_at': DateTime(2026, 5, 1).toIso8601String(),
  });
}

UnifiedPrinterModel _unifiedFromLegacy(PrinterModel legacy) {
  return UnifiedPrinterModel(
    id: 'tcp:192.168.1.50:9100',
    displayName: legacy.name,
    queueName: legacy.name,
    backend: DesktopPrinterBackend.tcp,
    os: DesktopPrinterOs.macos,
    isAvailable: true,
    canPrint: true,
    printerRecordId: legacy.id,
    raw: <String, dynamic>{
      'printer_profile_id': legacy.printerProfileId,
      'paper_width_mm': legacy.paperWidthMm,
      'host': legacy.ipAddress,
      'port': legacy.port,
    },
  );
}

void main() {
  group('Printer profile runtime repair', () {
    test('normalizeBridgePayload heals pos58 + 80mm to pos80', () {
      final payload = PrinterProfile.normalizeBridgePayload(<String, dynamic>{
        'printer_profile': 'pos58',
        'printer_profile_id': 'pos58',
        'paper_width_mm': 80,
        'raster_width_px': 576,
        'printer': <String, dynamic>{
          'printer_profile': 'pos58',
          'paper_width_mm': 80,
          'raster_width_px': 576,
          'name': 'yenisi 80mm',
        },
      });
      expect(payload['printer_profile_id'], 'pos80');
      expect(payload['printer_profile'], 'pos80');
      expect(payload['paper_width_mm'], 80);
      expect(payload['raster_width_px'], 576);
      final nested = payload['printer'] as Map<String, dynamic>;
      expect(nested['printer_profile_id'], 'pos80');
      expect(nested['paper_width_mm'], 80);
    });

    test('resolver snapshot uses pos80 for legacy pos58+80mm printer', () {
      final printer = _unifiedFromLegacy(_legacy80Printer());
      final snapshot = RestaurantPrinterDispatchResolver.buildPrinterSnapshot(
        printer,
        role: PrinterSetupRole.mutfak,
        documentType: 'kitchen_ticket_test',
      );
      expect(snapshot['printer_profile_id'], 'pos80');
      expect(snapshot['printer_profile'], 'pos80');
      expect(snapshot['paper_width_mm'], 80);
      expect(snapshot['raster_width_px'], 576);
    });

    test('needsMetadataRepair detects pos58 + 80mm legacy row', () {
      final legacy = _legacy80Printer();
      expect(
        PrinterProfile.needsMetadataRepair(
          profileId: legacy.printerProfileId,
          paperWidthMm: legacy.paperWidthMm,
          displayName: legacy.name,
        ),
        isTrue,
      );
      final normalized = PrinterProfile.normalizeSaveMetadata(
        profileId: legacy.printerProfileId,
        paperWidthMm: legacy.paperWidthMm,
        displayName: legacy.name,
      );
      expect(normalized.profileId, 'pos80');
      expect(normalized.paperWidthMm, 80);
      expect(normalized.rasterWidthPx, 576);
    });

    test('repair metadata keeps printer id stable conceptually', () {
      final legacy = _legacy80Printer();
      final normalized = PrinterProfile.normalizeSaveMetadata(
        profileId: legacy.printerProfileId,
        paperWidthMm: legacy.paperWidthMm,
        displayName: legacy.name,
      );
      expect(legacy.id, 'db-yenisi-80');
      expect(normalized.profileId, 'pos80');
    });

    test('inconsistency message mentions POS-80 for yenisi 80mm', () {
      final message = PrinterProfile.inconsistencyMessage(
        profileId: 'pos58',
        paperWidthMm: 80,
        rasterWidthPx: 576,
        displayName: 'yenisi 80mm',
      );
      expect(message, isNotNull);
      expect(message!, contains('POS-80'));
    });
  });
}
