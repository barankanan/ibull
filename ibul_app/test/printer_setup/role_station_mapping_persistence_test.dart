import 'package:flutter_test/flutter_test.dart';

/// Unit-level persistence helpers mirrored from KitchenPrintManagementPage.
String? coercePersistedPrinterSelectionId({
  required String? snapshotSelectedId,
  required List<Map<String, dynamic>> bridgePrinters,
}) {
  final id = snapshotSelectedId?.trim() ?? '';
  if (id.isEmpty) return null;
  for (final printer in bridgePrinters) {
    if (printer['isLive'] != true) continue;
    final bridgeId = printer['id']?.toString().trim() ?? '';
    final selectionId = printer['selectionId']?.toString().trim() ?? '';
    final recordId =
        printer['printerRecordId']?.toString().trim() ??
        printer['printer_record_id']?.toString().trim() ??
        '';
    if (bridgeId == id || selectionId == id || recordId == id) {
      return selectionId.isNotEmpty ? selectionId : bridgeId;
    }
  }
  return id;
}

String? persistedSelectionAfterSave({
  required String selected,
  required bool saveOk,
}) {
  return saveOk ? selected : null;
}

void main() {
  group('Role/station mapping persistence', () {
    test('mutfak printer selection survives empty bridge scan', () {
      const savedId = 'db-kitchen-80mm';
      final resolved = coercePersistedPrinterSelectionId(
        snapshotSelectedId: savedId,
        bridgePrinters: const <Map<String, dynamic>>[],
      );
      expect(resolved, savedId);
    });

    test('ocak printer selection survives stale bridge scan', () {
      const savedId = 'db-station-printer';
      final resolved = coercePersistedPrinterSelectionId(
        snapshotSelectedId: savedId,
        bridgePrinters: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'bridge-other',
            'isLive': true,
            'selectionId': 'bridge-other',
            'printerRecordId': 'other-record',
          },
        ],
      );
      expect(resolved, savedId);
    });

    test('save fail should not mark selection as persisted', () {
      expect(
        persistedSelectionAfterSave(selected: 'printer-a', saveOk: false),
        isNull,
      );
    });

    test('save success marks selection as persisted', () {
      expect(
        persistedSelectionAfterSave(selected: 'printer-a', saveOk: true),
        'printer-a',
      );
    });
  });
}
