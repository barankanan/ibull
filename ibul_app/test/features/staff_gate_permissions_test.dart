import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/staff_login_policy.dart';

void main() {
  test('a staff gate opens only what the owner stored', () {
    const gate = StaffMenuGate.staff(
      role: 'sub_admin',
      permissions: {'viewOrders', 'manageOrders'},
      jobTitle: 'Restoran Müdürü',
      visibleModules: {'orders', 'garson'},
    );
    expect(gate.restrict, isTrue);
    expect(gate.revoked, isFalse);
    expect(gate.permissions, {'viewOrders', 'manageOrders'});
    expect(gate.visibleModules, {'orders', 'garson'});
    // A grand title adds no permission.
    expect(gate.permissions.contains('manageStaff'), isFalse);
    expect(gate.permissions.contains('managePrintSettings'), isFalse);
  });

  test('a staff permission opens its operation only with an active membership', () {
    for (final op in ['manageOrders', 'closeBill', 'managePrintSettings']) {
      expect(
        staffOperationAllowed(
          isOwner: false,
          activeMembership: true,
          permissions: {op},
          operation: op,
        ),
        isTrue,
      );
      expect(
        staffOperationAllowed(
          isOwner: false,
          activeMembership: false,
          permissions: {op},
          operation: op,
        ),
        isFalse,
      );
    }
  });

  test('after the change only stored permissions open; inactive stays closed', () {
    expect(
      staffOperationAllowed(
        isOwner: false,
        activeMembership: true,
        permissions: {'viewOrders'},
        operation: 'closeBill',
      ),
      isFalse,
    );
    expect(
      staffOperationAllowed(
        isOwner: false,
        activeMembership: false,
        permissions: {'closeBill'},
        operation: 'closeBill',
      ),
      isFalse,
    );
    expect(
      restaurantPermissionAllowed(
        isOwner: true,
        activeMembership: false,
        hasPermission: false,
        managedStaff: false,
      ),
      isTrue,
    );
  });

  test('a revoked gate is restricted and holds nothing', () {
    const gate = StaffMenuGate.revoked();
    expect(gate.restrict, isTrue);
    expect(gate.revoked, isTrue);
    expect(gate.permissions, isEmpty);
  });
}
