import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/helpers/seller_panel_module_helpers.dart';
import 'package:ibul_app/features/seller/panel/models/seller_panel_types.dart';
import 'package:ibul_app/models/sub_admin.dart';

/// CLIENT-SIDE ONLY: 4 roles x 5 modules = 20 checks of modulesForStaff.
/// Server-side (RLS/RPC) enforcement is NOT covered here.
void main() {
  const catalog = SellerModule.values;
  final roles = <String, Map<String, Object>>{
    'owner': {'isOwner': true, 'role': 'owner', 'perms': <String>{}},
    'sub_admin_full': {
      'isOwner': false,
      'role': 'sub_admin',
      'perms': SellerPermission.values.map((p) => p.name).toSet(),
    },
    'waiter': {
      'isOwner': false,
      'role': 'waiter',
      'perms': <String>{'viewOrders', 'manageOrders'},
    },
    'sub_admin_none': {
      'isOwner': false,
      'role': 'sub_admin',
      'perms': <String>{},
    },
  };
  // module -> expected visibility per role
  final expected = <SellerModule, Map<String, bool>>{
    SellerModule.finance: {
      'owner': true, 'sub_admin_full': true, 'waiter': false, 'sub_admin_none': false,
    },
    SellerModule.products: {
      'owner': true, 'sub_admin_full': true, 'waiter': false, 'sub_admin_none': false,
    },
    SellerModule.team: {
      'owner': true, 'sub_admin_full': true, 'waiter': false, 'sub_admin_none': false,
    },
    SellerModule.store: {
      'owner': true, 'sub_admin_full': true, 'waiter': false, 'sub_admin_none': false,
    },
    SellerModule.orders: {
      'owner': true, 'sub_admin_full': true, 'waiter': true, 'sub_admin_none': false,
    },
  };

  for (final m in expected.entries) {
    for (final r in roles.entries) {
      test('${r.key} -> ${m.key.name} == ${m.value[r.key]}', () {
        final v = modulesForStaff(
          modules: catalog,
          isOwner: r.value['isOwner']! as bool,
          staffRole: r.value['role']! as String,
          permissions: r.value['perms']! as Set<String>,
        );
        expect(v.contains(m.key), m.value[r.key]);
      });
    }
  }

  test('changed permissions are reflected in next evaluation', () {
    List<SellerModule> eval(Set<String> p) => modulesForStaff(
        modules: catalog, isOwner: false, staffRole: 'sub_admin', permissions: p);
    expect(eval({'viewFinance'}).contains(SellerModule.finance), isTrue);
    expect(eval({'viewOrders'}).contains(SellerModule.finance), isFalse);
  });

  test('no-permission non-waiter staff must not receive garson fallback', () {
    final v = modulesForStaff(
        modules: catalog, isOwner: false, staffRole: 'sub_admin', permissions: {});
    expect(v, isEmpty);
  });
}
