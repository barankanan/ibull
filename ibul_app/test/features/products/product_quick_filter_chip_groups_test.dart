import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/products/helpers/product_quick_filter_chip_groups.dart';
import 'package:ibul_app/features/products/models/product_filter_models.dart';
import 'package:ibul_app/features/products/widgets/product_quick_filter_bottom_sheet.dart';
import 'package:ibul_app/models/product_model.dart';

void main() {
  group('ProductQuickFilterChipGroups', () {
    const brandGroup = ProductFilterGroup(
      id: 'brand',
      title: 'Marka',
      type: ProductFilterGroupType.brand,
      options: [
        ProductFilterOption(id: 'Apple', label: 'Apple', value: 'Apple'),
        ProductFilterOption(id: 'Samsung', label: 'Samsung', value: 'Samsung'),
      ],
    );

    const dynamicBrandGroup = ProductFilterGroup(
      id: 'attribute_brand',
      title: 'Marka',
      type: ProductFilterGroupType.dynamicAttribute,
      options: [
        ProductFilterOption(id: 'Apple', label: 'Apple', value: 'Apple'),
      ],
    );

    const storageGroup = ProductFilterGroup(
      id: 'attr::Depolama',
      title: 'Depolama',
      type: ProductFilterGroupType.dynamicAttribute,
      options: [
        ProductFilterOption(id: '128', label: '128GB', value: '128GB'),
        ProductFilterOption(id: '256', label: '256GB', value: '256GB'),
      ],
    );

    const dynamicBrandAttrGroup = ProductFilterGroup(
      id: 'attr::Marka',
      title: 'Marka',
      type: ProductFilterGroupType.dynamicAttribute,
      options: [
        ProductFilterOption(id: 'Apple', label: 'Apple', value: 'Apple'),
      ],
    );

    test('dedupes brand and dynamic Marka into single chip', () {
      final result = ProductQuickFilterChipGroups.resolve([
        brandGroup,
        dynamicBrandAttrGroup,
        storageGroup,
      ]);

      expect(result, hasLength(2));
      expect(
        result.map(ProductQuickFilterChipGroups.quickChipDisplayLabel).toList(),
        ['Marka', 'Depolama'],
      );
      expect(result.first.type, ProductFilterGroupType.brand);
      expect(result.first.id, 'brand');
    });

    test('canonical key maps Marka aliases to brand', () {
      expect(
        ProductQuickFilterChipGroups.quickFilterCanonicalKey(brandGroup),
        'brand',
      );
      expect(
        ProductQuickFilterChipGroups.quickFilterCanonicalKey(dynamicBrandGroup),
        'brand',
      );
      expect(
        ProductQuickFilterChipGroups.quickFilterCanonicalKey(storageGroup),
        'storage',
      );
    });

    test('dedupeForRender keeps Marka once for brand + attribute_brand + storage', () {
      final result = ProductQuickFilterChipGroups.dedupeForRender([
        brandGroup,
        dynamicBrandGroup,
        storageGroup,
      ]);

      expect(result, hasLength(2));
      expect(
        result.map(ProductQuickFilterChipGroups.quickChipDisplayLabel).toList(),
        ['Marka', 'Depolama'],
      );
      expect(
        result.where((g) => g.title == 'Marka').length,
        1,
      );
    });

    test('dedupeAndSort keeps Marka exactly once for duplicate inputs', () {
      final deduped = ProductQuickFilterChipGroups.dedupeAndSort([
        brandGroup,
        dynamicBrandGroup,
        storageGroup,
      ]);

      final labels = deduped
          .map(ProductQuickFilterChipGroups.quickChipDisplayLabel)
          .toList();

      expect(labels.where((label) => label == 'Marka').length, 1);
      expect(labels, contains('Depolama'));
    });
  });

  testWidgets('deduped Marka chip opens brand-only sheet', (tester) async {
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
                    currentState: const ProductFilterState(),
                    baseProducts: [
                      Product(
                        name: 'Telefon',
                        brand: 'Apple',
                        price: '1000 TL',
                        rating: 4,
                        reviewCount: 1,
                        tags: const [],
                        images: const [],
                      ),
                    ],
                    onApply: (_) {},
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Marka seç'), findsOneWidget);
  });

  testWidgets('deduped Depolama chip opens storage-only sheet', (tester) async {
    const storageGroup = ProductFilterGroup(
      id: 'attr::Depolama',
      title: 'Depolama',
      type: ProductFilterGroupType.dynamicAttribute,
      options: [
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
                    baseProducts: [
                      Product(
                        name: 'Telefon',
                        brand: 'Apple',
                        price: '1000 TL',
                        rating: 4,
                        reviewCount: 1,
                        tags: const [],
                        images: const [],
                        specifications: '{"Depolama":"256GB"}',
                      ),
                    ],
                    onApply: (_) {},
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Depolama seç'), findsOneWidget);
    expect(find.text('Marka seç'), findsNothing);
  });
}
