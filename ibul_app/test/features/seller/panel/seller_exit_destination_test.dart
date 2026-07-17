import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/home_navigation.dart';
import 'package:ibul_app/features/seller/panel/helpers/seller_exit_destination.dart';

void main() {
  group('SellerExitDestination', () {
    test('customer session resolves to account tab on /home', () {
      final dest = SellerExitDestination.resolve(
        customerSessionActive: true,
        hasSupabaseSession: true,
      );
      expect(dest.route, HomeNavigation.routeName);
      expect(dest.arguments, isA<HomeRouteArgs>());
      expect(
        (dest.arguments! as HomeRouteArgs).initialIndex,
        SellerExitDestination.accountTabIndex,
      );
      expect(dest.logLabel, contains('account'));
    });

    test('no customer session resolves to guest home fallback', () {
      final dest = SellerExitDestination.resolve(
        customerSessionActive: false,
        hasSupabaseSession: false,
      );
      expect(dest.route, HomeNavigation.routeName);
      expect(
        (dest.arguments! as HomeRouteArgs).initialIndex,
        0,
      );
    });

    test('does not use seller-login for customer session exit', () {
      final dest = SellerExitDestination.resolve(
        customerSessionActive: true,
        hasSupabaseSession: true,
      );
      expect(dest.route, isNot(SellerExitDestination.sellerLoginRoute));
    });
  });
}
