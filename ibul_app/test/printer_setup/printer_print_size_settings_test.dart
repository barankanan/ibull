import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/printer_model.dart';
import 'package:ibul_app/services/printer_print_size_settings.dart';

void main() {
  group('PrinterPrintSizeSettings', () {
    test('default is normal / 1.0', () {
      expect(PrinterPrintSizeSettings.normal.preset, PrintSizePreset.normal);
      expect(PrintSizePreset.normal.textScale, 1.0);
      expect(PrintSizePreset.small.textScale, 0.85);
      expect(PrintSizePreset.large.textScale, 1.20);
      expect(PrintSizePreset.xlarge.textScale, 1.40);
    });

    test('fromPrinterModel reads print_size', () {
      final printer = PrinterModel(
        id: 'p1',
        restaurantId: 'r1',
        name: 'Mutfak',
        code: 'K1',
        connectionType: 'network',
        paperWidthMm: 80,
        isActive: true,
        createdAt: DateTime(2026),
        printSize: 'large',
      );
      final settings = PrinterPrintSizeSettings.fromPrinterModel(printer);
      expect(settings.preset, PrintSizePreset.large);
      expect(settings.toDbFields()['print_size'], 'large');
      expect(settings.toBridgeFields()['print_text_scale'], 1.20);
    });

    test('missing print_size defaults to normal', () {
      final settings = PrinterPrintSizeSettings.fromMap(const {});
      expect(settings.preset, PrintSizePreset.normal);
    });

    test('live bridge fields mark override', () {
      final fields = PrinterPrintSizeSettings(
        preset: PrintSizePreset.xlarge,
      ).toLiveBridgeFields();
      expect(fields['print_size'], 'xlarge');
      expect(fields['print_size_live_override'], true);
      expect(fields['print_size_source'], 'live_form');
    });

    test('resolveForDispatch prefers live override', () {
      final resolved = PrinterPrintSizeSettings.resolveForDispatch(
        printerRaw: const {'print_size': 'small'},
        payload: const {'print_size': 'large'},
        liveOverride: const PrinterPrintSizeSettings(
          preset: PrintSizePreset.xlarge,
        ),
      );
      expect(resolved.preset, PrintSizePreset.xlarge);
    });
  });
}
