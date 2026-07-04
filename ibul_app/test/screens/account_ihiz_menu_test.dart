import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/screens/ihiz_courier_page.dart';
import 'package:ibul_app/screens/ihiz_home_page.dart';

void main() {
  testWidgets('IhizHomePage shows service cards and prototype entry', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: IhizHomePage()),
    );

    expect(find.text('iHız'), findsOneWidget);
    expect(
      find.text('Hızlı teslimat ve hizmet çözümleri yakında burada.'),
      findsOneWidget,
    );
    expect(find.text('Teslimat Prototipi'), findsOneWidget);
    expect(find.text('Hızlı Ürün Gönder'), findsOneWidget);
    expect(find.text('Garantili Tamir'), findsOneWidget);
    expect(find.text('Montaj Hizmeti'), findsOneWidget);
    expect(find.text('Yakında'), findsNWidgets(3));
  });

  testWidgets('IhizHomePage prototype card opens courier page', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: IhizHomePage()),
    );

    await tester.tap(find.text('Teslimat Prototipi'));
    await tester.pumpAndSettle();

    expect(find.byType(IhizCourierPage), findsOneWidget);
  });
}
