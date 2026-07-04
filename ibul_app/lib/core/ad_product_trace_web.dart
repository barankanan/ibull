import 'dart:convert';
import 'dart:html' as html;

import 'ad_product_trace.dart';

const _storageKey = 'ibul_ad_product_trace_v1';

void persistAdProductTrace(AdProductTraceSnapshot snapshot) {
  try {
    html.window.localStorage[_storageKey] = jsonEncode(snapshot.toJson());
  } catch (_) {}
}

String? readAdProductTraceJson() {
  try {
    return html.window.localStorage[_storageKey];
  } catch (_) {
    return null;
  }
}

void clearAdProductTrace() {
  try {
    html.window.localStorage.remove(_storageKey);
  } catch (_) {}
}
