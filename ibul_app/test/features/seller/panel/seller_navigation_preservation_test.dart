import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/helpers/seller_panel_module_helpers.dart';
import 'package:ibul_app/features/seller/panel/models/seller_panel_types.dart';

void main() {
  group('seller navigation preservation', () {
    test('background profile reload keeps products module on food store', () {
      expect(
        resolveSellerModuleAfterProfileReload(
          currentModule: SellerModule.products,
          storeCategory: 'Yemek & İçecek',
          garsonOnly: false,
        ),
        SellerModule.products,
      );
    });

    test('background profile reload keeps garson on food store', () {
      expect(
        resolveSellerModuleAfterProfileReload(
          currentModule: SellerModule.garson,
          storeCategory: 'Restoran',
          garsonOnly: false,
        ),
        SellerModule.garson,
      );
    });

    test('non-food store moves garson to dashboard', () {
      expect(
        resolveSellerModuleAfterProfileReload(
          currentModule: SellerModule.garson,
          storeCategory: 'Giyim',
          garsonOnly: false,
        ),
        SellerModule.dashboard,
      );
    });

    test('waiter entry always garson', () {
      expect(
        resolveSellerModuleAfterProfileReload(
          currentModule: SellerModule.products,
          storeCategory: 'Giyim',
          garsonOnly: true,
        ),
        SellerModule.garson,
      );
    });
  });
}
