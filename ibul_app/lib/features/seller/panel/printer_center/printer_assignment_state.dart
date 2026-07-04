import '../../../../../models/desktop_printer_setup_models.dart';
import '../../../../../models/printer_model.dart';

/// Pure helpers for role/station printer selection merge + normalization.
///
/// Keeps persisted DB ids visible even when live bridge scan is empty.
class PrinterAssignmentState {
  const PrinterAssignmentState._();

  static bool roleMappingsDirty({
    required String? selectedReceiptPrinterId,
    required String? selectedKitchenPrinterId,
    required String? persistedReceiptPrinterId,
    required String? persistedKitchenPrinterId,
  }) {
    final receiptChanged =
        (selectedReceiptPrinterId ?? '').trim() !=
        (persistedReceiptPrinterId ?? '').trim();
    final kitchenChanged =
        (selectedKitchenPrinterId ?? '').trim() !=
        (persistedKitchenPrinterId ?? '').trim();
    return receiptChanged || kitchenChanged;
  }

  /// Keeps persisted DB selection even when bridge live scan is empty/stale.
  static String? coercePersistedSelectionId({
    required String? snapshotSelectedId,
    required List<Map<String, dynamic>> bridgePrinters,
  }) {
    final id = snapshotSelectedId?.trim() ?? '';
    if (id.isEmpty) return null;
    for (final printer in bridgePrinters) {
      final bridgeId = printer['id']?.toString().trim() ?? '';
      final selectionId = printer['selectionId']?.toString().trim() ?? '';
      final recordId =
          printer['printerRecordId']?.toString().trim() ??
          printer['printer_record_id']?.toString().trim() ??
          '';
      if (bridgeId == id || selectionId == id || recordId == id) {
        if (recordId.isNotEmpty) return recordId;
        return selectionId.isNotEmpty ? selectionId : bridgeId;
      }
    }
    return id;
  }

  /// Dropdown source: active printers + persisted role picks + station mappings.
  static List<PrinterModel> mergePrinterOptions({
    required List<PrinterModel> activePrinters,
    required List<PrinterModel> allPrinters,
    Iterable<String?> extraPrinterIds = const <String?>[],
  }) {
    final merged = <String, PrinterModel>{
      for (final printer in activePrinters) printer.id: printer,
    };
    final allById = <String, PrinterModel>{
      for (final printer in allPrinters) printer.id: printer,
    };
    for (final rawId in extraPrinterIds) {
      final id = rawId?.trim() ?? '';
      if (id.isEmpty || merged.containsKey(id)) continue;
      final match = allById[id];
      if (match != null) {
        merged[id] = match;
      }
    }
    return merged.values.toList(growable: false);
  }

  static String? normalizeSelectedPrinterId({
    required List<PrinterModel> printers,
    required String? selectedPrinterId,
    required List<Map<String, dynamic>> bridgePrinters,
  }) {
    final id = selectedPrinterId?.trim() ?? '';
    if (id.isEmpty) return null;

    for (final printer in printers) {
      if (printer.id == id) return id;
    }

    for (final bridgePrinter in bridgePrinters) {
      final bridgeId = bridgePrinter['id']?.toString().trim() ?? '';
      final bridgeRecordId =
          bridgePrinter['printerRecordId']?.toString().trim() ??
          bridgePrinter['printer_record_id']?.toString().trim() ??
          '';
      if (id == bridgeId || id == bridgeRecordId) {
        if (bridgeRecordId.isNotEmpty &&
            printers.any((printer) => printer.id == bridgeRecordId)) {
          return bridgeRecordId;
        }
        if (printers.any((printer) => printer.id == bridgeId)) {
          return bridgeId;
        }
      }
    }

    // Persisted id not in live scan — keep if merged into printer list.
    if (printers.any((printer) => printer.id == id)) {
      return id;
    }
    return null;
  }

  static String? roleSelectionError({
    required PrinterSetupRole role,
    required String? selectedPrinterId,
    required List<PrinterModel> printers,
  }) {
    final id = selectedPrinterId?.trim() ?? '';
    if (id.isEmpty) {
      return role == PrinterSetupRole.adisyon
          ? 'Adisyon yazıcısı seçilmedi.'
          : 'Mutfak yazıcısı seçilmedi.';
    }
    PrinterModel? printer;
    for (final candidate in printers) {
      if (candidate.id == id) {
        printer = candidate;
        break;
      }
    }
    if (printer == null) {
      return 'Yazıcı kaydı bulunamadı.';
    }
    if (!printer.isActive) {
      return 'Seçili yazıcı aktif değil.';
    }
    return null;
  }
}
