import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/qr_initial_params.dart';
import '../core/route_trace_logger.dart';
import '../features/ihiz/delivery/ihiz_route_paths.dart';
import '../features/investor/investor_route_paths.dart';
import 'app_route_table.dart';
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
  return GoRouter(
    navigatorKey: navigatorKey,
    observers: observers,
    initialLocation: '/',
    redirect: (context, state) => ibulGoRouterRedirect(
      path: state.uri.path,
      includeAuthRoutes: includeAuthRoutes,
    ),
    errorBuilder: (context, state) {
      RouteTraceLogger.unknownRoute(route: state.uri.path);
      return buildSafeHome(source: 'go_router:unknown');
    },
    routes: _routes(includeAuthRoutes),
  );
}

List<RouteBase> _routes(bool includeAuthRoutes) {
  final routes = <RouteBase>[
    _pageRoute('/', includeAuthRoutes),
    _pageRoute('/home', includeAuthRoutes),
    _pageRoute('/qr', includeAuthRoutes),
    _pageRoute('/map', includeAuthRoutes),
    _pageRoute('/seller', includeAuthRoutes),
    _pageRoute('/admin', includeAuthRoutes),
    _pageRoute('/become-seller', includeAuthRoutes),
    _pageRoute('/yatirimci', includeAuthRoutes),
    _pageRoute('/ihiz', includeAuthRoutes),
    GoRoute(
      path: '/ihiz/track/:code',
      builder: (context, state) {
        final code = state.pathParameters['code'] ?? '';
        return _pageFor(IhizRoutePaths.track(code), state, includeAuthRoutes);
      },
    ),
    for (final path in SiteInfoRoutes.paths)
      _pageRoute(path, includeAuthRoutes),
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
String? ibulGoRouterRedirect({
  required String path,
  required bool includeAuthRoutes,
}) {
  if (path == '/qr' && QrInitialParams.wasResetAfterQrExit) {
    return '/home';
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
  return null;
}
