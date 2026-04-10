import 'package:flutter/foundation.dart';

/// Captures QR launch parameters from [Uri.base] at the very start of [main()],
/// before Flutter's router or Supabase auth can modify [window.location.href].
///
/// Usage:
///   1. Call [QrInitialParams.captureFromUri()] in main(), right after
///      WidgetsFlutterBinding.ensureInitialized() and BEFORE runApp() or any
///      async initialization.
///   2. In QrEntryScreen or _handleTableQrLaunch(), call [QrInitialParams.consume()]
///      to get the params and clear them so they aren't re-used on reload.
class QrInitialParams {
  QrInitialParams._();

  static Map<String, String> _params = const {};

  /// True when the app was launched from a dedicated `/qr` URL.
  /// Set by [captureFromUri] and checked in [MyApp] to render [QrEntryScreen]
  /// directly instead of [HomeWrapper].
  static bool isQrPath = false;

  /// Whether any QR-relevant params were found in the initial URL.
  static bool get hasParams => _params.isNotEmpty;

  /// The captured params map (read-only).
  static Map<String, String> get params => _params;

  /// True after [consume] has been called with non-empty params.
  ///
  /// Used by [HomeScreen._handleTableQrLaunch] to skip the live [Uri.base]
  /// fallback on subsequent [HomeScreen] instances (e.g. the one created after
  /// a seller panel exit) while the /qr URL is still in the browser address
  /// bar. Without this guard, a fresh HomeScreen would re-detect QR intent,
  /// set `_hasHandledQrIntent = true`, block all home-content loading and push
  /// a second BusinessDetailPage — leaving the home body stuck on skeleton
  /// loaders (appears blank).
  static bool everConsumed = false;

  /// Set when the user explicitly leaves a QR-opened flow and the app should
  /// not auto-bootstrap the same QR intent again on the next home route.
  static bool wasResetAfterQrExit = false;

  static String get debugState =>
      'isQrPath=$isQrPath '
      'hasParams=${_params.isNotEmpty} '
      'everConsumed=$everConsumed '
      'wasResetAfterQrExit=$wasResetAfterQrExit';

  static bool get shouldSkipHomeBootstrap =>
      wasResetAfterQrExit || everConsumed;

  /// Captures query parameters from the current [Uri.base] at startup.
  ///
  /// Two URL formats are supported:
  ///   • New path format  — `/qr?seller=X&table=1&token=T`
  ///     Params are read directly from [Uri.base.queryParameters].
  ///   • Legacy hash format — `/#/?table_qr=1&seller=X&table=1&token=T`
  ///     Params are extracted from the URI fragment automatically.
  ///
  /// Safe to call on non-web platforms (no-op).
  static void captureFromUri() {
    if (!kIsWeb) return;
    try {
      final uri = Uri.base;
      wasResetAfterQrExit = false;
      debugPrint('[QR-Bootstrap] START — Uri.base=$uri');
      debugPrint('[QrInitialParams] Raw Uri.base at startup = $uri');
      debugPrint('[QrInitialParams] uri.path              = ${uri.path}');
      debugPrint('[QrInitialParams] uri.queryParameters   = ${uri.queryParameters}');
      debugPrint('[QrInitialParams] uri.fragment          = ${uri.fragment}');

      // ── New format: /qr?seller=...&table=...&token=... ──────────────────
      if (uri.path == '/qr') {
        isQrPath = true;
        _params = Map.unmodifiable(uri.queryParameters);
        debugPrint('[QR-Bootstrap] CAPTURED — source=/qr-path params=$_params $debugState');
        debugPrint('[QrInitialParams] /qr path detected. Captured from queryParameters: $_params');
        return;
      }

      // ── Legacy format: /#/?table_qr=1&seller=...&table=...&token=... ────
      isQrPath = false;
      final params = <String, String>{...uri.queryParameters};

      // Hash-based Flutter web routing stores the route + query inside the
      // fragment, e.g. "#/?table_qr=1&seller=XXXX&table=1&token=TOKEN".
      final fragment = uri.fragment;
      final queryIndex = fragment.indexOf('?');
      if (queryIndex >= 0 && queryIndex + 1 < fragment.length) {
        final query = fragment.substring(queryIndex + 1);
        try {
          // Fragment params win (they are the "real" Flutter route query).
          params.addAll(Uri.splitQueryString(query));
        } catch (_) {}
      }

      _params = Map.unmodifiable(params);
      debugPrint('[QR-Bootstrap] CAPTURED — source=default-route params=$_params $debugState');
      debugPrint('[QrInitialParams] Captured params at startup: $_params');
    } catch (e) {
      debugPrint('[QrInitialParams] Failed to capture initial params: $e');
      _params = const {};
    }
  }

  /// Returns the captured params and CLEARS them so subsequent calls return {}.
  /// Call this exactly once from QrEntryScreen or _handleTableQrLaunch().
  static Map<String, String> consume({String source = 'unknown'}) {
    if (_params.isEmpty) {
      debugPrint('[QR-Bootstrap] SKIPPED — consume source=$source params=empty $debugState');
      return const {};
    }
    final result = _params;
    _params = const {};
    if (result.isNotEmpty) everConsumed = true;
    debugPrint('[QR-Bootstrap] CONSUMED — source=$source params=$result $debugState');
    debugPrint('[QrInitialParams] Consumed params (now cleared): $result');
    return result;
  }

  static void reset({required String source}) {
    final previousParams = _params;
    final previousState = debugState;
    _params = const {};
    isQrPath = false;
    everConsumed = true;
    wasResetAfterQrExit = true;
    debugPrint(
      '[QR-Bootstrap] GLOBAL RESET — source=$source '
      'previousParams=$previousParams previousState=$previousState '
      'nextState=$debugState',
    );
  }
}
