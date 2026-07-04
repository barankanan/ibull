import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/printer_profile.dart';

void main() {
  group('PrinterProfile metadata consistency', () {
    test('pos80 maps to paper_width=80 and raster=576', () {
      final normalized = PrinterProfile.normalizeSaveMetadata(
        profileId: 'pos80',
        paperWidthMm: 80,
      );
      expect(normalized.profileId, 'pos80');
      expect(normalized.paperWidthMm, 80);
      expect(normalized.rasterWidthPx, 576);
    });

    test('pos58 maps to paper_width=58 and raster=384', () {
      final normalized = PrinterProfile.normalizeSaveMetadata(
        profileId: 'pos58',
        paperWidthMm: 58,
      );
      expect(normalized.profileId, 'pos58');
      expect(normalized.paperWidthMm, 58);
      expect(normalized.rasterWidthPx, 384);
    });

    test('pos58 with 80mm paper auto-heals to pos80', () {
      final profile = PrinterProfile.resolveConsistentProfile(
        profileId: 'pos58',
        paperWidthMm: 80,
        displayName: 'yenisi 80mm',
      );
      expect(profile.id, 'pos80');
      expect(profile.paperWidthMm, 80);
      expect(profile.rasterWidthPx, 576);
    });

    test('pos80 station payload metadata stays consistent', () {
      final fields = PrinterProfile.bridgeProfileFields(PrinterProfile.pos80);
      expect(fields['printer_profile_id'], 'pos80');
      expect(fields['paper_width_mm'], 80);
      expect(fields['raster_width_px'], 576);
    });

    test('legacy inconsistent printer produces repair suggestion', () {
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
