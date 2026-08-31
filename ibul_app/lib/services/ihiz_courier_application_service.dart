import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/ihiz/apply/ihiz_courier_apply_validator.dart';
import '../models/courier_application_data.dart';

enum IhizApplyDocumentSlot {
  driverLicenseFront,
  driverLicenseBack,
  vehicleRegistration,
}

class IhizPickedDocument {
  const IhizPickedDocument({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;

  int get sizeBytes => bytes.lengthInBytes;
}

class IhizUploadedDocumentMeta {
  const IhizUploadedDocumentMeta({
    required this.fileName,
    required this.fileSize,
    required this.publicUrl,
  });

  final String fileName;
  final int fileSize;
  final String publicUrl;
}

class IhizCourierApplicationSubmitInput {
  const IhizCourierApplicationSubmitInput({
    required this.fullName,
    required this.phone,
    required this.tcNumber,
    required this.birthDate,
    required this.licenseType,
    required this.motorType,
    required this.criminalRecord,
    required this.companyType,
    required this.taxNumber,
    required this.city,
    required this.district,
    required this.availability,
    required this.email,
    required this.password,
    required this.note,
    required this.paymentAccountHolder,
    required this.paymentBankName,
    required this.paymentIban,
    required this.driverLicenseFront,
    required this.driverLicenseBack,
    required this.vehicleRegistration,
  });

  final String fullName;
  final String phone;
  final String tcNumber;
  final String birthDate;
  final String licenseType;
  final String motorType;
  final String criminalRecord;
  final String companyType;
  final String taxNumber;
  final String city;
  final String district;
  final String availability;
  final String email;
  final String password;
  final String note;
  final String paymentAccountHolder;
  final String paymentBankName;
  final String paymentIban;
  final IhizPickedDocument driverLicenseFront;
  final IhizPickedDocument driverLicenseBack;
  final IhizPickedDocument vehicleRegistration;
}

/// Gerçek İHIZ kurye başvurusu — ihiz_web `_submitToBackend` ile aynı alanlar.
class IhizCourierApplicationService {
  IhizCourierApplicationService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  static const String documentBucket = 'ihiz-courier-documents';
  static const int maxDocumentBytes = 10 * 1024 * 1024;
  static const Set<String> allowedDocumentExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'pdf',
  };
  static const Set<String> allowedImageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
  };

  final SupabaseClient _client;

  String extensionFromFileName(String fileName) {
    final normalized = fileName.trim().toLowerCase();
    final dotIndex = normalized.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex >= normalized.length - 1) {
      return '';
    }
    return normalized.substring(dotIndex + 1);
  }

  bool isAllowedDocumentName(String fileName, IhizApplyDocumentSlot slot) {
    final extension = extensionFromFileName(fileName);
    if (slot == IhizApplyDocumentSlot.vehicleRegistration) {
      return allowedDocumentExtensions.contains(extension);
    }
    return allowedImageExtensions.contains(extension);
  }

  String mimeTypeForExtension(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  String sanitizePathSegment(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  /// Upsert payload — field isimleri ihiz_web `ihiz_courier_applications` upsert'tan.
  Map<String, dynamic> buildApplicationRow({
    required String userId,
    required IhizCourierApplicationSubmitInput input,
    required IhizUploadedDocumentMeta driverFront,
    required IhizUploadedDocumentMeta driverBack,
    required IhizUploadedDocumentMeta vehicleRegistration,
    required String nowIso,
  }) {
    final email = input.email.trim().toLowerCase();
    final normalizedPaymentIban =
        IhizCourierApplyValidator.normalizedIban(input.paymentIban.trim());
    return {
      'user_id': userId,
      'status': 'pending',
      'full_name': input.fullName.trim(),
      'phone': input.phone.trim(),
      'tc_number': input.tcNumber.trim(),
      'birth_date': input.birthDate.trim(),
      'license_type': input.licenseType.trim(),
      'motor_type': input.motorType.trim(),
      'criminal_record': input.criminalRecord.trim(),
      'company_type': input.companyType.trim(),
      'tax_number': input.taxNumber.trim(),
      'city': input.city.trim(),
      'district': input.district.trim(),
      'availability': input.availability.trim(),
      'email': email,
      'note': input.note.trim(),
      'push_notifications_enabled': true,
      'sound_alerts_enabled': true,
      'night_mode_enabled': false,
      'face_id_enabled': true,
      'payment_account_holder': input.paymentAccountHolder.trim(),
      'payment_bank_name': input.paymentBankName.trim(),
      'payment_iban': normalizedPaymentIban,
      'driver_license_front_file_name': driverFront.fileName,
      'driver_license_front_file_size': driverFront.fileSize,
      'driver_license_front_url': driverFront.publicUrl,
      'driver_license_back_file_name': driverBack.fileName,
      'driver_license_back_file_size': driverBack.fileSize,
      'driver_license_back_url': driverBack.publicUrl,
      'vehicle_registration_file_name': vehicleRegistration.fileName,
      'vehicle_registration_file_size': vehicleRegistration.fileSize,
      'vehicle_registration_url': vehicleRegistration.publicUrl,
      'rejection_reason': null,
      'approved_at': null,
      'updated_at': nowIso,
    };
  }

  String normalizeSubmissionError(Object error) {
    if (error is StorageException) {
      return 'Belge yüklenemedi. Dosyaları kontrol edip tekrar deneyin.';
    }
    if (error is PostgrestException) {
      return 'Başvuru kaydedilemedi. Bilgilerinizi kontrol edip tekrar deneyin.';
    }
    if (error is AuthException) {
      if (error.code == 'user_already_exists') {
        return 'Bu e-posta için hesap zaten var. Şifreyi doğru girerek tekrar deneyin.';
      }
      if (error.code == 'email_address_invalid') {
        return 'Geçerli bir e-posta adresi girin.';
      }
      if (error.code == 'weak_password') {
        return 'Şifre en az 6 karakter olmalı.';
      }
      if (error.code == 'invalid_credentials') {
        return 'Bu e-posta için hesap zaten var. Şifreyi doğru girerek tekrar deneyin.';
      }
    }
    final normalized = error.toString().replaceAll('Exception:', '').trim();
    if (normalized.toLowerCase().contains('postgrest') ||
        normalized.toLowerCase().contains('storageexception') ||
        normalized.toLowerCase().contains('authexception')) {
      return 'Başvuru gönderilirken hata oluştu. Lütfen tekrar deneyin.';
    }
    return normalized.isEmpty
        ? 'Başvuru gönderilirken hata oluştu.'
        : normalized;
  }

  bool isAlreadyRegisteredError(Object error) {
    if (error is AuthException && error.code == 'user_already_exists') {
      return true;
    }
    final text = error.toString().toLowerCase();
    return text.contains('already registered') ||
        text.contains('already exists');
  }

  Future<IhizUploadedDocumentMeta> uploadDocumentToStorage({
    required String userId,
    required String key,
    required IhizPickedDocument document,
  }) async {
    final extension = extensionFromFileName(document.name);
    final safeExtension = extension.isEmpty ? 'bin' : extension;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeFileName = sanitizePathSegment(document.name);
    final objectPath = '$userId/$key-$timestamp-$safeFileName';
    final contentType = mimeTypeForExtension(safeExtension);

    final bucket = _client.storage.from(documentBucket);
    await bucket.uploadBinary(
      objectPath,
      document.bytes,
      fileOptions: FileOptions(contentType: contentType, upsert: true),
    );
    final publicUrl = bucket.getPublicUrl(objectPath);

    return IhizUploadedDocumentMeta(
      fileName: document.name,
      fileSize: document.sizeBytes,
      publicUrl: publicUrl,
    );
  }

  Future<CourierApplicationData> submitApplication(
    IhizCourierApplicationSubmitInput input,
  ) async {
    final nowIso = DateTime.now().toIso8601String();
    final email = input.email.trim().toLowerCase();
    final password = input.password;

    AuthResponse authResponse;
    try {
      authResponse = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': input.fullName.trim()},
      );
    } catch (error) {
      if (!isAlreadyRegisteredError(error)) rethrow;
      authResponse = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    }

    if (_client.auth.currentSession == null) {
      try {
        authResponse = await _client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } catch (_) {
        throw Exception(
          'Hesap oluşturuldu ancak oturum açılamadı. E-posta doğrulamasını tamamlayıp tekrar giriş yapın.',
        );
      }
    }

    final user = authResponse.user ?? _client.auth.currentUser;
    if (user == null) {
      throw Exception('Kullanıcı hesabı oluşturulamadı.');
    }

    final uploadedDriverFront = await uploadDocumentToStorage(
      userId: user.id,
      key: 'driver-license-front',
      document: input.driverLicenseFront,
    );
    final uploadedDriverBack = await uploadDocumentToStorage(
      userId: user.id,
      key: 'driver-license-back',
      document: input.driverLicenseBack,
    );
    final uploadedVehicleRegistration = await uploadDocumentToStorage(
      userId: user.id,
      key: 'vehicle-registration',
      document: input.vehicleRegistration,
    );

    await _client.from('users').upsert({
      'id': user.id,
      'email': email,
      'display_name': input.fullName.trim(),
      'phone': input.phone.trim(),
      'is_ihiz_approved': false,
      'updated_at': nowIso,
    }, onConflict: 'id');

    final row = buildApplicationRow(
      userId: user.id,
      input: input,
      driverFront: uploadedDriverFront,
      driverBack: uploadedDriverBack,
      vehicleRegistration: uploadedVehicleRegistration,
      nowIso: nowIso,
    );

    await _client.from('ihiz_courier_applications').upsert(
      row,
      onConflict: 'user_id',
    );

    final normalizedPaymentIban =
        IhizCourierApplyValidator.normalizedIban(input.paymentIban.trim());

    return CourierApplicationData(
      fullName: input.fullName.trim(),
      phone: input.phone.trim(),
      tcNumber: input.tcNumber.trim(),
      birthDate: input.birthDate.trim(),
      licenseType: input.licenseType.trim(),
      motorType: input.motorType.trim(),
      criminalRecord: input.criminalRecord.trim(),
      companyType: input.companyType.trim(),
      city: input.city.trim(),
      district: input.district.trim(),
      availability: input.availability.trim(),
      email: email,
      note: input.note.trim(),
      pushNotificationsEnabled: true,
      soundAlertsEnabled: true,
      nightModeEnabled: false,
      faceIdEnabled: true,
      paymentAccountHolder: input.paymentAccountHolder.trim(),
      paymentBankName: input.paymentBankName.trim(),
      paymentIban: normalizedPaymentIban,
      driverLicenseFileName: uploadedDriverFront.fileName,
      driverLicenseFileSize: uploadedDriverFront.fileSize,
      driverLicenseFrontFileName: uploadedDriverFront.fileName,
      driverLicenseFrontFileSize: uploadedDriverFront.fileSize,
      driverLicenseBackFileName: uploadedDriverBack.fileName,
      driverLicenseBackFileSize: uploadedDriverBack.fileSize,
      vehicleRegistrationFileName: uploadedVehicleRegistration.fileName,
      vehicleRegistrationFileSize: uploadedVehicleRegistration.fileSize,
    );
  }
}
