import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/customer_routes.dart';
import '../app/seller_routes.dart';
import '../app/site_info_routes.dart';
import '../features/vehicle/screens/vehicle_detail_page.dart'
    deferred as vehicle_detail;
import '../features/vehicle/screens/vehicle_hub_page.dart' deferred as vehicle_hub;
import '../features/vehicle/screens/vehicle_search_page.dart'
    deferred as vehicle_search;
import '../models/product_model.dart';
import '../screens/home_screen_gate.dart';

/// R6: previous layers plus seller route builders.
void main() {
  final Object kept = (
    Product,
    SiteInfoRoutes.paths,
    SellerRoutes.buildSellerPanel,
    vehicle_detail.loadLibrary,
    vehicle_hub.loadLibrary,
    vehicle_search.loadLibrary,
  );
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => HomeScreenGate(initialCategory: kept.toString()),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => CustomerRoutes.buildLoginPage(),
      ),
    ],
  );
  runApp(MaterialApp.router(debugShowCheckedModeBanner: false, routerConfig: router));
}
