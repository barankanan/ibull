import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/account_sections.dart';
import '../app/customer_routes.dart';
import '../app/marketplace_paths.dart';
import '../app/marketplace_route_pages.dart' deferred as marketplace_pages;
import '../app/route_args.dart';
import '../app/seller_routes.dart';
import '../app/site_info_routes.dart';
import '../core/qr_initial_params.dart';
import '../features/ihiz/delivery/ihiz_route_paths.dart';
import '../features/investor/investor_route_paths.dart';
import '../features/vehicle/screens/vehicle_detail_page.dart'
    deferred as vehicle_detail;
import '../features/vehicle/screens/vehicle_hub_page.dart' deferred as vehicle_hub;
import '../features/vehicle/screens/vehicle_search_page.dart'
    deferred as vehicle_search;
import '../models/product_model.dart';
import '../screens/ibul_not_found_page.dart';
import '../screens/qr_entry_screen.dart' deferred as qr_entry;
import '../screens/seller_panel_route_args.dart';
import '../widgets/deferred_module_screen.dart';

/// Production route table without [shared_app_widgets] / [app_bootstrap].
/// Home body is supplied by the benchmark entrypoint.
GoRouter createPhase14Router({
  required Widget Function() home,
}) {
  GoRouter.optionURLReflectsImperativeAPIs = true;
  return GoRouter(
    initialLocation: '/',
    errorBuilder: (context, state) => IbulNotFoundPage(path: state.uri.path),
    redirect: (context, state) => _redirect(state.uri.path),
    routes: [
      _route('/', home),
      _route('/home', home),
      for (final path in _paths) _route(path, () => _page(path) ?? home()),
      for (final path in SiteInfoRoutes.paths)
        _route(path, () => _page(path) ?? home()),
      GoRoute(
        path: '/hesabim/:section',
        builder: (_, state) =>
            _page('/hesabim/${state.pathParameters['section'] ?? ''}') ??
            home(),
      ),
      GoRoute(
        path: '/urun/:id',
        builder: (_, state) =>
            _page('/urun/${state.pathParameters['id'] ?? ''}') ?? home(),
      ),
      GoRoute(
        path: '/urun/:id/:slug',
        builder: (_, state) {
          final id = state.pathParameters['id'] ?? '';
          final slug = state.pathParameters['slug'] ?? '';
          return _page('/urun/$id/$slug') ?? home();
        },
      ),
      GoRoute(
        path: '/magaza/:id',
        builder: (_, state) =>
            _page('/magaza/${state.pathParameters['id'] ?? ''}') ?? home(),
      ),
      GoRoute(
        path: '/magaza/:id/:slug',
        builder: (_, state) {
          final id = state.pathParameters['id'] ?? '';
          final slug = state.pathParameters['slug'] ?? '';
          return _page('/magaza/$id/$slug') ?? home();
        },
      ),
      GoRoute(
        path: '/arac/:id',
        builder: (_, state) =>
            _page('/arac/${state.pathParameters['id'] ?? ''}') ?? home(),
      ),
      GoRoute(
        path: '/arac/:id/:slug',
        builder: (_, state) {
          final id = state.pathParameters['id'] ?? '';
          final slug = state.pathParameters['slug'] ?? '';
          return _page('/arac/$id/$slug') ?? home();
        },
      ),
      GoRoute(
        path: '/ihiz/track/:code',
        builder: (_, state) =>
            _page(IhizRoutePaths.track(state.pathParameters['code'] ?? '')) ??
            home(),
      ),
    ],
  );
}

const _paths = <String>[
  '/qr',
  '/map',
  '/seller',
  '/admin',
  '/become-seller',
  '/seller-forgot-password',
  '/yatirimci',
  '/ihiz',
  '/arac',
  '/arac/arama',
  '/hesabim',
  '/login',
  '/register',
  '/seller-login',
];

GoRoute _route(String path, Widget Function() page) {
  return GoRoute(path: path, builder: (_, _) => page());
}

String? _redirect(String path) {
  if (path == '/home') return MarketplacePaths.home;
  if (path == '/qr' && QrInitialParams.wasResetAfterQrExit) {
    return MarketplacePaths.home;
  }
  if (path == '/' &&
      kIsWeb &&
      QrInitialParams.isQrPath &&
      !QrInitialParams.wasResetAfterQrExit) {
    return '/qr';
  }
  if (path == '/' && kIsWeb && InvestorRoutePaths.isLaunchPath()) {
    return '/yatirimci';
  }
  if (path == '/hesabim/ozet') return MarketplacePaths.account;
  return null;
}

Widget? _page(String path) {
  switch (path) {
    case '/qr':
      return DeferredModuleScreen(
        moduleName: 'qr_entry',
        loadLibrary: qr_entry.loadLibrary,
        builder: () => qr_entry.QrEntryScreen(),
      );
    case '/map':
      return SellerRoutes.buildMapPage(args: const MapRouteArguments());
    case '/login':
      return CustomerRoutes.buildLoginPage();
    case '/register':
      return CustomerRoutes.buildRegisterPage();
    case '/seller-login':
      return CustomerRoutes.buildSellerLoginPage(adminMode: false);
    case '/seller-forgot-password':
      return CustomerRoutes.buildSellerForgotPasswordPage();
    case '/seller':
      return SellerRoutes.buildSellerPanel(source: 'phase14', arguments: null);
    case '/admin':
      return SellerRoutes.buildAdminPanel();
    case '/become-seller':
      return SellerRoutes.buildBecomeSeller();
    case '/yatirimci':
      return SellerRoutes.buildInvestorPage();
    case '/ihiz':
      return SellerRoutes.buildIhizCourier();
    case '/arac':
      return _deferred(
        'vehicle_hub_page',
        vehicle_hub.loadLibrary,
        () => vehicle_hub.VehicleHubPage(),
      );
    case '/arac/arama':
      return _deferred(
        'vehicle_search_page',
        vehicle_search.loadLibrary,
        () => vehicle_search.VehicleSearchPage(),
      );
    case '/hesabim':
      return _deferred(
        'marketplace_route_pages',
        marketplace_pages.loadLibrary,
        () => marketplace_pages.AccountSectionRoutePage(
          section: AccountSection.overview,
        ),
      );
    default:
      break;
  }
  final account = AccountSections.fromPath(path);
  if (account != null) {
    final section = account;
    return _deferred(
      'marketplace_route_pages',
      marketplace_pages.loadLibrary,
      () => marketplace_pages.AccountSectionRoutePage(section: section),
    );
  }
  final productId = MarketplacePaths.idFrom(path, MarketplacePaths.productRoot);
  if (productId != null) {
    final id = productId;
    return _deferred(
      'marketplace_route_pages',
      marketplace_pages.loadLibrary,
      () => marketplace_pages.ProductRoutePage(productId: id),
    );
  }
  final storeId = MarketplacePaths.idFrom(path, MarketplacePaths.storeRoot);
  if (storeId != null) {
    final id = storeId;
    return _deferred(
      'marketplace_route_pages',
      marketplace_pages.loadLibrary,
      () => marketplace_pages.StoreRoutePage(storeId: id),
    );
  }
  if (path.startsWith('/arac/') && path != '/arac/arama') {
    final id = MarketplacePaths.idFrom(path, MarketplacePaths.vehicleRoot) ?? '';
    if (id.isNotEmpty) {
      return _deferred(
        'vehicle_detail_page',
        vehicle_detail.loadLibrary,
        () => vehicle_detail.VehicleDetailPage(listingId: id),
      );
    }
  }
  final site = SiteInfoRoutes.pageForPath(path);
  if (site != null) return site;
  if (IhizRoutePaths.isTrackPath(path)) {
    return SellerRoutes.buildIhizTracking(
      IhizRoutePaths.trackingCodeFromPath(path) ?? '',
    );
  }
  return null;
}

Widget _deferred(
  String name,
  Future<void> Function() loadLibrary,
  Widget Function() builder,
) {
  return DeferredModuleScreen(
    moduleName: name,
    loadLibrary: loadLibrary,
    builder: builder,
  );
}

/// Keeps the product type reachable the same way the production table does.
Type get phase14ProductType => Product;
