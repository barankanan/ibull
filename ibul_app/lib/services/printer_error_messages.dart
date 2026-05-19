import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kDebugMode, kIsWeb;

import '../widgets/bridge_error_dialog.dart';

enum PrinterErrorSeverity { info, warning, error }

class PrinterErrorPresentation {
  const PrinterErrorPresentation({
    required this.code,
    required this.title,
    required this.message,
    this.primaryActionLabel,
    this.secondaryActionLabel,
    this.severity = PrinterErrorSeverity.error,
    this.canRetry = true,
    this.canClearQueue = false,
    this.canOpenLogs = false,
    this.canDownloadInstaller = false,
  });

  final String code;
  final String title;
  final String message;
  final String? primaryActionLabel;
  final String? secondaryActionLabel;
  final PrinterErrorSeverity severity;
  final bool canRetry;
  final bool canClearQueue;
  final bool canOpenLogs;
  final bool canDownloadInstaller;
}

TargetPlatform _platform() {
  if (kIsWeb) return TargetPlatform.windows;
  return defaultTargetPlatform;
}

PrinterErrorPresentation presentPrinterError(BridgeStructuredError error) {
  return presentPrinterErrorCode(
    error.errorCode,
    platform: _platform(),
    canClearQueue: error.canClearQueue,
  );
}

PrinterErrorPresentation presentPrinterErrorCode(
  String code, {
  TargetPlatform? platform,
  bool canClearQueue = false,
}) {
  final normalized = code.trim().isEmpty ? 'unknown' : code.trim();
  final p = platform ?? _platform();
  final isWindows = p == TargetPlatform.windows;

  switch (normalized) {
    case 'bridge_unreachable':
    case 'bridge_not_running':
      return PrinterErrorPresentation(
        code: normalized,
        title: 'Yazıcı servisi çalışmıyor',
        message: isWindows
            ? 'Yazıcı servisi kurulu değil veya çalışmıyor. Ibul Satıcı Windows uygulamasını indirip kurun, sonra tekrar deneyin.'
            : 'Yazıcı servisine ulaşılamadı. Servisi başlatın, sonra tekrar deneyin.',
        primaryActionLabel: isWindows ? 'Uygulamayı İndir' : 'Tekrar Dene',
        secondaryActionLabel: isWindows ? 'Logları Aç' : null,
        severity: PrinterErrorSeverity.error,
        canRetry: true,
        canOpenLogs: isWindows,
        canDownloadInstaller: isWindows,
      );
    case 'printer_not_found':
      return const PrinterErrorPresentation(
        code: 'printer_not_found',
        title: 'Yazıcı bulunamadı',
        message: 'Seçili yazıcı şu an bağlı değil. Kabloyu kontrol edip yeniden tarayın.',
        primaryActionLabel: 'Yeniden Tara',
        secondaryActionLabel: 'Tekrar Dene',
        severity: PrinterErrorSeverity.warning,
        canRetry: true,
      );
    case 'cups_queue_stuck':
      return PrinterErrorPresentation(
        code: normalized,
        title: 'Mac yazıcı kuyruğu takıldı',
        message: 'CUPS kuyruğu takılmış görünüyor. Kuyruğu temizleyip tekrar deneyin.',
        primaryActionLabel: 'Kuyruğu Temizle',
        secondaryActionLabel: 'Tekrar Dene',
        severity: PrinterErrorSeverity.error,
        canRetry: true,
        canClearQueue: true,
      );
    case 'cups_queue_busy':
      return PrinterErrorPresentation(
        code: normalized,
        title: 'Mac yazıcı kuyruğu meşgul',
        message: 'Yazıcı hâlâ önceki işi işliyor. Birkaç saniye bekleyin veya kuyruğu temizleyin.',
        primaryActionLabel: canClearQueue ? 'Kuyruğu Temizle' : 'Tekrar Dene',
        secondaryActionLabel: canClearQueue ? 'Tekrar Dene' : null,
        severity: PrinterErrorSeverity.warning,
        canRetry: true,
        canClearQueue: canClearQueue,
      );
    case 'duplicate_printer':
      return const PrinterErrorPresentation(
        code: 'duplicate_printer',
        title: 'Aynı yazıcı birden fazla görünüyor',
        message: 'Bu yazıcı birden fazla bağlantı yöntemiyle görünüyor. Mac için genelde CUPS önerilir.',
        primaryActionLabel: 'Önerilen Seçeneği Kullan',
        secondaryActionLabel: 'Alternatifi Seç',
        severity: PrinterErrorSeverity.warning,
        canRetry: false,
      );
    case 'stale_printer':
      return const PrinterErrorPresentation(
        code: 'stale_printer',
        title: 'Kayıtlı yazıcı bağlı değil',
        message: 'Bu yazıcı daha önce kayıtlıydı ama şu an bağlı değil. Yazıcıyı bağlayıp yeniden tarayın.',
        primaryActionLabel: 'Yeniden Tara',
        secondaryActionLabel: 'Ayarları Aç',
        severity: PrinterErrorSeverity.warning,
        canRetry: true,
      );
    case 'permission_denied':
      return const PrinterErrorPresentation(
        code: 'permission_denied',
        title: 'Erişim izni yok',
        message: 'Yazıcıya erişim izni yok. Uygulamayı yeniden başlatın veya sistem izinlerini kontrol edin.',
        primaryActionLabel: 'Tekrar Dene',
        secondaryActionLabel: 'Detayları Göster',
        severity: PrinterErrorSeverity.error,
        canRetry: true,
      );
    case 'windows_spooler_error':
      return const PrinterErrorPresentation(
        code: 'windows_spooler_error',
        title: 'Windows spooler yanıt vermiyor',
        message: 'Windows Yazdırma Biriktiricisi (Spooler) yanıt vermiyor. Hizmeti yeniden başlatın ve tekrar deneyin.',
        primaryActionLabel: 'Tekrar Dene',
        secondaryActionLabel: 'Logları Aç',
        severity: PrinterErrorSeverity.error,
        canRetry: true,
        canOpenLogs: true,
      );
    case 'installer_missing':
      return PrinterErrorPresentation(
        code: 'installer_missing',
        title: 'Kurulum dosyası bulunamadı',
        message: kDebugMode
            ? 'Kurulum dosyası sunucuda bulunamadı. Lütfen deploy paketini kontrol edin.\n'
                  'Teknik: build/web/downloads/IbulSellerSetup.exe staging + Firebase Hosting deploy.'
            : 'Kurulum dosyası şu an indirilemiyor. Lütfen daha sonra tekrar deneyin.',
        primaryActionLabel: kDebugMode ? 'Deploy Kontrolü' : 'Tekrar Dene',
        secondaryActionLabel: kDebugMode ? 'Tekrar Dene' : null,
        severity: PrinterErrorSeverity.error,
        canRetry: true,
      );
    case 'print_system_disabled':
      return const PrinterErrorPresentation(
        code: 'print_system_disabled',
        title: 'Baskı sistemi kapalı',
        message: 'Baskı sistemi kapalı. Test göndermek için sistemi açın.',
        primaryActionLabel: 'Baskı Sistemini Aç',
        secondaryActionLabel: 'Detayları Göster',
        severity: PrinterErrorSeverity.warning,
        canRetry: false,
      );
    case 'role_save_failed':
      return const PrinterErrorPresentation(
        code: 'role_save_failed',
        title: 'Ayarlar kaydedilemedi',
        message: 'Test başarılı olabilir ama rol/ayar kaydı tamamlanamadı. Tekrar kaydetmeyi deneyin.',
        primaryActionLabel: 'Tekrar Kaydet',
        secondaryActionLabel: 'Detayları Göster',
        severity: PrinterErrorSeverity.error,
        canRetry: true,
      );
    default:
      return PrinterErrorPresentation(
        code: normalized,
        title: 'Yazdırma hatası',
        message: 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.',
        primaryActionLabel: 'Tekrar Dene',
        secondaryActionLabel: 'Detayları Göster',
        severity: PrinterErrorSeverity.error,
        canRetry: true,
        canClearQueue: canClearQueue,
        canDownloadInstaller: isWindows,
      );
  }
}

