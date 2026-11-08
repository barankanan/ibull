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

enum TargetTableCloseVerdict { confirmed, notConfirmed }

/// Success requires this table's open `table_orders` and `orders` to be zero
/// and a history row for this session. A failed read, a missing session, or
/// a still-open target is not success. Other tables are not inputs.
TargetTableCloseVerdict judgeTargetTableCloseRead({
  required int? openTableOrders,
  required int? openCustomerOrders,
  required bool? historyMatchesSession,
}) {
  if (openTableOrders == null ||
      openCustomerOrders == null ||
      historyMatchesSession == null) {
    return TargetTableCloseVerdict.notConfirmed;
  }
  if (openTableOrders != 0 || openCustomerOrders != 0) {
    return TargetTableCloseVerdict.notConfirmed;
  }
  if (!historyMatchesSession) return TargetTableCloseVerdict.notConfirmed;
  return TargetTableCloseVerdict.confirmed;
}

bool rowIsTargetCloseSession({
  required int targetTableNumber,
  required String targetSellerId,
  required int rowTableNumber,
  required String rowSellerId,
  String? targetSessionKey,
  String? rowSessionKey,
  bool sessionScoped = false,
}) {
  if (rowTableNumber != targetTableNumber) return false;
  if (rowSellerId.trim() != targetSellerId.trim()) return false;
  if (!sessionScoped) return true;
  final target = targetSessionKey?.trim() ?? '';
  final row = rowSessionKey?.trim() ?? '';
  return target.isNotEmpty && row == target;
}

bool isCloseWriteForbiddenError(Object error) {
  final text = error.toString();
  return text.contains(closeTableRpcUnverifiedMessage) ||
      text.contains(closeTableRpcBlockedMessage);
}

bool furtherCloseWritesAllowed({
  required bool rpcTimedOut,
  required bool writesForbidden,
}) {
  return !rpcTimedOut && !writesForbidden;
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
