import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/home_product_preview.dart';
import 'package:ibul_app/widgets/home_product_preview_card.dart';

void main() {
  group('HomeProductPreviewCard layout', () {
    const longNamePreview = HomeProductPreview(
      id: 'p1',
      name:
          'Urban Care Hyaluronic Saç Bakım Seti Extra Uzun Ürün Adı İki Satır Test',
      imageUrl: 'https://example.com/img.jpg',
      price: 499.99,
      discountPrice: 349.99,
      brand: 'Urban Care Professional Series',
      storeName: 'Örnek Mağaza Adı Çok Uzun',
    );

    Future<void> pumpCard(WidgetTester tester, HomeProductPreview preview) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: HomeProductPreviewCard(
                preview: preview,
                showStore: true,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('does not overflow in default 312px rail cell', (tester) async {
      await pumpCard(tester, longNamePreview);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows price and add button', (tester) async {
      await pumpCard(tester, longNamePreview);
      expect(find.textContaining('349.99'), findsOneWidget);
      expect(find.text('Sepete Ekle'), findsOneWidget);
    });

    testWidgets('shows quick view icon top-left', (tester) async {
      await pumpCard(tester, longNamePreview);
      expect(find.byIcon(Icons.remove_red_eye_outlined), findsOneWidget);
    });

    testWidgets('two-line product name fits without overflow', (tester) async {
      await pumpCard(tester, longNamePreview);
      final nameFinder = find.text(longNamePreview.name);
      expect(nameFinder, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
