import 'dart:convert';

import '../models/mixed_service_order.dart';

/// Operational timestamp for garson order cards (revision / update, not first open).
DateTime? garsonOrderActivityAt(Map<String, dynamic> order) {
  const keys = <String>[
    'last_updated_at',
    'updated_at',
    'last_revision_at',
    'last_printed_at',
    'latest_order_event_at',
    'created_at',
  ];
  for (final key in keys) {
    final parsed = DateTime.tryParse(order[key]?.toString() ?? '');
    if (parsed != null) return parsed.toLocal();
  }
  return null;
}

String garsonOrderTimeAgoLabel(Map<String, dynamic> order) {
  final dt = garsonOrderActivityAt(order);
  if (dt == null) return '-';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Az önce';
  if (diff.inMinutes < 60) return '${diff.inMinutes} dk';
  if (diff.inHours < 24) return '${diff.inHours} sa';
  return '${diff.inDays} gün';
}

int garsonOrderRevision(Map<String, dynamic> order) {
  final parsed = order['revision'] is num
      ? (order['revision'] as num).toInt()
      : int.tryParse(order['revision']?.toString() ?? '');
  if (parsed == null || parsed <= 0) return 1;
  return parsed;
}

String garsonTableOrderIdentity(
  Map<String, dynamic> order, {
  required int fallbackTableNumber,
}) {
  final id = order['id']?.toString().trim() ?? '';
  if (id.isNotEmpty) return 'id:$id';
  final createdAt = order['created_at']?.toString().trim() ?? '';
  final status = order['status']?.toString().trim() ?? '';
  final tableNumber = order['table_number'] is int
      ? order['table_number'] as int
      : int.tryParse(order['table_number']?.toString() ?? '') ??
            fallbackTableNumber;
  final items = jsonEncode(garsonExtractOrderItems(order['items']));
  return 'fallback:$tableNumber|$createdAt|$status|$items';
}

List<Map<String, dynamic>> garsonExtractOrderItems(dynamic raw) {
  dynamic value = raw;
  if (value is String) {
    try {
      value = jsonDecode(value);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map(
        (entry) => MixedServiceOrder.normalizeOrderItem(
          Map<String, dynamic>.from(entry),
        ),
      )
      .toList(growable: false);
}

/// True when [candidate] should win over [incumbent] for the same order id.
bool isGarsonTableOrderNewer(
  Map<String, dynamic> candidate,
  Map<String, dynamic> incumbent,
) {
  final revisionDelta =
      garsonOrderRevision(candidate) - garsonOrderRevision(incumbent);
  if (revisionDelta != 0) return revisionDelta > 0;

  final candidateAt = garsonOrderActivityAt(candidate);
  final incumbentAt = garsonOrderActivityAt(incumbent);
  if (candidateAt != null && incumbentAt != null) {
    if (candidateAt.isAfter(incumbentAt)) return true;
    if (candidateAt.isBefore(incumbentAt)) return false;
  }

  final candidateItems = jsonEncode(garsonExtractOrderItems(candidate['items']));
  final incumbentItems = jsonEncode(garsonExtractOrderItems(incumbent['items']));
  return candidateItems != incumbentItems;
}

/// Merges order lists; newer revision / activity wins duplicate identities.
List<Map<String, dynamic>> mergeGarsonTableOrders(
  Iterable<Map<String, dynamic>> sources, {
  required int fallbackTableNumber,
}) {
  final byIdentity = <String, Map<String, dynamic>>{};
  for (final order in sources) {
    final normalized = Map<String, dynamic>.from(order);
    normalized['items'] = garsonExtractOrderItems(normalized['items']);
    normalized['revision'] = garsonOrderRevision(normalized);
    final identity = garsonTableOrderIdentity(
      normalized,
      fallbackTableNumber: fallbackTableNumber,
    );
    final existing = byIdentity[identity];
    if (existing == null || isGarsonTableOrderNewer(normalized, existing)) {
      byIdentity[identity] = normalized;
    }
  }
  final merged = byIdentity.values.toList(growable: false);
  merged.sort((a, b) {
    final left = garsonOrderActivityAt(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final right = garsonOrderActivityAt(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return right.compareTo(left);
  });
  return merged;
}

/// Applies a server snapshot while keeping newer optimistic rows.
({
  List<Map<String, dynamic>> hydrated,
  List<Map<String, dynamic>> optimisticRemaining,
}) reconcileGarsonTableOrdersAfterSnapshot({
  required List<Map<String, dynamic>> serverSnapshot,
  required List<Map<String, dynamic>> optimisticOrders,
  required int fallbackTableNumber,
}) {
  final normalizedSnapshot = serverSnapshot
      .map((order) => Map<String, dynamic>.from(order))
      .toList(growable: false);
  final optimisticRemaining = optimisticOrders.where((optimistic) {
    final identity = garsonTableOrderIdentity(
      optimistic,
      fallbackTableNumber: fallbackTableNumber,
    );
    final server = normalizedSnapshot.cast<Map<String, dynamic>?>().firstWhere(
      (row) =>
          garsonTableOrderIdentity(
            row!,
            fallbackTableNumber: fallbackTableNumber,
          ) ==
          identity,
      orElse: () => null,
    );
    if (server == null) return true;
    return isGarsonTableOrderNewer(optimistic, server);
  }).toList(growable: false);

  final hydrated = mergeGarsonTableOrders(
    <Map<String, dynamic>>[...normalizedSnapshot, ...optimisticRemaining],
    fallbackTableNumber: fallbackTableNumber,
  );
  return (hydrated: hydrated, optimisticRemaining: optimisticRemaining);
}

/// Ensures submitted payload items win over a stale DB row.
Map<String, dynamic> applyGarsonSubmittedOrderItems({
  required Map<String, dynamic> submittedOrder,
  required List<Map<String, dynamic>> items,
  required int revision,
  required String updatedAt,
}) {
  return <String, dynamic>{
    ...submittedOrder,
    'items': garsonExtractOrderItems(items),
    'revision': revision,
    'updated_at': updatedAt,
  };
}
