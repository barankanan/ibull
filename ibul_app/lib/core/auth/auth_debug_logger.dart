import 'package:flutter/foundation.dart';

import 'ibul_auth_context.dart';

/// Debug-only auth flow tracing. No-op in release builds.
class AuthDebugLogger {
  AuthDebugLogger._();

  static void loginStart({
    required String type,
    String? email,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[AuthDebug][login_start] type=$type email=${email ?? '-'}',
    );
  }

  static void loginSuccess({
    required String type,
    String? userId,
    String? role,
    String? storeId,
    IbulAuthContext? activeContext,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[AuthDebug][login_success] type=$type '
      'userId=${userId ?? '-'} role=${role ?? '-'} '
      'storeId=${storeId ?? '-'} '
      'activeContext=${(activeContext ?? IbulAuthContextService.instance.activeContext).storageValue}',
    );
  }

  static void logoutStart({
    required String type,
    String? userId,
    IbulAuthContext? activeContext,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[AuthDebug][logout_start] type=$type '
      'userId=${userId ?? '-'} '
      'activeContext=${(activeContext ?? IbulAuthContextService.instance.activeContext).storageValue}',
    );
  }

  static void logoutFinish({
    required String type,
    required bool hasSupabaseSession,
    required bool customerState,
    required bool sellerState,
    IbulAuthContext? activeContext,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[AuthDebug][logout_finish] type=$type '
      'hasSupabaseSession=$hasSupabaseSession '
      'customerState=$customerState sellerState=$sellerState '
      'activeContext=${(activeContext ?? IbulAuthContextService.instance.activeContext).storageValue}',
    );
  }

  static void customerHeader({
    required bool hasSession,
    required IbulAuthContext activeContext,
    required bool isCustomerSession,
    required bool isSellerSession,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[AuthDebug][customer_header] hasSession=$hasSession '
      'activeContext=${activeContext.storageValue} '
      'isCustomerSession=$isCustomerSession isSellerSession=$isSellerSession',
    );
  }
}
