import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ibul_app/core/app_state.dart';
import 'package:ibul_app/core/cart_state.dart';
import 'package:ibul_app/core/constants.dart';
import 'package:ibul_app/core/favorite_state.dart';
import 'package:ibul_app/core/review_state.dart';
import 'package:ibul_app/models/product_model.dart';
import 'package:ibul_app/widgets/brand_section.dart';
import 'package:ibul_app/widgets/feature_menu.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import 'package:ibul_app/widgets/product_card.dart';

const _frameBudgetMs = 16.0;

const _homeScrollKey = ValueKey('profile-home-scroll');
const _homeFeaturedRailKey = ValueKey('profile-home-featured-rail');
const _homePopularRailKey = ValueKey('profile-home-popular-rail');
const _gridScrollKey = ValueKey('profile-grid-scroll');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await _ensureSupabaseInitialized();
  });

  setUp(() {
    debugProfileBuildsEnabledUserWidgets = true;
    debugProfileLayoutsEnabled = true;
    debugProfilePaintsEnabled = true;
  });

  tearDown(() {
    debugProfileBuildsEnabledUserWidgets = false;
    debugProfileLayoutsEnabled = false;
    debugProfilePaintsEnabled = false;
  });

  testWidgets('profiles home-style lists and product grid', (tester) async {
    await binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() async {
      await binding.setSurfaceSize(null);
    });

    final products = _buildSampleProducts(120);

    await _captureScenario(
      binding: binding,
      tester: tester,
      reportPrefix: 'home_screen',
      screen: _ProfileHomeScreen(products: products.take(36).toList()),
      action: _driveHomeScenario,
    );

    await _captureScenario(
      binding: binding,
      tester: tester,
      reportPrefix: 'product_grid',
      screen: _ProfileProductGridScreen(products: products),
      action: _driveGridScenario,
    );
  });
}

Future<void> _captureScenario({
  required IntegrationTestWidgetsFlutterBinding binding,
  required WidgetTester tester,
  required String reportPrefix,
  required Widget screen,
  required Future<void> Function(WidgetTester tester) action,
}) async {
  final app = _ProfilePerfApp(child: screen);

  await tester.pumpWidget(app);
  await tester.pumpAndSettle();

  binding.reportData ??= <String, dynamic>{};

  await binding.watchPerformance(
    () async => action(tester),
    reportKey: '${reportPrefix}_performance',
  );

  await tester.pumpWidget(app);
  await tester.pumpAndSettle();

  await binding.traceAction(
    () async => action(tester),
    streams: const <String>['Dart'],
    reportKey: '${reportPrefix}_timeline',
  );

  final timeline = Map<String, dynamic>.from(
    binding.reportData!['${reportPrefix}_timeline'] as Map,
  );
  binding.reportData!['${reportPrefix}_analysis'] = _analyzeTimeline(timeline);
}

Future<void> _driveHomeScenario(WidgetTester tester) async {
  await tester.fling(find.byKey(_homeScrollKey), const Offset(0, -1400), 2600);
  await tester.pumpAndSettle();

  await tester.drag(find.byKey(_homeFeaturedRailKey), const Offset(-900, 0));
  await tester.pumpAndSettle();

  await tester.drag(find.byKey(_homePopularRailKey), const Offset(-900, 0));
  await tester.pumpAndSettle();

  await tester.fling(find.byKey(_homeScrollKey), const Offset(0, -1800), 2800);
  await tester.pumpAndSettle();

  await tester.fling(find.byKey(_homeScrollKey), const Offset(0, 1500), 2600);
  await tester.pumpAndSettle();
}

Future<void> _driveGridScenario(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.fling(
      find.byKey(_gridScrollKey),
      const Offset(0, -1900),
      3000,
    );
    await tester.pumpAndSettle();
  }

  for (var i = 0; i < 2; i++) {
    await tester.fling(find.byKey(_gridScrollKey), const Offset(0, 1700), 2800);
    await tester.pumpAndSettle();
  }
}

Future<void> _ensureSupabaseInitialized() async {
  try {
    Supabase.instance.client;
    return;
  } catch (_) {
    await Supabase.initialize(
      url: 'https://perf-profile.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
          'eyJpc3MiOiJwZXJmLXByb2ZpbGUiLCJyZWYiOiJwZXJmLXByb2ZpbGUiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTcwMDAwMDAwMCwiZXhwIjoyMDAwMDAwMDAwfQ.'
          'perf-profile-signature',
    );
  }
}

Map<String, dynamic> _analyzeTimeline(Map<String, dynamic> timeline) {
  const interestingWidgets = <String>{
    '_ProfileHomeScreen',
    '_ProfileProductGridScreen',
    '_ProfileProductRail',
    '_ProfileBannerStrip',
    'FeatureMenu',
    'BrandSection',
    'ProductCard',
    'OptimizedImage',
  };

  final byWidget = <String, _WidgetTimingSummary>{};
  final traceEvents = (timeline['traceEvents'] as List?) ?? const [];

  for (final rawEvent in traceEvents) {
    if (rawEvent is! Map) {
      continue;
    }

    final name = rawEvent['name'];
    final phase = rawEvent['ph'];
    final duration = rawEvent['dur'];
    if (name is! String || phase != 'X' || duration is! num) {
      continue;
    }
    if (!interestingWidgets.contains(name)) {
      continue;
    }

    final durationMs = duration / 1000.0;
    byWidget
        .putIfAbsent(name, () => _WidgetTimingSummary(name))
        .add(durationMs);
  }

  final overBudget =
      byWidget.values
          .where((summary) => summary.maxDurationMs > _frameBudgetMs)
          .toList()
        ..sort((a, b) => b.maxDurationMs.compareTo(a.maxDurationMs));

  final topByTotal = byWidget.values.toList()
    ..sort((a, b) => b.totalDurationMs.compareTo(a.totalDurationMs));

  return <String, dynamic>{
    'frame_budget_ms': _frameBudgetMs,
    'widgets_over_budget': overBudget
        .map((summary) => summary.toJson())
        .toList(),
    'top_widgets_by_total_build_ms': topByTotal
        .take(8)
        .map((summary) => summary.toJson())
        .toList(),
  };
}

class _ProfilePerfApp extends StatelessWidget {
  const _ProfilePerfApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>(create: (_) => AppState()),
        ChangeNotifierProvider<CartState>(create: (_) => CartState()),
        ChangeNotifierProvider<FavoriteState>(create: (_) => FavoriteState()),
        ChangeNotifierProvider<ReviewState>(create: (_) => ReviewState()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: AppColors.primary,
          scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        ),
        home: child,
      ),
    );
  }
}

class _ProfileHomeScreen extends StatefulWidget {
  const _ProfileHomeScreen({required this.products});

  final List<Product> products;

  @override
  State<_ProfileHomeScreen> createState() => _ProfileHomeScreenState();
}

class _ProfileHomeScreenState extends State<_ProfileHomeScreen> {
  late final Map<String, dynamic> _brandData;
  late final List<String> _brands;
  late String _selectedBrand;

  @override
  void initState() {
    super.initState();
    _brandData = _buildBrandData(widget.products);
    _brands = _brandData.keys.toList(growable: false);
    _selectedBrand = _brands.first;
  }

  @override
  Widget build(BuildContext context) {
    final featuredProducts = widget.products.take(12).toList(growable: false);
    final popularProducts = widget.products
        .skip(8)
        .take(12)
        .toList(growable: false);

    return Scaffold(
      body: CustomScrollView(
        key: _homeScrollKey,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Home Screen Profile Harness',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Production widgets arranged like a long home page.',
                    style: TextStyle(color: Colors.blueGrey.shade600),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: FeatureMenu()),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          const SliverToBoxAdapter(child: _ProfileBannerStrip()),
          SliverToBoxAdapter(
            child: _ProfileProductRail(
              title: 'Featured Deals',
              railKey: _homeFeaturedRailKey,
              products: featuredProducts,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: BrandSection(
                title: 'Brand Spotlight',
                brands: _brands,
                brandData: _brandData,
                selectedBrand: _selectedBrand,
                tightCards: true,
                pinActionsBottom: true,
                onBrandSelected: (brand) {
                  setState(() {
                    _selectedBrand = brand;
                  });
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _ProfileProductRail(
              title: 'Popular Products',
              railKey: _homePopularRailKey,
              products: popularProducts,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _ProfileBannerStrip extends StatelessWidget {
  const _ProfileBannerStrip();

  @override
  Widget build(BuildContext context) {
    const banners = [
      'assets/haircare/urban reklam 1.png',
      'assets/haircare/urban reklam 2.png',
      'assets/haircare/clear reklam 1.png',
    ];

    return SizedBox(
      height: 240,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.88),
        itemCount: banners.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: OptimizedImage(
                imageUrlOrPath: banners[index],
                fit: BoxFit.cover,
                cacheWidth: 1600,
                cacheHeight: 480,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfileProductRail extends StatelessWidget {
  const _ProfileProductRail({
    required this.title,
    required this.railKey,
    required this.products,
  });

  final String title;
  final Key railKey;
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 328,
            child: ListView.separated(
              key: railKey,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: products.length,
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) => SizedBox(
                width: 220,
                child: ProductCard(
                  product: products[index],
                  compact: false,
                  pinActionsBottom: true,
                  imagePriority: index < 4
                      ? OptimizedImagePriority.high
                      : OptimizedImagePriority.lazy,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileProductGridScreen extends StatelessWidget {
  const _ProfileProductGridScreen({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        key: _gridScrollKey,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Product Grid Profile Harness',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Primary scrollable grid with production ProductCard widgets.',
                    style: TextStyle(color: Colors.blueGrey.shade600),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 250,
                childAspectRatio: 0.65,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                return ProductCard(
                  product: products[index],
                  compact: false,
                  margin: EdgeInsets.zero,
                  imagePriority: index < 8
                      ? OptimizedImagePriority.high
                      : OptimizedImagePriority.lazy,
                );
              }, childCount: products.length),
            ),
          ),
        ],
      ),
    );
  }
}

Map<String, dynamic> _buildBrandData(List<Product> products) {
  final first = products
      .take(4)
      .map(_productToBrandMap)
      .toList(growable: false);
  final second = products
      .skip(4)
      .take(4)
      .map(_productToBrandMap)
      .toList(growable: false);
  final third = products
      .skip(8)
      .take(4)
      .map(_productToBrandMap)
      .toList(growable: false);

  return <String, dynamic>{
    'Urban': {
      'logo': 'assets/icons/ibul_logo_2.png',
      'adUrls': const [
        'assets/haircare/urban reklam 1.png',
        'assets/haircare/urban reklam 2.png',
      ],
      'products': first,
    },
    'Clear': {
      'logo': 'assets/icons/ibul_logo_2.png',
      'adUrls': const [
        'assets/haircare/clear reklam 1.png',
        'assets/haircare/clear reklam 2.png',
      ],
      'products': second,
    },
    'Dove': {
      'logo': 'assets/icons/ibul_logo_2.png',
      'adUrls': const ['assets/haircare/Dove reklam.png'],
      'products': third,
    },
  };
}

Map<String, dynamic> _productToBrandMap(Product product) {
  return <String, dynamic>{
    'name': product.name,
    'price': product.price,
    'oldPrice': product.oldPrice,
    'rating': product.rating,
    'reviews': product.reviewCount,
    'tags': product.tags,
    'images': product.images,
    'brand': product.brand,
  };
}

List<Product> _buildSampleProducts(int count) {
  const brands = [
    'Apple',
    'Samsung',
    'Nike',
    'Dyson',
    'Sony',
    'Mavi',
    'Urban Care',
    'Dove',
  ];
  const categories = ['Elektronik', 'Moda', 'Süpermarket', 'Kişisel Bakım'];
  const imagePool = [
    'assets/products/iphone15_mavi_256gb.png',
    'assets/products/s24_mor_2.webp',
    'assets/products/nike_airmax90.jpeg',
    'assets/products/dyson_v15.jpeg',
    'assets/products/sony_xm5.jpg',
    'assets/products/Mavi Erkek Kot Pantolon.jpeg',
    'assets/products/Urban Care Hyaluronic Şampuan.jpg',
    'assets/products/Dove Yoğun Onarım Şampuan.jpeg',
  ];

  return List<Product>.generate(count, (index) {
    final brand = brands[index % brands.length];
    final category = categories[index % categories.length];
    final image = imagePool[index % imagePool.length];
    final hasDiscount = index.isEven;

    return Product(
      productId: 'profile-$index',
      name: '$brand Profiling Product ${index + 1}',
      brand: brand,
      price: '${899 + (index * 17)} TL',
      oldPrice: hasDiscount ? '${1099 + (index * 19)} TL' : null,
      rating: 4.0 + ((index % 10) / 10),
      reviewCount: 32 + (index * 7),
      tags: [
        if (index % 3 == 0) 'Hızlı Kargo',
        if (index % 4 == 0) 'Ücretsiz Kargo',
        if (hasDiscount) '%20 indirim',
      ],
      images: [image],
      category: category,
      subCategory: category,
      store: 'Profile Store ${(index % 6) + 1}',
      description: 'Profiling fixture product used for frame analysis.',
    );
  });
}

class _WidgetTimingSummary {
  _WidgetTimingSummary(this.widgetName);

  final String widgetName;
  double maxDurationMs = 0;
  double totalDurationMs = 0;
  int eventCount = 0;

  void add(double durationMs) {
    eventCount++;
    totalDurationMs += durationMs;
    if (durationMs > maxDurationMs) {
      maxDurationMs = durationMs;
    }
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'widget': widgetName,
      'max_build_ms': double.parse(maxDurationMs.toStringAsFixed(3)),
      'total_build_ms': double.parse(totalDurationMs.toStringAsFixed(3)),
      'event_count': eventCount,
    };
  }
}
