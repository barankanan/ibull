import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/widgets/web_footer.dart';

void main() {
  testWidgets('WebFooter Admin Paneli linki gorunur', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 120),
                Text('HOME_PAGE'),
                SizedBox(height: 24),
                WebFooter(),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('HOME_PAGE'), findsOneWidget);
    expect(find.text('Admin Paneli'), findsOneWidget);
  });

  testWidgets('WebFooter Ihiz linki ihiz sayfasina gider', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 200),
                Text('HOME_PAGE'),
                SizedBox(height: 24),
                WebFooter(),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('İhız').last, 300);
    await tester.tap(find.text('İhız').last);
    await tester.pumpAndSettle();

    expect(
      find.text('Telefon ekranı için tasarlanmış kurye akışı'),
      findsOneWidget,
    );
    expect(find.text('HOME_PAGE'), findsNothing);
  });
}
