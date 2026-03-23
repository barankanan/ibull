import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/screens/seller/admin_panel_page.dart';

void main() {
  testWidgets('Dashboard stat kartları ilgili modüllere geçirir', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: AdminPanelPage(),
      ),
    );
    await tester.pump();

    expect(find.text('Dashboard'), findsWidgets);

    await tester.tap(find.text('Toplam Sipariş'));
    await tester.pump();
    expect(find.text('Sipariş & İade'), findsOneWidget);

    await tester.tap(find.text('Bugünkü Ciro'));
    await tester.pump();
    expect(find.text('Finans & Hakediş'), findsOneWidget);
  }, skip: true);
}
