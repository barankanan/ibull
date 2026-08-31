class SellerCargoGeocodeSuggestion {
  final String label;
  final double lat;
  final double lng;
  final String province;
  final String district;
  final String category;
  final String placeType;
  final String addressType;

  const SellerCargoGeocodeSuggestion({
    required this.label,
    required this.lat,
    required this.lng,
    required this.province,
    required this.district,
    required this.category,
    required this.placeType,
    required this.addressType,
  });
}
