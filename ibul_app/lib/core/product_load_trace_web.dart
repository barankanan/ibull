import 'dart:convert';
import 'dart:html' as html;

import 'product_load_trace.dart';

const _storageKey = 'ibul_product_load_trace_v1';

void persistProductLoadTrace(ProductLoadTraceSnapshot snapshot) {
  try {
    html.window.localStorage[_storageKey] = jsonEncode(snapshot.toJson());
  } catch (_) {}
}

String? readProductLoadTraceJson() {
  try {
    return html.window.localStorage[_storageKey];
  } catch (_) {
    return null;
  }
}

void clearProductLoadTrace() {
  try {
    html.window.localStorage.remove(_storageKey);
  } catch (_) {}
}
