import 'package:flutter/material.dart';

import '../app/ibul_router.dart';

/// Route arguments for opening [HomeScreenGate] without importing home_screen.
class HomeRouteArgs {
  const HomeRouteArgs({this.initialIndex = 0, this.initialCategory});

  final int initialIndex;
  final String? initialCategory;

  static HomeRouteArgs from(Object? raw) {
    if (raw is HomeRouteArgs) return raw;
    if (raw is Map) {
      final indexRaw = raw['initialIndex'] ?? raw['tab'];
      final categoryRaw = raw['initialCategory'] ?? raw['category'];
      return HomeRouteArgs(
        initialIndex: indexRaw is int ? indexRaw : int.tryParse('$indexRaw') ?? 0,
        initialCategory: categoryRaw?.toString(),
      );
    }
    return const HomeRouteArgs();
  }
}

/// Lightweight navigation to home — avoids static home_screen imports in shared widgets.
abstract final class HomeNavigation {
  static const String routeName = '/home';

  static void openHome(
    BuildContext context, {
    int initialIndex = 0,
    String? initialCategory,
    bool replaceStack = true,
  }) {
    final args = HomeRouteArgs(
      initialIndex: initialIndex,
      initialCategory: initialCategory,
    );
    if (replaceStack) {
      IbulRouter.go(context, routeName, extra: args);
      return;
    }
    IbulRouter.push(context, routeName, extra: args);
  }
}
