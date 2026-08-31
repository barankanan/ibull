import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/seller_saved_address.dart';

void main() {
  SellerSavedAddress address({
    String id = 'a1',
    String sellerId = 'seller-1',
    String name = 'Ayşe Yılmaz',
    String phone = '05551234567',
    String city = 'İstanbul',
    String district = 'Kadıköy',
    String building = 'Mavi Site',
    String detail = 'Moda Cad. No 12',
    double? lat = 40.99,
    double? lng = 29.03,
  }) {
    return SellerSavedAddress(
      id: id,
      sellerId: sellerId,
      customerName: name,
      customerPhone: phone,
      city: city,
      district: district,
      building: building,
      address: detail,
      latitude: lat,
      longitude: lng,
    );
  }

  test('fromMap and toInsertMap keep customer address fields', () {
    final parsed = SellerSavedAddress.fromMap({
      'id': 'id-1',
      'seller_id': 'seller-1',
      'customer_name': '  Mehmet Demir ',
      'customer_phone': '05321234567',
      'city': 'Ankara',
      'district': 'Çankaya',
      'building': 'Güneş Apt',
      'address': 'Tunalı Hilmi 10',
      'latitude': 39.92,
      'longitude': 32.85,
    });

    expect(parsed.customerName, 'Mehmet Demir');
    expect(parsed.hasCoordinates, isTrue);
    expect(parsed.toInsertMap()['seller_id'], 'seller-1');
    expect(parsed.toInsertMap()['building'], 'Güneş Apt');
    expect(parsed.toInsertMap()['latitude'], 39.92);
  });

  test('filter matches name, phone, city, district and address', () {
    final addresses = [
      address(),
      address(
        id: 'a2',
        name: 'Can Kaya',
        phone: '05441112233',
        city: 'İzmir',
        district: 'Bornova',
        building: '',
        detail: 'Kazım Dirik Mah. 5. Sokak',
        lat: null,
        lng: null,
      ),
    ];

    expect(filterSellerSavedAddresses(addresses, 'ayse').single.id, 'a1');
    expect(filterSellerSavedAddresses(addresses, '0555').single.id, 'a1');
    expect(filterSellerSavedAddresses(addresses, 'istanbul').single.id, 'a1');
    expect(filterSellerSavedAddresses(addresses, 'kadikoy').single.id, 'a1');
    expect(filterSellerSavedAddresses(addresses, 'moda').single.id, 'a1');
    expect(filterSellerSavedAddresses(addresses, 'bornova').single.id, 'a2');
    expect(filterSellerSavedAddresses(addresses, '0544').single.id, 'a2');
    expect(filterSellerSavedAddresses(addresses, ''), hasLength(2));
    expect(filterSellerSavedAddresses(addresses, 'yok'), isEmpty);
  });

  test('insert map omits blank building and keeps optional coordinates', () {
    final mapped = address(building: '  ', lat: null, lng: null).toInsertMap();
    expect(mapped['building'], isNull);
    expect(mapped.containsKey('latitude'), isTrue);
    expect(mapped['latitude'], isNull);
  });
}
