class SellerSavedAddress {
  const SellerSavedAddress({
    required this.id,
    required this.sellerId,
    required this.customerName,
    required this.customerPhone,
    required this.city,
    required this.district,
    required this.address,
    this.building = '',
    this.latitude,
    this.longitude,
    this.createdAt,
  });

  final String id;
  final String sellerId;
  final String customerName;
  final String customerPhone;
  final String city;
  final String district;
  final String building;
  final String address;
  final double? latitude;
  final double? longitude;
  final DateTime? createdAt;

  bool get hasCoordinates => latitude != null && longitude != null;

  String get subtitle {
    final parts = <String>[
      if (customerPhone.trim().isNotEmpty) customerPhone.trim(),
      if (city.trim().isNotEmpty) city.trim(),
      if (district.trim().isNotEmpty) district.trim(),
    ];
    return parts.join(' • ');
  }

  String get searchBlob => normalizeSellerSavedAddressSearch(
    [customerName, customerPhone, city, district, building, address].join(' '),
  );

  factory SellerSavedAddress.fromMap(Map<String, dynamic> map) {
    return SellerSavedAddress(
      id: (map['id'] ?? '').toString(),
      sellerId: (map['seller_id'] ?? '').toString(),
      customerName: (map['customer_name'] ?? '').toString().trim(),
      customerPhone: (map['customer_phone'] ?? '').toString().trim(),
      city: (map['city'] ?? '').toString().trim(),
      district: (map['district'] ?? '').toString().trim(),
      building: (map['building'] ?? '').toString().trim(),
      address: (map['address'] ?? '').toString().trim(),
      latitude: _readDouble(map['latitude'] ?? map['lat']),
      longitude: _readDouble(map['longitude'] ?? map['lng']),
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return <String, dynamic>{
      'seller_id': sellerId,
      'customer_name': customerName.trim(),
      'customer_phone': customerPhone.trim(),
      'city': city.trim(),
      'district': district.trim(),
      'building': building.trim().isEmpty ? null : building.trim(),
      'address': address.trim(),
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

String normalizeSellerSavedAddressSearch(String raw) {
  return raw
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('İ', 'i')
      .replaceAll('ş', 's')
      .replaceAll('Ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('Ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('Ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('Ö', 'o')
      .replaceAll('ç', 'c')
      .replaceAll('Ç', 'c')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

List<SellerSavedAddress> filterSellerSavedAddresses(
  List<SellerSavedAddress> addresses,
  String query,
) {
  final needle = normalizeSellerSavedAddressSearch(query);
  if (needle.isEmpty) return List<SellerSavedAddress>.from(addresses);
  return addresses
      .where((address) => address.searchBlob.contains(needle))
      .toList(growable: false);
}

double? _readDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse((value ?? '').toString().trim());
}
