import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/staff_login_policy.dart';

void main() {
  test('closeBill granted: no reason, button enabled', () {
    expect(tableCloseDisabledReason(allowed: true), isNull);
  });
  test('closeBill missing: understandable reason names the permission', () {
    final reason = tableCloseDisabledReason(allowed: false);
    expect(reason, contains('Hesabı Kes'));
  });
  test('stored closeBill opens the gate, manageOrders alone does not', () {
    expect(
      staffOperationAllowed(
        isOwner: false,
        activeMembership: true,
        permissions: {'manageOrders', 'viewOrders'},
        operation: 'closeBill',
      ),
      isFalse,
    );
    expect(
      staffOperationAllowed(
        isOwner: false,
        activeMembership: true,
        permissions: {'closeBill'},
        operation: 'closeBill',
      ),
      isTrue,
    );
  });
}
