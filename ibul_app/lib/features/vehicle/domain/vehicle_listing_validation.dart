import 'package:flutter/foundation.dart';

import '../models/vehicle_enums.dart';
import '../models/vehicle_wizard_draft.dart';
import 'vehicle_catalog.dart';

class VehiclePublishIssue {
  const VehiclePublishIssue({
    required this.step,
    required this.field,
    required this.message,
  });

  /// Wizard chrome step: 0 İlan, 1 Araç, 2 Teknik, 3 Durum & Donanım,
  /// 4 Fiyat, 5 Fotoğraflar, 6 Önizleme.
  final int step;
  final String field;
  final String message;
}

abstract final class VehicleListingValidator {
  static List<VehiclePublishIssue> validatePublish({
    required VehicleWizardDraft draft,
    required int uploadedPhotoCount,
  }) {
    final issues = <VehiclePublishIssue>[];
    final config = VehicleTypeConfig.of(draft.vehicleClass);

    void requireText(String field, int step, String value, String message) {
      if (config.requiredFields.contains(field) && value.trim().isEmpty) {
        issues.add(
          VehiclePublishIssue(step: step, field: field, message: message),
        );
      }
    }

    requireText('brand', 1, draft.brand, 'Marka seçin.');
    requireText('model', 1, draft.model, 'Model seçin.');
    if (draft.year < VehicleCatalog.minYear ||
        draft.year > VehicleCatalog.maxYear) {
      issues.add(
        const VehiclePublishIssue(
          step: 1,
          field: 'year',
          message: 'Geçerli bir model yılı seçin.',
        ),
      );
    }
    if (config.requiredFields.contains('mileageKm') &&
        (draft.mileageKm == null || draft.mileageKm! < 0)) {
      issues.add(
        const VehiclePublishIssue(
          step: 2,
          field: 'mileageKm',
          message: 'Kilometre girin.',
        ),
      );
    }
    requireText('fuel', 2, draft.fuel ?? '', 'Yakıt tipi seçin.');
    requireText(
      'transmission',
      2,
      draft.transmission ?? '',
      'Vites tipi seçin.',
    );
    if (draft.listingType.allowsSale &&
        (draft.salePrice == null || draft.salePrice! <= 0)) {
      issues.add(
        const VehiclePublishIssue(
          step: 4,
          field: 'salePrice',
          message: 'Geçerli bir satış fiyatı girin.',
        ),
      );
    }
    if (draft.listingType.allowsRental &&
        (draft.rental == null || draft.rental!.dailyPrice <= 0)) {
      issues.add(
        const VehiclePublishIssue(
          step: 4,
          field: 'rental',
          message: 'Kiralık ilan için günlük fiyat girin.',
        ),
      );
    }
    requireText('title', 0, draft.title, 'İlan başlığı girin.');
    if (draft.title.trim().length > VehicleCatalog.titleMax) {
      issues.add(
        const VehiclePublishIssue(
          step: 0,
          field: 'title',
          message: 'Başlık 80 karakteri aşamaz.',
        ),
      );
    }
    if ((draft.description ?? '').trim().isEmpty) {
      issues.add(
        const VehiclePublishIssue(
          step: 0,
          field: 'description',
          message: 'İlan açıklaması girin.',
        ),
      );
    }
    if ((draft.description ?? '').length > VehicleCatalog.descriptionMax) {
      issues.add(
        const VehiclePublishIssue(
          step: 0,
          field: 'description',
          message: 'Açıklama 5000 karakteri aşamaz.',
        ),
      );
    }
    if (uploadedPhotoCount < VehicleCatalog.minPhotos) {
      issues.add(
        VehiclePublishIssue(
          step: 5,
          field: 'photos',
          message:
              'Yayınlamak için en az ${VehicleCatalog.minPhotos} fotoğraf yükleyin.',
        ),
      );
    }
    return issues;
  }

  static List<VehiclePublishIssue> validateStep(
    int step, {
    required VehicleWizardDraft draft,
    required int uploadedPhotoCount,
  }) {
    return validatePublish(
      draft: draft,
      uploadedPhotoCount: uploadedPhotoCount,
    ).where((issue) => issue.step == step).toList(growable: false);
  }
}

abstract final class VehiclePublishErrorMapper {
  static String fromCode(String? code) {
    switch ((code ?? '').trim()) {
      case 'sale_price_required':
        return 'Satış fiyatı girilmeden ilan yayınlanamaz.';
      case 'specs_required':
        return 'Marka, model ve yıl kaydedilmeden ilan yayınlanamaz.';
      case 'rental_settings_required':
        return 'Kiralık ilan için günlük fiyat kaydedilmelidir.';
      case 'photos_required':
        return 'İlana en az bir fotoğraf ekleyin.';
      case 'forbidden':
        return 'Bu ilanı yayınlama yetkiniz yok.';
      case 'auth_required':
        return 'Oturumunuz sona ermiş. Tekrar giriş yapın.';
      case 'invalid_state':
        return 'Bu durumdaki ilan onaya gönderilemez.';
      case 'already_published':
        return 'Bu ilan zaten yayında.';
      case 'update_not_applied':
        return 'Taslak kaydedilemedi.';
      case 'state_drift':
        return 'Taslak kaydedilemedi. Bilgiler doğrulanamadı.';
      case 'hydration_incomplete':
        return 'İlan bilgileri yüklenemedi. Lütfen tekrar deneyin.';
      case 'not_found':
        return 'İlan bulunamadı.';
      case 'reason_required':
        return 'Red nedeni yazılmadan ilan reddedilemez.';
      case 'seller_cannot_publish':
        return 'İlan admin onayından sonra yayınlanır.';
      default:
        return 'İlan yayınlanamadı. Bilgileri kontrol edip tekrar deneyin.';
    }
  }

  static String fromObject(Object error) {
    debugPrint('[vehicle] publish/persist error: $error');
    if (error is VehicleUserFacing) return error.message;
    final text = error.toString();
    if (error is Exception && text.contains('VehicleRepositoryException')) {
      return text.replaceFirst('VehicleRepositoryException: ', '');
    }
    final lowered = text.toLowerCase();
    if (lowered.contains('already_published')) {
      return fromCode('already_published');
    }
    if (lowered.contains('invalid_state')) {
      return fromCode('invalid_state');
    }
    if (lowered.contains('state_drift')) {
      return fromCode('state_drift');
    }
    if (lowered.contains('sale_price_required')) {
      return fromCode('sale_price_required');
    }
    if (lowered.contains('specs_required')) return fromCode('specs_required');
    if (lowered.contains('rental_settings_required')) {
      return fromCode('rental_settings_required');
    }
    if (lowered.contains('photos_required')) return fromCode('photos_required');
    if (lowered.contains('pgrst202') ||
        lowered.contains('could not find the function') ||
        lowered.contains('publish_vehicle_listing')) {
      return 'Yayınlama servisi yanıt vermedi. Taslak kaydedildi; tekrar deneyin.';
    }
    if (lowered.contains('42501') || lowered.contains('row-level security')) {
      return 'Kayıt izni reddedildi. Bu mağaza için yetkiniz yok.';
    }
    if (lowered.contains('23503') || lowered.contains('foreign key')) {
      return 'Galeri mağazası bulunamadı. Satıcı onayını kontrol edin.';
    }
    if (lowered.contains('23502') || lowered.contains('null value')) {
      return 'Zorunlu bir alan eksik. Formu kontrol edin.';
    }
    if (lowered.contains('22p02') || lowered.contains('invalid input')) {
      return 'Gönderilen bilgiler geçersiz. Alanları kontrol edin.';
    }
    if (lowered.contains('42703') ||
        lowered.contains('does not exist') ||
        lowered.contains('hydration_incomplete')) {
      return fromCode('hydration_incomplete');
    }
    return 'İlan kaydedilemedi. Bağlantınızı kontrol edip tekrar deneyin.';
  }

  static String loadFailure(Object error) {
    debugPrint('[vehicle] listing load failed: $error');
    return 'İlan bilgileri yüklenemedi. Lütfen tekrar deneyin.';
  }
}

class VehicleUserFacing implements Exception {
  VehicleUserFacing(this.message, {this.code});
  final String message;
  final String? code;
  @override
  String toString() => message;
}
