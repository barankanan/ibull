import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/printer_profile.dart';
import 'package:ibul_app/services/print_tail_padding_policy.dart';

/// Minimal single-item kitchen payload mirroring OrderPrintJobService output.
Map<String, dynamic> _singleItemKitchenPayload() {
  return <String, dynamic>{
    'title': 'MUTFAK SIPARISI',
    'store_name': 'Test Restoran',
    'order_id': 'order-1',
    'order_no': '42',
    'table_no': '5',
    'table_name': 'Masa 5',
    'table_number': 5,
    'kitchen_ticket_header': 'Mutfak',
    'station_name': 'Mutfak',
    'waiter_name': 'Garson',
    'job_type': 'new_order',
    'render_mode': 'text',
    'items': <Map<String, dynamic>>[
      <String, dynamic>{
        'name': 'Katı Cacık',
        'quantity': 1,
        'product_name': 'Katı Cacık',
      },
    ],
  };
}

void _stampProductionKitchenTail(Map<String, dynamic> payload, int paperWidthMm) {
  final policy = PrintTailPaddingPolicy.forKitchenTicket(
    paperWidthMm: paperWidthMm,
  );
  payload.addAll(policy.toBridgeFields());
  payload['document_type'] = 'kitchen_ticket';
}

void main() {
  group('Real kitchen_ticket min length', () {
    test('single-item POS-80 payload bottom_feed_lines is 5 (normal)', () {
      final payload = _singleItemKitchenPayload();
      _stampProductionKitchenTail(payload, 80);
      expect(payload['bottom_feed_lines'], 5);
      expect(payload['cut_feed_lines'], 4);
    });

    test('single-item POS-80 min_receipt_height_px is 560 (normal)', () {
      final payload = _singleItemKitchenPayload();
      _stampProductionKitchenTail(payload, 80);
      expect(payload['min_receipt_height_px'], 560);
      expect(payload['bottom_padding_px'], 100);
    });

    test('single-item POS-80 raster policy min height floor', () {
      final policy = PrintTailPaddingPolicy.forKitchenTicket(paperWidthMm: 80);
      const simulatedContentHeightPx = 200;
      final finalHeightPx = simulatedContentHeightPx < policy.minReceiptHeightPx
          ? policy.minReceiptHeightPx
          : simulatedContentHeightPx;
      expect(finalHeightPx, 560);
    });

    test('single-item kitchen_ticket text min_trailing_blank_lines is 5', () {
      final payload = _singleItemKitchenPayload();
      _stampProductionKitchenTail(payload, 80);
      expect(payload['min_trailing_blank_lines'], 5);
    });

    test('production kitchen payload stamp adds tail policy fields', () {
      final payload = _singleItemKitchenPayload();
      expect(payload.containsKey('bottom_feed_lines'), isFalse);
      PrinterProfile.stampConsistentProfileOnMap(
        payload,
        profileId: 'pos80',
        paperWidthMm: 80,
      );
      expect(payload.containsKey('bottom_feed_lines'), isFalse);
      _stampProductionKitchenTail(payload, 80);
      expect(payload['bottom_feed_lines'], isNotNull);
      expect(payload['min_receipt_height_px'], isNotNull);
      expect(payload['document_type'], 'kitchen_ticket');
    });

    test('station_test and kitchen_ticket share policy helper', () {
      final kitchen = PrintTailPaddingPolicy.forKitchenTicket(
        paperWidthMm: 80,
        preset: ReceiptLengthPreset.normal,
      );
      final station = PrintTailPaddingPolicy.forProfile(
        PrinterProfile.pos80,
        documentType: 'station_test',
      );
      expect(kitchen.bottomFeedLines, station.bottomFeedLines);
      expect(kitchen.minReceiptHeightPx, station.minReceiptHeightPx);
    });

    test('short preset produces shorter min height than normal', () {
      final normal = PrintTailPaddingPolicy.forKitchenTicket(paperWidthMm: 80);
      final short = PrintTailPaddingPolicy.forKitchenTicket(
        paperWidthMm: 80,
        preset: ReceiptLengthPreset.short,
      );
      expect(short.minReceiptHeightPx, lessThan(normal.minReceiptHeightPx));
    });
  });
}
