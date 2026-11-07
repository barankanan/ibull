/// Garson-facing text for bill item edits and waiter-request decisions.
///
/// The server denial is final. A generic RLS sentence would hide which grant
/// is missing, so these phrases stay specific.
String? friendlyBillItemEditMessage({
  String? code,
  String? message,
  String? details,
  String? hint,
}) {
  final text = _combined(code: code, message: message, details: details, hint: hint);
  if (text.contains('adisyon düzenleme yetkiniz yok')) {
    return 'Adisyon düzenlenemedi. Bu işlem için Siparişleri Yönet veya Tam Erişim yetkisi gerekir.';
  }
  return null;
}

String? friendlyWaiterRequestDecisionMessage({
  String? code,
  String? message,
  String? details,
  String? hint,
}) {
  final text = _combined(code: code, message: message, details: details, hint: hint);
  if (text.contains('sipariş onaylama yetkiniz yok')) {
    return 'İstek onaylanamadı. Bu işlem için Siparişleri Yönet veya Tam Erişim yetkisi gerekir.';
  }
  return null;
}

/// Maps a `table_orders` mutation error. The bill-edit denial is checked
/// before the generic 42501 path so that phrase is not rewritten.
Exception tableOrderMutationException({
  required String action,
  String? code,
  required String message,
  String? details,
  String? hint,
}) {
  final billEdit = friendlyBillItemEditMessage(
    code: code,
    message: message,
    details: details,
    hint: hint,
  );
  if (billEdit != null) return Exception(billEdit);

  final text = _combined(code: code, message: message, details: details, hint: hint);
  final permissionDenied =
      code == '42501' ||
      text.contains('permission denied') ||
      text.contains('row-level security');
  if (permissionDenied) {
    return Exception(
      '$action yapılamadı. Yetki politikası (RLS) bu işlemi engelliyor.',
    );
  }
  return Exception('$action yapılamadı: $message');
}

String _combined({
  String? code,
  String? message,
  String? details,
  String? hint,
}) {
  return '${code ?? ''} ${message ?? ''} ${details ?? ''} ${hint ?? ''}'
      .toLowerCase();
}
