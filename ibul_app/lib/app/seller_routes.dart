import 'package:flutter/material.dart';

import '../features/investor/investor_page.dart' deferred as investor;
import '../screens/become_seller_page.dart' deferred as become_seller;
import '../screens/map_page.dart' deferred as map_page;
import '../screens/seller/admin_panel_page.dart' deferred as admin_panel;
import '../screens/seller_panel_page.dart' deferred as seller_panel;
import '../screens/seller_panel_route_args.dart';
import '../screens/ihiz_courier_page.dart' deferred as ihiz_courier;
import '../features/ihiz/delivery/ihiz_route_paths.dart';
import '../widgets/deferred_module_screen.dart';
import 'route_args.dart';

/// Seller / admin / courier routes — deferred, not in customer entrypoint.
abstract final class SellerRoutes {
  static Widget buildSellerPanel({
    required String source,
    Object? arguments,
  }) {
    final entryRole = parseSellerPanelEntryRole(arguments);
    final widgetKey = ValueKey<String>('seller_panel_${entryRole.name}');
    debugPrint(
      '[SellerPanel][Init] routeEnter source=$source path=/seller '
      'entryRole=${entryRole.name} widgetKey=$widgetKey',
    );
    return DeferredModuleScreen(
      moduleName: 'seller_panel_page',
      loadLibrary: seller_panel.loadLibrary,
      builder: () => seller_panel.SellerPanelPage(
        key: widgetKey,
        entryRole: entryRole,
      ),
    );
  }

  static Widget buildAdminPanel() {
    return DeferredModuleScreen(
      moduleName: 'admin_panel_page',
      loadLibrary: admin_panel.loadLibrary,
      builder: () => admin_panel.AdminPanelPage(),
    );
  }

  static Widget buildIhizCourier() {
    return DeferredModuleScreen(
      moduleName: 'ihiz_courier_page',
      loadLibrary: ihiz_courier.loadLibrary,
      builder: () => ihiz_courier.IhizCourierPage(),
    );
  }

  static Widget buildIhizTracking(String trackingCode) {
    return DeferredModuleScreen(
      moduleName: 'ihiz_courier_page',
      loadLibrary: ihiz_courier.loadLibrary,
      builder: () => ihiz_courier.IhizTrackingPage(
        trackingCode: trackingCode,
      ),
    );
  }

  static String? ihizTrackingCode(String path) {
    return IhizRoutePaths.trackingCodeFromPath(path);
  }

  static Widget buildBecomeSeller() {
    return DeferredModuleScreen(
      moduleName: 'become_seller_page',
      loadLibrary: become_seller.loadLibrary,
      builder: () => become_seller.BecomeSellerPage(),
    );
  }

  static Widget buildInvestorPage() {
    return DeferredModuleScreen(
      moduleName: 'investor_page',
      loadLibrary: investor.loadLibrary,
      builder: () => investor.InvestorPage(),
    );
  }

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
}
