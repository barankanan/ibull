import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/domain/store_vertical.dart';
import 'package:ibul_app/features/seller/storefront/storefront_catalog.dart';
import 'package:ibul_app/features/seller/storefront/storefront_copy.dart';
import 'package:ibul_app/features/vehicle/models/vehicle_enums.dart';
import 'package:ibul_app/features/vehicle/models/vehicle_listing.dart';

void main() {
  group('StorefrontCopy', () {
    test('gallery adapts catalog labels without changing ecommerce', () {
      expect(
        StorefrontCopy.of(StoreVertical.ecommerce).catalogTab,
        'Tüm Ürünler',
      );
      expect(
        StorefrontCopy.of(StoreVertical.ecommerce).featuredSection,
        'Öne Çıkan Ürünler',
      );
      expect(
        StorefrontCopy.of(StoreVertical.gallery).catalogTab,
        'Tüm Araçlar',
      );
      expect(
        StorefrontCopy.of(StoreVertical.gallery).featuredSection,
        'Öne Çıkan Araçlar',
      );
      expect(
        StorefrontCopy.of(StoreVertical.gallery).searchHint,
        'Galeride ara',
      );
    });

    test('real estate copy is ready without routing to gallery', () {
      expect(
        StorefrontCopy.of(StoreVertical.realEstate).catalogTab,
        'Tüm İlanlar',
      );
      expect(
        StorefrontCatalog.usesVehicleCatalog(StoreVertical.realEstate),
        isFalse,
      );
    });
  });

  group('StorefrontCatalog', () {
    VehicleListing listing({
      String id = 'v1',
      String title = 'toyotta corolla 2021',
      String brand = 'Toyota',
      String model = 'Corolla',
      String? version = '1.5 Flame',
      VehicleListingType type = VehicleListingType.sale,
    }) {
      return VehicleListing(
        id: id,
        sellerId: 's1',
        listingType: type,
        status: VehicleListingStatus.active,
        specs: VehicleSpecs(
          brand: brand,
          model: model,
          version: version,
          year: 2021,
        ),
        extras: {'title': title, 'vehicle_class': 'automobile'},
      );
    }

    test('vehicle search matches title brand model version and class', () {
      final item = listing();
      expect(StorefrontCatalog.matchesVehicle(item, 'corolla'), isTrue);
      expect(StorefrontCatalog.matchesVehicle(item, 'toyota'), isTrue);
      expect(StorefrontCatalog.matchesVehicle(item, 'flame'), isTrue);
      expect(StorefrontCatalog.matchesVehicle(item, 'automobile'), isTrue);
      expect(StorefrontCatalog.matchesVehicle(item, 'bmw'), isFalse);
    });

    test('sale and rental category filters stay separate', () {
      final rows = [
        listing(type: VehicleListingType.sale),
        listing(id: 'r1', type: VehicleListingType.rental),
      ];
      expect(
        StorefrontCatalog.filterVehicles(
          rows,
          query: '',
          category: 'Satılık',
          saleLabel: 'Satılık',
          rentalLabel: 'Kiralık',
        ).single.listingType,
        VehicleListingType.sale,
      );
    });
  });
}
