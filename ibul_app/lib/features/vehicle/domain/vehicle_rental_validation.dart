import '../models/vehicle_enums.dart';
import '../models/vehicle_listing.dart';
import 'turkish_national_id.dart';
import 'vehicle_availability.dart';
import 'vehicle_delivery_fee.dart';
import 'vehicle_pricing.dart';

abstract final class VehicleRentalValidation {
  static int ageYears(DateTime birth, {DateTime? now}) {
    final today = now ?? DateTime.now();
    var years = today.year - birth.year;
    final hadBirthday = today.month > birth.month ||
        (today.month == birth.month && today.day >= birth.day);
    if (!hadBirthday) years -= 1;
    return years;
  }

  static int licenseYears(DateTime issued, {DateTime? now}) {
    return ageYears(issued, now: now);
  }

  static String? dates({
    required DateTime pickupAt,
    required DateTime returnAt,
    required VehicleRentalSettings settings,
    required List<VehicleBusyInterval> busy,
  }) {
    if (pickupAt.isBefore(DateTime.now().subtract(const Duration(minutes: 5)))) {
      return 'Geçmiş tarih seçilemez.';
    }
    final days = VehicleRentalPricing.rentalDays(
      pickupAt: pickupAt,
      returnAt: returnAt,
    );
    final duration = VehicleRentalPricing.durationMessage(
      days: days,
      minDays: settings.minDays,
      maxDays: settings.maxDays,
      pickupAt: pickupAt,
    );
    if (duration != null) return duration;
    if (!VehicleAvailability.isFree(
      pickupAt: pickupAt,
      returnAt: returnAt,
      busy: busy,
    )) {
      return 'Bu tarihlerde araç müsait değil.';
    }
    return null;
  }

  static String? pickup({
    required VehicleDeliveryMode mode,
    required String address,
    required VehicleRentalSettings settings,
    double? lat,
    double? lng,
    bool zonesConfigured = true,
    String? quoteError,
  }) {
    if (mode == VehicleDeliveryMode.galleryPickup) return null;
    if (mode == VehicleDeliveryMode.homeDelivery &&
        (!settings.homeDelivery || !zonesConfigured)) {
      return 'Bu araç için adrese teslim hizmeti bulunmuyor.';
    }
    if (mode == VehicleDeliveryMode.mapPoint &&
        (!settings.mapPointDelivery || !zonesConfigured)) {
      return 'Bu araç için farklı teslim noktası kapalı.';
    }
    if (address.trim().length < 8) {
      return 'Teslim adresinizi tamamlayın.';
    }
    if (lat == null || lng == null) {
      return 'Teslim konumunu haritada seçin.';
    }
    if (quoteError != null && quoteError.isNotEmpty) {
      return VehicleDeliveryQuoteError.sanitizeForUi(quoteError);
    }
    return null;
  }

  static String? customer({
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
    required String nationalId,
    required DateTime? birthDate,
    required DateTime? licenseIssued,
    required VehicleRentalSettings settings,
  }) {
    if (firstName.trim().isEmpty || lastName.trim().isEmpty) {
      return 'Ad ve soyad zorunludur.';
    }
    final national = TurkishNationalId.validate(nationalId);
    if (national != null) return national;
    if (phone.trim().length < 10) {
      return 'Geçerli bir telefon girin.';
    }
    if (email.trim().isEmpty || !email.contains('@')) {
      return 'Geçerli bir e-posta girin.';
    }
    if (birthDate == null) {
      return 'Doğum tarihi zorunludur.';
    }
    final minAge = settings.minDriverAge ?? 18;
    final age = ageYears(birthDate);
    if (age < minAge) {
      return 'Bu araç için minimum yaş $minAge. Kiralayan $age yaşında.';
    }
    final minLicense = settings.minLicenseYears ?? 0;
    if (licenseIssued == null) {
      return 'Ehliyet alınma tarihi zorunludur.';
    }
    if (minLicense > 0 && licenseYears(licenseIssued) < minLicense) {
      return 'Bu araç için ehliyet en az $minLicense yıllık olmalıdır.';
    }
    return null;
  }

  static String? documents(Set<VehicleDocumentType> uploaded) {
    const required = {
      VehicleDocumentType.identityFront,
      VehicleDocumentType.identityBack,
      VehicleDocumentType.driverLicenseFront,
      VehicleDocumentType.driverLicenseBack,
    };
    if (!uploaded.containsAll(required)) {
      return 'Ehliyet ve kimlik fotoğraflarını yüklemelisiniz.';
    }
    return null;
  }

  static String friendlyError(Object error, {String? code}) {
    switch (code) {
      case 'document_upload_failed':
        return 'Belge yüklenemedi. Lütfen tekrar deneyin.';
      case 'contract_missing':
      case 'contract_required':
      case 'contract_mismatch':
        return 'Araç kiralama sözleşmesi kabul edilmeden talep gönderilemez.';
      case 'validation_failed':
      case 'invalid_national_id':
        return 'Kiralayan bilgilerini eksiksiz ve doğru girin.';
      case 'rental_create_failed':
      case 'database_function_missing':
        return 'Kiralama talebi oluşturulamadı. Lütfen tekrar deneyin.';
      case 'network_failed':
        return 'Bağlantı hatası. Lütfen tekrar deneyin.';
    }
    final raw = '$error'
        .replaceFirst('Bad state: ', '')
        .replaceFirst('StateError: ', '')
        .replaceFirst('Exception: ', '');
    if (raw.contains('gen_random_bytes') ||
        raw.contains('42883') ||
        raw.contains('PostgrestException')) {
      return 'Kiralama talebi oluşturulamadı. Lütfen tekrar deneyin.';
    }
    if (raw.contains('SocketException') || raw.contains('Failed host lookup')) {
      return 'Bağlantı hatası. Lütfen tekrar deneyin.';
    }
    if (raw.contains('outside [') || raw.contains('duration')) {
      return 'Bu araç için seçilen süre kiralama limitlerinin dışında.';
    }
    if (raw.contains('not available') || raw.contains('Vehicle is not')) {
      return 'Bu tarihlerde araç müsait değil.';
    }
    return VehicleDeliveryQuoteError.sanitizeForUi(raw);
  }
}
