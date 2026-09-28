import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ibul_app/app/account_sections.dart';
import 'package:ibul_app/app/ibul_router.dart';
import 'package:ibul_app/app/marketplace_paths.dart';
import 'package:ibul_app/features/vehicle/navigation/vehicle_routes.dart';
import 'package:ibul_app/models/product_model.dart';
import 'package:ibul_app/screens/home_lazy_routes.dart';

void main() {
  late GoRouter router;

  setUp(() {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    IbulRouter.debugUseRootRouter = true;
    router = GoRouter(
      initialLocation: '/',
      redirect: (context, state) {
        if (state.uri.path == '/home') return MarketplacePaths.home;
        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const _ClickHarness(),
        ),
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('legacy-home')),
        ),
        GoRoute(
          path: MarketplacePaths.account,
          builder: (_, __) => const Scaffold(body: Text('account-overview')),
        ),
        GoRoute(
          path: '/hesabim/:section',
          builder: (context, state) {
            final section = state.pathParameters['section'] ?? '';
            return Scaffold(body: Text('account-$section'));
          },
        ),
        GoRoute(
          path: '/urun/:id',
          builder: (context, state) {
            return Scaffold(
              body: Text('product-${state.pathParameters['id']}'),
            );
          },
        ),
        GoRoute(
          path: '/urun/:id/:slug',
          builder: (context, state) {
            return Scaffold(
              body: Text(
                'product-${state.pathParameters['id']}-${state.pathParameters['slug']}',
              ),
            );
          },
        ),
        GoRoute(
          path: '/arac/:id',
          builder: (context, state) {
            return Scaffold(
              body: Text('vehicle-${state.pathParameters['id']}'),
            );
          },
        ),
        GoRoute(
          path: '/arac/:id/:slug',
          builder: (context, state) {
            return Scaffold(
              body: Text(
                'vehicle-${state.pathParameters['id']}-${state.pathParameters['slug']}',
              ),
            );
          },
        ),
      ],
    );
    IbulGoRouterBinding.instance = router;
  });

  tearDown(() {
    if (IbulGoRouterBinding.instance == router) {
      IbulGoRouterBinding.instance = null;
    }
    IbulRouter.debugUseRootRouter = false;
    GoRouter.optionURLReflectsImperativeAPIs = false;
    router.dispose();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  String path() => router.routeInformationProvider.value.uri.path;

  testWidgets('legacy /home redirects to /', (tester) async {
    router.go('/home');
    await pumpApp(tester);
    expect(path(), '/');
    expect(find.text('home-shell'), findsOneWidget);
  });

  testWidgets('click Favorilerim updates router path', (tester) async {
    await pumpApp(tester);
    expect(path(), '/');

    await tester.tap(find.text('Favorilerim'));
    await tester.pumpAndSettle();

    expect(path(), MarketplacePaths.favorites);
    expect(find.text('account-favoriler'), findsOneWidget);
  });

  testWidgets('click Hesabım updates router path', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Hesabım'));
    await tester.pumpAndSettle();

    expect(path(), MarketplacePaths.account);
    expect(find.text('account-overview'), findsOneWidget);
  });

  testWidgets('click Siparişlerim updates router path', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Siparişlerim'));
    await tester.pumpAndSettle();

    expect(path(), MarketplacePaths.orders);
    expect(find.text('account-siparisler'), findsOneWidget);
  });

  testWidgets('click product card updates router path', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Samsung TV'));
    await tester.pumpAndSettle();

    expect(
      path(),
      MarketplacePaths.product(
        '178216519736848411',
        slug: 'Samsung 55 inc CU7000',
      ),
    );
    expect(path(), startsWith('/urun/178216519736848411'));
    expect(
      find.text('product-178216519736848411-samsung-55-inc-cu7000'),
      findsOneWidget,
    );
  });

  testWidgets('click vehicle card updates router path', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Toyota Corolla'));
    await tester.pumpAndSettle();

    expect(
      path(),
      MarketplacePaths.vehicle('de5ef4d2-veh', slug: 'Toyota Corolla'),
    );
    expect(path(), startsWith('/arac/de5ef4d2-veh'));
    expect(find.text('vehicle-de5ef4d2-veh-toyota-corolla'), findsOneWidget);
  });

  testWidgets('browser back returns to previous real URL', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Favorilerim'));
    await tester.pumpAndSettle();
    expect(path(), MarketplacePaths.favorites);

    router.pop();
    await tester.pumpAndSettle();
    expect(path(), '/');
    expect(find.text('home-shell'), findsOneWidget);
  });

  testWidgets('refresh product detail keeps the same route', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Samsung TV'));
    await tester.pumpAndSettle();
    final opened = path();
    expect(opened, startsWith('/urun/178216519736848411'));

    router.go(opened);
    await tester.pumpAndSettle();
    expect(path(), opened);
    expect(
      find.text('product-178216519736848411-samsung-55-inc-cu7000'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Navigator.push changes the screen but leaves the root path',
    (tester) async {
      await pumpApp(tester);
      final ctx = router.routerDelegate.navigatorKey.currentContext!;
      Navigator.of(ctx).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('nested-only')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('nested-only'), findsOneWidget);
      expect(path(), '/');
    },
  );
}

class _ClickHarness extends StatelessWidget {
  const _ClickHarness();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          const Text('home-shell'),
          TextButton(
            onPressed: () => HomeLazyRoutes.openAccount(context),
            child: const Text('Hesabım'),
          ),
          TextButton(
            onPressed: () => HomeLazyRoutes.openFavorites(context),
            child: const Text('Favorilerim'),
          ),
          TextButton(
            onPressed: () => AccountSections.open(
              context,
              AccountSection.orders,
              nativePage: const SizedBox.shrink(),
            ),
            child: const Text('Siparişlerim'),
          ),
          TextButton(
            onPressed: () => HomeLazyRoutes.openProductDetail(
              context,
              Product(
                productId: '178216519736848411',
                name: 'Samsung 55 inc CU7000',
                brand: 'Samsung',
                price: '1',
                rating: 4.5,
                reviewCount: 1,
                tags: const [],
                images: const [],
              ),
            ),
            child: const Text('Samsung TV'),
          ),
          TextButton(
            onPressed: () => VehicleRoutes.openDetail(
              context,
              'de5ef4d2-veh',
              slug: 'Toyota Corolla',
            ),
            child: const Text('Toyota Corolla'),
          ),
        ],
      ),
    );
  }
}
