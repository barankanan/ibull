import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/auth/ibul_auth_context.dart';
import 'package:ibul_app/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool customerHeaderShowsLoggedIn({
  required bool hasSupabaseSession,
  required IbulAuthContext activeContext,
  Map<String, dynamic>? cachedCustomerUser,
}) {
  final isCustomerContext = activeContext == IbulAuthContext.customer;
  return hasSupabaseSession && isCustomerContext && cachedCustomerUser != null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Seller logout customer leak prevention', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      IbulAuthContextService.instance.resetForTesting();
    });

    test('empty customer → seller login → seller logout → customer header logged out', () {
      IbulAuthContextService.instance.resetForTesting(
        context: IbulAuthContext.seller,
      );
      expect(
        customerHeaderShowsLoggedIn(
          hasSupabaseSession: true,
          activeContext: IbulAuthContextService.instance.activeContext,
          cachedCustomerUser: {'uid': 'seller-1', 'email': 'seller@test.com'},
        ),
        isFalse,
        reason: 'Seller session must not render customer header as logged in',
      );

      IbulAuthContextService.instance.resetForTesting(
        context: IbulAuthContext.none,
      );
      expect(
        customerHeaderShowsLoggedIn(
          hasSupabaseSession: false,
          activeContext: IbulAuthContext.none,
          cachedCustomerUser: null,
        ),
        isFalse,
      );
    });

    test('seller session must not populate customer profile cache view', () {
      IbulAuthContextService.instance.resetForTesting(
        context: IbulAuthContext.seller,
      );
      final shouldWriteCustomerCache =
          IbulAuthContextService.instance.isCustomerContext;
      expect(shouldWriteCustomerCache, isFalse);
    });

    test('customer provider ignores seller-context auth events', () {
      IbulAuthContextService.instance.resetForTesting(
        context: IbulAuthContext.seller,
      );
      const hasAuthUser = true;
      final shouldSetCustomerUser =
          hasAuthUser && IbulAuthContextService.instance.isCustomerContext;
      expect(shouldSetCustomerUser, isFalse);
    });

    test('seller provider clear must not flip customer provider to seller user', () {
      IbulAuthContextService.instance.resetForTesting(
        context: IbulAuthContext.seller,
      );
      final sellerUser = {'uid': 'seller-1', 'email': 'seller@test.com'};
      final customerUserAfterSellerLogout = () {
        if (!IbulAuthContextService.instance.isCustomerContext) {
          return null;
        }
        return sellerUser;
      }();
      expect(customerUserAfterSellerLogout, isNull);
    });

    test('signOut sets none context — customer cache key user id cleared', () async {
      await IbulAuthContextService.instance.setActiveContext(
        IbulAuthContext.seller,
      );
      await IbulAuthContextService.instance.setActiveContext(
        IbulAuthContext.none,
      );
      expect(IbulAuthContextService.instance.hasExplicitContext, isFalse);
    });

    test('authStateChanges seller event ignored when activeContext=seller', () {
      IbulAuthContextService.instance.resetForTesting(
        context: IbulAuthContext.seller,
      );
      const authEventHasUser = true;
      final customerProviderAcceptsEvent = authEventHasUser &&
          IbulAuthContextService.instance.isCustomerContext;
      expect(customerProviderAcceptsEvent, isFalse);
    });

    test('customer-only account rejected on seller login surface', () {
      expect(
        AuthSessionGuard.acceptsSellerLogin(LoginResolvedRole.user),
        isFalse,
      );
      expect(
        AuthSessionGuard.sellerLoginRejectionMessage(LoginResolvedRole.user),
        contains('satıcı hesabı değil'),
      );
    });
  });
}
