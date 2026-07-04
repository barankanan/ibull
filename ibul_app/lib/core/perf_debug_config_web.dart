import 'dart:html' as html;

bool perfDebugPanelEnabled(bool kDebugMode) {
  if (kDebugMode) return true;
  try {
    final params = Uri.parse(html.window.location.href).queryParameters;
    return params['debugBoot'] == '1' || params['perf'] == '1';
  } catch (_) {
    return false;
  }
}
