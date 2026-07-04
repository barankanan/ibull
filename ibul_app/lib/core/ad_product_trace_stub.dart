import 'dart:convert';

import 'ad_product_trace.dart';

String? _lastTraceJson;

void persistAdProductTrace(AdProductTraceSnapshot snapshot) {
  try {
    _lastTraceJson = jsonEncode(snapshot.toJson());
  } catch (_) {}
}

String? readAdProductTraceJson() => _lastTraceJson;

void clearAdProductTrace() {
  _lastTraceJson = null;
}
