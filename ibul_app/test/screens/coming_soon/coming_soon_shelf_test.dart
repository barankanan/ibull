import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/screens/coming_soon/coming_soon_catalog.dart';
import 'package:ibul_app/screens/coming_soon/coming_soon_shelf_page.dart';
import 'package:ibul_app/screens/feature_coming_soon_page.dart';

void main() {
  test('marketplace shelf lists the five unfinished marketplace features', () {
    expect(
      ComingSoonCatalog.marketplaceShelf.map((item) => item.id).toList(),
      ['premium', 'repair', 'assembly', 'barcode', 'app_feedback'],
    );
  });

  testWidgets('shelf lists items and opens an honest coming-soon page',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ComingSoonShelfPage()),
    );

    expect(find.text('Yakında'), findsOneWidget);
    expect(find.text('iBul Premium'), findsOneWidget);
    expect(find.text('Garantili Tamir'), findsOneWidget);
    expect(find.text('Montaj Hizmeti'), findsOneWidget);
    expect(find.text('Barkod Okut'), findsOneWidget);
    expect(find.text('Uygulama Görüşün'), findsOneWidget);

    await tester.tap(find.text('iBul Premium'));
    await tester.pumpAndSettle();

    expect(find.byType(FeatureComingSoonPage), findsOneWidget);
    expect(find.textContaining('abonelik sayfası değil'), findsOneWidget);
    expect(find.text('Beni haberdar et'), findsNothing);
  });
}
