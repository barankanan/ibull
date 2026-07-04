import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/home_mobile_shortcut.dart';
import 'package:ibul_app/features/products/helpers/category_filter_config.dart';
import 'package:ibul_app/features/products/helpers/product_quick_filter_chip_groups.dart';
import 'package:ibul_app/features/products/models/product_filter_models.dart';

ProductFilterGroup _group({
  required String id,
  required String title,
  ProductFilterGroupType type = ProductFilterGroupType.dynamicAttribute,
  List<String> options = const ['A', 'B'],
}) {
  return ProductFilterGroup(
    id: id,
    title: title,
    type: type,
    options: options
        .map((o) => ProductFilterOption(id: o, label: o, value: o))
        .toList(),
  );
}

void main() {
  group('Hızlı Yemek filtre config', () {
    test('isFoodCategory Türkçe normalize', () {
      expect(CategoryFilterConfig.isFoodCategory('Yemek'), isTrue);
      expect(CategoryFilterConfig.isFoodCategory('yemek'), isTrue);
      expect(CategoryFilterConfig.isFoodCategory('Hızlı Yemek'), isTrue);
      expect(CategoryFilterConfig.isFoodCategory('Elektronik'), isFalse);
    });

    test('Hızlı Yemek action Yemek kategorisine map edilir', () {
      final action = HomeMobileShortcutRegistry.fromKey('hizli_yemek');
      expect(action!.type, HomeMobileShortcutType.fastFood);
      expect(action.categorySlug, 'Yemek');
    });

    test('food category chip config Beden içermez', () {
      final allGroups = [
        _group(id: 'brand', title: 'Marka', type: ProductFilterGroupType.brand),
        _group(id: 'price', title: 'Fiyat Aralığı', type: ProductFilterGroupType.priceRange),
        _group(id: 'attr::size', title: 'Beden'),
        _group(id: 'attr::color', title: 'Renk'),
        _group(
          id: 'subcategory',
          title: 'Alt Kategori',
          type: ProductFilterGroupType.subcategory,
        ),
      ];

      final chips = ProductQuickFilterChipGroups.resolve(
        allGroups,
        mainCategory: 'Yemek',
      );

      final labels = chips
          .map(ProductQuickFilterChipGroups.quickFilterCanonicalKey)
          .toList();
      expect(labels, isNot(contains('size')));
      expect(labels, isNot(contains('color')));
    });

    test('food category Restoran/Mağaza/Fiyat chip içerir', () {
      final allGroups = [
        _group(id: 'brand', title: 'Marka', type: ProductFilterGroupType.brand),
        _group(
          id: 'seller',
          title: 'Satıcı / Mağaza',
          type: ProductFilterGroupType.seller,
        ),
        _group(
          id: 'price',
          title: 'Fiyat Aralığı',
          type: ProductFilterGroupType.priceRange,
        ),
        _group(id: 'attr::size', title: 'Beden'),
      ];

      final chips = ProductQuickFilterChipGroups.resolve(
        allGroups,
        mainCategory: 'Yemek',
      );

      final keys = chips
          .map(ProductQuickFilterChipGroups.quickFilterCanonicalKey)
          .toSet();
      expect(keys.contains('brand') || keys.contains('seller'), isTrue);
      expect(keys.contains('price'), isTrue);
    });

    test('non-food category Beden chip korunabilir', () {
      final allGroups = [
        _group(id: 'brand', title: 'Marka', type: ProductFilterGroupType.brand),
        _group(id: 'attr::size', title: 'Beden'),
      ];

      final chips = ProductQuickFilterChipGroups.resolve(
        allGroups,
        mainCategory: 'Giyim & Aksesuar',
      );

      final keys = chips
          .map(ProductQuickFilterChipGroups.quickFilterCanonicalKey)
          .toList();
      expect(keys, contains('size'));
    });

    test('food quick chip label Restoran döner', () {
      final brand = _group(
        id: 'brand',
        title: 'Marka',
        type: ProductFilterGroupType.brand,
      );
      final label = CategoryFilterConfig.quickChipLabel(
        mainCategory: 'Yemek',
        group: brand,
        defaultLabel: 'Marka',
      );
      expect(label, 'Restoran');
    });

    test('shouldLoadDbAttributeGroups yemek için false', () {
      expect(
        CategoryFilterConfig.shouldLoadDbAttributeGroups(
          mainCategory: 'Yemek',
          subCategory: 'HEPSİ',
        ),
        isFalse,
      );
      expect(
        CategoryFilterConfig.shouldLoadDbAttributeGroups(
          mainCategory: 'Elektronik',
          subCategory: 'HEPSİ',
        ),
        isTrue,
      );
    });
  });
}
