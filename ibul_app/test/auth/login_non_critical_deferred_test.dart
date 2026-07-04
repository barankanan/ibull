import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/auth/ibul_auth_context.dart';
import 'package:ibul_app/services/auth_service.dart';

/// Login must not trap the user when the (non-critical) profile/role lookup is
/// slow. On timeout the customer login area falls back to the customer route so
/// the user reaches home while side data (profile/cart/favorites) hydrates in
/// the background.
void main() {
  group('login non-critical init deferred', () {
    test('profile-timeout fallback resolves to the customer route', () {
      const fallback = LoginRouteResolution(
        userId: null,
        userEmail: null,
        profile: null,
        rawRole: 'user',
        resolvedRole: LoginResolvedRole.user,
        isSellerApproved: false,
        storeProfile: null,
      );

      expect(fallback.resolvedRole, LoginResolvedRole.user);
      expect(AuthSessionGuard.acceptsCustomerLogin(fallback.resolvedRole),
          isTrue);
      expect(fallback.chosenRoute, '/home');
    });

    test('waiter/admin are still rejected on the customer login area', () {
      expect(
        AuthSessionGuard.acceptsCustomerLogin(LoginResolvedRole.waiter),
        isFalse,
      );
      expect(
        AuthSessionGuard.acceptsCustomerLogin(LoginResolvedRole.admin),
        isFalse,
      );
    });
  });
}
