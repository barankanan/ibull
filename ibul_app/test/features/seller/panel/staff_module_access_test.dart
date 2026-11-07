import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/helpers/seller_panel_module_helpers.dart';
import 'package:ibul_app/features/seller/panel/models/seller_panel_types.dart';
import 'package:ibul_app/models/staff_access_policy.dart';

void main() {
  test('owner menu is unchanged when no staff grant is applied', () {
    final modules = visibleSellerModules('Restoran');
    expect(modules, contains(SellerModule.team));
    expect(modules, contains(SellerModule.garson));
    expect(modules.first, SellerModule.dashboard);
  });

  test('waiter entry still pins the menu to garson before a grant filter', () {
    expect(visibleSellerModules('Market', garsonOnly: true), <SellerModule>[
      SellerModule.garson,
    ]);
  });

  test('Tam Erişim keeps page operations and removes staff management', () {
    final modules = visibleSellerModules(
      'Restoran',
      staffGrant: const StaffGrant(
        status: 'active',
        permissions: <String>['fullAccess'],
      ),
    );
    expect(modules, contains(SellerModule.finance));
    expect(modules, contains(SellerModule.products));
    expect(modules, contains(SellerModule.garson));
    expect(modules, contains(SellerModule.orders));
    expect(modules, isNot(contains(SellerModule.team)));
  });

  test(
    'view-only grant cannot open finance and cannot keep garson if inactive',
    () {
      final active = visibleSellerModules(
        'Restoran',
        garsonOnly: true,
        staffGrant: const StaffGrant(
          status: 'active',
          permissions: <String>['viewOrders'],
        ),
      );
      expect(active, <SellerModule>[SellerModule.garson]);

      final inactive = visibleSellerModules(
        'Restoran',
        garsonOnly: true,
        staffGrant: const StaffGrant(
          status: 'invited',
          permissions: <String>['manageOrders', 'fullAccess'],
        ),
      );
      expect(inactive, isEmpty);
    },
  );
}
