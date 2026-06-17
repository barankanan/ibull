import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/products/models/product_filter_models.dart';
import 'package:ibul_app/features/products/widgets/product_filter_bottom_sheet.dart';
import 'package:ibul_app/features/products/widgets/product_quick_filter_bottom_sheet.dart';
import 'package:ibul_app/features/products/widgets/product_sort_bottom_sheet.dart';
import 'package:ibul_app/models/product_model.dart';

Product _sampleProduct({String brand = 'Apple'}) {
  return Product(
    name: 'Telefon',
    brand: brand,
    price: '10000 TL',
    rating: 4.5,
    reviewCount: 10,
    tags: const [],
    images: const [],
    specifications: '{"Depolama":"256GB"}',
  );
}

void main() {
  testWidgets('Marka quick chip opens brand-only sheet title', (tester) async {
    const brandGroup = ProductFilterGroup(
      id: 'brand',
      title: 'Marka',
      type: ProductFilterGroupType.brand,
      options: [
        ProductFilterOption(id: 'Apple', label: 'Apple', value: 'Apple'),
        ProductFilterOption(id: 'Samsung', label: 'Samsung', value: 'Samsung'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  ProductQuickFilterBottomSheet.show(
                    context: context,
                    group: brandGroup,
                    currentState: const ProductFilterState(),
                    baseProducts: [_sampleProduct()],
                    onApply: (_) {},
                  );
                },
                child: const Text('Open Brand'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open Brand'));
    await tester.pumpAndSettle();

    expect(find.text('Marka seç'), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('Fiyat Aralığı'), findsNothing);
  });

  testWidgets('Depolama quick chip opens storage-only sheet', (tester) async {
    const storageGroup = ProductFilterGroup(
      id: 'attr::Depolama',
      title: 'Depolama',
      type: ProductFilterGroupType.dynamicAttribute,
      options: [
        ProductFilterOption(id: '128', label: '128GB', value: '128GB'),
        ProductFilterOption(id: '256', label: '256GB', value: '256GB'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  ProductQuickFilterBottomSheet.show(
                    context: context,
                    group: storageGroup,
                    currentState: const ProductFilterState(),
                    baseProducts: [_sampleProduct()],
                    onApply: (_) {},
                  );
                },
                child: const Text('Open Storage'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open Storage'));
    await tester.pumpAndSettle();

    expect(find.text('Depolama seç'), findsOneWidget);
    expect(find.text('256GB'), findsOneWidget);
    expect(find.text('Marka seç'), findsNothing);
  });

  testWidgets('quick chip apply updates only brand state', (tester) async {
    ProductFilterState? applied;
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const brandGroup = ProductFilterGroup(
      id: 'brand',
      title: 'Marka',
      type: ProductFilterGroupType.brand,
      options: [
        ProductFilterOption(id: 'Apple', label: 'Apple', value: 'Apple'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  ProductQuickFilterBottomSheet.show(
                    context: context,
                    group: brandGroup,
                    currentState: const ProductFilterState(onlyDiscounted: true),
                    baseProducts: [_sampleProduct()],
                    onApply: (state) => applied = state,
                  );
                },
                child: const Text('Open Brand'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open Brand'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apple'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(ElevatedButton).last);
    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pumpAndSettle();

    expect(applied?.selectedBrands, {'Apple'});
    expect(applied?.onlyDiscounted, isTrue);
  });

  testWidgets('quick chip clear resets only its group', (tester) async {
    ProductFilterState? applied;
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const brandGroup = ProductFilterGroup(
      id: 'brand',
      title: 'Marka',
      type: ProductFilterGroupType.brand,
      options: [
        ProductFilterOption(id: 'Apple', label: 'Apple', value: 'Apple'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  ProductQuickFilterBottomSheet.show(
                    context: context,
                    group: brandGroup,
                    currentState: const ProductFilterState(
                      selectedBrands: {'Apple'},
                      onlyDiscounted: true,
                    ),
                    baseProducts: [_sampleProduct()],
                    onApply: (state) => applied = state,
                  );
                },
                child: const Text('Open Brand'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open Brand'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Temizle').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(ElevatedButton).last);
    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pumpAndSettle();

    expect(applied?.selectedBrands, isEmpty);
    expect(applied?.onlyDiscounted, isTrue);
  });

  testWidgets('full filter sheet still opens with all sections', (tester) async {
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
                            id: 'Apple',
                            label: 'Apple',
                            value: 'Apple',
                          ),
                        ],
                      ),
                      ProductFilterGroup(
                        id: 'price',
                        title: 'Fiyat Aralığı',
                        type: ProductFilterGroupType.priceRange,
                        minPrice: 0,
                        maxPrice: 1000,
                      ),
                    ],
                    initialState: const ProductFilterState(),
                    previewCount: (_) => 1,
                    onApply: (_) {},
                  );
                },
                child: const Text('Open Full Filter'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open Full Filter'));
    await tester.pumpAndSettle();

    expect(find.text('Filtrele'), findsWidgets);
    expect(find.text('Marka'), findsWidgets);
    expect(find.text('Fiyat Aralığı'), findsWidgets);
  });

  testWidgets('sort sheet opens independently', (tester) async {
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
    expect(find.text('Sıralama'), findsOneWidget);
  });
}
