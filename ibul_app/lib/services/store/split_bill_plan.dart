import 'dart:math' as math;

import 'table_merge_plan.dart';
import 'table_payment_guard.dart';

const int minEqualSplitPeople = 2;
const int maxEqualSplitPeople = 12;

enum SplitBillCode { ready, noBalance, count, zeroShare, key }

class SplitShare {
  const SplitShare({
    required this.index,
    required this.personCount,
    required this.amountKurus,
    required this.idempotencyKey,
  });

  /// 1-based person index inside this plan.
  final int index;
  final int personCount;
  final int amountKurus;
  final String idempotencyKey;

  String get note => 'Bölünmüş ödeme $index/$personCount';
}

class EqualSplitPlan {
  const EqualSplitPlan({
    required this.code,
    required this.remainingKurus,
    required this.personCount,
    required this.shares,
    this.message,
  });

  final SplitBillCode code;
  final int remainingKurus;
  final int personCount;
  final List<SplitShare> shares;
  final String? message;

  bool get isReady => code == SplitBillCode.ready;
}

/// Remaining open bill after visit-matched and in-window payments.
///
/// Matches `open_table_payment_total`: a payment with `visit_id` counts only
/// when that visit is still open. A payment without `visit_id` counts only
/// from the earliest open order.
int openTableRemainingKurus({
  required Iterable<Map<String, dynamic>> orders,
  required List<RecordedTablePayment> payments,
  DateTime? now,
}) {
  final open = openTableBills(orders);
  if (open.isEmpty) return 0;
  final bill = billKurusForOrders(open);
  final paid = paymentsInOpenBill(
    payments: payments,
    openedAt: earliestOrderOpenedAt(open),
    now: (now ?? DateTime.now()).toUtc(),
    hasOpenOrders: true,
    openVisitIds: openTableVisitIds(open),
  ).fold<int>(0, (sum, payment) => sum + payment.amountKurus);
  final remaining = bill - paid;
  return remaining < 0 ? 0 : remaining;
}

/// Equal shares of [remainingKurus]. The last person receives the leftover
/// kuruş so the shares add up to the remaining bill exactly.
EqualSplitPlan planEqualSplit({
  required int remainingKurus,
  required int personCount,
  required String idempotencyPrefix,
}) {
  final remaining = remainingKurus < 0 ? 0 : remainingKurus;
  if (remaining == 0) {
    return EqualSplitPlan(
      code: SplitBillCode.noBalance,
      remainingKurus: 0,
      personCount: personCount,
      shares: const <SplitShare>[],
      message: 'Bölünecek kalan hesap yok.',
    );
  }
  if (personCount < minEqualSplitPeople || personCount > maxEqualSplitPeople) {
    return EqualSplitPlan(
      code: SplitBillCode.count,
      remainingKurus: remaining,
      personCount: personCount,
      shares: const <SplitShare>[],
      message:
          'Kişi sayısı $minEqualSplitPeople ile $maxEqualSplitPeople arasında olmalı.',
    );
  }

  final prefix = idempotencyPrefix.trim();
  final base = remaining ~/ personCount;
  if (base <= 0) {
    return EqualSplitPlan(
      code: SplitBillCode.zeroShare,
      remainingKurus: remaining,
      personCount: personCount,
      shares: const <SplitShare>[],
      message: 'Kalan tutar bu kadar kişiye bölünemiyor.',
    );
  }

  final shares = <SplitShare>[];
  var allocated = 0;
  for (var index = 1; index <= personCount; index++) {
    final amount = index == personCount ? remaining - allocated : base;
    allocated += amount;
    final key = '$prefix:$index';
    if (prefix.isEmpty || key.length > tablePaymentIdempotencyKeyMaxLength) {
      return EqualSplitPlan(
        code: SplitBillCode.key,
        remainingKurus: remaining,
        personCount: personCount,
        shares: const <SplitShare>[],
        message: 'Ödeme işlemi kimliği geçersiz.',
      );
    }
    shares.add(
      SplitShare(
        index: index,
        personCount: personCount,
        amountKurus: amount,
        idempotencyKey: key,
      ),
    );
  }

  return EqualSplitPlan(
    code: SplitBillCode.ready,
    remainingKurus: remaining,
    personCount: personCount,
    shares: shares,
  );
}

String newSplitIdempotencyPrefix(String sessionKey) {
  final random = math.Random.secure();
  final noise = List<int>.generate(
    4,
    (_) => random.nextInt(256),
  ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  final session = sessionKey.trim();
  final prefix = 'split:${session.isEmpty ? 'oturum' : session}:$noise';
  if (prefix.length + 3 <= tablePaymentIdempotencyKeyMaxLength) {
    return prefix;
  }
  final hash = session.hashCode.toUnsigned(32).toRadixString(16);
  return 'split:$hash:$noise';
}
