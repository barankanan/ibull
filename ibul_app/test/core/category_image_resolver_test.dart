import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/category_image_resolver.dart';

void main() {
  group('CategoryImageResolver', () {
    test('Erkek Giyim resolves to Erkek Giyim asset', () {
      final asset = CategoryImageResolver.resolveSubCategoryAsset(
        mainCategoryName: 'Erkek',
        subCategoryName: 'Giyim',
      );

      expect(asset, 'assets/subcategory_icons/Erkek Giyim.png');
    });

    test('Kadın Giyim resolves with Turkish characters', () {
      final asset = CategoryImageResolver.resolveSubCategoryAsset(
        mainCategoryName: 'Kadın',
        subCategoryName: 'Giyim',
      );

      expect(asset, 'assets/subcategory_icons/Kadın giyim.png');
    });

    test('Ayakkabı & Çanta resolves for Erkek context', () {
      final asset = CategoryImageResolver.resolveSubCategoryAsset(
        mainCategoryName: 'Erkek',
        subCategoryName: 'Ayakkabı & Çanta',
      );

      expect(asset, 'assets/subcategory_icons/spor ayakkabı.png');
    });

    test('explicit fallback wins over resolver', () {
      final asset = CategoryImageResolver.resolveSubCategoryAsset(
        mainCategoryName: 'Erkek',
        subCategoryName: 'Giyim',
        explicitFallback: 'assets/custom.png',
      );

      expect(asset, 'assets/custom.png');
    });

    test('unknown subcategory without asset returns null', () {
      final asset = CategoryImageResolver.resolveSubCategoryAsset(
        mainCategoryName: 'Test',
        subCategoryName: 'Bilinmeyen Alt Kategori',
      );

      expect(asset, isNull);
    });

    test('Aksesuar resolves to aksesuar asset', () {
      final asset = CategoryImageResolver.resolveSubCategoryAsset(
        mainCategoryName: 'Erkek',
        subCategoryName: 'Aksesuar',
      );

      expect(asset, 'assets/subcategory_icons/aksesuar.png');
    });
  });
}
