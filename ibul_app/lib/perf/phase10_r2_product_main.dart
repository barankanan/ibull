import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/product_model.dart';
import '../screens/home_screen_gate.dart';

/// R2: home gate plus the product model the route table imports.
void main() {
  final Type kept = Product;
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => HomeScreenGate(initialCategory: kept.toString()),
      ),
    ],
  );
  runApp(MaterialApp.router(debugShowCheckedModeBanner: false, routerConfig: router));
}
