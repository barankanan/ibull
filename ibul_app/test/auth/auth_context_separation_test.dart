import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/auth/ibul_auth_context.dart';
import 'package:ibul_app/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Auth context separation', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      IbulAuthContextService.instance.resetForTesting();
    });

    test('seller login sets activeContext=seller', () async {
      await IbulAuthContextService.instance.setActiveContext(
        IbulAuthContext.seller,
      );
      expect(IbulAuthContextService.instance.activeContext, IbulAuthContext.seller);
      expect(IbulAuthContextService.instance.isSellerContext, isTrue);
      expect(IbulAuthContextService.instance.isCustomerContext, isFalse);
    });

    test('seller login is not treated as customer session', () {
      IbulAuthContextService.instance.resetForTesting(
        context: IbulAuthContext.seller,
      );
      expect(
        IbulAuthContextService.instance.isCustomerSessionActive(
          hasSupabaseSession: true,
        ),
        isFalse,
      );
      expect(
        IbulAuthContextService.instance.isSellerSessionActive(
          hasSupabaseSession: true,
        ),
        isTrue,
      );
    });

    test('seller logout clears activeContext to none', () async {
      await IbulAuthContextService.instance.setActiveContext(
        IbulAuthContext.seller,
      );
      await IbulAuthContextService.instance.setActiveContext(
        IbulAuthContext.none,
      );
      expect(IbulAuthContextService.instance.activeContext, IbulAuthContext.none);
      expect(
        IbulAuthContextService.instance.isCustomerSessionActive(
          hasSupabaseSession: false,
        ),
        isFalse,
      );
    });

    test('customer login sets activeContext=customer', () async {
      await IbulAuthContextService.instance.setActiveContext(
        IbulAuthContext.customer,
      );
      expect(
        IbulAuthContextService.instance.isCustomerSessionActive(
          hasSupabaseSession: true,
        ),
        isTrue,
      );
    });

    test('customer login does not imply seller session', () {
      IbulAuthContextService.instance.resetForTesting(
        context: IbulAuthContext.customer,
      );
      expect(
        IbulAuthContextService.instance.isSellerSessionActive(
          hasSupabaseSession: true,
        ),
        isFalse,
      );
    });

    test('seller-only profile is rejected for customer login', () {
      expect(
        AuthSessionGuard.acceptsCustomerLogin(LoginResolvedRole.waiter),
        isFalse,
      );
      expect(
        AuthSessionGuard.acceptsCustomerLogin(LoginResolvedRole.admin),
        isFalse,
      );
      expect(AuthSessionGuard.isSellerOnlyProfile(LoginResolvedRole.waiter), isTrue);
    });

    test('customer-only profile is rejected for seller login', () {
      expect(
        AuthSessionGuard.acceptsSellerLogin(LoginResolvedRole.user),
        isFalse,
      );
      expect(AuthSessionGuard.isCustomerOnlyProfile(LoginResolvedRole.user), isTrue);
    });

    test('dual-role seller may use customer login surface', () {
      expect(
        AuthSessionGuard.acceptsCustomerLogin(LoginResolvedRole.seller),
        isTrue,
      );
    });

    test('web reload with seller context keeps customer header logged out', () {
      IbulAuthContextService.instance.resetForTesting(
        context: IbulAuthContext.seller,
      );
      final customerHeaderLoggedIn = IbulAuthContextService.instance
          .isCustomerSessionActive(hasSupabaseSession: true);
      expect(customerHeaderLoggedIn, isFalse);
    });

    test('storage round-trip preserves activeContext', () {
      expect(
        IbulAuthContextStorage.fromStorage('seller'),
        IbulAuthContext.seller,
      );
      expect(
        IbulAuthContextStorage.fromStorage('customer'),
        IbulAuthContext.customer,
      );
      expect(
        IbulAuthContext.seller.storageValue,
        'seller',
      );
    });
  });
}
