import 'package:flutter/material.dart';

import '../core/qr_initial_params.dart';
import '../core/route_trace_logger.dart';
import '../features/ihiz/delivery/ihiz_route_paths.dart';
import '../screens/seller_panel_route_args.dart';
import 'customer_routes.dart';
import 'route_args.dart';
import 'seller_routes.dart';
import 'shared_app_widgets.dart';
import 'site_info_routes.dart';

/// Single named-route table for CustomerApp, FullApp, and root MyApp.
String normalizeRoutePath(String rawName) {
  final parsed = Uri.tryParse(rawName);
  if (parsed != null && parsed.path.isNotEmpty) return parsed.path;
  return rawName.split('?').first;
}

Route<dynamic> generateUnknownHomeRoute(RouteSettings settings) {
  final routeName = settings.name ?? 'unknown';
  RouteTraceLogger.unknownRoute(route: routeName);
  debugPrint(
    '[Routing] route redirect source=$routeName '
    'normalizedPath=unknown fallback=/home ${QrInitialParams.debugState}',
  );
  return MaterialPageRoute(
    settings: settings,
    builder: (_) => buildSafeHome(source: 'onUnknownRoute'),
  );
}

Route<dynamic>? generateAppRoute(
  RouteSettings settings, {
  required bool includeAuthRoutes,
}) {
  final rawName = settings.name ?? '/';
  final normalizedPath = normalizeRoutePath(rawName);
  RouteTraceLogger.push(route: normalizedPath);
  debugPrint(
    '[Routing] route redirect source=$rawName '
    'normalizedPath=$normalizedPath ${QrInitialParams.debugState}',
  );

  final page = pageForAppRoute(
    normalizedPath,
    settings: settings,
    includeAuthRoutes: includeAuthRoutes,
  );
  if (page == null) {
    RouteTraceLogger.unknownRoute(route: normalizedPath);
    return null;
  }
  return MaterialPageRoute(settings: settings, builder: (_) => page);
}

Widget? pageForAppRoute(
  String normalizedPath, {
  required RouteSettings settings,
  required bool includeAuthRoutes,
}) {
  switch (normalizedPath) {
    case '/home':
      return buildSafeHome(
        source: 'onGenerateRoute:/home',
        arguments: settings.arguments,
      );
    case '/qr':
      return buildQrEntry(source: 'onGenerateRoute:/qr');
    case '/map':
      return SellerRoutes.buildMapPage(
        args: parseMapRouteArguments(settings.arguments),
      );
    case '/login':
      if (!includeAuthRoutes) return null;
      return CustomerRoutes.buildLoginPage();
    case '/register':
      if (!includeAuthRoutes) return null;
      return CustomerRoutes.buildRegisterPage();
    case '/seller-login':
      if (!includeAuthRoutes) return null;
      return CustomerRoutes.buildSellerLoginPage(
        adminMode: parseSellerLoginAdminMode(settings.arguments),
      );
    case '/seller':
      final entryRole = parseSellerPanelEntryRole(settings.arguments);
      debugPrint(
        '[Routing] route=/seller mode=deferred entryRole=${entryRole.name}',
      );
      return SellerRoutes.buildSellerPanel(
        source: 'onGenerateRoute:/seller',
        arguments: settings.arguments,
      );
    case '/admin':
      return SellerRoutes.buildAdminPanel();
    case '/become-seller':
      return SellerRoutes.buildBecomeSeller();
    case '/yatirimci':
      return SellerRoutes.buildInvestorPage();
    case '/ihiz':
      return SellerRoutes.buildIhizCourier();
    case '/':
      return buildSafeHome(source: 'onGenerateRoute:/');
    default:
      final sitePage = SiteInfoRoutes.pageForPath(normalizedPath);
      if (sitePage != null) return sitePage;
      if (IhizRoutePaths.isTrackPath(normalizedPath)) {
        final code = IhizRoutePaths.trackingCodeFromPath(normalizedPath) ?? '';
        return SellerRoutes.buildIhizTracking(code);
      }
      return null;
  }
}
