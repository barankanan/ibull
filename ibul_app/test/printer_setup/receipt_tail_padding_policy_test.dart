import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/printer_profile.dart';
import 'package:ibul_app/services/print_tail_padding_policy.dart';

void main() {
  group('PrintTailPaddingPolicy', () {
    test('POS-80 kitchen_ticket normal bottom_feed_lines is 5', () {
      final policy = PrintTailPaddingPolicy.forProfile(
        PrinterProfile.pos80,
        documentType: 'kitchen_ticket',
      );
      expect(policy.bottomFeedLines, 5);
    });

    test('POS-80 short preset bottom_feed_lines is 2', () {
      final policy = PrintTailPaddingPolicy.forPaperWidth(
        80,
        preset: ReceiptLengthPreset.short,
      );
      expect(policy.bottomFeedLines, 2);
    });

    test('POS-58 kitchen_ticket short bottom_feed_lines is 3', () {
      final policy = PrintTailPaddingPolicy.forPaperWidth(
        58,
        preset: ReceiptLengthPreset.short,
      );
      expect(policy.bottomFeedLines, 3);
    });

    test('Raster POS-80 normal bottom_padding_px is 100', () {
      final policy = PrintTailPaddingPolicy.forPaperWidth(80);
      expect(policy.bottomPaddingPx, 100);
    });

    test('min_receipt_height_px POS-80 normal is 560', () {
      final policy = PrintTailPaddingPolicy.forPaperWidth(80);
      expect(policy.minReceiptHeightPx, 560);
    });

    test('bridge fields order: feed values precede cut in policy design', () {
      final policy = PrintTailPaddingPolicy.forPaperWidth(80);
      expect(policy.bottomFeedLines, greaterThan(0));
      expect(policy.cutFeedLines, greaterThan(0));
      expect(
        policy.minTrailingBlankLines,
        greaterThanOrEqualTo(policy.bottomFeedLines),
      );
      final fields = policy.toBridgeFields();
      expect(fields.containsKey('bottom_feed_lines'), isTrue);
      expect(fields.containsKey('cut_feed_lines'), isTrue);
      expect(fields['bottom_feed_lines'], policy.bottomFeedLines);
    });

    test('kitchen_ticket and station_test share the same policy', () {
      final kitchen = PrintTailPaddingPolicy.forProfile(
        PrinterProfile.pos80,
        documentType: 'kitchen_ticket',
      );
      final station = PrintTailPaddingPolicy.forProfile(
        PrinterProfile.pos80,
        documentType: 'station_test',
      );
      expect(kitchen.bottomFeedLines, station.bottomFeedLines);
      expect(kitchen.bottomPaddingPx, station.bottomPaddingPx);
      expect(kitchen.minReceiptHeightPx, station.minReceiptHeightPx);
    });

    test('resolveFromPayload honors explicit overrides', () {
      final resolved = PrintTailPaddingPolicy.resolveFromPayload(
        <String, dynamic>{
          'paper_width_mm': 80,
          'bottom_feed_lines': 20,
          'cut_feed_lines': 15,
          'bottom_padding_px': 400,
          'min_receipt_height_px': 1000,
        },
      );
      expect(resolved.bottomFeedLines, 20);
      expect(resolved.cutFeedLines, 15);
      expect(resolved.bottomPaddingPx, 400);
      expect(resolved.minReceiptHeightPx, 1000);
    });

    test('short preset reduces tail padding vs normal', () {
      final normal = PrintTailPaddingPolicy.forPaperWidth(80);
      final short = PrintTailPaddingPolicy.forPaperWidth(
        80,
        preset: ReceiptLengthPreset.short,
      );
      expect(short.bottomFeedLines, lessThan(normal.bottomFeedLines));
      expect(short.bottomPaddingPx, lessThan(normal.bottomPaddingPx));
      expect(short.minReceiptHeightPx, lessThan(normal.minReceiptHeightPx));
    });

    test('AB minimum and maximum policies differ materially', () {
      final min = PrintTailPaddingPolicy.abMinimumPhysicalTest;
      final max = PrintTailPaddingPolicy.abMaximumPhysicalTest;
      expect(min.minReceiptHeightPx, 0);
      expect(max.minReceiptHeightPx, 1400);
      expect(max.bottomPaddingPx, greaterThan(min.bottomPaddingPx));
    });
  });
}
