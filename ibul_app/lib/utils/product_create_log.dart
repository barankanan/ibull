import 'package:flutter/foundation.dart';

/// Ürün ekleme / görsel yükleme akışı için yapılandırılmış debug logları.
void productCreateLog(String stage, {Map<String, Object?>? extra}) {
  if (!kDebugMode) return;
  final suffix = extra == null || extra.isEmpty
      ? ''
      : ' ${extra.entries.map((e) => '${e.key}=${e.value}').join(' ')}';
  debugPrint('[ProductCreate] $stage$suffix');
}

String productCreateErrorMessage(Object error, {bool imagePhase = false}) {
  if (error is UnimplementedError) {
    return imagePhase
        ? 'Görsel yüklenemedi. Lütfen tekrar deneyin.'
        : 'Ürün kaydedilemedi. Lütfen tekrar deneyin.';
  }
  final raw = error.toString();
  if (raw.contains('UnimplementedError')) {
    return imagePhase
        ? 'Görsel yüklenemedi. Lütfen tekrar deneyin.'
        : 'Ürün kaydedilemedi. Lütfen tekrar deneyin.';
  }
  if (raw.contains('Görsel yüklenirken') ||
      raw.contains('Storage upload failed') ||
      raw.contains('product-images')) {
    return 'Görsel yüklenemedi. Lütfen tekrar deneyin.';
  }
  return raw
      .replaceFirst('Exception: ', '')
      .replaceFirst('Ürün eklenirken hata oluştu: ', '')
      .trim();
}
