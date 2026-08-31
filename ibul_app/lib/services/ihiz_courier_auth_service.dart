import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/courier_application_data.dart';

/// İHIZ kurye girişi — ihiz_web `_IhizLoginPage._handleLogin` ile aynı kurallar.
class IhizCourierAuthService {
  IhizCourierAuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const approvedStatus = 'approved';
  static const pendingStatus = 'pending';
  static const rejectedStatus = 'rejected';

  CourierApplicationData applicationDataFromRow(Map<String, dynamic> row) {
    final fullName = (row['full_name'] ?? '').toString();
    return CourierApplicationData(
      fullName: fullName,
      phone: (row['phone'] ?? '').toString(),
      tcNumber: (row['tc_number'] ?? '').toString(),
      birthDate: (row['birth_date'] ?? '').toString(),
      licenseType: (row['license_type'] ?? '').toString(),
      motorType: (row['motor_type'] ?? '').toString(),
      criminalRecord: (row['criminal_record'] ?? '').toString(),
      companyType: (row['company_type'] ?? '').toString(),
      city: (row['city'] ?? '').toString(),
      district: (row['district'] ?? '').toString(),
      availability: (row['availability'] ?? '').toString(),
      email: (row['email'] ?? '').toString(),
      note: (row['note'] ?? '').toString(),
      pushNotificationsEnabled: _asBool(
        row['push_notifications_enabled'],
        fallback: true,
      ),
      soundAlertsEnabled: _asBool(row['sound_alerts_enabled'], fallback: true),
      nightModeEnabled: _asBool(row['night_mode_enabled'], fallback: false),
      faceIdEnabled: _asBool(row['face_id_enabled'], fallback: true),
      paymentAccountHolder: (row['payment_account_holder'] ?? '').toString(),
      paymentIban: (row['payment_iban'] ?? '').toString(),
      paymentBankName: (row['payment_bank_name'] ?? '').toString(),
      driverLicenseFileName:
          (row['driver_license_front_file_name'] ?? '').toString(),
      driverLicenseFileSize: _asInt(row['driver_license_front_file_size']),
      driverLicenseFrontFileName:
          (row['driver_license_front_file_name'] ?? '').toString(),
      driverLicenseFrontFileSize: _asInt(row['driver_license_front_file_size']),
      driverLicenseBackFileName:
          (row['driver_license_back_file_name'] ?? '').toString(),
      driverLicenseBackFileSize: _asInt(row['driver_license_back_file_size']),
      vehicleRegistrationFileName:
          (row['vehicle_registration_file_name'] ?? '').toString(),
      vehicleRegistrationFileSize:
          _asInt(row['vehicle_registration_file_size']),
    );
  }

  String cleanErrorMessage(Object error) {
    final raw = error.toString().replaceAll('Exception:', '').trim();
    if (error is AuthException) {
      if (error.code == 'invalid_credentials') {
        return 'E-posta veya şifre hatalı.';
      }
      if (error.code == 'email_not_confirmed') {
        return 'E-posta hesabı henüz doğrulanmamış.';
      }
    }
    return raw.isEmpty ? 'Giriş sırasında hata oluştu.' : raw;
  }

  /// Onaylı kurye oturumu açar; değilse signOut + Exception.
  Future<CourierApplicationData> signInApprovedCourier({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    await _client.auth.signInWithPassword(
      email: normalizedEmail,
      password: password,
    );
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Kullanıcı oturumu açılamadı.');
    }

    final row = await _client
        .from('ihiz_courier_applications')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();

    if (row == null) {
      await _client.auth.signOut();
      throw Exception(
        'Bu hesap için kayıtlı bir kurye başvurusu bulunamadı.',
      );
    }

    final status = (row['status'] ?? pendingStatus).toString();
    if (status != approvedStatus) {
      await _client.auth.signOut();
      if (status == rejectedStatus) {
        final reason = (row['rejection_reason'] ?? '').toString().trim();
        final suffix = reason.isEmpty ? '' : ' Red nedeni: $reason';
        throw Exception('Başvurunuz reddedildi.$suffix');
      }
      throw Exception(
        'Başvurunuz henüz onaylanmadı. Lütfen admin onayını bekleyin.',
      );
    }

    return applicationDataFromRow(Map<String, dynamic>.from(row));
  }

  Future<CourierApplicationData?> restoreApprovedCourierSession() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final row = await _client
        .from('ihiz_courier_applications')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();
    if (row == null) return null;
    final status = (row['status'] ?? pendingStatus).toString();
    if (status != approvedStatus) return null;
    return applicationDataFromRow(Map<String, dynamic>.from(row));
  }

  Future<void> signOut() => _client.auth.signOut();

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toDouble().toInt();
    return int.tryParse('$value') ?? 0;
  }

  bool _asBool(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = (value ?? '').toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
    return fallback;
  }
}
