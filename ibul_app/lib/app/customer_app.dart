import 'package:flutter/material.dart';

import '../core/route_observer.dart';
import 'app_navigator.dart';
import 'ibul_material_app.dart';
import 'shared_app_widgets.dart';

final SeoRouteObserver customerSeoRouteObserver =
    SeoRouteObserver(includeSellerRoutes: true);

/// Lightweight customer MaterialApp — home, map, QR, auth, lazy seller panel.
class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return IbulMaterialApp(
      navigatorKey: appNavigatorKey,
      includeAuthRoutes: true,
      navigatorObservers: [routeObserver, customerSeoRouteObserver],
      builder: (context, child) {
        return OfflineListener(child: child ?? const SizedBox());
      },
    );
  }
}
