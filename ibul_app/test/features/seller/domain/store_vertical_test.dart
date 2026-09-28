import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/domain/store_vertical.dart';
import 'package:ibul_app/features/seller/panel/helpers/seller_panel_module_helpers.dart';
import 'package:ibul_app/features/seller/panel/models/seller_panel_types.dart';
import 'package:ibul_app/services/auth_service.dart';

void main() {
  group('resolveStoreVertical', () {
    test('maps Galerici to gallery, not restaurant', () {
      expect(resolveStoreVertical('Galerici'), StoreVertical.gallery);
      expect(isSellerFoodStoreCategory('Galerici'), isFalse);
    });

    test('maps Yemek to restaurant', () {
      expect(resolveStoreVertical('Yemek'), StoreVertical.restaurant);
    });

    test('maps Elektronik to ecommerce', () {
      expect(resolveStoreVertical('Elektronik'), StoreVertical.ecommerce);
    });

    test('maps emlak aliases without falling through to restaurant', () {
      expect(resolveStoreVertical('Emlak'), StoreVertical.realEstate);
      expect(resolveStoreVertical('real_estate'), StoreVertical.realEstate);
      expect(isSellerFoodStoreCategory('Emlak'), isFalse);
    });

    test('empty category is unknown, not restaurant', () {
      expect(resolveStoreVertical(''), StoreVertical.unknown);
      expect(resolveStoreVertical(null), StoreVertical.unknown);
    });

    test('parts shop is ecommerce, not gallery', () {
      expect(
        resolveStoreVertical('Otomotiv & Motosiklet'),
        StoreVertical.ecommerce,
      );
    });

    test(
      'map pin with mapped other still resolves gallery via store_category',
      () {
        expect(
          isGalleryStoreRecord({
            'category': 'other',
            'store_category': 'Galerici',
            'seller_id': 'dc3b13dc-6c64-47bf-9670-971dc01c728f',
          }),
          isTrue,
        );
        expect(
          isGalleryStoreRecord({'category': 'Elektronik', 'name': 'Teknosa'}),
          isFalse,
        );
      },
    );
  });

  group('SellerDashboardResolver', () {
    test('every seller vertical uses /seller, never restaurant-only auth', () {
      for (final vertical in StoreVertical.values) {
        expect(
          SellerDashboardResolver.routeFor(
            resolvedRoleName: 'seller',
            vertical: vertical,
          ),
          '/seller',
        );
      }
    });

    test('admin route is independent of store vertical', () {
      expect(
        SellerDashboardResolver.routeFor(
          resolvedRoleName: 'admin',
          vertical: StoreVertical.gallery,
        ),
        '/admin',
      );
    });
  });

  group('visibleSellerModules', () {
    test('gallery gets vehicles, restaurant gets garson, unknown does not', () {
      expect(visibleSellerModules('Galerici'), contains(SellerModule.vehicles));
      expect(
        visibleSellerModules('Yemek'),
        containsAll([SellerModule.garson, SellerModule.system]),
      );
      expect(
        visibleSellerModules('Yemek'),
        isNot(contains(SellerModule.vehicles)),
      );
      expect(
        visibleSellerModules('Emlak'),
        isNot(contains(SellerModule.garson)),
      );
      expect(
        visibleSellerModules('bilinmeyen-dikey'),
        isNot(contains(SellerModule.garson)),
      );
      expect(
        visibleSellerModules('bilinmeyen-dikey'),
        contains(SellerModule.dashboard),
      );
    });
  });

  group('SellerLoginAccess', () {
    test('owned verified store is an approved seller', () {
      expect(
        SellerLoginAccess.ownedStoreMarksUserAsSeller({
          'category': 'Galerici',
          'isVerified': true,
        }),
        isTrue,
      );
      expect(
        SellerLoginAccess.ownedStoreIsApproved({'isVerified': true}),
        isTrue,
      );
      expect(
        SellerLoginAccess.ownedStoreIsApproved({'is_verified': true}),
        isTrue,
      );
      expect(
        SellerLoginAccess.ownedStoreIsApproved({'isVerified': false}),
        isFalse,
      );
    });

    test('pending seller patch never overwrites admin', () {
      expect(
        SellerLoginAccess.pendingSellerUserPatch(
          currentRole: 'admin',
          isAdminRole: AuthService.isAdminRole,
        ),
        isNull,
      );
      expect(
        SellerLoginAccess.pendingSellerUserPatch(
          currentRole: 'user',
          isAdminRole: AuthService.isAdminRole,
        ),
        {'role': 'seller', 'is_seller_approved': false},
      );
    });
  });
}
