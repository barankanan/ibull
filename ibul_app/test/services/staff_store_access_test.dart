import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/sub_admin.dart';
import 'package:ibul_app/services/staff_login_policy.dart';

void main() {
  const staffAuthId = 'staff-auth';
  const destinaOwnerId = 'destina-owner';
  const otherOwnerId = 'other-restaurant';

  test('staff binds to the membership store and not their auth id', () {
    final restaurantId = resolvedRestaurantOwnerId(
      authUserId: staffAuthId,
      membershipStoreId: destinaOwnerId,
      managedStaff: true,
    );
    expect(restaurantId, destinaOwnerId);
    expect(restaurantId, isNot(staffAuthId));
  });

  test('staff cannot treat another restaurant as their store', () {
    final restaurantId = resolvedRestaurantOwnerId(
      authUserId: staffAuthId,
      membershipStoreId: destinaOwnerId,
      managedStaff: true,
    );
    expect(restaurantId == otherOwnerId, isFalse);
  });

  test('deactivated staff loses the restaurant and permission', () {
    expect(
      resolvedRestaurantOwnerId(
        authUserId: staffAuthId,
        membershipStoreId: null,
        managedStaff: true,
      ),
      isNull,
    );
    expect(
      restaurantPermissionAllowed(
        isOwner: false,
        activeMembership: false,
        hasPermission: true,
        managedStaff: true,
      ),
      isFalse,
    );
  });

  test('an owner is not rewritten into a staff auth id', () {
    expect(
      resolvedRestaurantOwnerId(
        authUserId: destinaOwnerId,
        membershipStoreId: null,
        managedStaff: false,
      ),
      destinaOwnerId,
    );
  });

  test('remember-me keeps a session unless the flag is explicitly off', () {
    expect(shouldDiscardPersistedSellerSession('1'), isFalse);
    expect(shouldDiscardPersistedSellerSession(null), isFalse);
    expect(shouldDiscardPersistedSellerSession('0'), isTrue);
  });

  test('unassigned tables stay visible and another branch stays closed', () {
    expect(
      restaurantStaffBranchCanSeeTable(
        staffBranchId: 'destina-branch',
        tableBranchId: null,
      ),
      isTrue,
    );
    expect(
      restaurantStaffBranchCanSeeTable(
        staffBranchId: 'destina-branch',
        tableBranchId: 'destina-branch',
      ),
      isTrue,
    );
    expect(
      restaurantStaffBranchCanSeeTable(
        staffBranchId: 'destina-branch',
        tableBranchId: 'other-branch',
      ),
      isFalse,
    );
  });

  test('print denial keeps the server reason', () {
    expect(
      restaurantWriteDenialMessage(
        code: '42501',
        details: 'Bu şubede işlem yetkiniz yok.',
      ),
      contains('şubesinde'),
    );
    expect(
      restaurantWriteDenialMessage(
        code: '42501',
        details: 'Bu restoran için işlem yetkiniz yok.',
      ),
      contains('manageOrders'),
    );
    expect(
      restaurantWriteDenialMessage(
        code: '42501',
        details: 'Bu restoran için işlem yetkiniz yok.',
      ),
      isNot(contains('email veya telefon')),
    );
    expect(
      restaurantWriteDenialMessage(
        code: '57014',
        details: 'canceling statement due to statement timeout',
      ),
      contains('57014'),
    );
  });

  test('the same payment confirmation keeps one server key', () {
    const first = '1001';
    final key = stableStaffPaymentRequestId(
      tableNumber: 4,
      sessionKey: 'session-a',
      amount: 20,
      method: 'cash',
      attemptToken: first,
    );
    expect(
      stableStaffPaymentRequestId(
        tableNumber: 4,
        sessionKey: 'session-a',
        amount: 20,
        method: 'cash',
        attemptToken: first,
      ),
      key,
    );
    expect(
      stableStaffPaymentRequestId(
        tableNumber: 4,
        sessionKey: 'session-a',
        amount: 25,
        method: 'cash',
        attemptToken: first,
      ),
      isNot(key),
    );
  });

  test('order taking stays on manageOrders and does not open close or transfer', () {
    const waiter = {'viewOrders', 'manageOrders'};
    expect(
      staffOperationAllowed(
        isOwner: false,
        activeMembership: true,
        permissions: waiter,
        operation: 'manageOrders',
      ),
      isTrue,
    );
    expect(
      staffOperationAllowed(
        isOwner: false,
        activeMembership: true,
        permissions: waiter,
        operation: 'closeBill',
      ),
      isFalse,
    );
    expect(
      staffOperationAllowed(
        isOwner: false,
        activeMembership: true,
        permissions: waiter,
        operation: 'transferTable',
      ),
      isFalse,
    );
  });

  test('assistant manager can use only the granted operations', () {
    const assistant = {'viewOrders', 'closeBill'};
    expect(
      staffOperationAllowed(
        isOwner: false,
        activeMembership: true,
        permissions: assistant,
        operation: 'closeBill',
      ),
      isTrue,
    );
    for (final operation in [
      'manageOrders',
      'transferTable',
      'takePartialPayment',
      'manageStaff',
      'manageStoreProfile',
    ]) {
      expect(
        staffOperationAllowed(
          isOwner: false,
          activeMembership: true,
          permissions: assistant,
          operation: operation,
        ),
        isFalse,
        reason: operation,
      );
    }
  });

  test('another branch and another restaurant stay closed', () {
    expect(
      restaurantStaffBranchCanSeeTable(
        staffBranchId: 'destina-branch',
        tableBranchId: 'other-branch',
      ),
      isFalse,
    );
    expect(
      resolvedRestaurantOwnerId(
        authUserId: staffAuthId,
        membershipStoreId: destinaOwnerId,
        managedStaff: true,
      ),
      isNot(otherOwnerId),
    );
  });

  test('rpc failure never allows a direct table_orders write', () {
    const cases = <(String?, String)>[
      ('42501', 'Hesabı kesme yetkisi yok.'),
      ('42501', 'Masa aktarma yetkisi yok.'),
      ('PGRST202', 'Could not find the function public.transfer_table_orders'),
      ('22023', 'Geçersiz parametre.'),
      ('P0001', 'Personel sipariş yetkisi yok.'),
      (null, ''),
    ];
    for (final item in cases) {
      expect(
        directTableOrderWriteAllowedAfterRpcFailure(
          code: item.$1,
          message: item.$2,
        ),
        isFalse,
      );
    }
  });

  test('new operation permissions stay closed unless granted', () {
    expect(
      defaultStaffPermissions,
      {SellerPermission.viewOrders, SellerPermission.manageOrders},
    );
    expect(
      staffOperationAllowed(
        isOwner: false,
        activeMembership: true,
        permissions: const {'manageOrders'},
        operation: 'closeBill',
      ),
      isFalse,
    );
    expect(
      staffOperationAllowed(
        isOwner: false,
        activeMembership: true,
        permissions: const {'closeBill'},
        operation: 'closeBill',
      ),
      isTrue,
    );
    expect(
      staffOperationAllowed(
        isOwner: true,
        activeMembership: false,
        permissions: const {},
        operation: 'transferTable',
      ),
      isTrue,
    );
    expect(
      staffOperationAllowed(
        isOwner: false,
        activeMembership: false,
        permissions: const {'transferTable'},
        operation: 'transferTable',
      ),
      isFalse,
    );
  });

  test('refresh resolves the same membership store again', () {
    String? load() => resolvedRestaurantOwnerId(
      authUserId: staffAuthId,
      membershipStoreId: destinaOwnerId,
      managedStaff: true,
    );
    final first = load();
    final refreshed = load();
    expect(refreshed, first);
    expect(refreshed, destinaOwnerId);
    expect(refreshed, isNot(staffAuthId));
    expect(refreshed, isNot(otherOwnerId));
  });
}
