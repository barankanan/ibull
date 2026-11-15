import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/helpers/seller_panel_module_helpers.dart';
import 'package:ibul_app/features/seller/panel/models/seller_panel_types.dart';
import 'package:ibul_app/models/sub_admin.dart';

void main() {
  const held = <String>{
    'manageStaff',
    'manageOrders',
    'closeBill',
    'transferTable',
    'takePartialPayment',
    'splitBill',
  };

  test('owner can grant staff management and each floor permission', () {
    expect(
      staffGrantWithinCeiling(
        isOwner: true,
        held: const <String>{},
        requested: <String>[
          'manageStaff',
          'manageOrders',
          'closeBill',
          'transferTable',
          'takePartialPayment',
          'splitBill',
        ],
      ),
      isTrue,
    );
    expect(actorCanManageStaff(isOwner: true, held: const <String>{}), isTrue);
  });

  test('sub-admin can grant only the permissions they hold', () {
    expect(
      staffGrantWithinCeiling(
        isOwner: false,
        held: held,
        requested: const <String>['manageOrders', 'closeBill'],
      ),
      isTrue,
    );
    expect(
      staffGrantWithinCeiling(
        isOwner: false,
        held: held,
        requested: const <String>['manageOrders', 'viewFinance'],
      ),
      isFalse,
    );
    final titles = staffGrantGroups(isOwner: false, held: held)
        .map((group) => group.title);
    expect(titles, isNot(contains('İşletme Yönetimi')));
  });

  test('sub-admin cannot grant store profile or act without staff permission', () {
    expect(
      staffGrantWithinCeiling(
        isOwner: false,
        held: <String>{...held, 'manageStoreProfile'},
        requested: const <String>['manageStoreProfile'],
      ),
      isFalse,
    );
    expect(
      actorCanManageStaff(isOwner: false, held: const <String>{'manageOrders'}),
      isFalse,
    );
    expect(
      modulesForStaff(
        modules: const <SellerModule>[SellerModule.team, SellerModule.store],
        isOwner: false,
        staffRole: 'sub_admin',
        permissions: held,
      ),
      <SellerModule>[SellerModule.team],
    );
  });
}
