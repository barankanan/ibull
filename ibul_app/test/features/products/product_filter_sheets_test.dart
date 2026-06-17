import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/products/models/product_filter_models.dart';
import 'package:ibul_app/features/products/widgets/product_filter_bottom_sheet.dart';
import 'package:ibul_app/features/products/widgets/product_sort_bottom_sheet.dart';

void main() {
  testWidgets('mobile sort sheet opens', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  ProductSortBottomSheet.show(
                    context: context,
                    initialSort: ProductSortOption.recommended,
                    onApply: (_) {},
                  );
                },
                child: const Text('Open Sort'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open Sort'));
    await tester.pumpAndSettle();

    expect(find.byType(ProductSortBottomSheet), findsOneWidget);
    expect(find.text('En düşük fiyat'), findsOneWidget);
  });

  testWidgets('mobile filter sheet opens', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  ProductFilterBottomSheet.show(
                    context: context,
                    groups: const [
                      ProductFilterGroup(
                        id: 'brand',
                        title: 'Marka',
                        type: ProductFilterGroupType.brand,
                        options: [
                          ProductFilterOption(
                            id: 'Test Marka',
                            label: 'Test Marka',
                            value: 'Test Marka',
                          ),
                        ],
                      ),
                    ],
                    initialState: const ProductFilterState(),
                    previewCount: (_) => 1,
                    onApply: (_) {},
                  );
                },
                child: const Text('Open Filter'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open Filter'));
    await tester.pumpAndSettle();

    expect(find.text('Marka'), findsWidgets);
    expect(find.text('1 ürünü göster'), findsOneWidget);
  });

  testWidgets('sort sheet apply returns selected option', (tester) async {
    ProductSortOption? applied;
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductSortBottomSheet(
            initialSort: ProductSortOption.recommended,
            onApply: (value) => applied = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('En düşük fiyat'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Uygula'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Uygula'));
    await tester.pumpAndSettle();

    expect(applied, ProductSortOption.priceAsc);
  });
}
