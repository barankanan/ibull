import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ibul_app/core/app_state.dart';
import 'package:ibul_app/core/home_navigation.dart';
import 'package:ibul_app/core/mobile_category_catalog.dart';
import 'package:ibul_app/app/marketplace_paths.dart';
import 'package:ibul_app/features/coupon/data/coupon_repository.dart';
import 'package:ibul_app/features/vehicle/data/vehicle_listing_repository.dart';
import 'package:ibul_app/features/vehicle/models/vehicle_enums.dart';
import 'package:ibul_app/features/vehicle/models/vehicle_listing.dart';
import 'package:ibul_app/models/db_category.dart';
import 'package:ibul_app/screens/home/home_discovery_loader.dart';
import 'package:ibul_app/screens/home/home_viewport_section.dart';
import 'package:ibul_app/screens/home/sections/home_category_navigation.dart';
import 'package:ibul_app/screens/home/sections/home_section_coupon_deal_column.dart';
import 'package:ibul_app/screens/home/sections/home_vehicle_rail_section.dart';
import 'package:ibul_app/widgets/web_header.dart';
import 'package:ibul_app/widgets/custom_header.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late AppState appState;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test',
    );
    appState = AppState();
  });
  tearDown(HomeDiscoveryLoader.resetForTest);

  test('mobile category tree shows DB-only names without seed categories', () {
    final tree = buildMobileCategoryTree(
      [
        CategoryWithSubcategories(
          mainCategory: DBCategory(
            id: 40,
            name: 'Bilgisayar / Elektronik',
            orderIndex: 1,
          ),
          subCategories: [
            DBCategory(id: 41, name: 'Tabletler', parentId: 40, orderIndex: 2),
            DBCategory(id: 42, name: 'TABLETLER', parentId: 40, orderIndex: 3),
          ],
        ),
        CategoryWithSubcategories(
          mainCategory: DBCategory(
            id: 50,
            name: 'Restoran ve Yemek',
            orderIndex: 2,
          ),
          subCategories: [],
        ),
      ],
      includeUnmatchedMainCategories: true,
      includeMissingDefaultCategories: false,
    );

    expect(tree.map((category) => category.name), [
      'Bilgisayar / Elektronik',
      'Restoran ve Yemek',
    ]);
    expect(tree.first.subCategories.single.id, 41);
    expect(tree.map((category) => category.name), isNot(contains('Erkek')));
  });

  testWidgets('mobile header logo, search and camera fit at 390px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: appState,
        child: MaterialApp(
          home: Scaffold(body: CustomHeader(onSearch: (_) {})),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Bildirimler'), findsOneWidget);
    final bell = tester.getRect(find.byTooltip('Bildirimler'));
    final search = tester.getRect(find.byType(TextField));
    final camera = tester.getRect(find.byTooltip('Kamera'));
    expect(find.byKey(const ValueKey('mobile-header-logo')), findsNothing);
    expect(bell.right, lessThanOrEqualTo(search.left));
    expect(search.width, greaterThan(150));
    expect(search.right, lessThan(camera.left));
    expect(tester.takeException(), isNull);
    expect(find.text('Erkek'), findsNothing);
    expect(find.text('Kadın'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [1440.0, 1024.0]) {
    testWidgets('header uses the remaining search width at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: appState,
          child: MaterialApp(
            home: Scaffold(
              body: WebHeader(onSearch: (_) {}, showCategories: false),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final search = tester.getRect(
        find
            .ancestor(
              of: find.byType(TextField),
              matching: find.byType(Container),
            )
            .first,
      );
      final map = tester.getRect(find.text('Harita'));
      final account = tester.getRect(find.text('Hesabım'));
      final favorites = tester.getRect(find.text('Favorilerim'));
      final cart = tester.getRect(find.text('Sepetim'));
      expect(search.width, greaterThan(180));
      expect(map.left - search.right, lessThan(170));
      expect(map.right, lessThan(account.left));
      expect(account.right, lessThan(favorites.left));
      expect(favorites.right, lessThan(cart.left));
      expect(account.center.dy, closeTo(favorites.center.dy, 1));
      expect(cart.center.dy, closeTo(account.center.dy, 1));
    });
  }

  testWidgets(
    'subcategory selection navigates without changing home state at 390px',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const homeCategory = 'Ana Sayfa';
      String? selectedRoute;
      final tree = [
        CategoryWithSubcategories(
          mainCategory: DBCategory(id: 1, name: 'Erkek', orderIndex: 0),
          subCategories: [
            DBCategory(id: 2, name: 'Giyim', parentId: 1, orderIndex: 0),
            DBCategory(
              id: 3,
              name: 'Inactive child',
              parentId: 1,
              orderIndex: 1,
              isActive: false,
            ),
            DBCategory(id: 4, name: 'Wrong parent', parentId: 9, orderIndex: 2),
          ],
        ),
        CategoryWithSubcategories(
          mainCategory: DBCategory(id: 9, name: 'Kadın', orderIndex: 1),
          subCategories: [],
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Column(
                children: [
                  HomeCategoryNavigation(
                    selectedCategory: homeCategory,
                    selectedSubCategory: null,
                    loadCategories: () async => tree,
                    onSelected: (_, _) => fail('Parent tap changed home state'),
                    onOpenSubCategory: (mainCategory, subCategory) {
                      selectedRoute = MarketplacePaths.category(
                        mainCategory.id!,
                        subCategory.id!,
                        slug: '${mainCategory.name}-${subCategory.name}',
                      );
                    },
                  ),
                  const Text('Teslimat Adresi'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Erkek'));
      await tester.pumpAndSettle();
      expect(find.text('Giyim'), findsOneWidget);
      expect(find.text('Inactive child'), findsNothing);
      expect(find.text('Wrong parent'), findsNothing);
      await tester.tap(find.text('Giyim'));
      await tester.pumpAndSettle();
      expect(homeCategory, 'Ana Sayfa');
      expect(selectedRoute, '/kategori/1/2/erkek-giyim');
      await tester.tap(find.text('Kadın'));
      await tester.pumpAndSettle();
      expect(find.text('Wrong parent'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('desktop mega-menu stays open while pointer enters it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final tree = [
      CategoryWithSubcategories(
        mainCategory: DBCategory(id: 1, name: 'Erkek', orderIndex: 0),
        subCategories: [
          DBCategory(id: 2, name: 'Giyim', parentId: 1, orderIndex: 0),
        ],
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeCategoryNavigation(
            selectedCategory: 'Ana Sayfa',
            selectedSubCategory: null,
            loadCategories: () async => tree,
            onSelected: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.text('Erkek')));
    await mouse.moveTo(tester.getCenter(find.text('Erkek')));
    await tester.pumpAndSettle();
    expect(find.text('Giyim'), findsOneWidget);
    expect(tester.getRect(find.byType(GridView)).height, lessThan(200));
    await mouse.moveTo(tester.getCenter(find.text('Giyim')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Giyim'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet category menu opens by tap, not hover', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final tree = [
      CategoryWithSubcategories(
        mainCategory: DBCategory(id: 1, name: 'Erkek', orderIndex: 0),
        subCategories: [
          DBCategory(id: 2, name: 'Giyim', parentId: 1, orderIndex: 0),
        ],
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeCategoryNavigation(
            selectedCategory: 'Ana Sayfa',
            selectedSubCategory: null,
            loadCategories: () async => tree,
            onSelected: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.text('Erkek')));
    await mouse.moveTo(tester.getCenter(find.text('Erkek')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Giyim'), findsNothing);
    await tester.tap(find.text('Erkek'));
    await tester.pumpAndSettle();
    expect(find.text('Giyim'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mounted deferred section receives new filter props', (
    tester,
  ) async {
    Widget page(String text) => MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            HomeViewportSection(
              placeholderHeight: 100,
              loadLibrary: () async {},
              builder: () => Text(text),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(page('All products'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(page('Selected subcategory'));
    await tester.pumpAndSettle();
    expect(find.text('Selected subcategory'), findsOneWidget);
    expect(find.text('All products'), findsNothing);
  });

  test('home route arguments retain the parent and subcategory', () {
    final args = HomeRouteArgs.from({
      'category': 'Erkek',
      'subcategory': 'Giyim',
    });
    expect(args.initialCategory, 'Erkek');
    expect(args.initialSubCategory, 'Giyim');
  });

  test('vehicle errors propagate and a failed request can retry', () async {
    var calls = 0;
    HomeDiscoveryLoader.debugVehiclesQuery = () async {
      if (++calls == 1) throw StateError('query failed');
      return [];
    };
    await expectLater(HomeDiscoveryLoader.loadVehicles(), throwsStateError);
    expect(await HomeDiscoveryLoader.loadVehicles(), isEmpty);
    expect(calls, 2);
  });

  test(
    'home vehicle query keeps moderation and rental data without gallery embed',
    () async {
      late Uri requested;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test',
        httpClient: MockClient((request) async {
          requested = request.url;
          return http.Response(
            jsonEncode([
              {
                'id': 'v1',
                'seller_id': 's1',
                'status': 'active',
                'listing_type': 'rental',
                'vehicle_specs': {
                  'brand': 'Toyota',
                  'model': 'Corolla',
                  'year': 2021,
                },
                'vehicle_rental_settings': {'daily_price': 1500},
                'vehicle_media': [
                  {
                    'id': 'm1',
                    'slot': 'front',
                    'url': 'https://example.com/car.jpg',
                    'is_cover': true,
                  },
                ],
                'ai_payload': {
                  'moderation': {'status': 'rejected'},
                },
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      final rows = await VehicleListingRepository(
        client: client,
      ).getHomeListings();
      expect(requested.queryParameters['status'], 'eq.active');
      expect(
        requested.queryParameters['select'],
        isNot(contains('vehicle_galleries')),
      );
      expect(rows.single.isLivePublished, isFalse);
      expect(rows.single.rental!.dailyPrice, 1500);
      expect(rows.single.primaryImageUrl, 'https://example.com/car.jpg');
      final pending = VehicleListing.fromMap({
        'id': 'v2',
        'seller_id': 's1',
        'status': 'active',
        'listing_type': 'sale',
        'vehicle_specs': {'brand': 'Toyota', 'model': 'Corolla', 'year': 2021},
        'ai_payload': {
          'moderation': {'status': 'pending'},
        },
      });
      expect(pending.isLivePublished, isFalse);
      await client.dispose();
    },
  );

  testWidgets(
    'vehicle loading, empty, error and populated states stay distinct',
    (tester) async {
      Future<void> pump({
        bool loading = false,
        String? error,
        List<VehicleListing> listings = const [],
      }) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeVehicleRailSection(
              isLoading: loading,
              errorMessage: error,
              listings: listings,
              onRetry: () {},
            ),
          ),
        ),
      );
      await pump(loading: true);
      expect(find.text('Şu anda yayında araç ilanı bulunmuyor.'), findsNothing);
      await pump();
      expect(
        find.text('Şu anda yayında araç ilanı bulunmuyor.'),
        findsOneWidget,
      );
      await pump(error: 'failed');
      expect(find.text('Araç ilanları yüklenemedi'), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
      await pump(
        listings: [
          VehicleListing(
            id: 'v1',
            sellerId: 's1',
            listingType: VehicleListingType.sale,
            status: VehicleListingStatus.active,
            salePrice: 500000,
            city: 'İstanbul',
            specs: const VehicleSpecs(
              brand: 'Toyota',
              model: 'Corolla',
              year: 2021,
              mileageKm: 20000,
            ),
          ),
        ],
      );
      expect(find.text('Araç İlanları'), findsOneWidget);
      expect(find.textContaining('Toyota'), findsOneWidget);
      expect(find.textContaining('İstanbul'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('daily deal errors are compact and retry recovers to empty', (
    tester,
  ) async {
    var fail = true;
    var calls = 0;
    late SupabaseClient client;
    await tester.runAsync(() async {
      client = SupabaseClient(
        'https://example.supabase.co',
        'test',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('list_daily_deal_products')) {
            calls++;
            if (fail) {
              return http.Response(
                jsonEncode({
                  'code': 'PGRST202',
                  'message': 'private technical details',
                }),
                404,
                headers: {'content-type': 'application/json'},
                request: request,
              );
            }
          }
          return http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              height: 264,
              child: HomeCouponDealColumn(
                repository: CouponRepository(client: client),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('private technical details'), findsNothing);
    expect(find.text('Günün fırsatı yüklenemedi.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    fail = false;
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Günün fırsatı yüklenemedi.'), findsNothing);
    expect(find.text('Kuponlarım'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(client.dispose);
  });
}
