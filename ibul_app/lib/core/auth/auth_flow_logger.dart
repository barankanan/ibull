import '../../utils/log_mask_helpers.dart';
import '../ibul_app_mode.dart';
import '../runtime_diagnostic_logger.dart';
import 'ibul_auth_context.dart';

/// Release-safe auth pipeline tracing. Never logs passwords or full emails.
abstract final class AuthFlowLogger {
  static void loginPageOpened({required String type}) {
    RuntimeDiagnosticLogger.auth('[AuthFlow] login_page_opened type=$type');
  }

  static void submitStart({required String type, String? email}) {
    RuntimeDiagnosticLogger.auth(
      '[AuthFlow] submit_start type=$type email=${maskEmail(email)}',
    );
  }

  static void supabaseSignInStart({required String type}) {
    RuntimeDiagnosticLogger.auth('[AuthFlow] supabase_signin_start type=$type');
  }

  static void supabaseSignInSuccess({String? userId}) {
    RuntimeDiagnosticLogger.auth(
      '[AuthFlow] supabase_signin_success userId=${maskSensitiveToken(userId, emptyLabel: '-')}',
    );
  }

  static void supabaseSignInError({String? code, String? message}) {
    RuntimeDiagnosticLogger.auth(
      '[AuthFlow] supabase_signin_error code=${code ?? '-'} message=${message ?? '-'}',
    );
  }

  static void sessionListenerMounted() {
    RuntimeDiagnosticLogger.auth(
      '[AuthFlow] session_listener_mounted appMode=${IbulAppModeRegistry.current.name}',
    );
  }

  static void sessionReceived({String? userId}) {
    RuntimeDiagnosticLogger.auth(
      '[AuthFlow] session_received userId=${maskSensitiveToken(userId, emptyLabel: '-')}',
    );
  }

  static void userProviderUpdated({String? userId}) {
    RuntimeDiagnosticLogger.auth(
      '[AuthFlow] user_provider_updated userId=${maskSensitiveToken(userId, emptyLabel: '-')}',
    );
  }

  static void appStateAuthUpdated({required bool isLoggedIn}) {
    RuntimeDiagnosticLogger.auth(
      '[AuthFlow] app_state_auth_updated isLoggedIn=$isLoggedIn',
    );
  }

  static void redirect({required String target}) {
    RuntimeDiagnosticLogger.auth('[AuthFlow] redirect target=$target');
  }

  static void sellerLoginPageOpened({bool adminMode = false}) {
    RuntimeDiagnosticLogger.auth(
      '[AuthFlow] seller_login_page_opened adminMode=$adminMode',
    );
  }

  static void sellerProfileFetchStart() {
    RuntimeDiagnosticLogger.auth('[AuthFlow] seller_profile_fetch_start');
  }

  static void sellerProfileFetchSuccess({String? sellerId}) {
    RuntimeDiagnosticLogger.auth(
      '[AuthFlow] seller_profile_fetch_success sellerId=${maskSensitiveToken(sellerId, emptyLabel: '-')}',
    );
  }

  static void sellerProfileFetchError({required String message}) {
    RuntimeDiagnosticLogger.auth(
      '[AuthFlow] seller_profile_fetch_error message=$message',
    );
  }

  static void customerSessionApplied({String? userId, IbulAuthContext? context}) {
    RuntimeDiagnosticLogger.auth(
      '[AuthFlow] customer_session_applied userId=${maskSensitiveToken(userId, emptyLabel: '-')} '
      'context=${(context ?? IbulAuthContextService.instance.activeContext).storageValue}',
    );
  }
}
