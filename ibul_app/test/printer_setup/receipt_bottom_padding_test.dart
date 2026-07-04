import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/printer_profile.dart';
import 'package:ibul_app/services/print_tail_padding_policy.dart';

void main() {
  group('Receipt bottom padding', () {
    test('POS-80 profile fields exclude tail padding defaults', () {
      final fields = PrinterProfile.bridgeProfileFields(PrinterProfile.pos80);
      expect(fields.containsKey('bottom_feed_lines'), isFalse);
      expect(fields.containsKey('min_receipt_height_px'), isFalse);
      expect(fields['raster_width_px'], 576);
      expect(fields['paper_width_mm'], 80);
    });

    test('POS-58 profile fields exclude tail padding defaults', () {
      final fields = PrinterProfile.bridgeProfileFields(PrinterProfile.pos58);
      expect(fields.containsKey('bottom_feed_lines'), isFalse);
      expect(fields['raster_width_px'], 384);
      expect(fields['paper_width_mm'], 58);
    });

    test('explicit receipt_length survives normalizeBridgePayload', () {
      final normalized = PrinterProfile.normalizeBridgePayload(
        <String, dynamic>{
          'printer_profile_id': 'pos80',
          'paper_width_mm': 80,
          'document_type': 'kitchen',
          'receipt_length': 'long',
          'bottom_feed_lines': 12,
          'min_receipt_height_px': 950,
        },
      );
      expect(normalized['receipt_length'], 'long');
      expect(normalized['bottom_feed_lines'], 12);
      expect(normalized['min_receipt_height_px'], 950);
    });

    test('stampConsistentProfileOnMap does not inject tail padding', () {
      final payload = <String, dynamic>{};
      PrinterProfile.stampConsistentProfileOnMap(
        payload,
        profileId: 'pos80',
        paperWidthMm: 80,
      );
      expect(payload.containsKey('bottom_feed_lines'), isFalse);
      expect(payload.containsKey('min_receipt_height_px'), isFalse);
      expect(payload['paper_width_mm'], 80);
    });

    test('orchestrator tail policy supplies normal POS-80 defaults', () {
      final policy = PrintTailPaddingPolicy.forPaperWidth(80);
      expect(policy.bottomFeedLines, 5);
      expect(policy.cutFeedLines, 4);
      expect(policy.bottomPaddingPx, 100);
      expect(policy.minReceiptHeightPx, 560);
    });
  });
}
