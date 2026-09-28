import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/vehicle/models/vehicle_enums.dart';
import 'package:ibul_app/features/vehicle/models/vehicle_listing.dart';
import 'package:ibul_app/models/db_product.dart';
import 'package:ibul_app/screens/home/home_discovery_resolver.dart';

DBProduct _product(String id, {String? sellerId}) {
  return DBProduct(
    id: id,
    name: 'Ürün $id',
    brand: 'Marka',
    price: '100',
    rating: 4,
    reviewCount: 1,
    imageUrl: 'https://example.com/$id.jpg',
    category: 'Elektronik',
    sellerId: sellerId,
    isActive: true,
    tags: '[]',
  );
}

VehicleListing _vehicle(String id, {VehicleListingStatus status = VehicleListingStatus.active}) {
  return VehicleListing(
    id: id,
    sellerId: 'gallery-1',
    listingType: VehicleListingType.sale,
    status: status,
    specs: const VehicleSpecs(brand: 'Toyota', model: 'Corolla', year: 2021),
    salePrice: 900000,
    city: 'Hatay',
  );
}

void main() {
  test('nearby mixes products and live vehicles with type badges', () {
    final items = HomeDiscoveryResolver.nearby(
      products: [_product('p1', sellerId: 's1')],
      vehicles: [
        _vehicle('v1'),
        _vehicle('draft', status: VehicleListingStatus.draft),
      ],
      distanceBySeller: {'s1': 2, 'gallery-1': 4},
    );
    expect(items.map((e) => e.id), containsAll(['p1', 'v1']));
    expect(items.map((e) => e.id), isNot(contains('draft')));
    expect(
      items.firstWhere((e) => e.id == 'p1').type,
      HomeDiscoveryContentType.product,
    );
    expect(
      items.firstWhere((e) => e.id == 'v1').typeBadge,
      'Araç',
    );
    expect(items.first.id, 'p1');
  });

  test('public vehicles hide pending and draft', () {
    final live = HomeDiscoveryResolver.publicVehicles([
      _vehicle('live'),
      _vehicle('pending', status: VehicleListingStatus.pendingReview),
      _vehicle('draft', status: VehicleListingStatus.draft),
    ]);
    expect(live.map((e) => e.id), ['live']);
  });
}
