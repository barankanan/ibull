import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/printer_model.dart';
import 'package:ibul_app/services/print_tail_padding_policy.dart';
import 'package:ibul_app/services/printer_receipt_length_settings.dart';

void main() {
  group('Production receipt length apply', () {
    Map<String, dynamic> dbPrinterRaw({
      String preset = 'short',
      int? bottomPaddingPx,
      int? minReceiptHeightPx,
    }) {
      return <String, dynamic>{
        'receipt_length_preset': preset,
        'receipt_length': preset,
        'receipt_bottom_padding_px': bottomPaddingPx,
        'receipt_min_receipt_height_px': minReceiptHeightPx,
        if (preset == 'custom') ...<String, dynamic>{
          'bottom_padding_px': bottomPaddingPx,
          'min_receipt_height_px': minReceiptHeightPx,
        },
      };
    }

    test('kitchen_ticket uses DB printer short preset over orchestrator normal', () {
      final payload = <String, dynamic>{
        'document_type': 'kitchen_ticket',
        'receipt_length': 'normal',
        'bottom_feed_lines': 8,
        'min_receipt_height_px': 740,
        'receipt_length_source': 'orchestrator',
      };
      final policy = PrinterReceiptLengthSettings.resolveForDispatch(
        paperWidthMm: 80,
        printerRaw: dbPrinterRaw(preset: 'short'),
        payload: payload,
      );
      expect(policy.preset, ReceiptLengthPreset.short);
      expect(policy.minReceiptHeightPx, 420);
    });

    test('kitchen_ticket uses DB custom values over stale orchestrator stamp', () {
      final payload = <String, dynamic>{
        'document_type': 'kitchen_ticket',
        'receipt_length': 'normal',
        'bottom_feed_lines': 8,
        'bottom_padding_px': 180,
        'min_receipt_height_px': 740,
        'receipt_length_source': 'orchestrator',
      };
      final policy = PrinterReceiptLengthSettings.resolveForDispatch(
        paperWidthMm: 80,
        printerRaw: dbPrinterRaw(
          preset: 'custom',
          bottomPaddingPx: 80,
          minReceiptHeightPx: 520,
        ),
        payload: payload,
      );
      expect(policy.preset, ReceiptLengthPreset.custom);
      expect(policy.bottomPaddingPx, 80);
      expect(policy.minReceiptHeightPx, 520);
    });

    test('receipt/adisyon uses DB printer short preset', () {
      final payload = <String, dynamic>{
        'document_type': 'receipt',
        'printer_role': 'adisyon',
        'receipt_length_source': 'orchestrator',
        'receipt_length': 'normal',
      };
      final policy = PrinterReceiptLengthSettings.resolveForDispatch(
        paperWidthMm: 80,
        printerRaw: dbPrinterRaw(preset: 'short'),
        payload: payload,
      );
      expect(policy.preset, ReceiptLengthPreset.short);
    });

    test('stale snapshot normal does not override fresh DB long preset', () {
      final stalePayload = <String, dynamic>{
        'document_type': 'kitchen_ticket',
        'receipt_length': 'normal',
        'bottom_feed_lines': 8,
        'receipt_length_source': 'orchestrator',
      };
      final freshDb = dbPrinterRaw(preset: 'long');
      final policy = PrinterReceiptLengthSettings.resolveForDispatch(
        paperWidthMm: 80,
        printerRaw: freshDb,
        payload: stalePayload,
      );
      expect(policy.preset, ReceiptLengthPreset.long);
      expect(policy.minReceiptHeightPx, 850);
    });

    test('test and production share same bridge fields for DB custom', () {
      final printer = PrinterModel(
        id: 'kitchen-1',
        restaurantId: 'r1',
        name: 'Mutfak 80mm',
        code: 'M1',
        connectionType: PrinterModel.networkConnectionType,
        paperWidthMm: 80,
        isActive: true,
        createdAt: DateTime(2024),
        receiptLengthPreset: 'custom',
        receiptBottomPaddingPx: 80,
        receiptMinReceiptHeightPx: 520,
        receiptBottomFeedLines: 3,
        receiptCutFeedLines: 3,
        receiptMinTrailingBlankLines: 3,
      );
      final dbPolicy = PrinterReceiptLengthSettings.fromPrinterModel(printer)
          .resolvePolicy(paperWidthMm: 80);
      final productionPolicy = PrinterReceiptLengthSettings.resolveForDispatch(
        paperWidthMm: 80,
        printerRaw: printer.toMap(),
        payload: <String, dynamic>{
          'document_type': 'kitchen_ticket',
          'receipt_length_source': 'orchestrator',
        },
      );
      expect(productionPolicy.bottomPaddingPx, dbPolicy.bottomPaddingPx);
      expect(productionPolicy.minReceiptHeightPx, dbPolicy.minReceiptHeightPx);
      expect(productionPolicy.bottomFeedLines, dbPolicy.bottomFeedLines);
    });

    test('top-level printer and selected_printer share stamped tail fields', () {
      final policy = PrintTailPaddingPolicy.forPaperWidth(
        80,
        preset: ReceiptLengthPreset.custom,
      );
      final custom = const PrinterReceiptLengthSettings(
        preset: ReceiptLengthPreset.custom,
        bottomPaddingPx: 80,
        minReceiptHeightPx: 520,
        bottomFeedLines: 3,
        cutFeedLines: 3,
        minTrailingBlankLines: 3,
      ).resolvePolicy(paperWidthMm: 80);
      final fields = custom.toBridgeFields();
      final payload = <String, dynamic>{
        'document_type': 'kitchen_ticket',
        'printer': <String, dynamic>{'id': 'kitchen-1'},
        'selected_printer': <String, dynamic>{'id': 'kitchen-1'},
      };
      payload.addAll(fields);
      for (final key in <String>['printer', 'selected_printer']) {
        final nested = Map<String, dynamic>.from(
          payload[key] as Map<String, dynamic>,
        )..addAll(fields);
        payload[key] = nested;
      }
      expect(payload['min_receipt_height_px'], 520);
      expect(
        (payload['printer'] as Map)['min_receipt_height_px'],
        payload['min_receipt_height_px'],
      );
      expect(
        (payload['selected_printer'] as Map)['bottom_padding_px'],
        80,
      );
      expect(custom.minReceiptHeightPx, lessThan(policy.minReceiptHeightPx));
    });

    test('kitchen and adisyon printers use their own DB settings', () {
      final kitchenPolicy = PrinterReceiptLengthSettings.resolveForDispatch(
        paperWidthMm: 80,
        printerRaw: dbPrinterRaw(preset: 'short'),
        payload: const <String, dynamic>{'document_type': 'kitchen_ticket'},
      );
      final adisyonPolicy = PrinterReceiptLengthSettings.resolveForDispatch(
        paperWidthMm: 80,
        printerRaw: dbPrinterRaw(
          preset: 'custom',
          bottomPaddingPx: 200,
          minReceiptHeightPx: 900,
        ),
        payload: const <String, dynamic>{
          'document_type': 'receipt',
          'printer_role': 'adisyon',
        },
      );
      expect(kitchenPolicy.preset, ReceiptLengthPreset.short);
      expect(adisyonPolicy.bottomPaddingPx, 200);
      expect(adisyonPolicy.minReceiptHeightPx, 900);
    });
  });
}
