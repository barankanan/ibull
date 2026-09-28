import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/vehicle/domain/vehicle_compare_fields.dart';
import 'package:ibul_app/features/vehicle/domain/vehicle_compare_recommend.dart';
import 'package:ibul_app/features/vehicle/domain/vehicle_nearby_query.dart';
import 'package:ibul_app/features/vehicle/models/vehicle_enums.dart';
import 'package:ibul_app/features/vehicle/models/vehicle_listing.dart';

VehicleListing _listing({
  String id = '1',
  VehicleListingType type = VehicleListingType.sale,
  String brand = 'Renault',
  String model = 'Clio',
  String? version,
  String title = 'reno clio kiralık',
  double? salePrice,
  VehicleRentalSettings? rental,
  String vehicleClass = 'automobile',
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
    salePrice: salePrice,
    rental: rental,
    extras: {'title': title, 'vehicle_class': vehicleClass},
  );
}

void main() {
  test('nearby query prefers brand model version over messy title', () {
    expect(
      VehicleNearbyQuery.fromListing(_listing(version: 'Techno')),
      'Renault Clio Techno',
    );
    expect(VehicleNearbyQuery.fromListing(_listing()), 'Renault Clio');
  });

  test('recommended vehicles exclude current and prefer same brand/model', () {
    final current = _listing(
      id: 'current',
      brand: 'Toyota',
      model: 'Corolla',
      title: 'Toyota Corolla',
    );
    final ranked = VehicleCompareRecommend.rank(
      current: current,
      candidates: [
        current,
        _listing(
          id: 'clio',
          brand: 'Renault',
          model: 'Clio',
          title: 'Renault Clio',
        ),
        _listing(
          id: 'corolla-2',
          brand: 'Toyota',
          model: 'Corolla',
          title: 'Toyota Corolla 2',
        ),
        _listing(
          id: 'civic',
          brand: 'Honda',
          model: 'Civic',
          title: 'Honda Civic',
        ),
      ],
    );
    expect(ranked.map((item) => item.id), isNot(contains('current')));
    expect(ranked.first.id, 'corolla-2');
  });

  test('sale and rental prices stay on their own compare rows', () {
    final rental = _listing(
      type: VehicleListingType.rental,
      salePrice: 1200212,
      rental: const VehicleRentalSettings(dailyPrice: 1166, deposit: 5000),
    );
    final sale = _listing(type: VehicleListingType.sale, salePrice: 1200212);
    expect(VehicleCompareFields.listingKind(rental), 'Kiralık');
    expect(VehicleCompareFields.listingKind(sale), 'Satılık');
    expect(VehicleCompareFields.headlinePrice(rental), contains('/ gün'));
    expect(VehicleCompareFields.headlinePrice(sale), isNot(contains('/ gün')));
    final rows = VehicleCompareFields.rowsFor([rental, sale]);
    final salePrice = rows.firstWhere((row) => row.label == 'Satış fiyatı');
    expect(salePrice.value(rental), '—');
    expect(salePrice.value(sale), isNot('—'));
    final daily = rows.firstWhere((row) => row.label == 'Günlük fiyat');
    expect(daily.value(rental), isNot('—'));
    expect(daily.value(sale), '—');
  });

  test('search row maps gallery_name onto listing gallery', () {
    final listing = VehicleListing.fromMap({
      'id': '1',
      'seller_id': 's1',
      'listing_type': 'rental',
      'status': 'active',
      'brand': 'Renault',
      'model': 'Clio',
      'year': 2021,
      'gallery_name': 'SECO Otomotiv',
      'gallery_verified': true,
    });
    expect(listing.gallery?.name, 'SECO Otomotiv');
    expect(listing.specs.brand, 'Renault');
  });
}
