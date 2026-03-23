import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ibul_app/core/constants.dart';
import 'package:ibul_app/core/cart_state.dart';
import 'package:ibul_app/core/favorite_state.dart';
import 'package:ibul_app/core/review_state.dart';
import 'package:ibul_app/models/product_model.dart';
import 'package:ibul_app/widgets/product_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://ihmixxzqnpamcwmrfibx.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlobWl4eHpxbnBhbWN3bXJmaWJ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3MDE0NTEsImV4cCI6MjA4NzI3NzQ1MX0.EZkjZAq2mwg-gfBhwotAGp4stb1D-rmWHuzVsz2yzX0',
    );
  });

  Product buildProduct({required bool withDiscount}) {
    return Product(
      name: 'Dondurma Dondurma Dondurma Çok Uzun Ürün Adı Test',
      brand: 'baranbaranbaran',
      price: '111 TL',
      oldPrice: withDiscount ? '1111 TL' : null,
      rating: 4.8,
      reviewCount: 123456,
      tags: const [],
      images: const [],
      category: 'Süpermarket',
      subCategory: 'Dondurma',
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

  testWidgets('SearchResults grid kartları mobilde overflow üretmez', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final products = List.generate(
      4,
      (i) => buildProduct(withDiscount: i.isEven),
    );

    await tester.pumpWidget(
      buildTestApp(
        GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.65,
            mainAxisSpacing: 12,
            crossAxisSpacing: 10,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            return ProductCard(
              product: products[index],
              compact: false,
              tight: true,
              margin: EdgeInsets.zero,
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'SearchResults grid kartları web/tablet genişlikte overflow üretmez',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(980, 820));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      final products = List.generate(
        6,
        (i) => buildProduct(withDiscount: i.isOdd),
      );

      await tester.pumpWidget(
        buildTestApp(
          GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 250,
              childAspectRatio: 0.65,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              return ProductCard(
                product: products[index],
                compact: false,
                margin: EdgeInsets.zero,
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Ana sayfa yatay kartlari sabit yukseklikte overflow uretmez', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      buildTestApp(
        Center(
          child: SizedBox(
            width: 220,
            height: 310,
            child: ProductCard(
              product: Product(
                name: 'Dondurma Dondurma Dondurma Çok Uzun Ürün Adı Test',
                brand: 'baranbaranbaran',
                price: '111111 TL',
                oldPrice: '45000 TL',
                rating: 4.8,
                reviewCount: 123456,
                tags: [],
                images: [],
                category: 'Süpermarket',
                subCategory: 'Dondurma',
              ),
              compact: false,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Fiyat alani ile buton arasi kompakt kalir', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 820));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      buildTestApp(
        Center(
          child: SizedBox(
            width: 220,
            height: 310,
            child: ProductCard(
              product: Product(
                name: 'Kompakt Kart Test Urunu',
                brand: 'Marka',
                price: '111 TL',
                oldPrice: '159 TL',
                rating: 4.7,
                reviewCount: 42,
                tags: const [],
                images: const [],
                category: 'Süpermarket',
                subCategory: 'Atıştırmalık',
              ),
              compact: false,
              margin: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final priceBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('product-card-price-block')))
        .dy;
    final buttonTop = tester
        .getTopLeft(find.byKey(const ValueKey('product-card-primary-button')))
        .dy;

    expect(buttonTop - priceBottom, lessThanOrEqualTo(8));
    expect(buttonTop, greaterThan(priceBottom));
  });
}
