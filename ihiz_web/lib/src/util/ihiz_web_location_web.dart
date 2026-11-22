// Web-only helper for the İHIZ URL routes.
//
// The app is single-page and state-driven; this keeps the browser address bar
// in sync for the one shareable route we expose — /admin/login — and supports
// the back/forward buttons. dart:html is safe here because ihiz_web only ever
// builds for web.
//
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

class IhizWebLocation {
  const IhizWebLocation._();

  static const String adminLoginPath = '/admin/login';

  /// True when the current URL points at the admin login route.
  static bool get isAdminLogin {
    final path = html.window.location.pathname ?? '/';
    return path == adminLoginPath || path == '$adminLoginPath/';
  }

  /// Reflect [path] in the address bar without a full page reload.
  static void push(String path) {
    try {
      html.window.history.pushState(null, '', path);
    } catch (_) {
      // Non-fatal: URL sync is a nicety, never break navigation over it.
    }
  }

  /// Fires whenever the user presses back/forward. [isAdminNow] reports whether
  /// the new URL is the admin login route.
  static void onPopState(void Function(bool isAdminNow) handler) {
    html.window.onPopState.listen((_) => handler(isAdminLogin));
  }
}
