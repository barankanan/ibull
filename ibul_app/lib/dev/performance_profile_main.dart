import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ibul_app/core/app_state.dart';
import 'package:ibul_app/core/build_profile.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPreferences.getInstance();
  await _ensureSupabaseInitialized();
  BuildProfileCollector.enabled = true;

  runApp(const _ProfileRunnerApp());
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

class _ProfileRunnerApp extends StatelessWidget {
  const _ProfileRunnerApp();

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
        home: const _ProfileRunnerScreen(),
      ),
    );
  }
}

enum _ProfileScenario { homeScreen, productGrid }

class _ProfileRunnerScreen extends StatefulWidget {
  const _ProfileRunnerScreen();

  @override
  State<_ProfileRunnerScreen> createState() => _ProfileRunnerScreenState();
}

class _ProfileRunnerScreenState extends State<_ProfileRunnerScreen> {
  final _frameCollector = _FrameTimingCollector();
  final _homeScrollController = ScrollController();
  final _homeFeaturedRailController = ScrollController();
  final _homePopularRailController = ScrollController();
  final _gridScrollController = ScrollController();
  final List<Product> _products = _buildSampleProducts(120);
  final Map<String, dynamic> _report = {};

  _ProfileScenario _scenario = _ProfileScenario.homeScreen;
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_frameCollector.addTimings);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_hasStarted) {
        return;
      }
      _hasStarted = true;
      unawaited(_runProfile());
    });
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_frameCollector.addTimings);
    _homeScrollController.dispose();
    _homeFeaturedRailController.dispose();
    _homePopularRailController.dispose();
    _gridScrollController.dispose();
    super.dispose();
  }

  Future<void> _runProfile() async {
    try {
      _report['home_screen'] = await _captureScenario(
        scenario: _ProfileScenario.homeScreen,
        action: _driveHomeScenario,
      );
      _report['product_lists'] = await _captureScenario(
        scenario: _ProfileScenario.productGrid,
        action: _driveGridScenario,
      );

      final encoded = jsonEncode(_report);
      stdout.writeln('PERF_REPORT:$encoded');
      exit(0);
    } catch (error, stackTrace) {
      stderr.writeln(
        'PERF_ERROR:${jsonEncode(<String, String>{'error': error.toString(), 'stackTrace': stackTrace.toString()})}',
      );
      exitCode = 1;
      exit(1);
    }
  }

  Future<Map<String, dynamic>> _captureScenario({
    required _ProfileScenario scenario,
    required Future<void> Function() action,
  }) async {
    await _switchScenario(scenario);
    BuildProfileCollector.reset();
    _frameCollector.reset();

    await _waitForFrames(4);
    await action();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await _waitForFrames(4);

    return <String, dynamic>{
      ..._frameCollector.snapshot(),
      'widgets': BuildProfileCollector.snapshot(frameBudgetMs: _frameBudgetMs),
    };
  }

  Future<void> _switchScenario(_ProfileScenario scenario) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _scenario = scenario;
    });

    await Future<void>.delayed(const Duration(milliseconds: 700));
    await _waitForFrames(6);
  }

  Future<void> _driveHomeScenario() async {
    await _awaitController(_homeScrollController);
    await _awaitController(_homeFeaturedRailController);
    await _awaitController(_homePopularRailController);

    await _animateBy(
      _homeScrollController,
      1200,
      const Duration(milliseconds: 750),
    );
    await _animateBy(
      _homeFeaturedRailController,
      840,
      const Duration(milliseconds: 550),
    );
    await _animateBy(
      _homePopularRailController,
      840,
      const Duration(milliseconds: 550),
    );
    await _animateBy(
      _homeScrollController,
      1700,
      const Duration(milliseconds: 850),
    );
    await _animateBy(
      _homeScrollController,
      -1700,
      const Duration(milliseconds: 800),
    );
  }

  Future<void> _driveGridScenario() async {
    await _awaitController(_gridScrollController);

    for (var i = 0; i < 4; i++) {
      await _animateBy(
        _gridScrollController,
        1900,
        const Duration(milliseconds: 820),
      );
    }

    for (var i = 0; i < 2; i++) {
      await _animateBy(
        _gridScrollController,
        -1500,
        const Duration(milliseconds: 760),
      );
    }
  }

  Future<void> _awaitController(ScrollController controller) async {
    while (mounted && !controller.hasClients) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> _animateBy(
    ScrollController controller,
    double delta,
    Duration duration,
  ) async {
    if (!controller.hasClients) {
      return;
    }

    final position = controller.position;
    final target = (position.pixels + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((target - position.pixels).abs() < 1) {
      return;
    }

    await controller.animateTo(
      target,
      duration: duration,
      curve: Curves.easeOutCubic,
    );
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }

  Future<void> _waitForFrames(int frameCount) {
    if (frameCount <= 0) {
      return Future<void>.value();
    }

    final completer = Completer<void>();
    var remaining = frameCount;

    void scheduleNext(Duration _) {
      remaining -= 1;
      if (remaining <= 0) {
        completer.complete();
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback(scheduleNext);
    }

    WidgetsBinding.instance.addPostFrameCallback(scheduleNext);
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    final child = switch (_scenario) {
      _ProfileScenario.homeScreen => _ProfileHomeScreen(
        products: _products.take(36).toList(growable: false),
        scrollController: _homeScrollController,
        featuredRailController: _homeFeaturedRailController,
        popularRailController: _homePopularRailController,
      ),
      _ProfileScenario.productGrid => _ProfileProductGridScreen(
        products: _products,
        scrollController: _gridScrollController,
      ),
    };

    return Stack(
      children: [
        child,
        Positioned(
          top: 18,
          right: 18,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.68),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                _scenario == _ProfileScenario.homeScreen
                    ? 'Profiling home screen'
                    : 'Profiling product lists',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileHomeScreen extends StatefulWidget {
  const _ProfileHomeScreen({
    required this.products,
    required this.scrollController,
    required this.featuredRailController,
    required this.popularRailController,
  });

  final List<Product> products;
  final ScrollController scrollController;
  final ScrollController featuredRailController;
  final ScrollController popularRailController;

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
    return BuildProfileCollector.measure('_ProfileHomeScreen', () {
      final featuredProducts = widget.products.take(12).toList(growable: false);
      final popularProducts = widget.products
          .skip(8)
          .take(12)
          .toList(growable: false);

      return Scaffold(
        body: CustomScrollView(
          controller: widget.scrollController,
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
                controller: widget.featuredRailController,
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
                controller: widget.popularRailController,
                products: popularProducts,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      );
    });
  }
}

class _ProfileBannerStrip extends StatelessWidget {
  const _ProfileBannerStrip();

  @override
  Widget build(BuildContext context) {
    return BuildProfileCollector.measure('_ProfileBannerStrip', () {
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
                  cacheWidth: 1200,
                  cacheHeight: 480,
                ),
              ),
            );
          },
        ),
      );
    });
  }
}

class _ProfileProductRail extends StatelessWidget {
  const _ProfileProductRail({
    required this.title,
    required this.controller,
    required this.products,
  });

  final String title;
  final ScrollController controller;
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return BuildProfileCollector.measure('_ProfileProductRail', () {
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
                controller: controller,
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
    });
  }
}

class _ProfileProductGridScreen extends StatelessWidget {
  const _ProfileProductGridScreen({
    required this.products,
    required this.scrollController,
  });

  final List<Product> products;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return BuildProfileCollector.measure('_ProfileProductGridScreen', () {
      return Scaffold(
        body: CustomScrollView(
          controller: scrollController,
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
    });
  }
}

class _FrameTimingCollector {
  final List<FrameTiming> _timings = [];

  void addTimings(List<FrameTiming> timings) {
    _timings.addAll(timings);
  }

  void reset() {
    _timings.clear();
  }

  Map<String, dynamic> snapshot() {
    final buildDurations = _timings
        .map((timing) => timing.buildDuration.inMicroseconds / 1000.0)
        .toList(growable: false);
    final rasterDurations = _timings
        .map((timing) => timing.rasterDuration.inMicroseconds / 1000.0)
        .toList(growable: false);

    final combinedJankCount = _timings.where((timing) {
      return timing.buildDuration.inMicroseconds / 1000.0 > _frameBudgetMs ||
          timing.rasterDuration.inMicroseconds / 1000.0 > _frameBudgetMs;
    }).length;

    return <String, dynamic>{
      'frame_count': _timings.length,
      'avg_build_ms': _average(buildDurations),
      'max_build_ms': _max(buildDurations),
      'avg_raster_ms': _average(rasterDurations),
      'max_raster_ms': _max(rasterDurations),
      'jank_build_frames': buildDurations
          .where((value) => value > _frameBudgetMs)
          .length,
      'jank_raster_frames': rasterDurations
          .where((value) => value > _frameBudgetMs)
          .length,
      'jank_frames_total': combinedJankCount,
      'worst_build_frames_ms': _topDurations(buildDurations),
      'worst_raster_frames_ms': _topDurations(rasterDurations),
    };
  }

  double _average(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }
    final total = values.fold<double>(0, (sum, value) => sum + value);
    return double.parse((total / values.length).toStringAsFixed(3));
  }

  double _max(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }
    return double.parse(
      values.reduce((a, b) => a > b ? a : b).toStringAsFixed(3),
    );
  }

  List<double> _topDurations(List<double> values) {
    final sorted = List<double>.from(values)..sort((a, b) => b.compareTo(a));
    return sorted
        .take(6)
        .map((value) => double.parse(value.toStringAsFixed(3)))
        .toList(growable: false);
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
  const categories = ['Elektronik', 'Moda', 'Supermarket', 'Kisisel Bakim'];
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
