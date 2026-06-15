import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ibul_app/screens/seller/printer_wizard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('add printer flow shows ethernet and standard choices', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () => showAddPrinterFlow(
                  context,
                  restaurantId: 'rest-1',
                ),
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Kurulum tipini seçin'), findsOneWidget);
    expect(find.text('Ethernet Yazıcı'), findsOneWidget);
    expect(find.text('Standart Yazıcı'), findsOneWidget);
    expect(find.byKey(const Key('add_printer_ethernet_card')), findsOneWidget);
    expect(find.byKey(const Key('add_printer_standard_card')), findsOneWidget);
  });

  testWidgets('ethernet card opens ethernet dialog with profile and test controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () => showAddPrinterFlow(
                  context,
                  restaurantId: 'rest-1',
                ),
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add_printer_ethernet_card')));
    await tester.pumpAndSettle();

    expect(find.text('Ethernet Yazıcı Ekle'), findsOneWidget);
    expect(find.byKey(const Key('ethernet_ip_field')), findsOneWidget);
    expect(find.byKey(const Key('ethernet_port_field')), findsOneWidget);
    expect(find.byKey(const Key('ethernet_name_field')), findsOneWidget);
    expect(find.text('Bağlantıyı Test Et'), findsOneWidget);
    expect(find.text('Test Fişi Gönder'), findsOneWidget);
    expect(find.byKey(const Key('ethernet_profile_pos80')), findsOneWidget);
    expect(find.text('POS-80'), findsOneWidget);
    expect(find.byKey(const Key('ethernet_auto_scan_button')), findsOneWidget);
  });
}
