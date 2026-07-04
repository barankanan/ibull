import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/desktop_printer_setup_models.dart';
import 'package:ibul_app/models/print_job_model.dart';
import 'package:ibul_app/services/bridge_print_dispatch_verification.dart';
import 'package:ibul_app/services/print_job_repository.dart';
import 'package:ibul_app/services/restaurant_printer_diagnostics_report_builder.dart';

void main() {
  group('Print job observability', () {
    UnifiedPrinterModel tcpPrinter() {
      return UnifiedPrinterModel.fromBridgeMap(<String, dynamic>{
        'id': 'tcp:192.168.1.10:9100',
        'name': 'Kitchen Ethernet',
        'queue': 'Kitchen Ethernet',
        'backend': 'tcp',
        'host': '192.168.1.10',
        'port': 9100,
        'printerRecordId': 'kitchen-eth',
        'isAvailable': true,
        'canPrint': true,
      }, os: DesktopPrinterOs.macos);
    }

    test('completed snapshot includes backend ip queue bytes_sent', () {
      final verification = BridgePrintDispatchVerification.verify(
        response: <String, dynamic>{
          'ok': true,
          'actual_backend': 'tcp',
          'bytes_sent': 512,
          'physical_confirmation': true,
        },
        printer: tcpPrinter(),
      );
      final snapshot = BridgePrintDispatchVerification.buildJobObservabilitySnapshot(
        verification: verification,
        jobId: 'job-1',
        orderId: 'order-1',
        role: 'mutfak',
        stationName: 'Ocak',
        printerName: 'Kitchen Ethernet',
        ip: '192.168.1.10',
        port: '9100',
        queueName: 'Kitchen Ethernet',
        retryCount: 0,
      );

      expect(snapshot['backend'], 'tcp');
      expect(snapshot['ip'], '192.168.1.10');
      expect(snapshot['port'], '9100');
      expect(snapshot['queue_name'], 'Kitchen Ethernet');
      expect(snapshot['bytes_sent'], 512);
      expect(snapshot['countsAsJobCompleted'], isTrue);
    });

    test('failed job snapshot carries error_message', () {
      final verification = BridgePrintDispatchVerification.verify(
        response: <String, dynamic>{
          'ok': false,
          'error_code': 'bridge_offline',
        },
        printer: tcpPrinter(),
      );
      final snapshot = BridgePrintDispatchVerification.buildJobObservabilitySnapshot(
        verification: verification,
        jobId: 'job-fail',
      );

      expect(snapshot['ok'], isFalse);
      expect(snapshot['countsAsJobCompleted'], isFalse);
      expect(snapshot['error_code'], 'bridge_offline');
    });

    test('used_fallback=true never counts as completed', () {
      final verification = BridgePrintDispatchVerification.verify(
        response: <String, dynamic>{
          'ok': true,
          'used_fallback': true,
          'actual_backend': 'cups',
        },
        printer: tcpPrinter(),
      );

      expect(verification.countsAsJobCompleted, isFalse);
    });

    test('backend mismatch never counts as completed', () {
      final verification = BridgePrintDispatchVerification.verify(
        response: <String, dynamic>{
          'ok': true,
          'actual_backend': 'cups',
          'selected_backend': 'tcp',
          'bytes_sent': 100,
        },
        printer: tcpPrinter(),
      );

      expect(verification.countsAsJobCompleted, isFalse);
      expect(verification.backendMismatch, isTrue);
    });

    test('PrintJobModel exposes retry and connection summary', () {
      final job = PrintJobModel.fromMap(<String, dynamic>{
        'id': 'job-ui',
        'restaurant_id': 'rest-1',
        'order_id': 'order-1',
        'job_type': 'new_order',
        'status': 'failed',
        'retry_count': 2,
        'last_error': 'Yazıcıya bağlanılamadı. IP adresini ve kabloyu kontrol edin.',
        'created_at': DateTime.now().toIso8601String(),
        'payload': <String, dynamic>{
          'station_name': 'Ocak',
          'printer_name': 'Kitchen Ethernet',
          'printer_role': 'mutfak',
          'selected_printer_backend': 'tcp',
          'selected_printer_host': '192.168.1.10',
          'selected_printer_port': 9100,
          'dispatch_verification': <String, dynamic>{
            'backend': 'tcp',
            'ip': '192.168.1.10',
            'port': '9100',
            'bytes_sent': 128,
          },
        },
      });

      expect(job.retryCount, 2);
      expect(job.roleLabel, 'Mutfak');
      expect(job.backendLabel, 'Ethernet');
      expect(job.connectionSummary, '192.168.1.10:9100');
      expect(job.canManualRetry, isTrue);
      expect(job.displayStatusLabel(), 'Başarısız');
    });

    test('CUPS unverified completed job is labeled Doğrulanamadı', () {
      final job = PrintJobModel.fromMap(<String, dynamic>{
        'id': 'job-unverified',
        'restaurant_id': 'rest-1',
        'order_id': 'order-1',
        'job_type': 'new_order',
        'status': 'completed',
        'retry_count': 0,
        'created_at': DateTime.now().toIso8601String(),
        'payload': <String, dynamic>{
          'dispatch_verification_status': 'ready_unverified',
          'dispatch_verification': <String, dynamic>{
            'ready_unverified': true,
            'verification_status': 'ready_unverified',
          },
        },
      });

      expect(job.isUnverifiedCompleted, isTrue);
      expect(job.displayStatusLabel(), 'Doğrulanamadı');
    });

    test('diagnostics report includes failed jobs and role mappings', () {
      final failedJob = PrintJobModel.fromMap(<String, dynamic>{
        'id': 'job-failed',
        'restaurant_id': 'rest-1',
        'order_id': 'order-9',
        'job_type': 'new_order',
        'status': 'failed',
        'retry_count': 1,
        'last_error': 'Bridge çalışmıyor. Yazıcı köprüsünü başlatın.',
        'created_at': DateTime.now().toIso8601String(),
        'payload': <String, dynamic>{
          'printer_role': 'adisyon',
          'printer_name': 'Adisyon',
        },
      });

      final report = RestaurantPrinterDiagnosticsReportBuilder.build(
        restaurantId: 'rest-1',
        bridgeHealth: const <String, dynamic>{'ok': false},
        roleMappings: const <String, dynamic>{
          'receipt_printer_id': 'db-receipt',
          'kitchen_printer_id': 'db-kitchen',
        },
        recentFailedJobs: <PrintJobModel>[failedJob],
      );

      expect(report, contains('rest-1'));
      expect(report, contains('job-failed'));
      expect(report, contains('receipt_printer_id'));
      expect(report, contains('Bridge çalışmıyor'));
    });

    test('manual retry cap is shared between model and repository', () {
      expect(PrintJobRepository.maxManualRetries, PrintJobModel.maxManualRetries);
      expect(PrintJobModel.maxManualRetries, 8);
    });
  });
}
