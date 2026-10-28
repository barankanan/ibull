import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/app_state.dart';
import 'package:ibul_app/core/cart_state.dart';
import 'package:ibul_app/core/compare_state.dart';
import 'package:ibul_app/core/favorite_state.dart';
import 'package:ibul_app/core/review_state.dart';
import 'package:ibul_app/features/coupon/domain/coupon_models.dart';
import 'package:ibul_app/features/vehicle/models/vehicle_enums.dart';
import 'package:ibul_app/features/vehicle/models/vehicle_listing.dart';
import 'package:ibul_app/models/db_category.dart';
import 'package:ibul_app/models/product_model.dart';
import 'package:ibul_app/screens/home/mobile/mobile_home_catalog.dart';
import 'package:ibul_app/screens/home/mobile/mobile_home_collections.dart';
import 'package:ibul_app/screens/home/mobile/mobile_home_feed.dart';
import 'package:ibul_app/screens/home/mobile/mobile_home_models.dart';
import 'package:ibul_app/screens/home/mobile/mobile_home_store_previews.dart';
import 'package:ibul_app/screens/home/mobile/mobile_home_nav.dart';
import 'package:ibul_app/widgets/custom_header.dart';
import 'package:ibul_app/widgets/product_card.dart';
import 'package:ibul_app/widgets/web_header.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Gate implements MobileHomeGateway {
  _Gate(this.bundle);

  final MobileHomeBundle bundle;

  @override
  Future<MobileHomeBundle> load() async => bundle;
}

Product _product() => Product(
  productId: 'p1',
  name: 'Kablosuz Kulaklık',
  brand: 'Sony',
  price: '1.299 TL',
  oldPrice: '1.599 TL',
  rating: 4.6,
  reviewCount: 12,
  tags: const [],
  images: const [],
  category: 'Elektronik',
);

VehicleListing _vehicle() => VehicleListing(
  id: 'v1',
  sellerId: 'seller',
  listingType: VehicleListingType.sale,
  status: VehicleListingStatus.active,
  specs: const VehicleSpecs(
    brand: 'Honda',
    model: 'Civic',
    year: 2020,
    mileageKm: 45000,
  ),
  salePrice: 750000,
  city: 'Hatay',
  district: 'İskenderun',
);

MobileHomeBundle _bundle({bool malls = true}) => MobileHomeBundle(
  categories: [DBCategory(name: 'Elektronik', orderIndex: 1)],
  products: [_product()],
  stores: const [
    MobileNearbyStore(
      id: 's1',
      name: 'Teknosa',
      category: 'Elektronik',
      contextLine: 'Primall new • 1. Kat',
      distanceKm: 0.374,
    ),
  ],
  malls: malls
      ? const [
          MobileHomeMall(
            id: 'm1',
            name: 'Primall new',
            place: 'Hatay • İskenderun',
            storeCount: 1,
            distanceKm: 0.4,
          ),
        ]
      : const [],
  vehicles: [_vehicle()],
  deals: const [
    DailyDealProduct(
      id: 'd1',
      name: 'Kampanyalı Kulaklık',
      price: 1000,
      discountPrice: 800,
      discountPercent: 20,
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required MobileHomeBundle bundle,
  bool heroLoading = false,
  List<String> urls = const ['https://example.com/banner.jpg'],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  final app = AppState();
  app.cartCountNotifier.value = 2;
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CartState>.value(value: CartState()),
        ChangeNotifierProvider<FavoriteState>.value(value: FavoriteState()),
        ChangeNotifierProvider<CompareState>.value(value: CompareState()),
        ChangeNotifierProvider<ReviewState>.value(value: ReviewState()),
        ChangeNotifierProvider<AppState>.value(value: app),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: MobileHomeFeed(
            key: UniqueKey(),
            bannerUrls: urls,
            heroLoading: heroLoading,
            gateway: _Gate(bundle),
            onSearch: (_) {},
            onOpenMap: () {},
            onOpenCategories: () {},
            onOpenCategory: (_) {},
            onOpenVehicles: () {},
          ),
          bottomNavigationBar: MobileHomeBottomNav(
            stackIndex: 0,
            onStack: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets('mobile home keeps banner geometry and hides empty malls', (
    tester,
  ) async {
    await _pump(
      tester,
      size: const Size(390, 844),
      bundle: _bundle(),
      heroLoading: true,
      urls: const [],
    );
    expect(find.byKey(const ValueKey('mobile-home-search')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('mobile-home-banner-skeleton')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mobile-home-feed-skeleton')),
      findsNothing,
    );
    final loading = tester.getSize(
      find.byKey(const ValueKey('mobile-home-banner')),
    );

    await _pump(
      tester,
      size: const Size(390, 844),
      bundle: _bundle(malls: false),
    );
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('mobile-home-banner-skeleton')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('mobile-home-feed-skeleton')),
      findsNothing,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('mobile-home-banner'))).height,
      loading.height,
    );
    final nearby = find.byKey(
      const ValueKey('mobile-home-nearby'),
      skipOffstage: false,
    );
    expect(nearby, findsOneWidget);
    await tester.ensureVisible(nearby);
    expect(find.text('Teknosa'), findsOneWidget);
    expect(find.text('Primall new • 1. Kat'), findsOneWidget);
    expect(find.text('Elektronik • 374 m'), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-home-malls')), findsNothing);
    expect(
      find.byKey(
        const ValueKey('mobile-product-rail-Sana Özel'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(find.text('Elektronik'), findsWidgets);
    expect(find.byType(WebHeader), findsNothing);
    expect(find.byKey(const ValueKey('mobile-home-header-cart')), findsNothing);
    expect(
      find.byKey(const ValueKey('mobile-home-notifications')),
      findsOneWidget,
    );
    expect(find.text('Sepetim'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text('Sepete Ekle', skipOffstage: false), findsWidgets);
    await tester.pump(const Duration(seconds: 9));
  });

  for (final width in [360.0, 375.0, 390.0, 412.0, 430.0]) {
    testWidgets('mobile home has no overflow at $width', (tester) async {
      await _pump(tester, size: Size(width, 844), bundle: _bundle());
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('mobile-home-quick-actions')),
        findsOneWidget,
      );
      expect(find.text('Yakındaki Mağazalar'), findsNothing);
      expect(
        find.byKey(
          const ValueKey('mobile-home-action-malls'),
          skipOffstage: false,
        ),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('mobile-home-malls'), skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('mobile-home-action-coupons'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('mobile-home-action-vehicles'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('mobile-home-action-deals'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      final coupons = tester.getSize(
        find.byKey(const ValueKey('mobile-home-action-coupons')),
      );
      expect(coupons.height, inInclusiveRange(54, 58));
      final couponTitle = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('mobile-home-action-coupons')),
          matching: find.byType(Text),
        ),
      );
      expect(couponTitle.data, 'Kuponlar');
      expect(couponTitle.maxLines, 1);
      expect(couponTitle.style?.fontSize, 13);
      expect(find.text('Yakınımdakiler'), findsNothing);
      expect(find.text('Yakın Lokasyon'), findsNothing);
      expect(
        tester.getSize(find.byKey(const ValueKey('mobile-home-header'))).height,
        48,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('mobile-home-chips'))).height,
        32,
      );
      if (width == 390) {
        final header = tester.getRect(
          find.byKey(const ValueKey('mobile-home-header')),
        );
        final chips = tester.getRect(
          find.byKey(const ValueKey('mobile-home-chips')),
        );
        final banner = tester.getRect(
          find.byKey(const ValueKey('mobile-home-banner')),
        );
        final above = chips.top - header.bottom;
        final below = banner.top - chips.bottom;
        expect(above, 12);
        expect(below, 12);
      }
      expect(
        find.byKey(const ValueKey('mobile-nav-home-active')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('mobile-nav-categories')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('mobile-nav-cart')), findsOneWidget);
      final categoriesNav = tester.getCenter(
        find.byKey(const ValueKey('mobile-nav-categories')),
      );
      final homeNav = tester.getCenter(
        find.byKey(const ValueKey('mobile-nav-home-active')),
      );
      final mapNav = tester.getCenter(
        find.byKey(const ValueKey('mobile-nav-map')),
      );
      final cartNav = tester.getCenter(
        find.byKey(const ValueKey('mobile-nav-cart')),
      );
      final accountNav = tester.getCenter(
        find.byKey(const ValueKey('mobile-nav-account')),
      );
      expect(homeNav.dx, lessThan(categoriesNav.dx));
      expect(categoriesNav.dx, lessThan(mapNav.dx));
      expect(mapNav.dx, lessThan(cartNav.dx));
      expect(cartNav.dx, lessThan(accountNav.dx));
      expect(find.byKey(const ValueKey('mobile-nav-favorites')), findsNothing);
      expect(
        find.byKey(const ValueKey('mobile-home-header-cart')),
        findsNothing,
      );
      expect(find.text('Sepete Ekle', skipOffstage: false), findsWidgets);
      final cta = find.byKey(
        const ValueKey('product-card-primary-button'),
        skipOffstage: false,
      );
      expect(cta, findsWidgets);
      expect(tester.getSize(cta.first).height, inInclusiveRange(34, 36));
      final sectionTitle = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data == 'Sana Özel' &&
            widget.style?.fontSize == 19,
        skipOffstage: false,
      );
      expect(sectionTitle, findsWidgets);
      expect(
        tester.widget<Text>(sectionTitle.first).style?.fontWeight,
        FontWeight.w600,
      );
      await tester.dragFrom(Offset(width / 2, 640), const Offset(0, -2200));
      await tester.pump();
      expect(tester.takeException(), isNull);
      if (width == 390) {
        final rail = find.byKey(
          const ValueKey('mobile-product-rail-Sana Özel'),
          skipOffstage: false,
        );
        await tester.ensureVisible(rail);
        await tester.pump();
        final heart = find.descendant(
          of: rail,
          matching: find.byIcon(Icons.favorite_border),
        );
        expect(heart, findsWidgets);
        await Scrollable.ensureVisible(
          tester.element(heart.first),
          alignment: 0.5,
        );
        await tester.pump();
        await tester.tap(heart.first);
        await tester.pump();
        await tester.pump();
        expect(
          find.text('Bu işlemi yapmak için giriş yapmanız gerekiyor.'),
          findsOneWidget,
        );
      }
      await tester.pump(const Duration(seconds: 9));
    });
  }

  testWidgets('category chip opens subcategory sheet', (tester) async {
    final bundle = MobileHomeBundle(
      categories: [DBCategory(id: 5, name: 'Elektronik', orderIndex: 1)],
      categoryTree: [
        CategoryWithSubcategories(
          mainCategory: DBCategory(id: 5, name: 'Elektronik', orderIndex: 1),
          subCategories: [
            DBCategory(id: 8, name: 'Telefonlar', orderIndex: 1, parentId: 5),
          ],
        ),
      ],
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: AppState()),
          ChangeNotifierProvider<FavoriteState>.value(value: FavoriteState()),
        ],
        child: MaterialApp(
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            builder: (_) => Text('route ${settings.name}'),
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => MobileHomeFeed(
                bannerUrls: const [],
                heroLoading: false,
                gateway: _Gate(bundle),
                onSearch: (_) {},
                onOpenMap: () {},
                onOpenCategories: () {},
                onOpenCategory: (_) {},
                onOpenCategoryNode: (node) =>
                    showMobileSubcategorySheet(context, node),
                onOpenVehicles: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final chip = find.byKey(const ValueKey('mobile-home-chip-Elektronik'));
    await tester.drag(
      find.byKey(const ValueKey('mobile-home-chips')),
      const Offset(-160, 0),
    );
    await tester.pump();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.text('Telefonlar'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mobile-subcategory-8')));
    await tester.pumpAndSettle();
    expect(find.textContaining('/kategori/5/8'), findsOneWidget);
    await tester.pump(const Duration(seconds: 9));
  });

  testWidgets('category rail scrolls sideways and skips empty categories', (
    tester,
  ) async {
    final products = [
      for (var i = 0; i < 12; i++)
        Product(
          productId: 'e$i',
          name: 'Elektronik $i',
          brand: 'Marka',
          price: '1000 TL',
          rating: 4,
          reviewCount: 1,
          tags: const [],
          images: const [],
          category: 'Elektronik',
          subCategory: i.isEven ? 'Telefonlar' : null,
        ),
    ];
    await _pump(
      tester,
      size: const Size(390, 844),
      bundle: MobileHomeBundle(
        products: products,
        categories: [DBCategory(name: 'Elektronik', orderIndex: 1)],
      ),
    );
    expect(
      find.byKey(const ValueKey('mobile-product-rail-Sana Özel')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('mobile-product-rail-Elektronik Dünyası'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('mobile-product-rail-Telefonlar'),
        skipOffstage: false,
      ),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('mobile-product-rail-Moda')),
      findsNothing,
    );
    final rail = find.byKey(
      const ValueKey('mobile-product-rail-Sana Özel'),
      skipOffstage: false,
    );
    await tester.ensureVisible(rail);
    final scrollable = find.descendant(
      of: rail,
      matching: find.byType(Scrollable),
    );
    final before = tester.state<ScrollableState>(scrollable).position.pixels;
    await tester.drag(scrollable, const Offset(-240, 0));
    await tester.pump();
    final after = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(after, greaterThan(before));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 9));
  });

  testWidgets(
    'product card shows a discount only when the old price is higher',
    (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CartState>.value(value: CartState()),
            ChangeNotifierProvider<FavoriteState>.value(value: FavoriteState()),
            ChangeNotifierProvider<CompareState>.value(value: CompareState()),
            ChangeNotifierProvider<ReviewState>.value(value: ReviewState()),
            ChangeNotifierProvider<AppState>.value(value: AppState()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ProductCard(
                    product: Product(
                      productId: 'plain',
                      name: 'Normal Ürün',
                      brand: 'Marka',
                      price: '1499 TL',
                      oldPrice: '1399 TL',
                      rating: 0,
                      reviewCount: 0,
                      tags: const [],
                      images: const [],
                    ),
                    width: 180,
                  ),
                  ProductCard(
                    product: Product(
                      productId: 'deal',
                      name: 'İndirimli Ürün',
                      brand: 'Marka',
                      price: '23999 TL',
                      oldPrice: '24999 TL',
                      rating: 4,
                      reviewCount: 3,
                      tags: const ['firsat'],
                      images: const [],
                    ),
                    width: 180,
                  ),
                  ProductCard(
                    product: Product(
                      productId: 'higher',
                      name: 'Yeni Fiyat Yüksek',
                      brand: 'Marka',
                      price: '18999 TL',
                      oldPrice: '17999 TL',
                      rating: 0,
                      reviewCount: 0,
                      tags: const [],
                      images: const [],
                    ),
                    width: 180,
                  ),
                  ProductCard(
                    product: Product(
                      productId: 'real',
                      name: 'Gerçek İndirim',
                      brand: 'Marka',
                      price: '18000 TL',
                      oldPrice: '20000 TL',
                      rating: 4,
                      reviewCount: 1,
                      tags: const [],
                      images: const [],
                    ),
                    width: 180,
                    homeRail: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('1399 TL'), findsNothing);
      expect(find.text('17999 TL'), findsNothing);
      expect(find.text('1499 TL'), findsOneWidget);
      expect(find.text('18999 TL'), findsOneWidget);
      expect(find.text('24999 TL'), findsOneWidget);
      expect(find.text('23999 TL'), findsOneWidget);
      expect(find.text('20000 TL'), findsOneWidget);
      expect(find.text('18000 TL'), findsOneWidget);
      expect(find.text('İndirim'), findsNWidgets(2));
      expect(find.text('Fırsat Ürünü'), findsWidgets);
      expect(find.text('Sepete Ekle'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'home rails hide invented discounts and keep a real recorded one',
    (tester) async {
      await _pump(
        tester,
        size: const Size(390, 844),
        bundle: MobileHomeBundle(
          categories: [DBCategory(name: 'Elektronik', orderIndex: 1)],
          products: [
            Product(
              productId: 'a',
              name: 'Normal Ürün',
              brand: 'Marka',
              price: '1499 TL',
              rating: 4,
              reviewCount: 2,
              tags: const [],
              images: const [],
              category: 'Elektronik',
            ),
            Product(
              productId: 'c',
              name: 'Tek Fiyat',
              brand: 'SanDisk',
              price: '1499 TL',
              oldPrice: '1399 TL',
              rating: 4,
              reviewCount: 2,
              tags: const [],
              images: const [],
              category: 'Elektronik',
            ),
            Product(
              productId: 'b',
              name: 'Kayıtlı Fırsat',
              brand: 'Marka',
              price: '1700 TL',
              oldPrice: '2000 TL',
              rating: 4,
              reviewCount: 2,
              tags: const [],
              images: const [],
              category: 'Elektronik',
            ),
          ],
          deals: const [
            DailyDealProduct(
              id: 'fake',
              name: 'Kampanyalı Kulaklık',
              price: 1499,
              discountPrice: 1399,
              discountPercent: 7,
            ),
          ],
        ),
      );
      expect(
        find.byKey(
          const ValueKey('mobile-product-rail-Bugünün Fırsatları'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(find.text('Kampanyalı Kulaklık'), findsNothing);
      expect(find.text('1399 TL'), findsNothing);
      expect(find.text('%7'), findsNothing);
      expect(find.text('1499 TL', skipOffstage: false), findsWidgets);
      expect(find.text('2000 TL', skipOffstage: false), findsWidgets);
      expect(find.text('1700 TL', skipOffstage: false), findsWidgets);
      expect(find.text('İndirim', skipOffstage: false), findsWidgets);
      expect(find.text('%7'), findsNothing);
      expect(find.text('%15'), findsNothing);
      expect(find.text('Fırsat Ürünü', skipOffstage: false), findsWidgets);
      expect(
        find.text('Popüler Kategoriler', skipOffstage: false),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey('mobile-home-categories'),
          skipOffstage: false,
        ),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('mobile-home-action-categories')),
        findsNothing,
      );
      final card = find.byType(ProductCard).first;
      final button = find.descendant(
        of: card,
        matching: find.byType(AnimatedSwitcher),
      );
      final gap = tester.getRect(card).bottom - tester.getRect(button).bottom;
      expect(gap, lessThan(12));
      expect(
        find.descendant(of: card, matching: find.text('İndirim')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 9));
    },
  );

  for (final width in [360.0, 375.0, 390.0, 412.0, 430.0]) {
    testWidgets('category header is bell, search, camera at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: AppState(),
          child: MaterialApp(
            home: Scaffold(body: CustomHeader(onSearch: (_) {})),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('mobile-header-logo')), findsNothing);
      final bell = tester.getRect(find.byTooltip('Bildirimler'));
      final search = tester.getRect(find.byType(TextField));
      final camera = tester.getRect(find.byTooltip('Kamera'));
      expect(bell.right, lessThanOrEqualTo(search.left));
      expect(search.right, lessThan(camera.left));
      expect(search.width, greaterThan(120));
      expect(tester.takeException(), isNull);
    });
  }

  test('smart collections mix categories and do not repeat products', () {
    final pool = [
      for (var i = 0; i < 8; i++)
        Product(
          productId: 'feat$i',
          name: 'Öne Çıkan $i',
          brand: 'Marka',
          price: '100 TL',
          rating: 4,
          reviewCount: 1,
          tags: const [],
          images: const [],
          category: 'Market',
        ),
      Product(
        productId: 'phone',
        name: 'Telefon',
        brand: 'Marka',
        price: '100 TL',
        rating: 5,
        reviewCount: 9,
        tags: const [],
        images: const [],
        category: 'Elektronik',
        subCategory: 'Akıllı Telefonlar',
      ),
      Product(
        productId: 'tv',
        name: 'Televizyon',
        brand: 'Marka',
        price: '100 TL',
        rating: 4,
        reviewCount: 4,
        tags: const [],
        images: const [],
        category: 'Elektronik',
        subCategory: 'Televizyon',
      ),
      Product(
        productId: 'tablet',
        name: 'Tablet',
        brand: 'Marka',
        price: '100 TL',
        rating: 4,
        reviewCount: 3,
        tags: const [],
        images: const [],
        category: 'Elektronik',
        subCategory: 'Tablet',
      ),
      Product(
        productId: 'dress',
        name: 'Elbise',
        brand: 'Marka',
        price: '100 TL',
        rating: 4,
        reviewCount: 2,
        tags: const [],
        images: const [],
        category: 'Giyim',
        subCategory: 'Kadın',
      ),
      Product(
        productId: 'shoe',
        name: 'Ayakkabı',
        brand: 'Marka',
        price: '100 TL',
        rating: 4,
        reviewCount: 2,
        tags: const [],
        images: const [],
        category: 'Giyim',
        subCategory: 'Ayakkabı',
      ),
      Product(
        productId: 'bag',
        name: 'Çanta',
        brand: 'Marka',
        price: '100 TL',
        rating: 4,
        reviewCount: 2,
        tags: const [],
        images: const [],
        category: 'Giyim',
        subCategory: 'Çanta',
      ),
    ];
    final plan = planMobileHomeCollections(pool: pool);
    final titles = plan.collections.map((item) => item.title).toList();
    expect(titles, contains('Elektronik Dünyası'));
    expect(titles, contains('Tarzına Uygun Kıyafetler'));
    expect(titles, isNot(contains('Akıllı Telefonlar')));
    expect(titles, isNot(contains('Televizyon')));
    final electronics = plan.collections
        .firstWhere((item) => item.title == 'Elektronik Dünyası')
        .products;
    expect(
      electronics.map((item) => item.subCategory).toSet().length,
      greaterThan(1),
    );
    final ids = [
      for (final collection in plan.collections)
        for (final product in collection.products) product.productId,
    ];
    expect(ids.toSet().length, ids.length);
    expect(ids, isNot(contains('feat0')));
  });

  test('personalized title uses the profile first name or falls back', () {
    expect(mobilePersonalizedTitle(null), 'Sana Özel');
    expect(mobilePersonalizedTitle({'name': 'Kullanıcı'}), 'Sana Özel');
    expect(
      mobilePersonalizedTitle({'display_name': 'Baran Kanan'}),
      'Baran Sana Özel',
    );
  });

  test('store preview fit keeps one bulk cap and shows overflow', () {
    final wide = MobileStorePreviewFit.measure(innerWidth: 320, available: 8);
    expect(wide.visible, greaterThan(0));
    expect(wide.visible + wide.hidden, 8);
    final narrow = MobileStorePreviewFit.measure(innerWidth: 180, available: 8);
    expect(narrow.hidden, greaterThan(0));
    expect(narrow.visible + narrow.hidden, 8);
  });

  test('store preview loader sends one bulk call for many stores', () async {
    MobileHomeQueryLog.reset();
    var calls = 0;
    final loader = MobileStorePreviewLoader(
      fetch: (stores) async {
        calls++;
        return {
          for (final store in stores) store.id: const <Product>[],
        };
      },
    );
    final stores = [
      for (var i = 0; i < 8; i++)
        MobileNearbyStore(id: 's$i', name: 'Magaza $i'),
    ];
    final first = loader.load(stores);
    final second = loader.load(stores);
    await Future.wait([first, second]);
    expect(calls, 1);
    expect(MobileHomeQueryLog.storePreviewQueries, 1);
  });

  testWidgets('mobile home pull refresh does not overlap fetches', (
    tester,
  ) async {
    final gate = _HoldGate(MobileHomeBundle.empty);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    var companion = 0;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: AppState()),
          ChangeNotifierProvider<FavoriteState>.value(value: FavoriteState()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MobileHomeFeed(
              bannerUrls: const [],
              heroLoading: false,
              gateway: gate,
              onPullRefresh: () async => companion++,
              onSearch: (_) {},
              onOpenMap: () {},
              onOpenCategories: () {},
              onOpenCategory: (_) {},
              onOpenVehicles: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(gate.calls, 1);
    expect(gate.maxInFlight, 1);
    final indicator = tester.widget<RefreshIndicator>(
      find.byKey(const ValueKey('mobile-home-refresh')),
    );
    final joined = indicator.onRefresh();
    await tester.pump();
    expect(gate.calls, 1);
    expect(gate.maxInFlight, 1);
    gate.release();
    await joined;
    await tester.pump();
    expect(companion, 0);
    final again = indicator.onRefresh();
    final overlap = indicator.onRefresh();
    await tester.pump();
    expect(gate.maxInFlight, 1);
    gate.release();
    await Future.wait([again, overlap]);
    await tester.pump();
    expect(gate.calls, 2);
    expect(companion, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile home sections follow the requested order', (tester) async {
    await _pump(tester, size: const Size(390, 844), bundle: _bundle());
    double offsetOf(Finder finder) {
      final box = tester.renderObject<RenderBox>(finder);
      return RenderAbstractViewport.of(box).getOffsetToReveal(box, 0).offset;
    }

    final personal = offsetOf(
      find.byKey(
        const ValueKey('mobile-product-rail-Sana Özel'),
        skipOffstage: false,
      ),
    );
    final malls = offsetOf(
      find.byKey(const ValueKey('mobile-home-malls'), skipOffstage: false),
    );
    final stores = offsetOf(
      find.byKey(const ValueKey('mobile-home-nearby'), skipOffstage: false),
    );
    expect(personal, lessThan(malls));
    expect(malls, lessThan(stores));
    expect(find.text('Yakınındaki AVM\'ler', skipOffstage: false), findsOneWidget);
    expect(
      find.text('Yakınındaki Mağazalar', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Yakındaki Mağazalar'), findsNothing);
    await tester.pump(const Duration(seconds: 9));
  });
}

class _HoldGate implements MobileHomeGateway {
  _HoldGate(this.bundle);

  final MobileHomeBundle bundle;
  var calls = 0;
  var inFlight = 0;
  var maxInFlight = 0;
  Completer<void>? _hold;

  void release() {
    final hold = _hold;
    _hold = null;
    if (hold != null && !hold.isCompleted) hold.complete();
  }

  @override
  Future<MobileHomeBundle> load() async {
    calls++;
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    final hold = Completer<void>();
    _hold = hold;
    await hold.future;
    inFlight--;
    return bundle;
  }
}
