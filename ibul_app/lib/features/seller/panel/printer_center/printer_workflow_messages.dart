import '../../../../../services/local_print_service.dart';

String normalizePrinterWorkflowMessage(
  Object error, {
  required String fallback,
}) {
  if (error is LocalPrintServiceException &&
      error.details is Map<String, dynamic>) {
    final details = error.details! as Map<String, dynamic>;
    final errorCode = details['errorCode']?.toString().trim() ?? '';
    if (errorCode == 'cups_queue_busy' || errorCode == 'cups_queue_stuck') {
      final queue =
          details['printer_queue']?.toString().trim() ??
          details['queue']?.toString().trim() ??
          '';
      return queue.isNotEmpty
          ? 'Yazıcı kuyruğu meşgul ($queue). '
                "Sistem Ayarları > Yazıcılar'dan kuyruğu temizleyin veya USB'yi çıkarıp takın."
          : 'Yazıcı kuyruğu meşgul. '
                "Sistem Ayarları > Yazıcılar'dan kuyruğu temizleyin veya USB'yi çıkarıp takın.";
    }
  }
  final rawMessage = error.toString().replaceFirst('Exception: ', '').trim();
  if (rawMessage.isEmpty) {
    return fallback;
  }
  final normalized = rawMessage.toLowerCase();
  if (normalized.contains('macos yazıcıyı kilitledi')) {
    return 'macOS yazıcıyı kilitledi. Sistem Ayarları > Yazıcılar içinde '
        'POS58/CUPS kaydini kaldirin, sonra gelen izin penceresinden USB '
        'kilidini acin.';
  }
  if (normalized.contains('cups_queue_busy') ||
      normalized.contains('cups_queue_stuck') ||
      normalized.contains('kuyruğunda bekleyen işler var')) {
    return 'Yazıcı kuyruğu meşgul. '
        "Sistem Ayarları > Yazıcılar'dan kuyruğu temizleyin veya USB'yi çıkarıp takın.";
  }
  if (normalized.contains('aktif yazdirma yetkisi yok') ||
      normalized.contains('bu restoranda aktif') ||
      normalized.contains('bu restoran için işlem yetkiniz yok') ||
      normalized.contains('permission denied') ||
      normalized.contains('row-level security') ||
      normalized.contains('42501')) {
    return rawMessage;
  }
  return rawMessage;
}
