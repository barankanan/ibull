import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/cart_state.dart';
import 'package:ibul_app/core/compare_state.dart';
import 'package:ibul_app/core/favorite_state.dart';
import 'package:ibul_app/core/review_state.dart';
import 'package:ibul_app/models/product_model.dart';
import 'package:ibul_app/screens/home/mobile/mobile_home_catalog.dart';
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
