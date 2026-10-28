import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/app_state.dart';
import 'package:ibul_app/core/cart_state.dart';
import 'package:ibul_app/core/compare_state.dart';
import 'package:ibul_app/core/constants.dart';
import 'package:ibul_app/core/favorite_state.dart';
import 'package:ibul_app/core/review_state.dart';
import 'package:ibul_app/models/product_model.dart';
import 'package:ibul_app/screens/compare_products_page.dart';
import 'package:ibul_app/screens/home/mobile/mobile_home_catalog.dart';
import 'package:ibul_app/screens/home/mobile/mobile_home_see_all_page.dart';
import 'package:ibul_app/widgets/product_card.dart';
import 'package:provider/provider.dart';
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

  Product sample({
    required String id,
    required String name,
    required String price,
    String? oldPrice,
    String category = 'Elektronik',
  }) {
    return Product(
      productId: id,
      name: name,
      brand: 'Marka',
      price: price,
      oldPrice: oldPrice,
      rating: 4.6,
      reviewCount: 18,
      tags: const [],
      images: const [],
      category: category,
    );
  }

  Widget host(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CartState>.value(value: CartState()),
        ChangeNotifierProvider<FavoriteState>.value(value: FavoriteState()),
        ChangeNotifierProvider<CompareState>.value(value: CompareState()),
        ChangeNotifierProvider<ReviewState>.value(value: ReviewState()),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  Future<void> pumpCards(
    WidgetTester tester, {
    required double width,
    required bool homeRail,
    double? railHeight,
  }) async {
    final cardWidth = homeRail ? MobileProductRail.cardWidthFor(width) : 220.0;
    Widget card(Product product, Key key) {
      return ProductCard(
        key: key,
        product: product,
        width: cardWidth,
        homeRail: homeRail,
        margin: EdgeInsets.zero,
      );
    }

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        card(
          sample(
            id: 'deal',
            name: 'İndirimli Kulaklık Extra Uzun Ürün Adı Satır Testi',
            price: '1499 TL',
            oldPrice: '1899 TL',
          ),
          const Key('card-deal'),
        ),
        card(
          sample(id: 'plain', name: 'Sade Ürün', price: '899 TL'),
          const Key('card-plain'),
        ),
        card(
          sample(
            id: 'food',
            name: 'Izgara Köfte Porsiyon',
            price: '240 TL',
            category: 'Yemek',
          ),
          const Key('card-food'),
        ),
      ],
    );

    await tester.pumpWidget(
      host(
        SizedBox(
          height: railHeight ?? 360,
          child: ListView(scrollDirection: Axis.horizontal, children: [row]),
        ),
      ),
    );
    await tester.pump();
  }

  void expectAlignedCards(WidgetTester tester) {
    final deal = tester.getRect(find.byKey(const Key('card-deal')));
    final plain = tester.getRect(find.byKey(const Key('card-plain')));
    final food = tester.getRect(find.byKey(const Key('card-food')));

    expect(deal.height, closeTo(plain.height, 0.5));
    expect(deal.height, closeTo(food.height, 0.5));
    expect(deal.bottom, closeTo(plain.bottom, 0.5));
    expect(deal.bottom, closeTo(food.bottom, 0.5));

    final dealPrice = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('card-deal')),
        matching: find.byKey(const ValueKey('product-card-price-block')),
      ),
    );
    final plainPrice = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('card-plain')),
        matching: find.byKey(const ValueKey('product-card-price-block')),
      ),
    );
    expect(dealPrice.height, closeTo(plainPrice.height, 0.5));
    expect(dealPrice.top, closeTo(plainPrice.top, 0.5));
    expect(tester.takeException(), isNull);
  }

  testWidgets(
    'indirimli kart eski fiyat, yeni fiyat ve indirim etiketini gösterir',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpCards(tester, width: 390, homeRail: true);

      expect(find.text('1899 TL'), findsOneWidget);
      expect(find.text('1499 TL'), findsOneWidget);
      expect(find.text('İndirim'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
      expect(find.text('Fırsat Ürünü'), findsOneWidget);
      expectAlignedCards(tester);
    },
  );

  testWidgets(
    'indirimsiz kart aynı yükseklikte kalır ve indirim alanını gizler',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpCards(tester, width: 390, homeRail: true);

      expect(find.text('899 TL'), findsOneWidget);
      expect(find.text('İndirim'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('card-plain')),
          matching: find.text('İndirim'),
        ),
        findsNothing,
      );
      expect(find.text('Sepete Ekle'), findsNWidgets(2));
      expect(find.text('Sipariş Ver'), findsOneWidget);
      expectAlignedCards(tester);
    },
  );

  testWidgets('karışık mobil rail alt hizası sabit kalır', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpCards(tester, width: 390, homeRail: true, railHeight: 320);
    expectAlignedCards(tester);
    expect(
      tester.getSize(find.byKey(const Key('card-deal'))).height,
      lessThanOrEqualTo(320),
    );
  });

  for (final width in <double>[360, 375, 390, 412, 430]) {
    testWidgets('mobil $width genişlikte kart taşmaz', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpCards(tester, width: width, homeRail: true, railHeight: 320);
      expectAlignedCards(tester);
    });
  }

  testWidgets('satıcı profil kartı discount_price ile 1499 ve 1399 gösterir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final product = Product.fromDBProduct({
      'id': 'sandisk-extreme-pro-128',
      'name': 'SanDisk Extreme Pro 128 GB SDXC Hafıza Kartı',
      'brand': 'SanDisk',
      'price': 1499,
      'discount_price': 1399,
      'main_category': 'Elektronik',
      'store': 'Teknosa',
    });

    await tester.pumpWidget(
      host(
        SizedBox(
          width: 180,
          height: 320,
          child: ProductCard(
            product: product,
            tight: true,
            margin: EdgeInsets.zero,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(product.price, '1399 TL');
    expect(product.oldPrice, '1499 TL');
    expect(find.text('1499 TL'), findsOneWidget);
    expect(find.text('1399 TL'), findsOneWidget);
    expect(find.text('İndirim'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('satıcı profil kartı indirimsiz üründe tek fiyat gösterir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final product = Product.fromDBProduct({
      'id': 'plain-card',
      'name': 'Düz Ürün',
      'brand': 'Marka',
      'price': 899,
      'main_category': 'Elektronik',
    });

    await tester.pumpWidget(
      host(
        SizedBox(
          width: 180,
          height: 320,
          child: ProductCard(
            product: product,
            tight: true,
            margin: EdgeInsets.zero,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(product.oldPrice, isNull);
    expect(find.text('899 TL'), findsOneWidget);
    expect(find.text('İndirim'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sepette butonu ürünü sepetten çıkarır, sepet ikonu silmez', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(CartState().clear);

    final product = sample(
      id: 'cart-sync',
      name: 'Sepet Test Ürünü',
      price: '1399 TL',
      oldPrice: '1499 TL',
    );
    CartState().addOrReplace(product);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: AppState(),
        child: host(
          SizedBox(
            width: 180,
            height: 320,
            child: ProductCard(product: product, margin: EdgeInsets.zero),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Sepette'), findsOneWidget);
    expect(find.byKey(const ValueKey('product-card-open-cart')), findsOneWidget);
    expect(find.text('1499 TL'), findsOneWidget);
    expect(find.text('1399 TL'), findsOneWidget);
    expect(find.text('İndirim'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('product-card-in-cart-button')));
    await tester.pump();
    expect(CartState().isInCart(product), isFalse);
    expect(find.text('Sepete Ekle'), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('web yatay rail kartları aynı fiyat ve alt hizasını korur', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      host(
        const SizedBox(
          height: 348,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 220, height: 348, child: _WebDealCard()),
              SizedBox(width: 12),
              SizedBox(width: 220, height: 348, child: _WebPlainCard()),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final deal = tester.getRect(find.byKey(const Key('web-deal')));
    final plain = tester.getRect(find.byKey(const Key('web-plain')));
    expect(deal.height, 348);
    expect(plain.height, 348);
    expect(deal.bottom, plain.bottom);

    final dealPrice = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('web-deal')),
        matching: find.byKey(const ValueKey('product-card-price-block')),
      ),
    );
    final plainPrice = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('web-plain')),
        matching: find.byKey(const ValueKey('product-card-price-block')),
      ),
    );
    expect(dealPrice.top, closeTo(plainPrice.top, 0.5));
    expect(dealPrice.height, closeTo(plainPrice.height, 0.5));

    final dealButton = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('web-deal')),
        matching: find.byKey(const ValueKey('product-card-primary-button')),
      ),
    );
    final plainButton = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('web-plain')),
        matching: find.byKey(const ValueKey('product-card-primary-button')),
      ),
    );
    expect(dealButton.top, closeTo(plainButton.top, 0.5));
    expect(tester.takeException(), isNull);
  });

  for (final width in <double>[360, 390, 430]) {
    testWidgets('tümünü gör $width kartı action altında boşluk bırakmaz', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        host(
          MobileHomeSeeAllPage.products(
            title: 'Sana Özel',
            products: [
              sample(id: 'short', name: 'Kısa', price: '100 TL'),
              sample(
                id: 'long',
                name:
                    'Çok uzun ürün adı iki satırı doldurup taşacak kadar devam eder',
                price: '250 TL',
                oldPrice: '400 TL',
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      final cards = find.byType(ProductCard);
      expect(cards, findsNWidgets(2));
      final shortRect = tester.getRect(cards.at(0));
      final longRect = tester.getRect(cards.at(1));
      expect(shortRect.height, closeTo(longRect.height, 0.5));
      expect(
        shortRect.height,
        closeTo(
          ProductCard.homeRailCardHeight(tester.element(cards.first)),
          1,
        ),
      );

      for (var index = 0; index < 2; index++) {
        final card = cards.at(index);
        final cardRect = tester.getRect(card);
        final buttonRect = tester.getRect(
          find.descendant(
            of: card,
            matching: find.byKey(const ValueKey('product-card-primary-button')),
          ),
        );
        expect(cardRect.bottom - buttonRect.bottom, inInclusiveRange(4, 14));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('karşılaştırma ikonu ekler ve ikinci basışta çıkarır', (
    tester,
  ) async {
    CompareState().clear();
    addTearDown(CompareState().clear);

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final product = Product(
      productId: 'cmp-1',
      name: 'Kulaklık',
      brand: 'Marka',
      price: '1499 TL',
      oldPrice: '1899 TL',
      rating: 4.6,
      reviewCount: 12,
      tags: const [],
      images: const ['https://example.com/kulaklik.jpg'],
      category: 'Elektronik',
      store: 'Teknosa',
    );

    await tester.pumpWidget(
      host(
        Center(
          child: ProductCard(
            product: product,
            width: 180,
            homeRail: true,
            margin: EdgeInsets.zero,
          ),
        ),
      ),
    );
    await tester.pump();

    final button = find.byKey(const ValueKey('product-card-compare-button'));
    await tester.tap(button);
    await tester.pump();

    expect(find.text('Ürün karşılaştırmaya eklendi'), findsOneWidget);
    final stored = CompareState().compareProducts.single;
    expect(stored.productId, 'cmp-1');
    expect(stored.name, 'Kulaklık');
    expect(stored.brand, 'Marka');
    expect(stored.price, '1499 TL');
    expect(stored.store, 'Teknosa');
    expect(stored.images, ['https://example.com/kulaklik.jpg']);
    expect(CompareState().isCompared(product), isTrue);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.compare_arrows)).color,
      AppColors.primary,
    );

    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Ürün karşılaştırmadan çıkarıldı'), findsOneWidget);
    expect(CompareState().compareProducts, isEmpty);
    expect(CompareState().isCompared(product), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tümünü gör en düşük fiyata göre sıralar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      host(
        MobileHomeSeeAllPage.products(
          title: 'Sana Özel',
          products: [
            sample(id: 'hi', name: 'Pahalı Ürün', price: '500 TL'),
            sample(id: 'lo', name: 'Ucuz Ürün', price: '100 TL'),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('2 ürün'), findsOneWidget);
    expect(find.text('Filtrele'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('see-all-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('En düşük fiyat'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Uygula'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump();
    await tester.tap(find.text('Uygula'));
    await tester.pumpAndSettle();

    final cards = tester
        .widgetList<ProductCard>(find.byType(ProductCard))
        .toList();
    expect(cards.first.product.name, 'Ucuz Ürün');
    expect(cards.last.product.name, 'Pahalı Ürün');
    expect(tester.takeException(), isNull);
  });

  testWidgets('beğendiğim ürünleri karşılaştır FavoriteState listesini gösterir', (
    tester,
  ) async {
    FavoriteState().clear();
    addTearDown(FavoriteState().clear);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (var i = 0; i < 7; i++) {
      FavoriteState().toggleFavorite(
        sample(
          id: 'fav-$i',
          name: i == 0 ? 'iPhone' : 'Ürün $i',
          price: '${100 + i} TL',
          category: i < 4 ? 'Elektronik' : 'Yemek',
        ),
      );
    }

    await tester.pumpWidget(
      host(
        const MediaQuery(
          data: MediaQueryData(size: Size(390, 844)),
          child: CompareProductsPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Karşılaştırma yapabilmek için lütfen en az 2 ürün beğenin.'),
      findsNothing,
    );
    expect(find.text('iPhone'), findsWidgets);
    expect(find.text('Elektronik'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

class _WebDealCard extends StatelessWidget {
  const _WebDealCard();

  @override
  Widget build(BuildContext context) {
    return ProductCard(
      key: const Key('web-deal'),
      width: 220,
      margin: EdgeInsets.zero,
      product: Product(
        productId: 'web-deal',
        name: 'Web İndirimli Ürün Adı İki Satır Taşma Testi',
        brand: 'Marka',
        price: '1499 TL',
        oldPrice: '1899 TL',
        rating: 4.8,
        reviewCount: 20,
        tags: const [],
        images: const [],
        category: 'Elektronik',
      ),
    );
  }
}

class _WebPlainCard extends StatelessWidget {
  const _WebPlainCard();

  @override
  Widget build(BuildContext context) {
    return ProductCard(
      key: const Key('web-plain'),
      width: 220,
      margin: EdgeInsets.zero,
      product: Product(
        productId: 'web-plain',
        name: 'Web Sade Ürün',
        brand: 'Marka',
        price: '899 TL',
        rating: 4.2,
        reviewCount: 4,
        tags: const [],
        images: const [],
        category: 'Elektronik',
      ),
    );
  }
}
