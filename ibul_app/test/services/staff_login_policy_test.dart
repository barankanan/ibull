import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/staff_login_policy.dart';

import 'package:ibul_app/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('a banned staff login says the account is passive', () {
    final message = AuthService().describeSignInError(
      AuthApiException('User is banned', statusCode: '400', code: 'user_banned'),
      authArea: 'seller',
    );
    expect(message, 'Bu personel hesabı pasif. İşletme sahibine başvurun.');
  });

  test('active waiter and sub-admin skip the seller application', () {
    final waiter = resolveStaffLoginAccess(
      managedStaffFlag: true,
      access: const <String, dynamic>{
        'store_id': 'store-1',
        'staff_role': 'waiter',
      },
      diagnosticContext: 'seller_login',
    );
    final subAdmin = resolveStaffLoginAccess(
      managedStaffFlag: false,
      access: const <String, dynamic>{
        'store_id': 'store-1',
        'staff_role': 'sub_admin',
      },
      diagnosticContext: 'seller_login',
    );
    expect(waiter.role, 'waiter');
    expect(waiter.storeId, 'store-1');
    expect(subAdmin.role, 'seller');
    expect(subAdmin.rejectionMessage, isNull);
  });

  test('managed auth without a membership is a distinct error', () {
    final decision = resolveStaffLoginAccess(
      managedStaffFlag: true,
      access: null,
      diagnosticContext: 'seller_login',
    );
    expect(decision.isActiveStaff, isFalse);
    expect(decision.rejectionMessage, contains('Personel üyeliği'));
  });

  test('customer login does not turn a missing membership into a seller error', () {
    final decision = resolveStaffLoginAccess(
      managedStaffFlag: true,
      access: null,
      diagnosticContext: 'user_login',
    );
    expect(decision.rejectionMessage, isNull);
  });

  test('login throttle locks after repeated failures and does not store secrets', () {
    final clock = <DateTime>[DateTime.utc(2026, 11, 1, 8)];
    final throttle = StaffLoginThrottle(
      limit: 2,
      lockout: const Duration(seconds: 30),
      clock: () => clock.single,
    );
    expect(throttle.rejection(), isNull);
    throttle.recordFailure();
    expect(throttle.rejection(), isNull);
    throttle.recordFailure();
    expect(throttle.rejection(), contains('saniye'));
    clock[0] = clock.single.add(const Duration(seconds: 31));
    expect(throttle.rejection(), isNull);
  });

  test('printed and uncertain local tickets are not reprinted from the cloud', () {
    expect(localPrintShouldSkipCloudReprint('printed'), isTrue);
    expect(localPrintShouldSkipCloudReprint('forwarded'), isTrue);
    expect(localPrintShouldSkipCloudReprint('uncertain'), isTrue);
    expect(localPrintShouldSkipCloudReprint('failed'), isFalse);
    expect(
      localPrintStatusFromDispatch(
        physicallyDispatched: false,
        error: 'client_timeout',
      ),
      'uncertain',
    );
    expect(
      localPrintStatusFromDispatch(physicallyDispatched: true),
      'printed',
    );
  });

  test('email match alone cannot claim an auth account', () {
    final denied = decideStaffAccountLink(
      confirmLink: true,
      ownerStoreId: 'store-1',
      provisionedByStoreId: null,
      managedStaff: false,
      foreignMembership: false,
      ownsStore: false,
    );
    final needsConfirm = decideStaffAccountLink(
      confirmLink: false,
      ownerStoreId: 'store-1',
      provisionedByStoreId: 'store-1',
      managedStaff: true,
      foreignMembership: false,
      ownsStore: false,
    );
    final allowed = decideStaffAccountLink(
      confirmLink: true,
      ownerStoreId: 'store-1',
      provisionedByStoreId: 'store-1',
      managedStaff: true,
      foreignMembership: false,
      ownsStore: false,
    );
    expect(denied.allowed, isFalse);
    expect(denied.linkAvailable, isFalse);
    expect(needsConfirm.allowed, isFalse);
    expect(needsConfirm.linkAvailable, isTrue);
    expect(allowed.allowed, isTrue);
  });

  test('waiter cannot open finance or store setup', () {
    expect(waiterMayOpenScreen('orders'), isTrue);
    expect(waiterMayOpenScreen('viewFinance'), isFalse);
    expect(waiterMayOpenScreen('manageStoreProfile'), isFalse);
  });

  test('paired order is not shown as saved when the host is down', () {
    final down = decideLanOrderSubmit(
      paired: true,
      hostReachable: false,
      hostSaved: false,
    );
    final saved = decideLanOrderSubmit(
      paired: true,
      hostReachable: true,
      hostSaved: true,
    );
    expect(down.showSuccess, isFalse);
    expect(down.error, contains('Ana bilgisayar'));
    expect(saved.showSuccess, isTrue);
    expect(lanTicketStatusText('failed'), contains('iletilmedi'));
    expect(lanTicketStatusText('uncertain'), contains('otomatik tekrar yok'));
    expect(lanTicketStatusText('forwarded'), isNot(contains('Basıldı')));
    expect(lanTicketStatusText('forwarded'), contains('onaylanmadı'));
  });

  test('no password flag blocks a permission; membership and permission still decide', () {
    expect(
      restaurantPermissionAllowed(
        isOwner: true,
        activeMembership: false,
        hasPermission: false,
        managedStaff: false,
      ),
      isTrue,
    );
    expect(
      restaurantPermissionAllowed(
        isOwner: false,
        activeMembership: true,
        hasPermission: true,
        managedStaff: true,
      ),
      isTrue,
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
    expect(
      restaurantPermissionAllowed(
        isOwner: false,
        activeMembership: true,
        hasPermission: false,
        managedStaff: true,
      ),
      isFalse,
    );
  });

  test('staff membership selects the restaurant, not the staff auth id', () {
    expect(
      resolvedRestaurantOwnerId(
        authUserId: 'staff-1',
        membershipStoreId: 'destina-owner',
        managedStaff: true,
      ),
      'destina-owner',
    );
    expect(
      resolvedRestaurantOwnerId(
        authUserId: 'staff-1',
        membershipStoreId: null,
        managedStaff: true,
      ),
      isNull,
    );
    expect(
      resolvedRestaurantOwnerId(
        authUserId: 'owner-1',
        membershipStoreId: null,
        managedStaff: false,
      ),
      'owner-1',
    );
  });
}
