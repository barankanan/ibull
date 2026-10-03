import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/qr_initial_params.dart';
import '../core/web_boot_loader.dart';
import '../core/route_trace_logger.dart';
import '../features/blog/blog_paths.dart';
import '../features/ihiz/delivery/ihiz_route_paths.dart';
import '../features/investor/investor_route_paths.dart';
import '../screens/ibul_not_found_page.dart';
import 'app_route_table.dart';
import 'ibul_router.dart';
import 'marketplace_paths.dart';
import 'shared_app_widgets.dart';
import 'site_info_routes.dart';

export 'ibul_router.dart';

/// Builds the single [GoRouter] used by CustomerApp, FullApp, and root MyApp.
///
/// Page widgets still come from [pageForAppRoute] so deferred seller/admin/İHIZ
/// chunks and auth gating stay in one table.
GoRouter createIbulGoRouter({
  required GlobalKey<NavigatorState> navigatorKey,
  required bool includeAuthRoutes,
  List<NavigatorObserver> observers = const <NavigatorObserver>[],
}) {
  // Imperative push() otherwise keeps the browser URL on / or /home.
  GoRouter.optionURLReflectsImperativeAPIs = true;
  final router = GoRouter(
    navigatorKey: navigatorKey,
    observers: observers,
    initialLocation: '/',
    redirect: (context, state) => ibulGoRouterRedirect(
      path: state.uri.path,
      next: state.uri.queryParameters['next'],
      includeAuthRoutes: includeAuthRoutes,
      authenticated: _isAuthenticated(),
    ),
    errorBuilder: (context, state) {
      RouteTraceLogger.unknownRoute(route: state.uri.path);
      return IbulNotFoundPage(path: state.uri.path);
    },
    routes: _routes(includeAuthRoutes),
  );
  IbulGoRouterBinding.instance = router;
  return router;
}

List<RouteBase> _routes(bool includeAuthRoutes) {
  final routes = <RouteBase>[
    _pageRoute('/', includeAuthRoutes),
    _pageRoute('/home', includeAuthRoutes),
    _pageRoute('/sepet', includeAuthRoutes),
    _pageRoute('/qr', includeAuthRoutes),
    _pageRoute('/map', includeAuthRoutes),
    _pageRoute('/seller', includeAuthRoutes),
    _pageRoute('/admin', includeAuthRoutes),
    _pageRoute('/become-seller', includeAuthRoutes),
    _pageRoute(MarketplacePaths.mallHub, includeAuthRoutes),
    _pageRoute(MarketplacePaths.mallLogin, includeAuthRoutes),
    _pageRoute(MarketplacePaths.mallRegister, includeAuthRoutes),
    _pageRoute(MarketplacePaths.mallApplication, includeAuthRoutes),
    _pageRoute(MarketplacePaths.mallManagement, includeAuthRoutes),
    for (final pattern in mallPanelRoutePatterns)
      GoRoute(
        path: pattern,
        pageBuilder: (context, state) =>
            mallPanelPage(state, _pageFor(state.uri.path, state, includeAuthRoutes)),
      ),
    GoRoute(
      path: '${MarketplacePaths.mallProfileRoot}/:mallId',
      builder: (context, state) =>
          _pageFor(state.uri.path, state, includeAuthRoutes),
    ),
    _pageRoute('/seller-forgot-password', includeAuthRoutes),
    _pageRoute('/yatirimci', includeAuthRoutes),
    _pageRoute('/ihiz', includeAuthRoutes),
    _pageRoute('/arac', includeAuthRoutes),
    _pageRoute('/arac/arama', includeAuthRoutes),
    GoRoute(
      path: '/kategori/:mainCategoryId/:subCategoryId/:slug',
      builder: (context, state) => _pageFor(
        state.uri.path,
        state,
        includeAuthRoutes,
      ),
    ),
    _pageRoute(MarketplacePaths.account, includeAuthRoutes),
    GoRoute(
      path: '/hesabim/:section',
      builder: (context, state) {
        final section = state.pathParameters['section'] ?? '';
        return _pageFor('/hesabim/$section', state, includeAuthRoutes);
      },
    ),
    GoRoute(
      path: '/urun/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return _pageFor('/urun/$id', state, includeAuthRoutes);
      },
    ),
    GoRoute(
      path: '/urun/:id/:slug',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final slug = state.pathParameters['slug'] ?? '';
        return _pageFor('/urun/$id/$slug', state, includeAuthRoutes);
      },
    ),
    GoRoute(
      path: '/magaza/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return _pageFor('/magaza/$id', state, includeAuthRoutes);
      },
    ),
    GoRoute(
      path: '/magaza/:id/:slug',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final slug = state.pathParameters['slug'] ?? '';
        return _pageFor('/magaza/$id/$slug', state, includeAuthRoutes);
      },
    ),
    GoRoute(
      path: '/arac/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return _pageFor('/arac/$id', state, includeAuthRoutes);
      },
    ),
    GoRoute(
      path: '/arac/:id/:slug',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final slug = state.pathParameters['slug'] ?? '';
        return _pageFor('/arac/$id/$slug', state, includeAuthRoutes);
      },
    ),
    GoRoute(
      path: '/ihiz/track/:code',
      builder: (context, state) {
        final code = state.pathParameters['code'] ?? '';
        return _pageFor(IhizRoutePaths.track(code), state, includeAuthRoutes);
      },
    ),
    for (final path in SiteInfoRoutes.paths)
      _pageRoute(path, includeAuthRoutes),
    _pageRoute(BlogPaths.root, includeAuthRoutes),
    _pageRoute(BlogPaths.studio, includeAuthRoutes),
    GoRoute(
      path: '${BlogPaths.previewRoot}/:id',
      builder: (context, state) => _pageFor(
        BlogPaths.preview(state.pathParameters['id'] ?? ''),
        state,
        includeAuthRoutes,
      ),
    ),
    GoRoute(
      path: '${BlogPaths.root}/:slug',
      builder: (context, state) => _pageFor(
        BlogPaths.post(state.pathParameters['slug'] ?? ''),
        state,
        includeAuthRoutes,
      ),
    ),
  ];
  if (includeAuthRoutes) {
    routes.addAll([
      _pageRoute('/login', includeAuthRoutes),
      _pageRoute('/register', includeAuthRoutes),
      _pageRoute('/seller-login', includeAuthRoutes),
    ]);
  }
  return routes;
}

/// Sibling (not nested) routes: a nested `:mallId` parent stayed mounted under
/// every section page and kept its first-load data, so Genel Bakış showed
/// stale counts.
const mallPanelRoutePatterns = <String>[
  '${MarketplacePaths.mallManagement}/:mallId',
  '${MarketplacePaths.mallManagement}/:mallId/katlar/:floorId',
  '${MarketplacePaths.mallManagement}/:mallId/:section',
];

/// Every section of one mall shares this page key, so the Navigator updates
/// the same route and the panel keeps a single state per mall.
Page<void> mallPanelPage(GoRouterState state, Widget child) {
  final mallId = state.pathParameters['mallId'] ?? '';
  return MaterialPage<void>(
    key: ValueKey<String>('mall-panel:$mallId'),
    name: state.uri.path,
    child: child,
  );
}

GoRoute _pageRoute(String path, bool includeAuthRoutes) {
  return GoRoute(
    path: path,
    builder: (context, state) => _pageFor(path, state, includeAuthRoutes),
  );
}

Widget _pageFor(
  String path,
  GoRouterState state,
  bool includeAuthRoutes,
) {
  RouteTraceLogger.push(route: path);
  final page = pageForAppRoute(
    path,
    settings: RouteSettings(
      name: path,
      arguments: state.extra ?? _queryArguments(state),
    ),
    includeAuthRoutes: includeAuthRoutes,
  );
  return page ?? buildSafeHome(source: 'go_router:$path');
}

Map<String, String>? _queryArguments(GoRouterState state) {
  final query = state.uri.queryParameters;
  return query.isEmpty ? null : query;
}

/// Redirect rules shared by [createIbulGoRouter] and architecture tests.
bool _isAuthenticated() {
  try {
    return Supabase.instance.client.auth.currentUser != null;
  } catch (_) {
    return false;
  }
}

/// Redirect rules shared by [createIbulGoRouter] and architecture tests.
String? ibulGoRouterRedirect({
  required String path,
  String? next,
  required bool includeAuthRoutes,
  bool authenticated = false,
}) {
  final target = _ibulGoRouterRedirect(
    path: path,
    next: next,
    includeAuthRoutes: includeAuthRoutes,
    authenticated: authenticated,
  );
  recordRouteRedirectDecision(
    'path=$path auth=$authenticated includeAuth=$includeAuthRoutes '
    'target=${target ?? '-'}',
  );
  return target;
}

String? _ibulGoRouterRedirect({
  required String path,
  String? next,
  required bool includeAuthRoutes,
  bool authenticated = false,
}) {
  if (includeAuthRoutes &&
      authenticated &&
      (path == '/login' || path == '/register')) {
    if (next != null && next.startsWith('/') && !next.startsWith('//')) {
      return next;
    }
    return MarketplacePaths.home;
  }
  if (path == '/home') {
    return MarketplacePaths.home;
  }
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
  if (!includeAuthRoutes &&
      (path == '/login' || path == '/register' || path == '/seller-login')) {
    return '/';
  }
  if (path == '/hesabim/ozet') {
    return MarketplacePaths.account;
  }
  if (path == MarketplacePaths.legacyMallApplication ||
      path == MarketplacePaths.legacyPublicMallApplication) {
    return MarketplacePaths.mallApplication;
  }
  if (path == MarketplacePaths.mallRegister) {
    return MarketplacePaths.mallApplication;
  }
  if (path == MarketplacePaths.legacyMallManagement ||
      path.startsWith('${MarketplacePaths.legacyMallManagement}/')) {
    return path.replaceFirst(
      MarketplacePaths.legacyMallManagement,
      MarketplacePaths.mallManagement,
    );
  }
  // `/avm/yonetim` is guarded by MallAuthGate against the separate AVM
  // session; [authenticated] is the marketplace customer session.
  if (includeAuthRoutes &&
      MarketplacePaths.isAccountPath(path) &&
      !authenticated) {
    return '/login?next=${Uri.encodeComponent(path)}';
  }
  return null;
}
