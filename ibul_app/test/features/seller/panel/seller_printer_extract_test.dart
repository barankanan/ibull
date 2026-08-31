import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/printer_center/printer_receipt_routing.dart';
import 'package:ibul_app/features/seller/panel/printer_center/printer_service_status.dart';
import 'package:ibul_app/features/seller/panel/printer_center/printer_workflow_messages.dart';
import 'package:ibul_app/services/local_print_service.dart';

void main() {
  test('printer service chrome lives outside the panel god file', () {
    final panel = File('lib/screens/seller_panel_page.dart').readAsStringSync();
    expect(panel, contains('PrinterServicePanel('));
    expect(panel, contains('PrinterServiceStatusBadge('));
    expect(panel, contains('PrinterServiceCompactBar('));
    expect(panel, contains('showPrinterServiceSheet('));
    expect(panel, isNot(contains('Durum ve kısa test işlemleri')));
    expect(panel, isNot(contains("part of 'seller_panel_page.dart'")));

    final view = File(
      'lib/features/seller/panel/printer_center/widgets/printer_service_view.dart',
    ).readAsStringSync();
    expect(view, contains('class PrinterServicePanel'));
    expect(view, isNot(contains("part of 'seller_panel_page.dart'")));
  });

  test('printer status color and relative time are stable', () {
    expect(printerServiceStatusColor(true), const Color(0xFF16A34A));
    expect(printerServiceStatusColor(false), const Color(0xFFDC2626));
    expect(printerServiceStatusColor(null), const Color(0xFF6B7280));

    final now = DateTime(2026, 9, 1, 12);
    expect(
      printerServiceTimeAgoShort(now.subtract(const Duration(seconds: 10)), now: now),
      'şimdi',
    );
    expect(
      printerServiceTimeAgoShort(now.subtract(const Duration(minutes: 5)), now: now),
      '5 dk önce',
    );
  });

  test('workflow message mapper stays actionable for cups queue busy', () {
    final mapped = normalizePrinterWorkflowMessage(
      LocalPrintServiceException(
        'raw',
        details: <String, dynamic>{
          'errorCode': 'cups_queue_busy',
          'printer_queue': 'POS58',
        },
      ),
      fallback: 'Yazdırılamadı',
    );
    expect(mapped, contains('kuyruğu meşgul'));
    expect(mapped, contains('POS58'));
  });

  test('adisyon routing keeps role mappings and fallback printer id', () {
    expect(hasConfiguredAdisyonPrinter(null), isFalse);
    expect(
      hasConfiguredAdisyonPrinter({
        'role_mappings': {
          'adisyon': {'id': 'bridge-1'},
        },
      }),
      isTrue,
    );
    final enriched = enrichQueuedReceiptPayloadWithPrinterRouting(
      <String, dynamic>{'store_name': 'Cafe'},
      stationConfig: {
        'role_mappings': {
          'adisyon': {
            'id': 'bridge-1',
            'displayName': 'Mutfak',
            'queueName': 'POS58',
          },
        },
      },
    );
    expect(enriched['printer_role'], 'adisyon');
    expect(enriched['printer_id'], 'bridge-1');
    expect(enriched['printer_name'], 'Mutfak');
    expect(enriched['printer_queue'], 'POS58');
  });
}
