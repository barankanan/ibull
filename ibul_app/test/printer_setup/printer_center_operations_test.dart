import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/printer_center/printer_center_operations.dart';
import 'package:ibul_app/models/print_job_model.dart';
import 'package:ibul_app/models/printer_model.dart';
import 'package:ibul_app/models/station_model.dart';
import 'package:ibul_app/models/station_printer_model.dart';

PrintJobModel _job({
  required String id,
  required String status,
  String? error,
  String station = 'ocak',
  bool physical = false,
}) {
  return PrintJobModel.fromMap(<String, dynamic>{
    'id': id,
    'restaurant_id': 'rest-1',
    'order_id': 'order-1',
    'job_type': 'new_order',
    'status': status,
    'payload': <String, dynamic>{
      'station': station,
      'station_id': 'st-$station',
      'dispatch_verification': <String, dynamic>{
        'physical_confirmation': physical,
        'backend': 'tcp',
      },
    },
    'retry_count': 0,
    'last_error': error,
    'created_at': '2026-11-13T12:00:00Z',
  });
}

void main() {
  test('queue counts come from the loaded jobs', () {
    final counts = PrinterQueueSummary.counts(<PrintJobModel>[
      _job(id: '1', status: 'pending'),
      _job(id: '2', status: 'failed', error: 'Kapak açık'),
      _job(id: '3', status: 'completed', error: 'belirsiz'),
      _job(id: '4', status: 'quarantined'),
      _job(id: '5', status: 'paused_by_operator'),
    ]);
    expect(counts['pending'], 1);
    expect(counts['failed'], 1);
    expect(counts['uncertain'], 1);
    expect(counts['quarantine'], 1);
    expect(counts['paused_closed'], 1);
    expect(PrinterQueueSummary.isPhysicalPrint(_job(id: '6', status: 'completed')), isFalse);
    expect(
      PrinterQueueSummary.isPhysicalPrint(
        _job(id: '7', status: 'completed', physical: true),
      ),
      isTrue,
    );
  });

  testWidgets('ocak card shows address and blocks a closed service test', (tester) async {
    final views = printerCenterStationViews(
      stations: <StationModel>[
        StationModel.fromMap(<String, dynamic>{
          'id': 'st-ocak',
          'restaurant_id': 'rest-1',
          'name': 'Ocak',
          'code': 'ocak',
          'is_active': true,
        }),
      ],
      mappings: <StationPrinterModel>[
        StationPrinterModel.fromMap(<String, dynamic>{
          'id': 'map-1',
          'station_id': 'st-ocak',
          'printer_id': 'printer-1',
          'is_primary': true,
        }),
      ],
      printers: <PrinterModel>[
        PrinterModel.fromMap(<String, dynamic>{
          'id': 'printer-1',
          'restaurant_id': 'rest-1',
          'name': 'Ocak 80',
          'code': 'ocak-80',
          'connection_type': 'network',
          'ip_address': '192.168.1.40',
          'port': 9100,
          'is_active': true,
          'created_at': '2026-11-01T00:00:00Z',
        }),
      ],
      jobs: <PrintJobModel>[
        _job(id: '1', status: 'pending', station: 'ocak'),
      ],
      printSystemEnabledLoaded: true,
      printSystemEnabled: false,
      queueRuntimeDisabled: false,
      bridgeReachable: true,
      testInFlight: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PrinterCenterStationCards(views: views)),
      ),
    );
    expect(find.textContaining('192.168.1.40:9100'), findsOneWidget);
    expect(find.textContaining('Baskı sistemi kapalı'), findsOneWidget);
    expect(find.text('Yetkili test baskısı'), findsNothing);
  });
}
