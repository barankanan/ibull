import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/staff_access_policy.dart';
import 'package:ibul_app/models/sub_admin.dart';

void main() {
  group('parseStaffPermissionTokens', () {
    test('keeps known grants and Tam Erişim aliases', () {
      expect(
        parseStaffPermissionTokens(<Object>[
          'manageOrders',
          'Tam Erişim',
          'tam_erisim',
          'fullAccess',
        ]),
        <String>{'manageOrders', 'fullAccess'},
      );
    });

    test(
      'drops unknown tokens instead of turning them into product access',
      () {
        expect(
          parseStaffPermissionTokens(<Object>[
            'not-a-permission',
            'viewOrders',
          ]),
          <String>{'viewOrders'},
        );
        final admin = SubAdmin.fromMap(<String, dynamic>{
          'permissions': <String>['garbage', 'fullAccess'],
          'status': 'active',
        }, 'row-1');
        expect(admin.permissions, <SellerPermission>[
          SellerPermission.fullAccess,
        ]);
      },
    );
  });

  group('staffMayPerform', () {
    test('owner can collect and manage staff', () {
      expect(
        staffMayPerform(
          isOwner: true,
          status: 'invited',
          permissions: const <String>[],
          operation: StaffOperation.collectPayment,
        ),
        isTrue,
      );
      expect(
        staffMayPerform(
          isOwner: true,
          status: 'active',
          permissions: const <String>[],
          operation: StaffOperation.manageStaff,
        ),
        isTrue,
      );
    });

    test('active order manager can collect but cannot manage staff', () {
      expect(
        staffMayPerform(
          isOwner: false,
          status: 'active',
          permissions: const <String>['manageOrders'],
          operation: StaffOperation.collectPayment,
        ),
        isTrue,
      );
      expect(
        staffMayPerform(
          isOwner: false,
          status: 'active',
          permissions: const <String>['manageOrders'],
          operation: StaffOperation.manageStaff,
        ),
        isFalse,
      );
    });

    test('Tam Erişim covers page operations and not staff administration', () {
      for (final operation in <StaffOperation>[
        StaffOperation.collectPayment,
        StaffOperation.manageOrders,
        StaffOperation.manageProducts,
        StaffOperation.viewFinance,
        StaffOperation.manageCampaigns,
        StaffOperation.manageSupport,
        StaffOperation.manageStoreProfile,
      ]) {
        expect(
          staffMayPerform(
            isOwner: false,
            status: 'active',
            permissions: const <String>['Tam Erişim'],
            operation: operation,
          ),
          isTrue,
          reason: operation.name,
        );
      }
      expect(
        staffMayPerform(
          isOwner: false,
          status: 'active',
          permissions: const <String>['fullAccess'],
          operation: StaffOperation.manageStaff,
        ),
        isFalse,
      );
    });

    test('view-only and inactive grants cannot collect', () {
      expect(
        staffMayPerform(
          isOwner: false,
          status: 'active',
          permissions: const <String>['viewOrders', 'manageProducts'],
          operation: StaffOperation.collectPayment,
        ),
        isFalse,
      );
      expect(
        staffMayPerform(
          isOwner: false,
          status: 'invited',
          permissions: const <String>['manageOrders'],
          operation: StaffOperation.collectPayment,
        ),
        isFalse,
      );
      expect(
        staffMayPerform(
          isOwner: false,
          status: 'active',
          permissions: const <String>['viewOrders'],
          operation: StaffOperation.viewOrders,
        ),
        isTrue,
      );
    });
  });

  group('staffMayOpenModule', () {
    test('Tam Erişim opens operating pages and hides the team page', () {
      const permissions = <String>['fullAccess'];
      expect(
        staffMayOpenModule(
          module: 'finance',
          status: 'active',
          permissions: permissions,
        ),
        isTrue,
      );
      expect(
        staffMayOpenModule(
          module: 'garson',
          status: 'active',
          permissions: permissions,
        ),
        isTrue,
      );
      expect(
        staffMayOpenModule(
          module: 'products',
          status: 'active',
          permissions: permissions,
        ),
        isTrue,
      );
      expect(
        staffMayOpenModule(
          module: 'team',
          status: 'active',
          permissions: permissions,
        ),
        isFalse,
      );
    });

    test('view orders opens the order and waiter pages only', () {
      const permissions = <String>['viewOrders'];
      expect(
        staffMayOpenModule(
          module: 'orders',
          status: 'active',
          permissions: permissions,
        ),
        isTrue,
      );
      expect(
        staffMayOpenModule(
          module: 'garson',
          status: 'active',
          permissions: permissions,
        ),
        isTrue,
      );
      expect(
        staffMayOpenModule(
          module: 'finance',
          status: 'active',
          permissions: permissions,
        ),
        isFalse,
      );
      expect(
        staffMayOpenModule(
          module: 'team',
          status: 'active',
          permissions: permissions,
        ),
        isFalse,
      );
    });
  });
}
