import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/home_product_preview.dart';
import 'package:ibul_app/screens/home/sections/ibul_nearby_products_section.dart';
import 'package:ibul_app/widgets/home_product_preview_card.dart';

void main() {
  testWidgets('IbulNearbyProductsSection uses legacy rail height', (tester) async {
    const previews = [
      HomeProductPreview(
        id: '1',
        name: 'Test Ürün',
        imageUrl: '',
        price: 100,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IbulNearbyProductsSection(
            previews: previews,
            isLoading: false,
          ),
        ),
      ),
    );

    final rail = tester.widget<SizedBox>(
      find.descendant(
        of: find.byType(IbulNearbyProductsSection),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is SizedBox &&
              widget.height == HomeProductPreviewCard.defaultHeight,
        ),
      ).first,
    );
    expect(rail.height, 312);
  });
}
