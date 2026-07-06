import 'runtime_diagnostic_logger.dart';

/// Sepete ekleme akışı için release-safe, throttled teşhis logları.
///
/// Büyük JSON veya kişisel veri loglanmaz; yalnızca kısa alan/karar sinyalleri.
abstract final class CartAddDiagnostics {
  static int _lastLogMs = 0;

  static void _log(String message) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastLogMs < 800) return;
    _lastLogMs = now;
    RuntimeDiagnosticLogger.products('[CartAdd] $message');
  }

  static String _shortName(String? name) {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return '-';
    return trimmed.length <= 48 ? trimmed : '${trimmed.substring(0, 48)}…';
  }

  static void tap({
    required String source,
    String? productId,
    String? canonicalId,
    String? name,
  }) {
    _log(
      'tap source=$source productId=${productId ?? '-'} '
      'canonicalId=${canonicalId ?? '-'} name=${_shortName(name)}',
    );
  }

  static void appStateAddStart({
    required String productId,
    String? canonicalId,
  }) {
    _log(
      'app_state_add_start productId=$productId '
      'canonicalId=${canonicalId ?? productId}',
    );
  }

  static void validationStart({
    required String productId,
    String? canonicalId,
  }) {
    _log(
      'validation_start productId=$productId '
      'canonicalId=${canonicalId ?? productId}',
    );
  }

  static void dbLookup({
    required String method,
    required List<String> ids,
  }) {
    final preview = ids.take(3).join(',');
    final suffix = ids.length > 3 ? ',…' : '';
    _log('db_lookup method=$method ids=[$preview$suffix]');
  }

  static void dbLookupResult({
    required bool found,
    required int count,
  }) {
    _log('db_lookup_result found=$found count=$count');
  }

  static void validationResult({
    required bool canPurchase,
    required String reason,
    String? message,
  }) {
    final msg = message == null || message.isEmpty ? '-' : message;
    _log(
      'validation_result canPurchase=$canPurchase reason=$reason message=$msg',
    );
  }

  static void productStatus({
    String? status,
    String? approvalStatus,
    String? adminApprovalStatus,
    int? stock,
  }) {
    _log(
      'product_status status=${status ?? '-'} '
      'approvalStatus=${approvalStatus ?? '-'} '
      'adminApprovalStatus=${adminApprovalStatus ?? '-'} '
      'stock=${stock ?? '-'}',
    );
  }

  static void blocked({required String source, required String reason}) {
    _log('blocked source=$source reason=$reason');
  }

  static void success({required String source, required String productId}) {
    _log('success source=$source productId=$productId');
  }

  static void error({required String source, required String message}) {
    _log('error source=$source message=$message');
  }
}
