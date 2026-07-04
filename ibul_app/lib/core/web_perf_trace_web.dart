import 'dart:convert';
import 'dart:html' as html;

import 'web_perf_trace.dart';

const _storageKey = 'ibul_web_perf_trace_v1';

void persistWebPerfTrace(WebPerfTraceSnapshot snapshot) {
  try {
    html.window.localStorage[_storageKey] = jsonEncode(snapshot.toJson());
  } catch (_) {}
}

String? readWebPerfTraceJson() {
  try {
    return html.window.localStorage[_storageKey];
  } catch (_) {
    return null;
  }
}

void clearWebPerfTrace() {
  try {
    html.window.localStorage.remove(_storageKey);
  } catch (_) {}
}
