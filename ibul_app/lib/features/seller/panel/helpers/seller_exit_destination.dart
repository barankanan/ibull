import '../../../../core/home_navigation.dart';

/// Resolved navigation target after seller panel exit or seller-login back.
class SellerExitNavigation {
  const SellerExitNavigation({
    required this.route,
    required this.logLabel,
    this.arguments,
  });

  final String route;
  final Object? arguments;
  final String logLabel;
}

/// Result of seller panel session teardown.
class SellerExitResult {
  const SellerExitResult({
    required this.restoredCustomerSession,
    required this.hasSupabaseSession,
    required this.customerSessionActive,
  });

  final bool restoredCustomerSession;
  final bool hasSupabaseSession;
  final bool customerSessionActive;
}

/// Chooses customer-safe routes after leaving the seller surface.
abstract final class SellerExitDestination {
  SellerExitDestination._();

  /// Home tab index for the customer "Hesabım" surface.
  static const int accountTabIndex = 4;

  static const String loginRoute = '/login';
  static const String sellerLoginRoute = '/seller-login';

  static SellerExitNavigation resolve({
    required bool customerSessionActive,
    required bool hasSupabaseSession,
  }) {
    if (customerSessionActive) {
      return SellerExitNavigation(
        route: HomeNavigation.routeName,
        arguments: const HomeRouteArgs(initialIndex: accountTabIndex),
        logLabel: '${HomeNavigation.routeName}?tab=account',
      );
    }
    if (hasSupabaseSession) {
      return SellerExitNavigation(
        route: HomeNavigation.routeName,
        arguments: const HomeRouteArgs(initialIndex: 0),
        logLabel: HomeNavigation.routeName,
      );
    }
    return SellerExitNavigation(
      route: HomeNavigation.routeName,
      arguments: const HomeRouteArgs(initialIndex: 0),
      logLabel: '${HomeNavigation.routeName}?guest',
    );
  }
}
