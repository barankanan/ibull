import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'marketplace_paths.dart';

/// The live [GoRouter] mounted by [IbulMaterialApp].
abstract final class IbulGoRouterBinding {
  static GoRouter? instance;
}

/// Named-route bridge: GoRouter when mounted, Navigator otherwise.
///
/// Web marketplace navigation always uses the bound [GoRouter]. Imperative
/// [Navigator.push] on that navigator changes the screen but leaves the
/// browser URL on `/` or `/home`.
abstract final class IbulRouter {
  static const String marketplaceHome = MarketplacePaths.home;
  static const String marketplaceRoot = MarketplacePaths.home;
  static const String legacyHomeAlias = '/home';

  /// Widget tests cannot set [kIsWeb]; they flip this to exercise root routing.
  @visibleForTesting
  static bool debugUseRootRouter = false;

  static bool get usesRootRouter => kIsWeb || debugUseRootRouter;

  static void _syncBrowserUrlFromImperativeApi() {
    GoRouter.optionURLReflectsImperativeAPIs = true;
  }

  static void go(BuildContext context, String location, {Object? extra}) {
    _syncBrowserUrlFromImperativeApi();
    final router = routerOf(context);
    if (router != null) {
      router.go(_canonicalLocation(location), extra: extra);
      return;
    }
    if (kIsWeb) {
      debugPrint('[IbulRouter] go missing GoRouter location=$location');
      return;
    }
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushNamedAndRemoveUntil(location, (_) => false, arguments: extra);
  }

  /// Returns to marketplace home (`/`) without toggling a `/home` alias.
  static void goMarketplaceHome(BuildContext context, {Object? extra}) {
    try {
      final router = routerOf(context);
      final nav = Navigator.of(context, rootNavigator: true);
      if (router != null) {
        final path = router.state.uri.path;
        final onHome = path == marketplaceRoot || path == legacyHomeAlias;
        if (nav.canPop()) {
          nav.popUntil((route) => route.isFirst);
        }
        if (!onHome || path == legacyHomeAlias) {
          router.go(marketplaceRoot, extra: extra);
        }
        return;
      }
      if (nav.canPop()) {
        nav.popUntil((route) => route.isFirst);
        return;
      }
      if (!kIsWeb) {
        nav.pushNamedAndRemoveUntil(
          marketplaceRoot,
          (_) => false,
          arguments: extra,
        );
      }
    } catch (error, stackTrace) {
      debugPrint('[Nav] goMarketplaceHome failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<T?> push<T extends Object?>(
    BuildContext context,
    String location, {
    Object? extra,
  }) {
    _syncBrowserUrlFromImperativeApi();
    final router = routerOf(context);
    final canonical = _canonicalLocation(location);
    if (kDebugMode) {
      debugPrint(
        '[IbulRouter] push target=$canonical '
        'before=${router?.state.uri.path ?? 'no-router'}',
      );
    }
    if (router != null) {
      return router.push<T>(canonical, extra: extra);
    }
    if (kIsWeb) {
      debugPrint('[IbulRouter] push missing GoRouter location=$canonical');
      return Future<T?>.value();
    }
    return Navigator.of(
      context,
      rootNavigator: true,
    ).pushNamed<T>(location, arguments: extra);
  }

  /// Prefer the inherited router for this widget tree, then the mounted app
  /// binding. Never push onto a stale static instance from another test/app.
  static GoRouter? routerOf(BuildContext context) {
    return GoRouter.maybeOf(context) ??
        _routerFromRootNavigator(context) ??
        IbulGoRouterBinding.instance;
  }

  static GoRouter? _routerFromRootNavigator(BuildContext context) {
    try {
      return GoRouter.maybeOf(
        Navigator.of(context, rootNavigator: true).context,
      );
    } catch (_) {
      return null;
    }
  }

  static String? currentPath(BuildContext context) {
    return routerOf(context)?.state.uri.path;
  }

  static void replace(BuildContext context, String location, {Object? extra}) {
    _syncBrowserUrlFromImperativeApi();
    final router = routerOf(context);
    if (router != null) {
      router.pushReplacement(_canonicalLocation(location), extra: extra);
      return;
    }
    if (kIsWeb) {
      debugPrint('[IbulRouter] replace missing GoRouter location=$location');
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
    if (!kIsWeb) {
      navigator?.pushNamed(location, arguments: extra);
    }
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
    if (kIsWeb) return Future<T?>.value();
    return navigator?.pushNamed<T>(location, arguments: extra) ??
        Future<T?>.value();
  }

  static String _canonicalLocation(String location) {
    final uri = Uri.tryParse(location);
    final path = uri?.path.isNotEmpty == true
        ? uri!.path
        : location.split('?').first;
    if (path == legacyHomeAlias) {
      final query = uri?.query;
      if (query != null && query.isNotEmpty) {
        return '$marketplaceRoot?$query';
      }
      return marketplaceRoot;
    }
    return location;
  }
}
