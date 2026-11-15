import 'dart:convert';

/// Lines a new waiter send will create.
///
/// An open bill that already contains the same product does not remove them.
/// Quantity, note and variant stay as the waiter entered them. A repeated
/// send is identified by [resolveGarsonSubmitKey], not by these lines.
List<Map<String, dynamic>> garsonNewOrderLines(
  List<Map<String, dynamic>> draft,
) {
  return [
    for (final item in draft) Map<String, dynamic>.from(item),
  ];
}

/// True when the waiter has added at least one line to send.
bool garsonDraftHasNewOrder(List<Map<String, dynamic>> draft) {
  return garsonNewOrderLines(draft).isNotEmpty;
}

/// Extra lines of an order that is already open for editing.
///
/// Used only so leaving an edit does not store that order as a new draft.
/// A new order of the same product does not go through this function.
List<Map<String, dynamic>> garsonDraftLinesBeyond({
  required List<Map<String, dynamic>> draft,
  required List<Map<String, dynamic>> covered,
}) {
  final remaining = <String, int>{};
  for (final item in covered) {
    final key = garsonDraftLineKey(item);
    remaining[key] = (remaining[key] ?? 0) + garsonDraftLineQuantity(item);
  }
  final fresh = <Map<String, dynamic>>[];
  for (final item in draft) {
    final key = garsonDraftLineKey(item);
    final quantity = garsonDraftLineQuantity(item);
    final cover = remaining[key] ?? 0;
    final used = cover < quantity ? cover : quantity;
    remaining[key] = cover - used;
    final extra = quantity - used;
    if (extra <= 0) continue;
    final copy = Map<String, dynamic>.from(item);
    if (extra != quantity) {
      copy['quantity'] = extra;
      final line = _draftLineAmount(item['line_total']);
      if (line != null && quantity > 0) {
        copy['line_total'] = line * extra / quantity;
      }
    }
    fresh.add(copy);
  }
  return fresh;
}

/// The local order key for one waiter send.
///
/// A saved key is reused only when the payload is the same request. After
/// that request is cleared, the next order gets [mintedKey], even when the
/// products match. A different payload while a send is still unverified is
/// blocked instead of becoming a second order.
class GarsonSubmitKeyPlan {
  const GarsonSubmitKeyPlan({
    required this.localOrderId,
    required this.reuse,
    required this.blocked,
  });

  final String? localOrderId;
  final bool reuse;
  final bool blocked;
}

GarsonSubmitKeyPlan resolveGarsonSubmitKey({
  String? savedKey,
  String? savedPayload,
  String? pendingKey,
  String? pendingPayload,
  required String requestPayload,
  required String mintedKey,
}) {
  final saved = savedKey?.trim() ?? '';
  final requestCanon = canonicalGarsonSubmitPayload(requestPayload);
  if (saved.isNotEmpty && savedPayload != null) {
    if (canonicalGarsonSubmitPayload(savedPayload) != requestCanon) {
      return const GarsonSubmitKeyPlan(
        localOrderId: null,
        reuse: false,
        blocked: true,
      );
    }
    return GarsonSubmitKeyPlan(
      localOrderId: saved,
      reuse: true,
      blocked: false,
    );
  }
  final pending = pendingKey?.trim() ?? '';
  if (pending.isNotEmpty &&
      pendingPayload != null &&
      canonicalGarsonSubmitPayload(pendingPayload) == requestCanon) {
    return GarsonSubmitKeyPlan(
      localOrderId: pending,
      reuse: true,
      blocked: false,
    );
  }
  return GarsonSubmitKeyPlan(
    localOrderId: mintedKey,
    reuse: false,
    blocked: false,
  );
}

/// Same cart with a different JSON key order is still the same send.
String canonicalGarsonSubmitPayload(String raw) {
  try {
    return jsonEncode(_sortedJson(jsonDecode(raw)));
  } catch (_) {
    return raw;
  }
}

Object? _sortedJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _sortedJson(value[key]),
    };
  }
  if (value is List) {
    return <Object?>[for (final entry in value) _sortedJson(entry)];
  }
  return value;
}

String garsonDraftLineKey(Map<String, dynamic> item) {
  final productId = (item['product_id'] ?? '').toString().trim();
  final name = (item['name'] ?? '').toString().trim().toLowerCase();
  final note = (item['notes'] ?? item['note'] ?? '').toString().trim();
  return '${productId.isEmpty ? name : productId}|$note';
}

int garsonDraftLineQuantity(Map<String, dynamic> item) {
  final raw = item['quantity'];
  if (raw is int && raw > 0) return raw;
  if (raw is num && raw > 0) return raw.round();
  final parsed = int.tryParse(raw?.toString() ?? '');
  if (parsed != null && parsed > 0) return parsed;
  return 1;
}

double? _draftLineAmount(Object? raw) {
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '');
}
