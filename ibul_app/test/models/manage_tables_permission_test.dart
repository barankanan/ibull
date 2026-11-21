import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/helpers/seller_panel_module_helpers.dart';
import 'package:ibul_app/features/seller/panel/models/seller_panel_types.dart';
import 'package:ibul_app/features/seller/staff/staff_business_catalog.dart';
import 'package:ibul_app/models/sub_admin.dart';
import 'package:ibul_app/services/staff_login_policy.dart';

void main() {
  tableAdminHelperTests();
  test('manageTables sunucuda saklanır ve Sistem tam erişimine dahildir', () {
    expect(staffPermissionPersists(SellerPermission.manageTables), isTrue);
    final ops = pageFullAccessOperations(SellerModule.system);
    expect(ops, contains(SellerPermission.manageTables));
    expect(ops, contains(SellerPermission.managePrintSettings));
  });

  test('manageTables sipariş, ödeme, personel veya finans yetkisi içermez', () {
    final ops = pageFullAccessOperations(SellerModule.system);
    for (final blocked in <SellerPermission>{
      SellerPermission.manageStaff,
      SellerPermission.closeBill,
      SellerPermission.takePartialPayment,
      SellerPermission.viewFinance,
      SellerPermission.manageStoreProfile,
    }) {
      expect(ops, isNot(contains(blocked)));
    }
  });

  test('garson tavanı manageTables vermez; alt yönetici tavanı verir', () {
    expect(waiterPermissionCeiling, isNot(contains(SellerPermission.manageTables)));
    expect(
      staffStoredRoleCeiling('sub_admin'),
      contains(SellerPermission.manageTables),
    );
  });

  test('yalnız manageTables olan personel Sistem sayfasını görür, Garson/Ürünleri görmez', () {
    final modules = modulesForStaff(
      modules: SellerModule.values,
      isOwner: false,
      staffRole: 'sub_admin',
      permissions: const <String>{'manageTables'},
    );
    expect(modules, contains(SellerModule.system));
    expect(modules, isNot(contains(SellerModule.garson)));
    expect(modules, isNot(contains(SellerModule.products)));
  });

  test('yetki adı sunucu sözleşmesiyle aynı', () {
    expect(SellerPermission.manageTables.name, 'manageTables');
  });
}

void tableAdminHelperTests() {
  group('Sistem sayfası masa yönetimi yardımcıları', () {
    test('sahip veya manageTables masa yönetebilir; diğerleri yönetemez', () {
      expect(staffMayManageTables(isOwner: true, held: const {}), isTrue);
      expect(
        staffMayManageTables(isOwner: false, held: const {'manageTables'}),
        isTrue,
      );
      for (final held in <Set<String>>[
        {'manageOrders'},
        {'managePrintSettings'},
        {'manageStaff', 'closeBill'},
        <String>{},
      ]) {
        expect(staffMayManageTables(isOwner: false, held: held), isFalse);
      }
    });

    test('yalnız yazıcı kısayolu: masa izni varsa devre dışı', () {
      expect(systemModuleIsPrinterOnly(held: {'managePrintSettings'}), isTrue);
      expect(
        systemModuleIsPrinterOnly(
          held: {'managePrintSettings', 'manageTables'},
        ),
        isFalse,
      );
      expect(
        systemModuleIsPrinterOnly(
          held: {'managePrintSettings', 'manageOrders'},
        ),
        isFalse,
      );
      expect(systemModuleIsPrinterOnly(held: {'manageTables'}), isFalse);
    });

    test('get_my_staff_access şubesi: dolu, boş ve bozuk yanıt', () {
      expect(staffBranchFromAccess({'branch_id': ' b-1 '}), 'b-1');
      expect(staffBranchFromAccess({'branch_id': null}), isNull);
      expect(staffBranchFromAccess({'branch_id': ''}), isNull);
      expect(staffBranchFromAccess(null), isNull);
      expect(staffBranchFromAccess('x'), isNull);
    });
  });
}
