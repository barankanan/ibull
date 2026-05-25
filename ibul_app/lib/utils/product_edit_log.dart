import 'package:flutter/foundation.dart';

/// Ürün düzenleme yönlendirmesi ve admin onay akışı logları.
void productEditLog(String stage, {Map<String, Object?>? extra}) {
  if (!kDebugMode) return;
  final suffix = extra == null || extra.isEmpty
      ? ''
      : ' ${extra.entries.map((e) => '${e.key}=${e.value}').join(' ')}';
  debugPrint('[ProductEdit] $stage$suffix');
}

void adminProductApprovalLog(String stage, {Map<String, Object?>? extra}) {
  if (!kDebugMode) return;
  final suffix = extra == null || extra.isEmpty
      ? ''
      : ' ${extra.entries.map((e) => '${e.key}=${e.value}').join(' ')}';
  debugPrint('[AdminProductApproval] $stage$suffix');
}

void productVisibilityLog(String stage, {Map<String, Object?>? extra}) {
  if (!kDebugMode) return;
  final suffix = extra == null || extra.isEmpty
      ? ''
      : ' ${extra.entries.map((e) => '${e.key}=${e.value}').join(' ')}';
  debugPrint('[ProductVisibility] $stage$suffix');
}
