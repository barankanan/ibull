import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/printer_model.dart';
import 'package:ibul_app/models/printer_profile.dart';
import 'package:ibul_app/services/print_tail_padding_policy.dart';
import 'package:ibul_app/services/printer_receipt_length_settings.dart';

void main() {
  group('PrinterReceiptLengthSettings live apply', () {
    test('unsaved short preset wins over printer DB custom with live override', () {
      final livePayload = PrinterReceiptLengthSettings(
        preset: ReceiptLengthPreset.short,
      ).toLiveBridgeFields(paperWidthMm: 80);
      final policy = PrinterReceiptLengthSettings.resolveForDispatch(
        paperWidthMm: 80,
        printerRaw: <String, dynamic>{
          'receipt_length_preset': 'custom',
          'receipt_bottom_padding_px': 280,
          'receipt_min_receipt_height_px': 950,
        },
        payload: livePayload,
      );
      expect(policy.preset, ReceiptLengthPreset.short);
      expect(policy.bottomFeedLines, 2);
    });

    test('unsaved long preset wins over printer DB normal with live override', () {
      final livePayload = PrinterReceiptLengthSettings(
        preset: ReceiptLengthPreset.long,
      ).toLiveBridgeFields(paperWidthMm: 80);
      final policy = PrinterReceiptLengthSettings.resolveForDispatch(
        paperWidthMm: 80,
        printerRaw: const <String, dynamic>{
          'receipt_length_preset': 'normal',
        },
        payload: livePayload,
      );
      expect(policy.preset, ReceiptLengthPreset.long);
      expect(policy.minReceiptHeightPx, 850);
    });

    test('unsaved custom values are stamped into payload', () {
      final settings = const PrinterReceiptLengthSettings(
        preset: ReceiptLengthPreset.custom,
        bottomPaddingPx: 120,
        minReceiptHeightPx: 620,
        bottomFeedLines: 5,
        cutFeedLines: 4,
        minTrailingBlankLines: 5,
      );
      final payload = <String, dynamic>{
        'document_type': 'test_receipt',
        ...settings.toLiveBridgeFields(paperWidthMm: 80),
      };
      final policy = PrinterReceiptLengthSettings.resolveForDispatch(
        paperWidthMm: 80,
        printerRaw: const <String, dynamic>{'receipt_length_preset': 'long'},
        payload: payload,
      );
      expect(policy.bottomPaddingPx, 120);
      expect(policy.minReceiptHeightPx, 620);
      expect(policy.preset, ReceiptLengthPreset.custom);
    });

    test('normalizeBridgePayload preserves explicit receipt_length', () {
      final normalized = PrinterProfile.normalizeBridgePayload(
        <String, dynamic>{
          'printer_profile_id': 'pos80',
          'paper_width_mm': 80,
          'receipt_length': 'short',
          'bottom_feed_lines': 6,
          'min_receipt_height_px': 650,
        },
      );
      expect(normalized['receipt_length'], 'short');
      expect(normalized['bottom_feed_lines'], 6);
      expect(normalized['min_receipt_height_px'], 650);
    });

    test('printer DB custom overrides profile default when payload empty', () {
      final policy = PrinterReceiptLengthSettings.resolveForDispatch(
        paperWidthMm: 80,
        printerRaw: <String, dynamic>{
          'receipt_length_preset': 'custom',
          'receipt_bottom_padding_px': 120,
          'receipt_min_receipt_height_px': 620,
        },
        payload: const <String, dynamic>{'document_type': 'kitchen_ticket'},
      );
      expect(policy.bottomPaddingPx, 120);
      expect(policy.minReceiptHeightPx, 620);
    });

    test('top-level and nested printer share tail values', () {
      final payload = <String, dynamic>{
        'document_type': 'kitchen_ticket',
        'printer': <String, dynamic>{'id': 'printer-1'},
      };
      final policy = PrintTailPaddingPolicy.forPaperWidth(
        80,
        preset: ReceiptLengthPreset.long,
      );
      payload.addAll(policy.toBridgeFields());
      final nested = Map<String, dynamic>.from(
        payload['printer'] as Map<String, dynamic>,
      )..addAll(policy.toBridgeFields());
      payload['printer'] = nested;

      expect(payload['receipt_length'], nested['receipt_length']);
      expect(payload['min_receipt_height_px'], nested['min_receipt_height_px']);
    });

    test('raster custom min height is not replaced by normal default', () {
      final custom = const PrinterReceiptLengthSettings(
        preset: ReceiptLengthPreset.custom,
        minReceiptHeightPx: 420,
        bottomPaddingPx: 40,
      ).resolvePolicy(paperWidthMm: 80);
      final normal = PrintTailPaddingPolicy.forPaperWidth(80);
      expect(custom.minReceiptHeightPx, 420);
      expect(custom.minReceiptHeightPx, lessThan(normal.minReceiptHeightPx));
    });

    test('kitchen_ticket uses printer saved long preset from model map', () {
      final printer = PrinterModel(
        id: 'p1',
        restaurantId: 'r1',
        name: 'Mutfak',
        code: 'M1',
        connectionType: PrinterModel.networkConnectionType,
        paperWidthMm: 80,
        isActive: true,
        createdAt: DateTime(2024),
        receiptLengthPreset: 'long',
      );
      final policy = PrinterReceiptLengthSettings.fromPrinterModel(printer)
          .resolvePolicy(paperWidthMm: 80);
      expect(policy.preset, ReceiptLengthPreset.long);
      expect(policy.minReceiptHeightPx, 850);
    });
  });
}
