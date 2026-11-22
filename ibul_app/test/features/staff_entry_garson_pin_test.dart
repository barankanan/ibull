import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/helpers/seller_panel_module_helpers.dart';
import 'package:ibul_app/services/staff_login_policy.dart';

void main() {
  group('staffGateIsGarsonOnly (staff all log in with role=waiter)', () {
    test('sub-admin with full pages is NOT pinned to Garson', () {
      const gate = StaffMenuGate.staff(
        role: 'sub_admin',
        permissions: {'viewOrders', 'manageOrders', 'viewFinance'},
        visibleModules: {'dashboard', 'products', 'orders', 'garson', 'system', 'finance'},
      );
      expect(staffGateIsGarsonOnly(gate), isFalse);
      final menu = modulesForStaff(
        modules: visibleSellerModules('Yemek'),
        isOwner: false,
        staffRole: gate.role,
        permissions: gate.permissions,
        visibleModules: gate.visibleModules,
      ).map((m) => m.name).toSet();
      expect(menu, {'dashboard', 'products', 'orders', 'garson', 'system', 'finance'});
    });

    test('real waiter with only the floor stays pinned', () {
      const stored = StaffMenuGate.staff(
        role: 'waiter',
        permissions: {'viewOrders'},
        visibleModules: {'garson'},
      );
      expect(staffGateIsGarsonOnly(stored), isTrue);
      const legacy = StaffMenuGate.staff(role: 'waiter', permissions: {'viewOrders'});
      expect(staffGateIsGarsonOnly(legacy), isTrue);
    });

    test('unknown, revoked and not-yet-loaded gates stay narrow', () {
      expect(staffGateIsGarsonOnly(null), isTrue);
      expect(staffGateIsGarsonOnly(const StaffMenuGate.revoked()), isTrue);
    });

    test('sub-admin without stored pages is not pinned; owner is not pinned', () {
      const legacy = StaffMenuGate.staff(
        role: 'sub_admin',
        permissions: {'viewOrders'},
      );
      expect(staffGateIsGarsonOnly(legacy), isFalse);
      expect(staffGateIsGarsonOnly(const StaffMenuGate.owner()), isFalse);
    });
  });
}
