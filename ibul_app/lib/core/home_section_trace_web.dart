// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'dart:convert';

import 'home_section_trace.dart';

const _storageKey = 'ibul_home_section_trace_v1';

void persistHomeSectionTrace(HomeSectionTraceSnapshot snapshot) {
  try {
    html.window.localStorage[_storageKey] = jsonEncode(snapshot.toJson());
  } catch (_) {}
}

String? readHomeSectionTraceJson() {
  try {
    return html.window.localStorage[_storageKey];
  } catch (_) {
    return null;
  }
}

void clearHomeSectionTrace() {
  try {
    html.window.localStorage.remove(_storageKey);
  } catch (_) {}
}
