import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/printer_center/widgets/printer_center_health_banner.dart';
import 'package:ibul_app/features/seller/panel/printer_center/widgets/printer_center_sections.dart';
import 'package:ibul_app/models/print_job_model.dart';
import 'package:ibul_app/models/printer_model.dart';

PrinterModel _samplePrinter() {
  return PrinterModel.fromMap(<String, dynamic>{
    'id': 'db-1',
    'restaurant_id': 'rest-1',
    'name': 'yenisi 80mm',
    'code': 'P1',
    'connection_type': PrinterModel.networkConnectionType,
    'ip_address': '192.168.10.100',
    'port': 9100,
    'device_identifier': 'tcp:192.168.10.100:9100',
    'paper_width_mm': 80,
    'printer_profile_id': 'pos80',
    'is_active': true,
    'created_at': DateTime(2026, 6, 1).toIso8601String(),
  });
}

void main() {
  group('Printer Center UI summary', () {
    testWidgets('health card bridge/internet/supabase durumlarını gösterir', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PrinterCenterHealthBanner(
              bridgeHealthy: true,
              bridgeReachable: true,
              printSystemEnabled: true,
              activePrinterCount: 2,
              issueMappingCount: 0,
              hasNetwork: true,
              supabaseReachable: false,
            ),
          ),
        ),
      );

      final richTexts = tester
          .widgetList<RichText>(find.byType(RichText))
          .map((widget) => widget.text.toPlainText())
          .toList();
      expect(richTexts.any((text) => text.contains('Bridge')), isTrue);
      expect(richTexts.any((text) => text.contains('Çalışıyor')), isTrue);
      expect(richTexts.any((text) => text.contains('İnternet')), isTrue);
      expect(richTexts.any((text) => text.contains('Bağlı değil')), isTrue);
    });

    testWidgets('eşleştirme özeti eksik mutfak/adisyonu gösterir', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrinterAssignmentSummaryCard(
              items: const <PrinterAssignmentSummaryItem>[
                PrinterAssignmentSummaryItem(
                  label: 'Adisyon',
                  isMapped: false,
                ),
                PrinterAssignmentSummaryItem(
                  label: 'Mutfak',
                  isMapped: true,
                  printerName: 'yenisi 80mm',
                ),
                PrinterAssignmentSummaryItem(
                  label: 'Ocak',
                  isMapped: false,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Eşleştirme Özeti'), findsOneWidget);
      expect(find.text('2 eksik'), findsOneWidget);
      final richTexts = tester
          .widgetList<RichText>(find.byType(RichText))
          .map((widget) => widget.text.toPlainText())
          .toList();
      expect(richTexts.any((text) => text.contains('Seçilmedi')), isTrue);
      expect(richTexts.any((text) => text.contains('yenisi 80mm')), isTrue);
    });

    testWidgets('registered printer card backend/IP/profile gösterir', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrinterRegisteredListCard(
              printers: <PrinterModel>[_samplePrinter()],
            ),
          ),
        ),
      );

      expect(find.text('yenisi 80mm'), findsOneWidget);
      expect(find.textContaining('Ethernet'), findsOneWidget);
      expect(find.textContaining('192.168.10.100:9100'), findsOneWidget);
      expect(find.textContaining('pos80'), findsOneWidget);
    });

    testWidgets('recent jobs card shows failed job error', (tester) async {
      final job = PrintJobModel.fromMap(<String, dynamic>{
        'id': 'job-1',
        'restaurant_id': 'rest-1',
        'job_type': 'kitchen',
        'status': 'failed',
        'payload': <String, dynamic>{},
        'retry_count': 0,
        'last_error': 'Bridge kapalı',
        'print_job_created_at': DateTime(2026, 6, 1).toIso8601String(),
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrinterRecentJobsCard(jobs: <PrintJobModel>[job]),
          ),
        ),
      );

      expect(find.textContaining('Başarısız'), findsOneWidget);
      expect(find.textContaining('Bridge kapalı'), findsOneWidget);
    });
  });
}
