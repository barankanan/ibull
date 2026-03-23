part of '../../main.dart';

enum _IhizView { landing, login, apply, dashboard }

enum _DeliveryStage { idle, headingToStore, onTheWay, delivered }

enum _ApplyDocumentSlot {
  driverLicenseFront,
  driverLicenseBack,
  vehicleRegistration,
}

class _ApplyPickedDocument {
  const _ApplyPickedDocument({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;

  int get sizeBytes => bytes.lengthInBytes;
}

class _UploadedDocumentMeta {
  const _UploadedDocumentMeta({
    required this.fileName,
    required this.fileSize,
    required this.publicUrl,
  });

  final String fileName;
  final int fileSize;
  final String publicUrl;
}

class CourierApplicationData {
  const CourierApplicationData({
    required this.fullName,
    required this.phone,
    required this.tcNumber,
    required this.birthDate,
    required this.licenseType,
    required this.motorType,
    required this.criminalRecord,
    required this.companyType,
    required this.city,
    required this.district,
    required this.availability,
    required this.email,
    required this.note,
    this.pushNotificationsEnabled = true,
    this.soundAlertsEnabled = true,
    this.nightModeEnabled = false,
    this.faceIdEnabled = true,
    this.paymentAccountHolder = '',
    this.paymentIban = '',
    this.paymentBankName = '',
    this.driverLicenseFileName = '',
    this.driverLicenseFileSize = 0,
    this.driverLicenseFrontFileName = '',
    this.driverLicenseFrontFileSize = 0,
    this.driverLicenseBackFileName = '',
    this.driverLicenseBackFileSize = 0,
    this.vehicleRegistrationFileName = '',
    this.vehicleRegistrationFileSize = 0,
  });

  final String fullName;
  final String phone;
  final String tcNumber;
  final String birthDate;
  final String licenseType;
  final String motorType;
  final String criminalRecord;
  final String companyType;
  final String city;
  final String district;
  final String availability;
  final String email;
  final String note;
  final bool pushNotificationsEnabled;
  final bool soundAlertsEnabled;
  final bool nightModeEnabled;
  final bool faceIdEnabled;
  final String paymentAccountHolder;
  final String paymentIban;
  final String paymentBankName;
  final String driverLicenseFileName;
  final int driverLicenseFileSize;
  final String driverLicenseFrontFileName;
  final int driverLicenseFrontFileSize;
  final String driverLicenseBackFileName;
  final int driverLicenseBackFileSize;
  final String vehicleRegistrationFileName;
  final int vehicleRegistrationFileSize;

  CourierApplicationData copyWith({
    String? fullName,
    String? phone,
    String? tcNumber,
    String? birthDate,
    String? licenseType,
    String? motorType,
    String? criminalRecord,
    String? companyType,
    String? city,
    String? district,
    String? availability,
    String? email,
    String? note,
    bool? pushNotificationsEnabled,
    bool? soundAlertsEnabled,
    bool? nightModeEnabled,
    bool? faceIdEnabled,
    String? paymentAccountHolder,
    String? paymentIban,
    String? paymentBankName,
    String? driverLicenseFileName,
    int? driverLicenseFileSize,
    String? driverLicenseFrontFileName,
    int? driverLicenseFrontFileSize,
    String? driverLicenseBackFileName,
    int? driverLicenseBackFileSize,
    String? vehicleRegistrationFileName,
    int? vehicleRegistrationFileSize,
  }) {
    return CourierApplicationData(
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      tcNumber: tcNumber ?? this.tcNumber,
      birthDate: birthDate ?? this.birthDate,
      licenseType: licenseType ?? this.licenseType,
      motorType: motorType ?? this.motorType,
      criminalRecord: criminalRecord ?? this.criminalRecord,
      companyType: companyType ?? this.companyType,
      city: city ?? this.city,
      district: district ?? this.district,
      availability: availability ?? this.availability,
      email: email ?? this.email,
      note: note ?? this.note,
      pushNotificationsEnabled:
          pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      soundAlertsEnabled: soundAlertsEnabled ?? this.soundAlertsEnabled,
      nightModeEnabled: nightModeEnabled ?? this.nightModeEnabled,
      faceIdEnabled: faceIdEnabled ?? this.faceIdEnabled,
      paymentAccountHolder: paymentAccountHolder ?? this.paymentAccountHolder,
      paymentIban: paymentIban ?? this.paymentIban,
      paymentBankName: paymentBankName ?? this.paymentBankName,
      driverLicenseFileName:
          driverLicenseFileName ?? this.driverLicenseFileName,
      driverLicenseFileSize:
          driverLicenseFileSize ?? this.driverLicenseFileSize,
      driverLicenseFrontFileName:
          driverLicenseFrontFileName ?? this.driverLicenseFrontFileName,
      driverLicenseFrontFileSize:
          driverLicenseFrontFileSize ?? this.driverLicenseFrontFileSize,
      driverLicenseBackFileName:
          driverLicenseBackFileName ?? this.driverLicenseBackFileName,
      driverLicenseBackFileSize:
          driverLicenseBackFileSize ?? this.driverLicenseBackFileSize,
      vehicleRegistrationFileName:
          vehicleRegistrationFileName ?? this.vehicleRegistrationFileName,
      vehicleRegistrationFileSize:
          vehicleRegistrationFileSize ?? this.vehicleRegistrationFileSize,
    );
  }

  String get locationLabel {
    final cityValue = city.trim();
    final districtValue = district.trim();
    if (cityValue.isEmpty && districtValue.isEmpty) return '';
    if (cityValue.isEmpty) return districtValue;
    if (districtValue.isEmpty) return cityValue;
    return '$districtValue / $cityValue';
  }
}
