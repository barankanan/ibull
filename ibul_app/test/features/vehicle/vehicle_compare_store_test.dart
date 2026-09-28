import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/vehicle/domain/vehicle_compare_fields.dart';
import 'package:ibul_app/features/vehicle/domain/vehicle_compare_store.dart';
import 'package:ibul_app/features/vehicle/models/vehicle_enums.dart';
import 'package:ibul_app/features/vehicle/models/vehicle_listing.dart';

VehicleListing _listing(String id, {String brand = 'Toyota'}) {
  return VehicleListing(
    id: id,
    sellerId: 's1',
    listingType: VehicleListingType.sale,
    status: VehicleListingStatus.active,
    specs: VehicleSpecs(brand: brand, model: 'Corolla', year: 2021),
    salePrice: 900000,
    city: 'Hatay',
  );
}

void main() {
  tearDown(VehicleCompareStore.instance.clear);

  test('compare store is vehicle-only and capped at 4', () {
    final store = VehicleCompareStore.instance;
    expect(store.toggle(_listing('1')), isTrue);
    expect(store.toggle(_listing('2')), isTrue);
    expect(store.toggle(_listing('3')), isTrue);
    expect(store.toggle(_listing('4')), isTrue);
    expect(store.toggle(_listing('5')), isFalse);
    expect(
      store.applyToggle(_listing('5')),
      VehicleCompareToggleResult.atLimit,
    );
    expect(store.length, 4);
    expect(store.toggle(_listing('2')), isFalse);
    expect(store.contains('2'), isFalse);
    expect(store.length, 3);
    expect(store.canCompare, isTrue);
  });

  test('compare fields expose brand model price location', () {
    final rows = VehicleCompareFields.rowsFor([_listing('1')]);
    expect(
      rows.map((row) => row.label).toList(),
      containsAll([
        'İlan tipi',
        'Satış fiyatı',
        'Marka',
        'Model',
        'Versiyon',
        'Yıl',
        'Kilometre',
        'Yakıt',
        'Vites',
        'Kasa tipi',
        'Motor hacmi',
        'Motor gücü',
        'Çekiş',
        'Renk',
        'Araç durumu',
        'Konum',
        'Tramer',
        'Takas',
        'Kiralama durumu',
        'Günlük fiyat',
        'Haftalık fiyat',
        'Aylık fiyat',
        'Depozito',
        'Minimum kiralama süresi',
        'Maksimum kiralama süresi',
        'KM limiti',
        'Garanti',
        'Boya / Değişen',
        'ABS',
      ]),
    );
    expect(rows.first.label, 'İlan tipi');
    expect(rows.first.value(_listing('1')), 'Satılık');
  });
}
