import 'dart:convert';

import 'home_section_trace.dart';

String? _lastTraceJson;

void persistHomeSectionTrace(HomeSectionTraceSnapshot snapshot) {
  try {
    _lastTraceJson = jsonEncode(snapshot.toJson());
  } catch (_) {}
}

String? readHomeSectionTraceJson() => _lastTraceJson;

void clearHomeSectionTrace() {
  _lastTraceJson = null;
}
