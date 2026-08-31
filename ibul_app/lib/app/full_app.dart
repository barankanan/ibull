import 'package:flutter/material.dart';

import '../core/route_observer.dart';
import 'app_navigator.dart';
import 'ibul_material_app.dart';
import 'shared_app_widgets.dart';

final SeoRouteObserver fullSeoRouteObserver = SeoRouteObserver();

/// Full IBUL app — customer routes plus deferred seller/admin/courier modules.
class FullApp extends StatelessWidget {
  const FullApp({super.key});

  @override
  Widget build(BuildContext context) {
    return IbulMaterialApp(
      navigatorKey: appNavigatorKey,
      includeAuthRoutes: false,
      navigatorObservers: [routeObserver, fullSeoRouteObserver],
      builder: (context, child) {
        return OfflineListener(child: child ?? const SizedBox());
      },
    );
  }
}
