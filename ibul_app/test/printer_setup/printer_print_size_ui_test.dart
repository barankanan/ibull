import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/printer_center/widgets/printer_print_size_settings_section.dart';
import 'package:ibul_app/services/printer_print_size_settings.dart';

void main() {
  testWidgets('Baskı Boyutu chips render and change selection', (tester) async {
    var current = PrinterPrintSizeSettings.normal;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return PrinterPrintSizeSettingsSection(
                settings: current,
                onChanged: (value) => setState(() => current = value),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Baskı Boyutu'), findsOneWidget);
    expect(find.text('Yazı Boyutu'), findsOneWidget);
    expect(find.byKey(const Key('print_size_chips')), findsOneWidget);

    await tester.tap(find.byKey(const Key('print_size_large')));
    await tester.pumpAndSettle();
    expect(current.preset, PrintSizePreset.large);

    await tester.tap(find.byKey(const Key('print_size_xlarge')));
    await tester.pumpAndSettle();
    expect(current.preset, PrintSizePreset.xlarge);
  });
}
