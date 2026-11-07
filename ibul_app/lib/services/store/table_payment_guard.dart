import 'dart:async';
import 'dart:math' as math;

import '../../models/mixed_service_order.dart';

/// Money and idempotency rules for one open table bill.
///
/// The open bill is the active orders on the table, not the ephemeral
/// client session key. A reopened table page used to mint a new session
/// and ignore partial payments already stored for the same visit.

const int tablePaymentIdempotencyKeyMaxLength = 120;
const Duration tablePaymentOpenBillFallbackWindow = Duration(hours: 18);

enum TablePaymentPlanCode { accept, replay, amount, overpay, idempotency }

class TablePaymentPlan {
  const TablePaymentPlan._({required this.code, this.message, this.existing});

  const TablePaymentPlan.accept() : this._(code: TablePaymentPlanCode.accept);

  const TablePaymentPlan.replay(RecordedTablePayment existing)
    : this._(code: TablePaymentPlanCode.replay, existing: existing);

  const TablePaymentPlan.reject(TablePaymentPlanCode code, String message)
    : this._(code: code, message: message);

  final TablePaymentPlanCode code;
  final String? message;
  final RecordedTablePayment? existing;

  bool get isAccept => code == TablePaymentPlanCode.accept;
  bool get isReplay => code == TablePaymentPlanCode.replay;
  bool get isReject => !isAccept && !isReplay;
}

class RecordedTablePayment {
  const RecordedTablePayment({
    required this.id,
    required this.tableNumber,
    required this.amountKurus,
    required this.createdAt,
    required this.raw,
    this.idempotencyKey,
    this.visitId,
  });

  final String id;
  final int tableNumber;
  final int amountKurus;
  final DateTime createdAt;
  final String? idempotencyKey;
  final String? visitId;
  final Map<String, dynamic> raw;

  factory RecordedTablePayment.fromMap(Map<String, dynamic> map) {
    final createdAt =
        DateTime.tryParse(map['created_at']?.toString() ?? '')?.toUtc() ??
        DateTime.now().toUtc();
    final key = map['idempotency_key']?.toString().trim();
    final rawTable = map['table_number'];
    final tableNumber = rawTable is int
        ? rawTable
        : int.tryParse(rawTable?.toString() ?? '') ?? 0;
    final visit = map['visit_id']?.toString().trim();
    return RecordedTablePayment(
      id: map['id']?.toString() ?? '',
      tableNumber: tableNumber,
      amountKurus: moneyToKurus(map['amount']),
      visitId: visit == null || visit.isEmpty ? null : visit,
      createdAt: createdAt,
      idempotencyKey: key == null || key.isEmpty ? null : key,
      raw: Map<String, dynamic>.from(map),
    );
  }
}

class TablePaymentTurnstile {
  final Map<String, Future<void>> _pending = <String, Future<void>>{};

  Future<T> run<T>(String key, Future<T> Function() action) async {
    while (_pending[key] != null) {
      final current = _pending[key]!;
      try {
        await current;
      } catch (_) {}
      if (identical(_pending[key], current)) {
        _pending.remove(key);
      }
    }
    final done = Completer<void>();
    _pending[key] = done.future;
    try {
      return await action();
    } finally {
      if (identical(_pending[key], done.future)) {
        _pending.remove(key);
      }
      if (!done.isCompleted) {
        done.complete();
      }
    }
  }
}

String newTablePaymentIdempotencyKey() {
  final random = math.Random.secure();
  final time = DateTime.now().toUtc().microsecondsSinceEpoch.toRadixString(16);
  final noise = List<int>.generate(
    8,
    (_) => random.nextInt(256),
  ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return 'pay_$time$noise';
}

int moneyToKurus(Object? value) {
  final amount = _asFiniteDouble(value);
  if (amount == null) return 0;
  return (amount * 100).round();
}

double kurusToMoney(int kurus) => kurus / 100.0;

String formatTablePaymentKurus(int kurus) {
  final sign = kurus < 0 ? '-' : '';
  final absolute = kurus.abs();
  final whole = absolute ~/ 100;
  final fraction = (absolute % 100).toString().padLeft(2, '0');
  return '$sign$whole,$fraction ₺';
}

DateTime? earliestOrderOpenedAt(Iterable<Map<String, dynamic>> orders) {
  DateTime? earliest;
  for (final order in orders) {
    final parsed = DateTime.tryParse(order['created_at']?.toString() ?? '');
    if (parsed == null) continue;
    final utc = parsed.toUtc();
    if (earliest == null || utc.isBefore(earliest)) {
      earliest = utc;
    }
  }
  return earliest;
}

int billKurusForOrders(Iterable<Map<String, dynamic>> orders) {
  var total = 0;
  for (final order in orders) {
    final rawItems = order['items'];
    if (rawItems is! List) continue;
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final normalized = MixedServiceOrder.normalizeOrderItem(
        Map<String, dynamic>.from(raw),
      );
      total += moneyToKurus(MixedServiceOrder.itemLineTotal(normalized));
    }
  }
  return total;
}

List<RecordedTablePayment> paymentsInOpenBill({
  required List<RecordedTablePayment> payments,
  required DateTime? openedAt,
  required DateTime now,
  required bool hasOpenOrders,
  Set<String> openVisitIds = const <String>{},
}) {
  if (!hasOpenOrders) return const <RecordedTablePayment>[];
  final start =
      (openedAt ?? now.toUtc().subtract(tablePaymentOpenBillFallbackWindow))
          .toUtc();
  return payments
      .where((payment) {
        final visit = payment.visitId;
        if (visit != null && visit.isNotEmpty) {
          return openVisitIds.contains(visit);
        }
        return !payment.createdAt.toUtc().isBefore(start);
      })
      .toList(growable: false);
}

TablePaymentPlan planTablePayment({
  required int tableNumber,
  required int billKurus,
  required Object? amount,
  required String idempotencyKey,
  required List<RecordedTablePayment> openBillPayments,
  required List<RecordedTablePayment> idempotencyCandidates,
}) {
  final key = idempotencyKey.trim();
  if (key.isEmpty || key.length > tablePaymentIdempotencyKeyMaxLength) {
    return const TablePaymentPlan.reject(
      TablePaymentPlanCode.idempotency,
      'Ödeme işlemi kimliği geçersiz.',
    );
  }

  for (final payment in idempotencyCandidates) {
    if (payment.idempotencyKey == key) {
      if (payment.tableNumber != tableNumber) {
        return const TablePaymentPlan.reject(
          TablePaymentPlanCode.idempotency,
          'Bu işlem kimliği başka bir masada kullanılmış.',
        );
      }
      return TablePaymentPlan.replay(payment);
    }
  }

  if (_asFiniteDouble(amount) == null) {
    return const TablePaymentPlan.reject(
      TablePaymentPlanCode.amount,
      'Ödeme tutarı geçersiz.',
    );
  }
  final amountKurus = moneyToKurus(amount);
  if (amountKurus <= 0) {
    return const TablePaymentPlan.reject(
      TablePaymentPlanCode.amount,
      'Ödeme tutarı sıfırdan büyük olmalı.',
    );
  }

  final paidKurus = openBillPayments.fold<int>(
    0,
    (sum, payment) => sum + payment.amountKurus,
  );
  final remaining = billKurus - paidKurus;
  final cappedRemaining = remaining < 0 ? 0 : remaining;
  if (amountKurus > cappedRemaining) {
    return TablePaymentPlan.reject(
      TablePaymentPlanCode.overpay,
      'Kalan tutardan fazla ödeme alınamaz. Kalan: ${formatTablePaymentKurus(cappedRemaining)}',
    );
  }
  return const TablePaymentPlan.accept();
}

double? _asFiniteDouble(Object? value) {
  if (value is num) {
    final amount = value.toDouble();
    if (!amount.isFinite) return null;
    return amount;
  }
  final parsed = double.tryParse(value?.toString().trim() ?? '');
  if (parsed == null || !parsed.isFinite) return null;
  return parsed;
}
