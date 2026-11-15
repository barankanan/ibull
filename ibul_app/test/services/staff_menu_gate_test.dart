import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/helpers/seller_panel_module_helpers.dart';
import 'package:ibul_app/features/seller/panel/models/seller_panel_types.dart';

void main() {
  const modules = <SellerModule>[
    SellerModule.dashboard,
    SellerModule.products,
    SellerModule.finance,
    SellerModule.orders,
    SellerModule.garson,
    SellerModule.store,
    SellerModule.system,
  ];

  test('waiter keeps the floor and the permissions granted with that role', () {
    final waiter = modulesForStaff(
      modules: modules,
      isOwner: false,
      staffRole: 'waiter',
      permissions: const <String>{'viewFinance', 'manageStoreProfile'},
    );
    expect(
      waiter,
      <SellerModule>[
        SellerModule.garson,
        SellerModule.finance,
        SellerModule.store,
      ],
    );
    expect(waiter, isNot(contains(SellerModule.products)));
  });

  test('waiter without extra permissions stays on the floor', () {
    expect(
      modulesForStaff(
        modules: modules,
        isOwner: false,
        staffRole: 'waiter',
        permissions: const <String>{},
      ),
      <SellerModule>[SellerModule.garson],
    );
  });

  test('sub-admin with no permissions still has the floor fallback', () {
    expect(
      modulesForStaff(
        modules: modules,
        isOwner: false,
        staffRole: 'sub_admin',
        permissions: const <String>{},
      ),
      <SellerModule>[SellerModule.garson],
    );
  });

  test('sub-admin modules follow the permission that was granted', () {
    final finance = modulesForStaff(
      modules: modules,
      isOwner: false,
      staffRole: 'sub_admin',
      permissions: const <String>{'viewFinance', 'viewOrders'},
    );
    expect(
      finance,
      containsAll(<SellerModule>[
        SellerModule.dashboard,
        SellerModule.finance,
        SellerModule.orders,
        SellerModule.garson,
      ]),
    );
    expect(finance, isNot(contains(SellerModule.store)));
    expect(finance, isNot(contains(SellerModule.products)));
  });

  test('printer permission opens system without order management', () {
    final modulesShown = modulesForStaff(
      modules: modules,
      isOwner: false,
      staffRole: 'waiter',
      permissions: const <String>{'managePrintSettings'},
    );
    expect(modulesShown, contains(SellerModule.system));
    expect(modulesShown, contains(SellerModule.garson));
    expect(modulesShown, isNot(contains(SellerModule.orders)));
  });

  test('an owner keeps the modules already visible for the store', () {
    expect(
      modulesForStaff(modules: modules, isOwner: true),
      modules,
    );
  });
}
