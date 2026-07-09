import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ibul_app/core/constants.dart';
import 'package:ibul_app/core/cart_state.dart';
import 'package:ibul_app/core/favorite_state.dart';
import 'package:ibul_app/core/review_state.dart';
import 'package:ibul_app/models/product_model.dart';
import 'package:ibul_app/responsive/breakpoints.dart';
import 'package:ibul_app/widgets/product_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const testSupabaseUrl = String.fromEnvironment(
    'TEST_SUPABASE_URL',
    defaultValue: 'https://example.supabase.co',
  );
  const testSupabaseAnonKey = String.fromEnvironment(
    'TEST_SUPABASE_ANON_KEY',
    defaultValue: 'test-anon-key',
  );

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: testSupabaseUrl,
      anonKey: testSupabaseAnonKey,
    );
  });

  group('ProductGridSizing kolon hesabı', () {
    // Kullanılabilir genişlik = ekran - grid yatay padding (~24).
    test('küçük mobil 2 kolon kalır', () {
      expect(ProductGridSizing.columnCountForWidth(360 - 24, spacing: 10), 2);
      expect(ProductGridSizing.columnCountForWidth(419 - 24, spacing: 10), 2);
    });

    test('büyük mobil / küçük tablet 2-3 kolon', () {
      final at420 = ProductGridSizing.columnCountForWidth(420 - 24, spacing: 10);
      final at600 = ProductGridSizing.columnCountForWidth(600 - 24, spacing: 10);
      expect(at420, inInclusiveRange(2, 3));
      expect(at600, inInclusiveRange(2, 3));
    });

    test('tablet genişliği en az 3 kolon', () {
      // iPad Mini / iPad portrait ve küçük landscape aralığı.
      for (final width in [700.0, 768.0, 834.0, 900.0]) {
        final columns =
            ProductGridSizing.columnCountForWidth(width - 24, spacing: 10);
        expect(columns, greaterThanOrEqualTo(3),
            reason: 'width=$width en az 3 kolon olmalı');
        expect(columns, lessThanOrEqualTo(4),
            reason: 'width=$width kart bandını korumalı');
      }
    });

    test('desktop genişliği 4+ kolon', () {
      expect(
        ProductGridSizing.columnCountForWidth(1000 - 24, spacing: 10),
        greaterThanOrEqualTo(4),
      );
      expect(
        ProductGridSizing.columnCountForWidth(1300 - 24, spacing: 10),
        greaterThanOrEqualTo(5),
      );
      // Üst sınır: 6 kolonu aşmaz.
      expect(
        ProductGridSizing.columnCountForWidth(2000, spacing: 10),
        lessThanOrEqualTo(ProductGridSizing.maxColumns),
      );
    });

    test('kart max genişliği korunur (dev kart oluşmaz)', () {
      // Sayfaların fixed-count grid kullandığı aralık (<900) + geniş tablet.
      for (double width = 320; width <= 1250; width += 10) {
        final cardWidth = ProductGridSizing.cardWidthFor(width, spacing: 10);
        expect(
          cardWidth,
          lessThanOrEqualTo(ProductGridSizing.maxCardWidth + 0.001),
          reason: 'availableWidth=$width kart ${ProductGridSizing.maxCardWidth}px sınırını aşmamalı',
        );
      }
    });

    test('sınır durumları güvenli', () {
      expect(ProductGridSizing.columnCountForWidth(0), 2);
      expect(ProductGridSizing.columnCountForWidth(-100), 2);
      expect(ProductGridSizing.columnCountForWidth(double.infinity), 2);
    });
  });

  group('Responsive ürün grid render', () {
    Product buildProduct(int i) {
      return Product(
        name: 'Ürün $i — Uzun İsimli Test Ürünü Deneme',
        brand: 'Marka',
        price: '${100 + i} TL',
        oldPrice: i.isEven ? '${150 + i} TL' : null,
        rating: 4.6,
        reviewCount: 1200,
        tags: const ['Ücretsiz Kargo'],
        images: const [],
        category: 'Süpermarket',
        subCategory: 'Atıştırmalık',
      );
    }

    /// Sayfalardaki grid yapısının aynısı: LayoutBuilder + ProductGridSizing.
    Widget buildResponsiveGrid({required double aspectRatio}) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final columns = ProductGridSizing.columnCountForWidth(
            constraints.maxWidth - 24,
            spacing: 10,
          );
          return GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              childAspectRatio: aspectRatio,
              crossAxisSpacing: 10,
              mainAxisSpacing: 12,
            ),
            itemCount: 8,
            itemBuilder: (context, index) => ProductCard(
              product: buildProduct(index),
              compact: false,
              tight: true,
              margin: EdgeInsets.zero,
            ),
          );
        },
      );
    }

    Widget buildTestApp(Widget child) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<CartState>.value(value: CartState()),
          ChangeNotifierProvider<FavoriteState>.value(value: FavoriteState()),
          ChangeNotifierProvider<ReviewState>.value(value: ReviewState()),
        ],
        child: MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: AppColors.primary,
          ),
          home: Scaffold(body: child),
        ),
      );
    }

    /// İlk satırdaki kart sayısı = kolon sayısı.
    int firstRowCardCount(WidgetTester tester) {
      final cards = find.byType(ProductCard);
      final count = cards.evaluate().length;
      expect(count, greaterThan(0));
      final tops = <double>[
        for (var i = 0; i < count; i++) tester.getTopLeft(cards.at(i)).dy,
      ];
      final minTop = tops.reduce((a, b) => a < b ? a : b);
      return tops.where((t) => (t - minTop).abs() < 1).length;
    }

    testWidgets('mobil (360) 2 kolon ve overflow yok', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() async => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestApp(buildResponsiveGrid(aspectRatio: 0.70)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(firstRowCardCount(tester), 2);
    });

    testWidgets('tablet (768) en az 3 kolon ve overflow yok', (tester) async {
      await tester.binding.setSurfaceSize(const Size(768, 1024));
      addTearDown(() async => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestApp(buildResponsiveGrid(aspectRatio: 0.70)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(firstRowCardCount(tester), greaterThanOrEqualTo(3));
    });

    testWidgets('desktop (1100) 4+ kolon ve overflow yok', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 900));
      addTearDown(() async => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestApp(buildResponsiveGrid(aspectRatio: 0.70)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(firstRowCardCount(tester), greaterThanOrEqualTo(4));
    });

    testWidgets('favoriler oranıyla (0.78) tablet genişliğinde overflow yok',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(768, 1024));
      addTearDown(() async => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestApp(buildResponsiveGrid(aspectRatio: 0.78)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(firstRowCardCount(tester), greaterThanOrEqualTo(3));
    });

    testWidgets('favoriler compact oranıyla (0.78) mobil 2 kolon korunur',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() async => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestApp(buildResponsiveGrid(aspectRatio: 0.78)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(firstRowCardCount(tester), 2);
    });

    testWidgets('favoriler compact oranıyla (0.78) overflow yok (414)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(414, 896));
      addTearDown(() async => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestApp(buildResponsiveGrid(aspectRatio: 0.78)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('market ürünü kartında Sepete Ekle davranışı korunur',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(768, 1024));
      addTearDown(() async => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestApp(buildResponsiveGrid(aspectRatio: 0.70)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sepete Ekle'), findsWidgets);
      expect(find.text('Sipariş Ver'), findsNothing);
    });

    testWidgets('ProductCard default mode (non-compact) overflow yok',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() async => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestApp(buildResponsiveGrid(aspectRatio: 0.70)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(firstRowCardCount(tester), 2);
    });
  });

  group('Sayfalar responsive helper kullanıyor (kaynak doğrulama)', () {
    test('mağaza ürün grid\'i ProductGridSizing kullanır', () {
      final source =
          File('lib/screens/business_detail_page.dart').readAsStringSync();
      expect(
        source.contains('ProductGridSizing.columnCountForWidth('),
        isTrue,
        reason: 'Mağaza ürün grid\'i sabit kolona geri dönmemeli',
      );
    });

    test('favoriler grid\'i ProductGridSizing kullanır', () {
      final source =
          File('lib/screens/favorites_page.dart').readAsStringSync();
      expect(
        'ProductGridSizing.columnCountForWidth('.allMatches(source).length,
        greaterThanOrEqualTo(2),
        reason: 'Beğeniler + öneriler ürün grid\'leri helper kullanmalı',
      );
    });

    test('favoriler grid childAspectRatio 0.78 kullanır', () {
      final source =
          File('lib/screens/favorites_page.dart').readAsStringSync();
      expect(
        source.contains('childAspectRatio: 0.78'),
        isTrue,
        reason: 'Favoriler compact kart oranı 0.78 olmalı',
      );
      // Eski 0.65 oranı kalmamalı
      expect(
        source.contains('childAspectRatio: 0.65'),
        isFalse,
        reason: 'Eski 0.65 oranı kaldırılmış olmalı',
      );
    });

    test('favoriler _buildProductCard Spacer kullanmaz', () {
      final source =
          File('lib/screens/favorites_page.dart').readAsStringSync();
      // _buildProductCard metodu Spacer yerine SizedBox kullanmalı
      final buildProductCardStart = source.indexOf('Widget _buildProductCard(');
      expect(buildProductCardStart, greaterThan(-1));
      final methodBody = source.substring(buildProductCardStart);
      // Spacer Expanded child olarak kullanılmamalı
      expect(
        methodBody.contains('const Spacer()'),
        isFalse,
        reason: 'Spacer kaldırılmış olmalı, fiyat hemen yıldızdan sonra gelmeli',
      );
    });
  });
}
