import '../../../../../models/printer_model.dart';
import '../../../../../models/station_model.dart';
import '../../../../../models/station_printer_model.dart';

/// Validates station test preconditions with explicit user-facing messages.
class PrinterStationTestGuard {
  const PrinterStationTestGuard._();

  static String? validate({
    required StationModel station,
    required StationPrinterModel? primaryMapping,
    required PrinterModel? mappedPrinter,
    required bool printSystemEnabledLoaded,
    required bool printSystemEnabled,
    required bool queueRuntimeDisabled,
    required bool bridgeReachable,
    required bool testInFlight,
  }) {
    if (testInFlight) {
      return 'Test fişi zaten gönderiliyor, lütfen bekleyin.';
    }
    if (printSystemEnabledLoaded &&
        (queueRuntimeDisabled || !printSystemEnabled)) {
      return 'Baskı sistemi kapalı.';
    }
    if (!bridgeReachable) {
      return 'Yazıcı köprüsü çalışmıyor. Fiş basılamaz.';
    }
    if (primaryMapping == null) {
      return '${station.name} için yazıcı eşleştirmesi yok.';
    }
    if (mappedPrinter == null) {
      return 'Yazıcı kaydı bulunamadı.';
    }
    if (!mappedPrinter.isActive) {
      return 'Seçili yazıcı aktif değil.';
    }
    return null;
  }

  static String backendLabel(PrinterModel printer) {
    if (printer.isEthernetConnection) return 'Ethernet';
    if (printer.connectionType == PrinterModel.usbConnectionType) {
      return 'USB';
    }
    return printer.connectionType;
  }
}
