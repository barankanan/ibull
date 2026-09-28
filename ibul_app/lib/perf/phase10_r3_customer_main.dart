import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/customer_routes.dart';
import '../models/product_model.dart';
import '../screens/home_screen_gate.dart';

/// R3: previous layers plus customer route builders.
void main() {
  final Type kept = Product;
  final WidgetBuilder login = (_) => CustomerRoutes.buildLoginPage();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => HomeScreenGate(initialCategory: kept.toString()),
      ),
      GoRoute(path: '/login', builder: (context, _) => login(context)),
    ],
  );
  runApp(MaterialApp.router(debugShowCheckedModeBanner: false, routerConfig: router));
}
