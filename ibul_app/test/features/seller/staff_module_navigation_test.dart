import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/helpers/seller_panel_module_helpers.dart';
import 'package:ibul_app/features/seller/panel/models/seller_panel_types.dart';

void main() {
  const restaurant = <SellerModule>[
    SellerModule.dashboard,
    SellerModule.orders,
    SellerModule.garson,
    SellerModule.products,
    SellerModule.support,
  ];
  const unresolved = <SellerModule>[
    SellerModule.dashboard,
    SellerModule.orders,
    SellerModule.products,
    SellerModule.support,
  ];

  test('owner keeps the open module', () {
    expect(
      judgeStaffModuleAccess(
        module: SellerModule.garson,
        profileLoaded: true,
        isOwner: true,
        staffRole: null,
        permissions: const <String>{},
        catalog: restaurant,
      ),
      StaffModuleAccess.allowed,
    );
  });

  test('authorized sub_admin stays on garson before the profile resolves', () {
    expect(
      judgeStaffModuleAccess(
        module: SellerModule.garson,
        profileLoaded: false,
        isOwner: false,
        staffRole: 'sub_admin',
        permissions: const <String>{'viewOrders', 'manageOrders'},
        catalog: unresolved,
      ),
      StaffModuleAccess.pending,
    );
    expect(
      judgeStaffModuleAccess(
        module: SellerModule.garson,
        profileLoaded: true,
        isOwner: false,
        staffRole: 'sub_admin',
        permissions: const <String>{
          'viewOrders',
          'manageOrders',
          'takePartialPayment',
        },
        catalog: restaurant,
      ),
      StaffModuleAccess.allowed,
    );
  });

  test('unauthorized staff is denied without receiving an extra permission', () {
    expect(
      judgeStaffModuleAccess(
        module: SellerModule.garson,
        profileLoaded: true,
        isOwner: false,
        staffRole: 'sub_admin',
        permissions: const <String>{'manageSupport'},
        catalog: restaurant,
      ),
      StaffModuleAccess.denied,
    );
    expect(
      judgeStaffModuleAccess(
        module: SellerModule.finance,
        profileLoaded: true,
        isOwner: false,
        staffRole: 'sub_admin',
        permissions: const <String>{'viewOrders', 'manageOrders'},
        visibleModules: const <String>{'garson', 'orders'},
        catalog: restaurant,
      ),
      StaffModuleAccess.denied,
    );
    expect(staffModuleDeniedMessage, 'Bu sayfaya erişim yetkiniz yok.');
    expect(staffAdisyonDeniedMessage, 'Adisyonu açma yetkiniz yok.');
  });
}
