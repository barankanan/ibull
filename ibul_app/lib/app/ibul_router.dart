import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Named-route bridge: GoRouter when mounted, Navigator otherwise.
///
/// Seller desktop and widget tests still use [MaterialApp.onGenerateRoute].
abstract final class IbulRouter {
  static void go(
    BuildContext context,
    String location, {
    Object? extra,
  }) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go(location, extra: extra);
      return;
    }
    Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
      location,
      (_) => false,
      arguments: extra,
    );
  }

  static Future<T?> push<T extends Object?>(
    BuildContext context,
    String location, {
    Object? extra,
  }) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      return router.push<T>(location, extra: extra);
    }
    return Navigator.of(context, rootNavigator: true).pushNamed<T>(
      location,
      arguments: extra,
    );
  }

  static void replace(
    BuildContext context,
    String location, {
    Object? extra,
  }) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.pushReplacement(location, extra: extra);
      return;
    }
    Navigator.of(context).pushReplacementNamed(location, arguments: extra);
  }

  static void goFromNavigator(
    NavigatorState? navigator,
    String location, {
    Object? extra,
  }) {
    final context = navigator?.context;
    if (context != null && context.mounted) {
      go(context, location, extra: extra);
      return;
    }
    navigator?.pushNamed(location, arguments: extra);
  }

  static Future<T?> pushFromNavigator<T extends Object?>(
    NavigatorState? navigator,
    String location, {
    Object? extra,
  }) {
    final context = navigator?.context;
    if (context != null && context.mounted) {
      return push<T>(context, location, extra: extra);
    }
    return navigator?.pushNamed<T>(location, arguments: extra) ??
        Future<T?>.value();
  }
}
