import 'package:flutter/material.dart';

import '../core/qr_initial_params.dart';
import '../core/route_trace_logger.dart';
import '../features/ihiz/delivery/ihiz_route_paths.dart';
import '../features/vehicle/screens/vehicle_detail_page.dart'
    deferred as vehicle_detail;
import '../models/product_model.dart';
import '../screens/cart_page.dart' deferred as cart_page;
import '../features/vehicle/screens/vehicle_hub_page.dart'
    deferred as vehicle_hub;
import '../features/vehicle/screens/vehicle_search_page.dart'
    deferred as vehicle_search;
import '../screens/seller_panel_route_args.dart';
import '../widgets/deferred_module_screen.dart';
import 'account_sections.dart';
import 'customer_routes.dart';
import 'marketplace_paths.dart';
import 'marketplace_route_pages.dart' deferred as marketplace_pages;
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
    case '/sepet':
      return _deferredRoutePage(
        moduleName: 'cart_page',
        loadLibrary: cart_page.loadLibrary,
        builder: () => cart_page.CartPage(),
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
    case '/seller-forgot-password':
      return CustomerRoutes.buildSellerForgotPasswordPage(
        initialEmail: parseSellerForgotPasswordEmail(settings.arguments),
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
    case '/arac':
      return _deferredRoutePage(
        moduleName: 'vehicle_hub_page',
        loadLibrary: vehicle_hub.loadLibrary,
        builder: () => vehicle_hub.VehicleHubPage(),
      );
    case '/arac/arama':
      return _deferredRoutePage(
        moduleName: 'vehicle_search_page',
        loadLibrary: vehicle_search.loadLibrary,
        builder: () => vehicle_search.VehicleSearchPage(),
      );
    case MarketplacePaths.account:
      return _deferredRoutePage(
        moduleName: 'marketplace_route_pages',
        loadLibrary: marketplace_pages.loadLibrary,
        builder: () => marketplace_pages.AccountSectionRoutePage(
          section: AccountSection.overview,
        ),
      );
    case '/':
      return buildSafeHome(source: 'onGenerateRoute:/');
    default:
      final accountSection = AccountSections.fromPath(normalizedPath);
      if (accountSection != null) {
        final section = accountSection;
        return _deferredRoutePage(
          moduleName: 'marketplace_route_pages',
          loadLibrary: marketplace_pages.loadLibrary,
          builder: () =>
              marketplace_pages.AccountSectionRoutePage(section: section),
        );
      }
      final productId = MarketplacePaths.idFrom(
        normalizedPath,
        MarketplacePaths.productRoot,
      );
      if (productId != null) {
        final productIdValue = productId;
        final initial = settings.arguments is Product
            ? settings.arguments as Product
            : null;
        return _deferredRoutePage(
          moduleName: 'marketplace_route_pages',
          loadLibrary: marketplace_pages.loadLibrary,
          builder: () => marketplace_pages.ProductRoutePage(
            productId: productIdValue,
            initial: initial,
          ),
        );
      }
      final storeId = MarketplacePaths.idFrom(
        normalizedPath,
        MarketplacePaths.storeRoot,
      );
      if (storeId != null) {
        final storeIdValue = storeId;
        final initial = settings.arguments is Map
            ? Map<String, dynamic>.from(settings.arguments as Map)
            : null;
        return _deferredRoutePage(
          moduleName: 'marketplace_route_pages',
          loadLibrary: marketplace_pages.loadLibrary,
          builder: () => marketplace_pages.StoreRoutePage(
            storeId: storeIdValue,
            initial: initial,
          ),
        );
      }
      if (normalizedPath.startsWith('/arac/') &&
          normalizedPath != '/arac/arama') {
        final id = MarketplacePaths.idFrom(
              normalizedPath,
              MarketplacePaths.vehicleRoot,
            ) ??
            '';
        if (id.isNotEmpty) {
          final listingId = id;
          return _deferredRoutePage(
            moduleName: 'vehicle_detail_page',
            loadLibrary: vehicle_detail.loadLibrary,
            builder: () => vehicle_detail.VehicleDetailPage(listingId: listingId),
          );
        }
      }
      final sitePage = SiteInfoRoutes.pageForPath(normalizedPath);
      if (sitePage != null) return sitePage;
      if (IhizRoutePaths.isTrackPath(normalizedPath)) {
        final code = IhizRoutePaths.trackingCodeFromPath(normalizedPath) ?? '';
        return SellerRoutes.buildIhizTracking(code);
      }
      return null;
  }
}

Widget _deferredRoutePage({
  required String moduleName,
  required Future<void> Function() loadLibrary,
  required Widget Function() builder,
}) {
  return DeferredModuleScreen(
    moduleName: moduleName,
    loadLibrary: loadLibrary,
    loading: const Scaffold(
      backgroundColor: Color(0xFFF9FAFB),
      body: Center(child: CircularProgressIndicator()),
    ),
    builder: builder,
  );
}
