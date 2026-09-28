import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/home_quick_action.dart';
import 'package:ibul_app/models/db_product.dart';

DBProduct _product({
  required String id,
  String price = '100',
  String? oldPrice,
  String tags = '[]',
  int reviewCount = 0,
  double rating = 4.0,
  bool isActive = true,
}) {
  return DBProduct(
    id: id,
    name: 'Product $id',
    brand: 'Brand',
    price: price,
    oldPrice: oldPrice,
    rating: rating,
    reviewCount: reviewCount,
    imageUrl: 'img.jpg',
    category: 'Elektronik',
    tags: tags,
    isActive: isActive,
    approvalStatus: 'approved',
  );
}

void main() {
  group('HomeQuickActionRegistry', () {
    test('Ana sayfa kısayolları eşlenir', () {
      const titles = [
        'Süper Fırsat',
        'İndirimler',
        'Çok Satanlar',
        'Yeniler',
        'Özel Ürünler',
        'Hediye',
        'Elektronik',
        'Ev & Yaşam',
        'Moda',
        'Spor',
        'Kitap',
      ];

      for (final title in titles) {
        final action = HomeQuickActionRegistry.fromHomeShortcutTitle(title);
        expect(action, isNotNull, reason: title);
        expect(action!.title, title);
      }
    });

    test('Süper Fırsat deals filter tipindedir', () {
      final action = HomeQuickActionRegistry.fromHomeShortcutTitle('Süper Fırsat');
      expect(action!.type, HomeQuickActionType.deals);
      expect(action.filterType, 'deals');
    });

    test('Elektronik kategori aksiyonudur', () {
      final action = HomeQuickActionRegistry.fromHomeShortcutTitle('Elektronik');
      expect(action!.type, HomeQuickActionType.category);
      expect(action.categorySlug, 'Elektronik');
    });

    test('Moda Giyim & Aksesuar kategorisine map edilir', () {
      final action = HomeQuickActionRegistry.fromHomeShortcutTitle('Moda');
      expect(action!.categorySlug, 'Giyim & Aksesuar');
    });

    test('Araç vehicle aksiyonudur', () {
      final action = HomeQuickActionRegistry.fromHomeShortcutTitle('Araç');
      expect(action, isNotNull);
      expect(action!.type, HomeQuickActionType.vehicle);
    });
  });

  group('HomeQuickActionFilter', () {
    test('İndirimler discounted ürünleri seçer', () {
      const action = HomeQuickAction(
        id: 'discounts',
        title: 'İndirimler',
        type: HomeQuickActionType.discounts,
        filterType: 'discounted',
      );

      final result = HomeQuickActionFilter.apply(action, [
        _product(id: 'a', price: '80', oldPrice: '120'),
        _product(id: 'b', price: '100'),
      ]);

      expect(result.length, 1);
      expect(result.first.id, 'a');
    });

    test('Çok Satanlar reviewCount sıralaması', () {
      const action = HomeQuickAction(
        id: 'best_sellers',
        title: 'Çok Satanlar',
        type: HomeQuickActionType.bestSellers,
        filterType: 'best_sellers',
      );

      final result = HomeQuickActionFilter.apply(action, [
        _product(id: 'low', reviewCount: 1),
        _product(id: 'high', reviewCount: 50),
      ]);

      expect(result.first.id, 'high');
    });

    test('inactive ürünler filtrelenir', () {
      const action = HomeQuickAction(
        id: 'discounts',
        title: 'İndirimler',
        type: HomeQuickActionType.discounts,
      );

      final result = HomeQuickActionFilter.apply(action, [
        _product(id: 'inactive', isActive: false, oldPrice: '200'),
      ]);

      expect(result, isEmpty);
    });
  });

  group('HomeQuickActionChip', () {
    testWidgets('render edilir ve tıklanabilir', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeQuickActionChip(
              icon: Icons.flash_on,
              title: 'Süper Fırsat',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Süper Fırsat'), findsOneWidget);
      expect(find.byType(HomeQuickActionChip), findsOneWidget);

      await tester.tap(find.byType(HomeQuickActionChip));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('web pointer click cursor içerir', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeQuickActionChip(
              icon: Icons.flash_on,
              title: 'Süper Fırsat',
              onTap: () {},
            ),
          ),
        ),
      );

      final mouseRegions = tester.widgetList<MouseRegion>(
        find.byType(MouseRegion),
      );
      expect(
        mouseRegions.any((region) => region.cursor == SystemMouseCursors.click),
        isTrue,
      );
    });

    testWidgets('Semantics etiketi title içerir', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeQuickActionChip(
              icon: Icons.flash_on,
              title: 'İndirimler',
              onTap: () {},
            ),
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byType(HomeQuickActionChip));
      expect(semantics.label, contains('İndirimler'));
    });
  });
}
