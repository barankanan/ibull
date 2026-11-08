/// Decides whether a failed table close or transfer may fall back to a
/// direct write.
///
/// The server denial "Bu restoran için masa işlemi yetkiniz yok." is final.
/// A direct delete or table-number update would repeat the same operation
/// outside the RPC. Older owner-only errors still fall back so an authorized
/// waiter keeps the previous path until the staff-guard migration is applied.
bool isTableOperationPermissionDenied({
  String? code,
  String? message,
  String? details,
  String? hint,
}) {
  final normalizedCode = (code ?? '').trim();
  final text = '${message ?? ''} ${details ?? ''} ${hint ?? ''}'.toLowerCase();
  return normalizedCode == '42501' ||
      text.contains('42501') ||
      text.contains('permission denied') ||
      text.contains('row-level security') ||
      text.contains('yetki politikası') ||
      text.contains('masa işlemi yetkiniz yok') ||
      text.contains('yetkisiz');
}

bool isFinalTableOperationDenial({
  String? code,
  String? message,
  String? details,
  String? hint,
}) {
  final text = '${message ?? ''} ${details ?? ''} ${hint ?? ''}'.toLowerCase();
  return text.contains('masa işlemi yetkiniz yok');
}

bool shouldFallbackToDirectTableWrite({
  String? code,
  String? message,
  String? details,
  String? hint,
}) {
  return !isFinalTableOperationDenial(
    code: code,
    message: message,
    details: details,
    hint: hint,
  );
}

bool isFinalTableOperationDenialError(Object error) {
  return isFinalTableOperationDenial(message: error.toString());
}

const String closeTableRpcBlockedMessage =
    'Masa kapatma BLOCKED. close_table_with_history yok. Masa açık kaldı.';

const String closeTableRpcUnverifiedMessage =
    'Masa kapatma yanıtı belirsiz. Yeni yazma yapılmadı.';

enum CloseTableRpcDecision { accept, readOnly, blocked }

/// A numeric `orders_updated` is the live contract, including zero.
/// A missing function is blocked. Timeout or any other payload is read-only.
CloseTableRpcDecision decideCloseTableRpc({
  required bool functionMissing,
  required bool timedOut,
  required Object? ordersUpdated,
}) {
  if (functionMissing) return CloseTableRpcDecision.blocked;
  if (timedOut || ordersUpdated is! num) return CloseTableRpcDecision.readOnly;
  return CloseTableRpcDecision.accept;
}

bool isCloseTableRpcMissing({
  String? code,
  String? message,
  String? details,
  String? hint,
}) {
  final text = '${message ?? ''} ${details ?? ''} ${hint ?? ''}'.toLowerCase();
  return code == 'PGRST202' ||
      code == '42883' ||
      text.contains('could not find the function') ||
      (text.contains('close_table_with_history') &&
          (text.contains('does not exist') ||
              text.contains('schema cache') ||
              text.contains('could not find')));
}
