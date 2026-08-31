class IhizPackageSendInput {
  const IhizPackageSendInput({
    required this.pickupName,
    required this.pickupPhone,
    required this.pickupAddress,
    required this.pickupCity,
    required this.pickupDistrict,
    required this.dropoffName,
    required this.dropoffPhone,
    required this.dropoffAddress,
    required this.dropoffCity,
    required this.dropoffDistrict,
    required this.packageSize,
    this.packageWeight,
    this.notes,
    this.pickupLat,
    this.pickupLng,
    this.dropoffLat,
    this.dropoffLng,
  });

  final String pickupName;
  final String pickupPhone;
  final String pickupAddress;
  final String pickupCity;
  final String pickupDistrict;
  final String dropoffName;
  final String dropoffPhone;
  final String dropoffAddress;
  final String dropoffCity;
  final String dropoffDistrict;
  final String packageSize;
  final double? packageWeight;
  final String? notes;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropoffLat;
  final double? dropoffLng;
}

class IhizPackageSendValidator {
  const IhizPackageSendValidator._();

  static const packageSizes = <String>['small', 'medium', 'large'];

  static String packageSizeLabel(String size) {
    switch (size) {
      case 'small':
        return 'Küçük';
      case 'medium':
        return 'Orta';
      case 'large':
        return 'Büyük';
      default:
        return size;
    }
  }

  static String? validate(IhizPackageSendInput input) {
    if (input.pickupName.trim().isEmpty) {
      return 'Gönderici adı gerekli.';
    }
    if (input.pickupAddress.trim().length < 6) {
      return 'Alınacak adres gerekli.';
    }
    if (input.dropoffName.trim().isEmpty) {
      return 'Alıcı adı gerekli.';
    }
    if (input.dropoffAddress.trim().length < 6) {
      return 'Teslim edilecek adres gerekli.';
    }
    if (!packageSizes.contains(input.packageSize)) {
      return 'Paket boyutu seçin.';
    }
    if (input.packageWeight != null && input.packageWeight! < 0) {
      return 'Paket ağırlığı geçersiz.';
    }
    return null;
  }
}
