import 'dart:convert';

import 'package:flutter/foundation.dart';

String _readText(Object? value) => value?.toString().trim() ?? '';

int _readPositiveInt(Object? value, {int fallback = 0}) {
  final parsed = value is num
      ? value.toInt()
      : int.tryParse(value?.toString().trim() ?? '');
  if (parsed == null || parsed <= 0) return fallback;
  return parsed;
}

String buildKitchenItemsHash(List<Map<String, dynamic>> items) {
  if (items.isEmpty) return 'no_items';
  final normalized = items.map((item) {
    final source = Map<String, dynamic>.from(item);
    return <String, Object?>{
      'product_id': _readText(source['product_id']),
      'name': _readText(source['name']),
      'display_label': _readText(source['display_label']),
      // LAN/hub payloads may use qty or quantity.
      'quantity': _readPositiveInt(
        source['quantity'] ?? source['qty'],
        fallback: 1,
      ),
      'station_id': _readText(source['station_id']),
      'station_name': _readText(source['station_name']),
      'amount_label': _readText(source['amount_label']),
      'note': _readText(source['note']),
    };
  }).toList(growable: false)
    ..sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b)));
  return jsonEncode(normalized);
}

/// Logical kitchen ticket identity shared by LAN (`lan-*`) and hub (DB UUID).
///
/// Intentionally omits `order_id` so both paths collide on the same key.
String buildKitchenLogicalPrintKey({
  required String restaurantId,
  required String tableNumber,
  required String stationId,
  required String stationName,
  required int revision,
  required List<Map<String, dynamic>> items,
}) {
  final resolvedStationId = stationId.trim();
  final resolvedStationName = stationName.trim().toLowerCase();
  final stationKey = resolvedStationId.isNotEmpty
      ? resolvedStationId
      : (resolvedStationName.isNotEmpty ? resolvedStationName : 'general');
  final itemsHash = buildKitchenItemsHash(items);
  return 'logical:${[
    restaurantId.trim(),
    tableNumber.trim(),
    stationKey,
    revision.toString(),
    itemsHash,
  ].join('|')}';
}

String buildKitchenLogicalPrintKeyFromPayload({
  required String restaurantId,
  required Map<String, dynamic> payload,
  Map<String, dynamic>? job,
}) {
  final rawItems = payload['items'];
  final items = rawItems is List
      ? rawItems
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: false)
      : const <Map<String, dynamic>>[];
  final revision = _readPositiveInt(
    payload['revision'] ?? job?['revision'] ?? payload['order_revision'],
    fallback: 1,
  );
  return buildKitchenLogicalPrintKey(
    restaurantId: restaurantId,
    tableNumber: _readText(
      payload['table_number'] ??
          payload['table_no'] ??
          payload['display_table_label'] ??
          payload['table_name'],
    ),
    stationId: _readText(
      job?['station_id'] ?? payload['station_id'],
    ),
    stationName: _readText(
      payload['station_name'] ?? payload['kitchen_ticket_header'],
    ),
    revision: revision,
    items: items,
  );
}

/// Sync in-process barrier: LAN success remembers logical keys so hub/fallback
/// can skip physical reprint without any network round-trip.
class KitchenLanPrintBarrier {
  KitchenLanPrintBarrier._();

  static final Map<String, DateTime> _recent = <String, DateTime>{};
  static final Set<String> _durablePrinted = <String>{};
  static const Duration _ttl = Duration(seconds: 90);

  static void remember(String logicalKey) {
    final key = logicalKey.trim();
    if (key.isEmpty) return;
    _purge();
    _recent[key] = DateTime.now();
  }

  /// Survives the 90s race window. A timeout is not stored here.
  /// Process restart reloads this set from the local order queue.
  static void rememberDurable(String logicalKey) {
    final key = logicalKey.trim();
    if (key.isEmpty) return;
    _durablePrinted.add(key);
  }

  static bool alreadyPrinted(String logicalKey) {
    final key = logicalKey.trim();
    if (key.isEmpty) return false;
    if (_durablePrinted.contains(key)) return true;
    _purge();
    return _recent.containsKey(key);
  }

  static void _purge() {
    if (_recent.isEmpty) return;
    final cutoff = DateTime.now().subtract(_ttl);
    _recent.removeWhere((_, at) => at.isBefore(cutoff));
  }

  @visibleForTesting
  static void clearForTest() {
    _recent.clear();
    _durablePrinted.clear();
  }
}

void logPrintDedup({
  required String source,
  String orderId = '-',
  String printJobId = '-',
  String jobId = '-',
  String logicalPrintKey = '-',
  String claim = '-',
  String claimResult = '-',
  bool alreadyProcessed = false,
  bool physicalPrintStarted = false,
  bool physicalPrintCompleted = false,
  bool duplicate = false,
  String skipReason = '-',
}) {
  debugPrint(
    'PRINT_DEDUP '
    'order_id=$orderId '
    'print_job_id=$printJobId '
    'logical_print_key=$logicalPrintKey '
    'job_id=$jobId '
    'source=$source '
    'claim=$claim '
    'claim_result=$claimResult '
    'already_processed=$alreadyProcessed '
    'physical_print_started=$physicalPrintStarted '
    'physical_print_completed=$physicalPrintCompleted '
    'duplicate=$duplicate '
    'skip_reason=$skipReason',
  );
}

String buildKitchenPrintIdempotencyKey({
  required String restaurantId,
  required String orderId,
  required String stationId,
  required String stationName,
  required int revision,
  required List<Map<String, dynamic>> items,
}) {
  final resolvedStationId = stationId.trim();
  final resolvedStationName = stationName.trim().toLowerCase();
  final stationKey = resolvedStationId.isNotEmpty
      ? resolvedStationId
      : (resolvedStationName.isNotEmpty ? resolvedStationName : 'general');
  final itemsHash = buildKitchenItemsHash(items);
  return [
    restaurantId.trim(),
    orderId.trim(),
    stationKey,
    revision.toString(),
    itemsHash,
  ].join('|');
}

String kitchenPrintIdempotencyKeyFromJob({
  required String restaurantId,
  required Map<String, dynamic> job,
  required Map<String, dynamic> payload,
}) {
  final rawItems = payload['items'];
  final items = rawItems is List
      ? rawItems
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: false)
      : const <Map<String, dynamic>>[];
  final revision = _readPositiveInt(
    payload['revision'] ?? job['revision'] ?? payload['order_revision'],
    fallback: 1,
  );
  return buildKitchenPrintIdempotencyKey(
    restaurantId: restaurantId,
    orderId: _readText(job['order_id']).isNotEmpty
        ? _readText(job['order_id'])
        : _readText(payload['order_id']),
    stationId: _readText(job['station_id']).isNotEmpty
        ? _readText(job['station_id'])
        : _readText(payload['station_id']),
    stationName: _readText(payload['station_name']).isNotEmpty
        ? _readText(payload['station_name'])
        : _readText(payload['kitchen_ticket_header']),
    revision: revision,
    items: items,
  );
}

/// Text beside the Garson label. Job title wins. An empty title uses the name.
/// Callers must not put this string into an idempotency or queue key.
String kitchenTicketGarsonLabel({String? waiterTitle, String? waiterName}) {
  final title = waiterTitle?.trim() ?? '';
  if (title.isNotEmpty) return title;
  return waiterName?.trim() ?? '';
}

({
  List<String> primaryJobIds,
  Map<String, String> duplicateOfByJobId,
}) dedupeKitchenJobIdsByKey(Map<String, String> keysByJobId) {
  final primaryJobIds = <String>[];
  final duplicateOfByJobId = <String, String>{};
  final ownerByKey = <String, String>{};
  for (final entry in keysByJobId.entries) {
    final jobId = entry.key.trim();
    final key = entry.value.trim();
    if (jobId.isEmpty) continue;
    if (key.isEmpty) {
      primaryJobIds.add(jobId);
      continue;
    }
    final existing = ownerByKey[key];
    if (existing == null) {
      ownerByKey[key] = jobId;
      primaryJobIds.add(jobId);
      continue;
    }
    duplicateOfByJobId[jobId] = existing;
  }
  return (
    primaryJobIds: primaryJobIds,
    duplicateOfByJobId: duplicateOfByJobId,
  );
}

/// Physical bytes may start only when the service is open and this revision
/// was not already sent or left uncertain. A later pause write is not the gate.
bool kitchenJobMayStartPhysicalPrint({
  required bool printSystemEnabled,
  required bool suppressPhysicalPrint,
  String? localPrintStatus,
}) {
  if (!printSystemEnabled || suppressPhysicalPrint) return false;
  switch ((localPrintStatus ?? '').trim()) {
    case 'printed':
    case 'forwarded':
    case 'uncertain':
      return false;
    default:
      return true;
  }
}

class KitchenFastDispatchReport {
  const KitchenFastDispatchReport({
    required this.printedJobIds,
    required this.failedJobIds,
    required this.unclaimedJobIds,
    required this.closedWithoutPrintJobIds,
    required this.claimWaveMs,
  });

  final List<String> printedJobIds;
  final List<String> failedJobIds;
  final List<String> unclaimedJobIds;
  final List<String> closedWithoutPrintJobIds;
  final int claimWaveMs;
}

Future<KitchenFastDispatchReport> runKitchenFastDispatch({
  required List<String> jobIds,
  required Future<bool> Function(String id) claim,
  required Future<bool> Function(String id) prepare,
  required bool Function(String id) alreadyPrinted,
  required Future<void> Function(String id) markPrinting,
  required Future<bool> Function(String id) printTcp,
  required Future<void> Function(String id) markCompleted,
  required Future<void> Function(String id, Object error) markFailed,
  Map<String, bool> claimedAhead = const <String, bool>{},
  int claimAheadMs = 0,
}) async {
  final claimWatch = Stopwatch()..start();
  final claims = await Future.wait(jobIds.map((id) async {
    if (claimedAhead.containsKey(id)) {
      return MapEntry(id, claimedAhead[id]!);
    }
    return MapEntry(id, await claim(id));
  }));
  final claimWaveMs = claimedAhead.length == jobIds.length
      ? claimAheadMs
      : claimWatch.elapsedMilliseconds;
  final claimedById = Map<String, bool>.fromEntries(claims);
  await Future.wait(jobIds.map((id) async {
    if (claimedById[id] != true || alreadyPrinted(id)) return;
    await prepare(id);
  }));

  final printed = <String>[];
  final failed = <String>[];
  final unclaimed = <String>[];
  final closed = <String>[];
  final background = <Future<void>>[];
  for (final id in jobIds) {
    if (claimedById[id] != true) {
      unclaimed.add(id);
      continue;
    }
    if (alreadyPrinted(id)) {
      closed.add(id);
      background.add(markCompleted(id));
      continue;
    }
    background.add(markPrinting(id));
    final ok = await printTcp(id);
    if (ok) {
      printed.add(id);
      background.add(markCompleted(id));
    } else {
      failed.add(id);
      background.add(markFailed(id, StateError('tcp_failed')));
    }
  }
  await Future.wait(background);
  return KitchenFastDispatchReport(
    printedJobIds: printed,
    failedJobIds: failed,
    unclaimedJobIds: unclaimed,
    closedWithoutPrintJobIds: closed,
    claimWaveMs: claimWaveMs,
  );
}
