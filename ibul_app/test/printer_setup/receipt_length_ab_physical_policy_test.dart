import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/print_tail_padding_policy.dart';
import 'package:ibul_app/services/printer_receipt_length_settings.dart';

void main() {
  group('Receipt length A/B physical policy', () {
    test('custom zero policy POS-80 bottom_feed=0 padding=0 min_height=0', () {
      final policy = PrintTailPaddingPolicy.resolveFromPayload(
        <String, dynamic>{
          'paper_width_mm': 80,
          'receipt_length': 'custom',
          'bottom_feed_lines': 0,
          'cut_feed_lines': 0,
          'min_trailing_blank_lines': 0,
          'bottom_padding_px': 0,
          'min_receipt_height_px': 0,
        },
      );
      expect(policy.bottomFeedLines, 0);
      expect(policy.cutFeedLines, 0);
      expect(policy.minTrailingBlankLines, 0);
      expect(policy.bottomPaddingPx, 0);
      expect(policy.minReceiptHeightPx, 0);
    });

    test('custom long policy POS-80 bottom_feed=20 padding=600 min_height=1400',
        () {
      final policy = PrintTailPaddingPolicy.resolveFromPayload(
        <String, dynamic>{
          'paper_width_mm': 80,
          'receipt_length': 'custom',
          'bottom_feed_lines': 20,
          'cut_feed_lines': 16,
          'min_trailing_blank_lines': 20,
          'bottom_padding_px': 600,
          'min_receipt_height_px': 1400,
        },
      );
      expect(policy.bottomFeedLines, 20);
      expect(policy.cutFeedLines, 16);
      expect(policy.bottomPaddingPx, 600);
      expect(policy.minReceiptHeightPx, 1400);
    });

    test('A and B policy final payload values differ', () {
      final a = PrintTailPaddingPolicy.abMinimumBridgeFields();
      final b = PrintTailPaddingPolicy.abMaximumBridgeFields();
      expect(a['bottom_feed_lines'], isNot(equals(b['bottom_feed_lines'])));
      expect(a['bottom_padding_px'], isNot(equals(b['bottom_padding_px'])));
      expect(
        a['min_receipt_height_px'],
        isNot(equals(b['min_receipt_height_px'])),
      );
    });

    test('raster custom zero min height not replaced by normal default', () {
      final zero = PrintTailPaddingPolicy.resolveFromPayload(
        <String, dynamic>{
          'receipt_length': 'custom',
          'min_receipt_height_px': 0,
          'bottom_padding_px': 0,
        },
      );
      final normal = PrintTailPaddingPolicy.forPaperWidth(80);
      expect(zero.minReceiptHeightPx, 0);
      expect(zero.minReceiptHeightPx, isNot(normal.minReceiptHeightPx));
      expect(zero.bottomPaddingPx, 0);
    });

    test('text custom zero blank/feed not replaced by normal default', () {
      final settings = PrinterReceiptLengthSettings.fromMap(
        <String, dynamic>{
          'receipt_length': 'custom',
          'bottom_feed_lines': 0,
          'cut_feed_lines': 0,
          'min_trailing_blank_lines': 0,
          'receipt_length_live_override': true,
        },
      );
      final policy = settings.resolvePolicy(paperWidthMm: 80);
      expect(policy.bottomFeedLines, 0);
      expect(policy.cutFeedLines, 0);
      expect(policy.minTrailingBlankLines, 0);
    });

    test(
      'production kitchen_ticket uses UI-edited printer DB receipt settings',
      () {
        const uiPrinterId = 'kitchen-printer-1';
        final policy = PrinterReceiptLengthSettings.resolveForDispatch(
          paperWidthMm: 80,
          printerRaw: <String, dynamic>{
            'id': uiPrinterId,
            'receipt_length_preset': 'short',
          },
          payload: <String, dynamic>{
            'document_type': 'kitchen_ticket',
            'selected_printer_id': uiPrinterId,
          },
        );
        expect(policy.preset, ReceiptLengthPreset.short);
        expect(policy.minReceiptHeightPx, 420);
      },
    );

    test('production receipt uses its own printer id settings', () {
      final policy = PrinterReceiptLengthSettings.resolveForDispatch(
        paperWidthMm: 80,
        printerRaw: <String, dynamic>{
          'id': 'adisyon-printer-2',
          'receipt_length_preset': 'long',
        },
        payload: const <String, dynamic>{
          'document_type': 'receipt',
          'printer_role': 'adisyon',
        },
      );
      expect(policy.preset, ReceiptLengthPreset.long);
      expect(policy.minReceiptHeightPx, 850);
    });

    test('printer id mismatch produces diagnostic message', () {
      final message = PrinterReceiptLengthSettings.printerIdMismatchDiagnostic(
        uiEditedPrinterId: 'printer-a',
        dispatchPrinterRecordId: 'printer-b',
      );
      expect(message, isNotNull);
      expect(message!, contains('farklı yazıcı kaydıyla'));
      expect(message, contains('printer-b'));
    });

    test('POS-80 short preset matches tightened values', () {
      final short = PrintTailPaddingPolicy.forPaperWidth(
        80,
        preset: ReceiptLengthPreset.short,
      );
      expect(short.bottomFeedLines, 2);
      expect(short.cutFeedLines, 1);
      expect(short.bottomPaddingPx, 40);
      expect(short.minReceiptHeightPx, 420);
    });

    test('custom min height allows zero clamp floor', () {
      final settings = PrinterReceiptLengthSettings(
        preset: ReceiptLengthPreset.custom,
        minReceiptHeightPx: 0,
        bottomPaddingPx: 0,
        bottomFeedLines: 0,
        cutFeedLines: 0,
        minTrailingBlankLines: 0,
      );
      final policy = settings.resolvePolicy(paperWidthMm: 80);
      expect(policy.minReceiptHeightPx, 0);
    });
  });
}
