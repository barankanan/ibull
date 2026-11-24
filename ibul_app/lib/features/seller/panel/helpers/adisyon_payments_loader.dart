import 'dart:async';

import '../../../../models/restaurant_ops_models.dart';

/// Adisyon payment-read state. Three states are never mixed:
/// - `loading`: the read is still inside its deadline.
/// - `readable` with `paid == 0`: the server answered, there are no payments.
/// - not `readable` and not `loading`: the read failed or timed out; the
///   remaining balance must NOT be shown as if payments were zero.
typedef AdisyonPaymentsState = ({double paid, bool readable, bool loading});

const AdisyonPaymentsState adisyonPaymentsLoading = (
  paid: 0,
  readable: false,
  loading: true,
);
const AdisyonPaymentsState adisyonPaymentsUnreadable = (
  paid: 0,
  readable: false,
  loading: false,
);

/// Hard upper bound for the UI spinner, independent of the service timeout.
const Duration adisyonPaymentsDeadline = Duration(seconds: 12);

/// Reads payments once. Always completes within [deadline]; never throws.
/// An unreadable row (missing/non-numeric amount) makes the whole read
/// unreadable instead of silently counting it as zero.
Future<AdisyonPaymentsState> loadAdisyonPayments({
  required Future<List<Map<String, dynamic>>> Function() fetch,
  DateTime? earliestOrderAt,
  Duration deadline = adisyonPaymentsDeadline,
  void Function(Object error)? onError,
}) async {
  try {
    final rows = await fetch().timeout(deadline);
    var paid = 0.0;
    for (final row in rows) {
      final raw = row['amount'];
      final amount = raw is num ? raw.toDouble() : double.tryParse('$raw');
      if (amount == null || amount.isNaN || amount.isInfinite) {
        throw const FormatException('payment amount unreadable');
      }
      final payment = TablePayment.fromMap(row);
      if (earliestOrderAt != null &&
          payment.createdAt.isBefore(
            earliestOrderAt.subtract(const Duration(minutes: 1)),
          )) {
        continue;
      }
      paid += amount;
    }
    return (paid: paid, readable: true, loading: false);
  } catch (error) {
    onError?.call(error);
    return adisyonPaymentsUnreadable;
  }
}
