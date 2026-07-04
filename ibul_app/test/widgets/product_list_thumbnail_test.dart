import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/widgets/product_list_thumbnail.dart';

void main() {
  testWidgets('ProductListThumbnail uses contain fit for network images', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProductListThumbnail(
            imageUrlOrPath: 'https://example.com/product.jpg',
            width: 120,
            height: 120,
          ),
        ),
      ),
    );

    final imageFinder = find.byType(Image);
    expect(imageFinder, findsOneWidget);

    final image = tester.widget<Image>(imageFinder);
    expect(image.fit, BoxFit.contain);
  });

  testWidgets('ProductListThumbnail shows fallback when url empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProductListThumbnail(
            imageUrlOrPath: null,
            width: 80,
            height: 80,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
  });
}
