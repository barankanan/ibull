import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/printer_error_messages.dart';

void main() {
  test('cups_queue_stuck maps to clear-queue action', () {
    final p = presentPrinterErrorCode(
      'cups_queue_stuck',
      platform: TargetPlatform.macOS,
      canClearQueue: true,
    );
    expect(p.title, contains('kuyruğu'));
    expect(p.canClearQueue, isTrue);
    expect(p.primaryActionLabel, 'Kuyruğu Temizle');
  });

  test('bridge_unreachable on Windows maps to download installer', () {
    final p = presentPrinterErrorCode(
      'bridge_unreachable',
      platform: TargetPlatform.windows,
    );
    expect(p.canDownloadInstaller, isTrue);
    expect(p.primaryActionLabel, 'Uygulamayı İndir');
  });

  test('stale_printer maps to rescan', () {
    final p = presentPrinterErrorCode(
      'stale_printer',
      platform: TargetPlatform.macOS,
    );
    expect(p.primaryActionLabel, 'Yeniden Tara');
    expect(p.severity, PrinterErrorSeverity.warning);
  });

  test('installer_missing has deploy/hosting hint', () {
    final p = presentPrinterErrorCode(
      'installer_missing',
      platform: TargetPlatform.windows,
    );
    expect(p.message, contains('IbulSellerSetup.exe'));
  });
}

