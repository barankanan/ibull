import 'package:flutter/foundation.dart';

/// Debug-only performance logging for garson entry, table open, and reprint.
class GarsonPerfTrace {
  GarsonPerfTrace(this.label) : _startedAt = DateTime.now();

  final String label;
  final DateTime _startedAt;
  final Map<String, int> _marksMs = <String, int>{};

  void mark(String key) {
    _marksMs[key] = DateTime.now().difference(_startedAt).inMilliseconds;
  }

  int get elapsedMs => DateTime.now().difference(_startedAt).inMilliseconds;

  void finish({Map<String, Object?> extra = const <String, Object?>{}}) {
    if (!kDebugMode) return;
    final totalMs = elapsedMs;
    final parts = <String>[
      for (final entry in _marksMs.entries) '${entry.key}=${entry.value}ms',
      'totalMs=$totalMs',
      for (final entry in extra.entries)
        if (entry.value != null) '${entry.key}=${entry.value}',
    ];
    debugPrint('[GarsonPerf][$label] ${parts.join(' ')}');
  }
}

void logGarsonPerfEntry({
  required String restaurantId,
  required int totalMs,
  int? tablesFetchMs,
  int? activeOrdersFetchMs,
  int? productsFetchMs,
  int? areasFetchMs,
  bool? usedOfflineCache,
}) {
  if (!kDebugMode) return;
  debugPrint(
    '[GarsonPerf][entry] '
    'restaurantId=$restaurantId '
    'tablesFetchMs=${tablesFetchMs ?? '-'} '
    'activeOrdersFetchMs=${activeOrdersFetchMs ?? '-'} '
    'productsFetchMs=${productsFetchMs ?? '-'} '
    'areasFetchMs=${areasFetchMs ?? '-'} '
    'usedOfflineCache=${usedOfflineCache ?? false} '
    'totalMs=$totalMs',
  );
}

void logGarsonPerfTableOpen({
  required int tableId,
  required bool hasCachedSnapshot,
  required int firstPaintMs,
  int? ordersFetchMs,
  int? productsReadyMs,
  int? totalMs,
}) {
  if (!kDebugMode) return;
  debugPrint(
    '[GarsonPerf][table_open] '
    'tableId=$tableId '
    'hasCachedSnapshot=$hasCachedSnapshot '
    'firstPaintMs=$firstPaintMs '
    'ordersFetchMs=${ordersFetchMs ?? '-'} '
    'productsReadyMs=${productsReadyMs ?? '-'} '
    'totalMs=${totalMs ?? '-'}',
  );
}

void logGarsonPerfReprint({
  String? jobId,
  String? orderId,
  int? tableId,
  int? fetchJobMs,
  int? preparePayloadMs,
  int? resolvePrinterMs,
  int? bridgeMs,
  int? totalMs,
  bool? usedCachedPayload,
}) {
  if (!kDebugMode) return;
  debugPrint(
    '[GarsonPerf][reprint] '
    'jobId=${jobId ?? '-'} '
    'orderId=${orderId ?? '-'} '
    'tableId=${tableId ?? '-'} '
    'fetchJobMs=${fetchJobMs ?? '-'} '
    'preparePayloadMs=${preparePayloadMs ?? '-'} '
    'resolvePrinterMs=${resolvePrinterMs ?? '-'} '
    'bridgeMs=${bridgeMs ?? '-'} '
    'usedCachedPayload=${usedCachedPayload ?? false} '
    'totalMs=${totalMs ?? '-'}',
  );
}
