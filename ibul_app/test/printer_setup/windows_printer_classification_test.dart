import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/desktop_printer_setup_models.dart';
import 'package:ibul_app/models/windows_printer_classification.dart';

void main() {
  test('Fax is not recommended and not selectable', () {
    final printer = UnifiedPrinterModel.fromBridgeMap(
      <String, dynamic>{
        'id': 'windows:Fax',
        'name': 'Fax',
        'queue': 'Fax',
        'backend': 'windows-spool',
        'statusLevel': 'ready',
        'ready': true,
      },
      os: DesktopPrinterOs.windows,
    );

    expect(printer.raw['operatorTier'], 'not_recommended');
    expect(printer.canPrint, isFalse);
    expect(isSelectableLivePrinter(printer), isFalse);
  });

  test('Generic Text Only shows ESC/POS warning', () {
    final profile = WindowsPrinterClassification.profileFor(
      name: 'Generic / Text Only (Kopya 1)',
    );
    expect(profile.warningCode, 'generic_text_only');
    expect(profile.selectionWarning, isNotNull);
  });

  test('pos-58 is POS candidate and can print when ready', () {
    final printer = UnifiedPrinterModel.fromBridgeMap(
      <String, dynamic>{
        'id': 'windows:pos-58',
        'name': 'pos-58',
        'queue': 'pos-58',
        'backend': 'windows-spool',
        'statusLevel': 'ready',
        'ready': true,
        'operatorTier': 'pos_candidate',
        'isPosCandidate': true,
      },
      os: DesktopPrinterOs.windows,
    );

    expect(printer.raw['isPosCandidate'], isTrue);
    expect(printer.canPrint, isTrue);
    expect(isSelectableLivePrinter(printer), isTrue);
  });

  test('formatTestFailureDetails includes spool fields', () {
    final details = WindowsPrinterClassification.formatTestFailureDetails(
      <String, dynamic>{
        'error': 'RAW print failed',
        'selected_queue': 'Generic / Text Only',
        'job_id': '42',
        'spool_jobs_after_print': 1,
      },
    );
    expect(details, contains('Generic / Text Only'));
    expect(details, contains('42'));
  });

  test('formatTestFailureDetails includes client timeout spool snapshot', () {
    final details = WindowsPrinterClassification.formatTestFailureDetails(
      <String, dynamic>{
        'errorCode': 'client_timeout',
        'timeoutMs': 15000,
        'printer_name': 'POS-58',
        'spool_latest_job_id': 12,
        'spool_active_job_ids': <int>[12],
        'spool_jobs_after_print': 1,
      },
    );
    expect(details, contains('POS-58'));
    expect(details, contains('12'));
    expect(details, contains('15000'));
  });

  test('formatTestFailureDetails includes pillow runtime fields', () {
    final details = WindowsPrinterClassification.formatTestFailureDetails(
      <String, dynamic>{
        'error': 'Bitmap baski icin Pillow gerekir',
        'pillow_available': false,
        'python_executable': r'C:\venv\python.exe',
        'import_error': 'No module named PIL',
      },
    );
    expect(details, contains('Pillow: yok'));
    expect(details, contains(r'C:\venv\python.exe'));
    expect(details, contains('No module named PIL'));
  });
}
