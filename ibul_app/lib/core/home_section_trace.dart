import 'package:flutter/foundation.dart';

import 'home_section_trace_stub.dart'
    if (dart.library.html) 'home_section_trace_web.dart' as impl;
import 'web_boot_trace.dart';

abstract final class HomeSectionTraceStage {
  static const homeSectionsBootStarted = 'home_sections_boot_started';
  static const popularSectionStarted = 'popular_section_started';
  static const popularSectionCacheHit = 'popular_section_cache_hit';
  static const popularSectionCacheMiss = 'popular_section_cache_miss';
  static const popularSectionFetchStarted = 'popular_section_fetch_started';
  static const popularSectionFetchCompleted = 'popular_section_fetch_completed';
  static const popularSectionRenderStarted = 'popular_section_render_started';
  static const popularSectionRenderCompleted = 'popular_section_render_completed';
  static const popularSectionEmpty = 'popular_section_empty';
  static const personalizedSectionStarted = 'personalized_section_started';
  static const personalizedSectionCacheHit = 'personalized_section_cache_hit';
  static const personalizedSectionCacheMiss = 'personalized_section_cache_miss';
  static const personalizedSectionFetchStarted =
      'personalized_section_fetch_started';
  static const personalizedSectionFetchCompleted =
      'personalized_section_fetch_completed';
  static const personalizedSectionRenderStarted =
      'personalized_section_render_started';
  static const personalizedSectionRenderCompleted =
      'personalized_section_render_completed';
  static const personalizedSectionEmpty = 'personalized_section_empty';
  static const sectionError = 'section_error';
}

class HomeSectionTraceSnapshot {
  const HomeSectionTraceSnapshot({
    required this.stage,
    required this.sectionName,
    this.elapsedMs,
    this.rawCount,
    this.filteredCount,
    this.renderedCount,
    this.cacheHit,
    this.query,
    this.error,
    this.source,
    this.timestamp,
    this.bootAttemptId,
    this.timeoutMs,
    this.fallbackUsed,
    this.itemCount,
  });

  final String stage;
  final String sectionName;
  final int? elapsedMs;
  final int? rawCount;
  final int? filteredCount;
  final int? renderedCount;
  final bool? cacheHit;
  final String? query;
  final String? error;
  final String? source;
  final String? timestamp;
  final String? bootAttemptId;
  final int? timeoutMs;
  final bool? fallbackUsed;
  final int? itemCount;

  Map<String, dynamic> toJson() => {
        'stage': stage,
        'sectionName': sectionName,
        if (elapsedMs != null) 'elapsedMs': elapsedMs,
        if (rawCount != null) 'rawCount': rawCount,
        if (filteredCount != null) 'filteredCount': filteredCount,
        if (renderedCount != null) 'renderedCount': renderedCount,
        if (itemCount != null) 'itemCount': itemCount,
        if (cacheHit != null) 'cacheHit': cacheHit,
        if (query != null) 'query': query,
        if (error != null) 'error': error,
        if (source != null) 'source': source,
        if (timestamp != null) 'timestamp': timestamp,
        if (bootAttemptId != null) 'bootAttemptId': bootAttemptId,
        if (timeoutMs != null) 'timeoutMs': timeoutMs,
        if (fallbackUsed != null) 'fallbackUsed': fallbackUsed,
      };
}

void traceHomeSection({
  required String stage,
  required String sectionName,
  int? elapsedMs,
  int? rawCount,
  int? filteredCount,
  int? renderedCount,
  bool? cacheHit,
  String? query,
  String? error,
  String? source,
  String? bootAttemptId,
  int? timeoutMs,
  bool? fallbackUsed,
  int? itemCount,
}) {
  final snapshot = HomeSectionTraceSnapshot(
    stage: stage,
    sectionName: sectionName,
    elapsedMs: elapsedMs,
    rawCount: rawCount,
    filteredCount: filteredCount,
    renderedCount: renderedCount,
    itemCount: itemCount ?? rawCount,
    cacheHit: cacheHit,
    query: query,
    error: error,
    source: source,
    timestamp: DateTime.now().toIso8601String(),
    bootAttemptId: bootAttemptId ?? currentWebBootAttemptId,
    timeoutMs: timeoutMs,
    fallbackUsed: fallbackUsed,
  );
  impl.persistHomeSectionTrace(snapshot);
  if (kDebugMode) {
    debugPrint(
      '[HomeSectionTrace][$stage] section=$sectionName '
      'raw=$rawCount filtered=$filteredCount render=$renderedCount '
      'cacheHit=$cacheHit source=$source elapsedMs=$elapsedMs '
      'timeoutMs=$timeoutMs fallbackUsed=$fallbackUsed '
      'bootAttemptId=${snapshot.bootAttemptId} error=$error',
    );
  }
}

/// Records a lazy/home section load outcome without affecting global boot.
void notifyHomeSectionLoadOutcome({
  required String sectionName,
  required String source,
  required String state,
  int? elapsedMs,
  int? itemCount,
  int? renderedCount,
  String? error,
  bool fallbackUsed = false,
  int? timeoutMs,
}) {
  traceHomeSection(
    stage: error == 'timeout' || source == 'timeout'
        ? HomeSectionTraceStage.sectionError
        : (state == 'empty'
            ? '${sectionName}_empty'
            : '${sectionName}_loaded'),
    sectionName: sectionName,
    elapsedMs: elapsedMs,
    rawCount: itemCount,
    renderedCount: renderedCount,
    error: error,
    source: source,
    fallbackUsed: fallbackUsed,
    timeoutMs: timeoutMs,
  );
  if (error == 'timeout' || source == 'timeout') {
    WebBootTraceNotifier.active?.noteSectionTimeout(sectionName);
  }
}

String? readHomeSectionTraceJson() => impl.readHomeSectionTraceJson();

void clearHomeSectionTrace() => impl.clearHomeSectionTrace();
