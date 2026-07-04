import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/printer_model.dart';
import 'package:ibul_app/services/print_tail_padding_policy.dart';
import 'package:ibul_app/services/printer_receipt_length_settings.dart';

void main() {
  group('PrinterReceiptLengthSettings', () {
    test('POS-80 normal preset produces expected values', () {
      final policy = PrinterReceiptLengthSettings.normal.resolvePolicy(
        paperWidthMm: 80,
      );
      expect(policy.bottomFeedLines, 5);
      expect(policy.cutFeedLines, 4);
      expect(policy.bottomPaddingPx, 100);
      expect(policy.minReceiptHeightPx, 560);
    });

    test('POS-80 short preset is shorter than normal', () {
      final normal = PrintTailPaddingPolicy.forPaperWidth(80);
      final short = PrinterReceiptLengthSettings(
        preset: ReceiptLengthPreset.short,
      ).resolvePolicy(paperWidthMm: 80);
      expect(short.bottomFeedLines, lessThan(normal.bottomFeedLines));
      expect(short.minReceiptHeightPx, lessThan(normal.minReceiptHeightPx));
    });

    test('POS-80 long preset is longer than normal', () {
      final normal = PrintTailPaddingPolicy.forPaperWidth(80);
      final long = PrinterReceiptLengthSettings(
        preset: ReceiptLengthPreset.long,
      ).resolvePolicy(paperWidthMm: 80);
      expect(long.bottomFeedLines, greaterThan(normal.bottomFeedLines));
      expect(long.minReceiptHeightPx, greaterThan(normal.minReceiptHeightPx));
    });

    test('custom values are stamped into bridge fields', () {
      final settings = PrinterReceiptLengthSettings(
        preset: ReceiptLengthPreset.custom,
        bottomFeedLines: 15,
        cutFeedLines: 11,
        minTrailingBlankLines: 15,
        bottomPaddingPx: 250,
        minReceiptHeightPx: 900,
      );
      final fields = settings.resolvePolicy(paperWidthMm: 80).toBridgeFields();
      expect(fields['receipt_length'], 'custom');
      expect(fields['bottom_feed_lines'], 15);
      expect(fields['min_receipt_height_px'], 900);
    });

    test('printer custom setting overrides profile default', () {
      final printer = PrinterModel(
        id: 'p1',
        restaurantId: 'r1',
        name: 'Mutfak',
        code: 'MUTFAK',
        connectionType: PrinterModel.localConnectionType,
        paperWidthMm: 80,
        isActive: true,
        createdAt: DateTime.now(),
        receiptLengthPreset: 'long',
      );
      final policy = PrinterReceiptLengthSettings.resolveForDispatch(
        paperWidthMm: 80,
        printerRaw: printer.toMap(),
      );
      expect(policy.preset, ReceiptLengthPreset.long);
      expect(policy.minReceiptHeightPx, 850);
    });

    test('top-level and nested printer map share tail values', () {
      final payload = <String, dynamic>{
        'printer': <String, dynamic>{'name': 'Mutfak'},
      };
      final policy = PrintTailPaddingPolicy.forPaperWidth(
        80,
        preset: ReceiptLengthPreset.long,
      );
      payload.addAll(policy.toBridgeFields());
      final nested = Map<String, dynamic>.from(
        payload['printer'] as Map<String, dynamic>,
      );
      nested.addAll(policy.toBridgeFields());
      payload['printer'] = nested;
      expect(payload['bottom_feed_lines'], nested['bottom_feed_lines']);
      expect(payload['min_receipt_height_px'], nested['min_receipt_height_px']);
    });

    test('kitchen_ticket uses printer saved long preset', () {
      final printerRaw = <String, dynamic>{
        'paper_width_mm': 80,
        'receipt_length_preset': 'long',
      };
      final policy = PrinterReceiptLengthSettings.resolveForDispatch(
        paperWidthMm: 80,
        printerRaw: printerRaw,
        payload: <String, dynamic>{'document_type': 'kitchen_ticket'},
      );
      expect(policy.bottomFeedLines, greaterThanOrEqualTo(10));
    });

    test('persisted printer settings survive saved-only raw merge', () {
      final printer = PrinterModel(
        id: 'p1',
        restaurantId: 'r1',
        name: 'Mutfak',
        code: 'MUTFAK',
        connectionType: PrinterModel.networkConnectionType,
        ipAddress: '192.168.1.50',
        port: 9100,
        paperWidthMm: 80,
        isActive: true,
        createdAt: DateTime.now(),
        receiptLengthPreset: 'short',
      );
      final fromDb = PrinterReceiptLengthSettings.fromPrinterModel(printer);
      expect(fromDb.preset, ReceiptLengthPreset.short);
      expect(
        fromDb.resolvePolicy(paperWidthMm: 80).bottomFeedLines,
        2,
      );
    });
  });
}
