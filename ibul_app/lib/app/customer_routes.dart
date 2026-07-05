import 'package:flutter/material.dart';

import '../screens/login_page.dart' deferred as login_page;
import '../screens/map_page.dart' deferred as map_page;
import '../screens/register_page.dart' deferred as register_page;
import '../screens/seller_login_page.dart' deferred as seller_login_page;
import '../widgets/deferred_module_screen.dart';
import 'route_args.dart';
import 'seller_routes.dart';

/// Customer-only route builders — auth + map; seller panel lazy, no admin boot.
abstract final class CustomerRoutes {
  static Widget buildMapPage({required MapRouteArguments args}) {
    return DeferredModuleScreen(
      moduleName: 'map_page',
      loadLibrary: map_page.loadLibrary,
      builder: () => map_page.MapPage(
        targetStoreName: args.targetStoreName,
        initialStoreProductQuery: args.initialStoreProductQuery,
      ),
    );
  }

  static Widget buildLoginPage() {
    return DeferredModuleScreen(
      moduleName: 'login_page',
      loadLibrary: login_page.loadLibrary,
      builder: () => login_page.LoginPage(),
    );
  }

  static Widget buildRegisterPage() {
    return DeferredModuleScreen(
      moduleName: 'register_page',
      loadLibrary: register_page.loadLibrary,
      builder: () => register_page.RegisterPage(),
    );
  }

  static Widget buildSellerLoginPage({bool adminMode = false}) {
    return DeferredModuleScreen(
      moduleName: 'seller_login_page',
      loadLibrary: seller_login_page.loadLibrary,
      builder: () => seller_login_page.SellerLoginPage(adminMode: adminMode),
    );
  }

  static Widget buildSellerPanel({
    required String source,
    Object? arguments,
  }) {
    return SellerRoutes.buildSellerPanel(source: source, arguments: arguments);
  }

  static Widget buildAdminPanel() {
    return SellerRoutes.buildAdminPanel();
  }
}

bool parseSellerLoginAdminMode(Object? arguments) {
  if (arguments is bool) return arguments;
  if (arguments is Map) {
    final raw = arguments['adminMode'] ?? arguments['admin'];
    if (raw is bool) return raw;
    if (raw?.toString().toLowerCase() == 'true') return true;
  }
  return false;
}
