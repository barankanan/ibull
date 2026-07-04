import 'dart:convert';
import 'dart:html' as html;

const _storageKey = 'ibul_web_boot_error_v1';

void saveWebBootError({
  required String module,
  required String message,
  String? detail,
}) {
  try {
    html.window.localStorage[_storageKey] = jsonEncode({
      'module': module,
      'message': message,
      'detail': detail,
      'at': DateTime.now().toIso8601String(),
    });
  } catch (_) {}
}

String? readLastWebBootError() {
  try {
    return html.window.localStorage[_storageKey];
  } catch (_) {
    return null;
  }
}

void clearWebBootError() {
  try {
    html.window.localStorage.remove(_storageKey);
  } catch (_) {}
}
