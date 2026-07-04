import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/printer_center/widgets/printer_receipt_length_settings_section.dart';
import 'package:ibul_app/services/print_tail_padding_policy.dart';
import 'package:ibul_app/services/printer_receipt_length_settings.dart';

void main() {
  testWidgets('receipt length dropdown is visible', (tester) async {
    var settings = PrinterReceiptLengthSettings.normal;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrinterReceiptLengthSettingsSection(
            paperWidthMm: 80,
            settings: settings,
            onChanged: (PrinterReceiptLengthSettings next) => settings = next,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('receipt_length_dropdown')), findsOneWidget);
    expect(find.text('Fiş Uzunluğu'), findsOneWidget);
  });

  testWidgets('short normal long custom options are available', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrinterReceiptLengthSettingsSection(
            paperWidthMm: 80,
            settings: PrinterReceiptLengthSettings.normal,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('receipt_length_dropdown')));
    await tester.pumpAndSettle();
    expect(find.text('Kısa'), findsOneWidget);
    expect(find.text('Normal'), findsWidgets);
    expect(find.text('Uzun'), findsOneWidget);
    expect(find.text('Özel'), findsOneWidget);
  });

  testWidgets('custom selection reveals advanced fields', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrinterReceiptLengthSettingsSection(
            paperWidthMm: 80,
            settings: const PrinterReceiptLengthSettings(
              preset: ReceiptLengthPreset.custom,
              bottomFeedLines: 9,
              cutFeedLines: 7,
              minTrailingBlankLines: 9,
              bottomPaddingPx: 200,
              minReceiptHeightPx: 800,
            ),
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('receipt_length_advanced_fields')), findsOneWidget);
    expect(find.text('Alt boşluk satırı'), findsOneWidget);
    expect(find.text('Minimum fiş yüksekliği'), findsOneWidget);
  });

  testWidgets('changing preset updates callback', (tester) async {
    PrinterReceiptLengthSettings settings = PrinterReceiptLengthSettings.normal;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return PrinterReceiptLengthSettingsSection(
                paperWidthMm: 80,
                settings: settings,
                onChanged: (PrinterReceiptLengthSettings next) =>
                    setState(() => settings = next),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('receipt_length_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Uzun').last);
    await tester.pumpAndSettle();
    expect(settings.preset, ReceiptLengthPreset.long);
  });
}
