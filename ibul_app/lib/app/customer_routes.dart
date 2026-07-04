import 'package:flutter/material.dart';

import '../screens/map_page.dart' deferred as map_page;
import '../widgets/deferred_module_screen.dart';
import 'route_args.dart';

/// Customer-only route builders — no seller/admin/print modules.
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
}
