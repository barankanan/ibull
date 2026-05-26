import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/helpers/seller_panel_module_helpers.dart';
import 'package:ibul_app/features/seller/panel/models/seller_panel_types.dart';

void main() {
  setUp(SellerPanelNavigationController.clearCachedControllersForTests);

  group('SellerPanelNavigationController lifecycle persistence', () {
    test(
      'same sellerId keeps active module across dispose/recreate simulation',
      () {
        final controllerA = SellerPanelNavigationController.forSeller(
          'seller-1',
        );
        controllerA.selectByUser(
          SellerModule.garson,
          source: 'test_user_select_garson',
        );

        final controllerB = SellerPanelNavigationController.forSeller(
          'seller-1',
        );

        expect(identical(controllerA, controllerB), isTrue);
        expect(controllerB.activeModule, SellerModule.garson);
        expect(controllerB.hasUserSelected, isTrue);
      },
    );

    test('same sellerId survives parent recreation style lookup', () {
      final controller = SellerPanelNavigationController.forSeller('seller-42');
      controller.selectByUser(
        SellerModule.products,
        source: 'test_user_select_products',
      );

      final recreated = SellerPanelNavigationController.forSeller('seller-42');
      expect(recreated.activeModule, SellerModule.products);
      expect(recreated.hasUserSelected, isTrue);
    });

    test('different sellerIds do not share active module state', () {
      final sellerA = SellerPanelNavigationController.forSeller('seller-a');
      final sellerB = SellerPanelNavigationController.forSeller('seller-b');

      sellerA.selectByUser(SellerModule.system, source: 'seller_a_system');

      expect(sellerA.activeModule, SellerModule.system);
      expect(sellerB.activeModule, SellerModule.dashboard);
    });

    test('waiter seed only applies before user selection', () {
      final controller = SellerPanelNavigationController.forSeller('seller-w');
      expect(
        controller.seedIfPristine(
          SellerModule.garson,
          source: 'waiter_entry_seed',
        ),
        isTrue,
      );
      controller.selectByUser(SellerModule.products, source: 'user_products');
      expect(
        controller.seedIfPristine(
          SellerModule.garson,
          source: 'waiter_entry_seed_again',
        ),
        isFalse,
      );
      expect(controller.activeModule, SellerModule.products);
    });

    test('async dashboard write is blocked after user selection', () {
      final controller = SellerPanelNavigationController.forSeller(
        'seller-lock',
      );
      controller.selectByUser(SellerModule.garson, source: 'user_garson');

      final applied = controller.tryAsyncSet(
        SellerModule.dashboard,
        source: 'async_dashboard_attempt',
      );

      expect(applied, isFalse);
      expect(controller.activeModule, SellerModule.garson);
    });
  });
}
