import '../../../../services/admin_service.dart';
import 'admin_finance_commission_helper.dart';

/// Satıcı hakediş durum geçiş kuralları.
class SellerPayoutStatusTransition {
  const SellerPayoutStatusTransition._();

  static const Map<String, Set<String>> _allowed = {
    'pending': {'approved', 'disputed', 'cancelled'},
    'approved': {'paid', 'disputed', 'cancelled'},
    'disputed': {'approved', 'cancelled'},
    'paid': {},
    'cancelled': {},
  };

  static bool canTransition(String from, String to) {
    if (from == to) return true;
    return _allowed[from]?.contains(to) ?? false;
  }

  static bool isTerminal(String status) =>
      status == 'paid' || status == 'cancelled';

  static String errorMessage(String from, String to) {
    if (from == 'paid') {
      return 'Ödenmiş hakediş durumu değiştirilemez.';
    }
    if (from == 'cancelled') {
      return 'İptal edilmiş hakediş yenilenemez.';
    }
    return 'Geçersiz durum geçişi: ${AdminFinancePayoutHelper.statusLabel(from)} → ${AdminFinancePayoutHelper.statusLabel(to)}';
  }
}

/// Satıcı hakediş hesabı — canlı order_items snapshot + seller_payouts durum birleşimi.
class AdminFinancePayoutHelper {
  const AdminFinancePayoutHelper._();

  static const double defaultCommissionRate = 0.15;

  /// Teslim/tamamlanma tarihi: delivered/refund item'larda updated_at, yoksa created_at.
  static DateTime itemEventDate(AdminFinanceOrderItem item) {
    if (item.updatedAt != null) {
      return DateTime(
        item.updatedAt!.year,
        item.updatedAt!.month,
        item.updatedAt!.day,
      );
    }
    return DateTime(
      item.createdAt.year,
      item.createdAt.month,
      item.createdAt.day,
    );
  }

  static bool isInPeriod(
    DateTime eventDate,
    DateTime start,
    DateTime endExclusive,
  ) {
    final day = DateTime(eventDate.year, eventDate.month, eventDate.day);
    return !day.isBefore(start) && day.isBefore(endExclusive);
  }

  static String sellerKey(String sellerId, String storeName) =>
      '${sellerId.trim()}|${storeName.trim().toLowerCase()}';

  static String shortSellerId(String sellerId) {
    final id = sellerId.trim();
    if (id.length <= 8) return id;
    return '${id.substring(0, 8)}…';
  }

  static AdminFinancePayoutPeriodSnapshot buildSnapshot({
    required DateTime periodStart,
    required DateTime periodEndExclusive,
    required List<AdminFinanceOrderItem> orderItems,
    required List<SellerPayout> payoutRecords,
    required AdminFinanceCommissionConfig commissionConfig,
    required bool Function(String status) isDelivered,
    required bool Function(String status) isRefund,
    String? statusFilter,
    String? searchQuery,
    double? minAmount,
    List<AdminFinanceStoreEntry> allStores = const [],
  }) {
    final periodEnd = periodEndExclusive.subtract(const Duration(days: 1));
    final bySeller = <String, _SellerAccumulator>{};

    for (final item in orderItems) {
      final delivered = isDelivered(item.status);
      final refund = isRefund(item.status);
      if (!delivered && !refund) continue;

      final eventDate = itemEventDate(item);
      if (!isInPeriod(eventDate, periodStart, periodEndExclusive)) continue;

      final storeName = item.storeName.trim().isNotEmpty
          ? item.storeName.trim()
          : 'Bilinmeyen mağaza';
      final key = sellerKey(item.sellerId, storeName);
      final acc = bySeller.putIfAbsent(
        key,
        () => _SellerAccumulator(
          sellerId: item.sellerId,
          storeName: storeName,
        ),
      );

      if (delivered) {
        final commission = AdminFinanceCommissionHelper.commissionForItem(
          item: item,
          config: commissionConfig,
        );
        acc.grossAmount += item.totalPrice;
        acc.commissionAmount += commission;
        acc.itemCount++;
        if (item.orderId.isNotEmpty) {
          acc.orderIds.add(item.orderId);
          acc.addOrderRow(
            orderId: item.orderId,
            eventDate: eventDate,
            amount: item.totalPrice,
            commission: commission,
            status: item.status,
            isRefund: false,
          );
        }
      } else if (refund) {
        acc.refundAmount += item.totalPrice;
        acc.itemCount++;
        if (item.orderId.isNotEmpty) {
          acc.orderIds.add(item.orderId);
          acc.addOrderRow(
            orderId: item.orderId,
            eventDate: eventDate,
            amount: item.totalPrice,
            commission: 0,
            status: item.status,
            isRefund: true,
          );
        }
      }
    }

    final recordBySeller = <String, SellerPayout>{};
    for (final record in payoutRecords) {
      if (!_recordMatchesPeriod(record, periodStart, periodEnd)) continue;
      final key = sellerKey(
        record.sellerId,
        record.storeName ?? 'Bilinmeyen mağaza',
      );
      recordBySeller[key] = record;
    }

    final rows = <AdminFinancePayoutSellerRow>[];
    for (final acc in bySeller.values) {
      final key = sellerKey(acc.sellerId, acc.storeName);
      final record = recordBySeller.remove(key);
      final net = acc.grossAmount -
          acc.commissionAmount -
          acc.refundAmount -
          acc.deductionsAmount;
      final status = record?.status ?? 'pending';
      rows.add(
        AdminFinancePayoutSellerRow(
          sellerId: acc.sellerId,
          storeId: record?.storeId ?? acc.sellerId,
          storeName: acc.storeName,
          grossAmount: acc.grossAmount,
          commissionAmount: acc.commissionAmount,
          refundAmount: acc.refundAmount,
          deductionsAmount: acc.deductionsAmount,
          netPayoutAmount: net,
          orderCount: acc.orderIds.length,
          itemCount: acc.itemCount,
          status: status,
          payoutRecordId: record?.id,
          paymentReference: record?.paymentReference,
          paidAt: record?.paidAt,
          approvedAt: record?.approvedAt,
          lastUpdatedAt: record?.updatedAt ?? record?.createdAt,
          orderRows: acc.orderRows,
          note: record?.note,
          hasPeriodActivity: acc.grossAmount > 0 || acc.refundAmount > 0,
        ),
      );
    }

    // DB kaydı var ama dönemde canlı sipariş yoksa yine göster.
    for (final record in recordBySeller.values) {
      if (!_recordMatchesPeriod(record, periodStart, periodEnd)) continue;
      rows.add(
        AdminFinancePayoutSellerRow(
          sellerId: record.sellerId,
          storeId: record.storeId ?? record.sellerId,
          storeName: record.storeName ?? 'Bilinmeyen mağaza',
          grossAmount: record.grossAmount,
          commissionAmount: record.commissionAmount,
          refundAmount: record.refundAmount,
          deductionsAmount: record.deductionsAmount,
          netPayoutAmount: record.netPayoutAmount,
          orderCount: record.orderCount,
          itemCount: record.itemCount,
          status: record.status,
          payoutRecordId: record.id,
          paymentReference: record.paymentReference,
          paidAt: record.paidAt,
          approvedAt: record.approvedAt,
          lastUpdatedAt: record.updatedAt ?? record.createdAt,
          orderRows: const [],
          note: record.note,
          hasPeriodActivity: record.grossAmount > 0 || record.refundAmount > 0,
        ),
      );
    }

    final seenSellerIds = rows.map((row) => row.sellerId.trim()).toSet();
    for (final store in allStores) {
      final sellerId = store.sellerId.trim();
      if (sellerId.isEmpty || seenSellerIds.contains(sellerId)) continue;
      seenSellerIds.add(sellerId);
      rows.add(
        AdminFinancePayoutSellerRow(
          sellerId: sellerId,
          storeId: sellerId,
          storeName: store.storeName,
          grossAmount: 0,
          commissionAmount: 0,
          refundAmount: 0,
          deductionsAmount: 0,
          netPayoutAmount: 0,
          orderCount: 0,
          itemCount: 0,
          status: 'pending',
          orderRows: const [],
          hasPeriodActivity: false,
        ),
      );
    }

    rows.sort((a, b) {
      if (a.hasPeriodActivity != b.hasPeriodActivity) {
        return a.hasPeriodActivity ? -1 : 1;
      }
      final netCompare = b.netPayoutAmount.compareTo(a.netPayoutAmount);
      if (netCompare != 0) return netCompare;
      return a.storeName.toLowerCase().compareTo(b.storeName.toLowerCase());
    });

    final filtered = rows.where((row) {
      if (statusFilter != null &&
          statusFilter.isNotEmpty &&
          row.status != statusFilter) {
        return false;
      }
      if (minAmount != null && row.netPayoutAmount < minAmount) return false;
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        final haystack =
            '${row.storeName} ${row.sellerId}'.toLowerCase();
        if (!haystack.contains(q)) return false;
      }
      return true;
    }).toList(growable: false);

    var pendingPayout = 0.0;
    var paidPayout = 0.0;
    var awaitingApproval = 0;
    var overduePayout = 0.0;
    var periodGmv = 0.0;
    var platformCommission = 0.0;
    final now = DateTime.now();

    for (final row in rows) {
      periodGmv += row.grossAmount;
      platformCommission += row.commissionAmount;
      if (row.status == 'paid') {
        paidPayout += row.netPayoutAmount;
      } else if (row.status != 'cancelled') {
        pendingPayout += row.netPayoutAmount;
        if (row.status == 'pending') awaitingApproval++;
        if (row.status == 'approved') {
          final approvedAt = row.approvedAt;
          if (approvedAt != null &&
              now.difference(approvedAt).inDays >= 7) {
            overduePayout += row.netPayoutAmount;
          }
        }
      }
    }

    final totalNetPayout = rows.fold<double>(
      0,
      (sum, row) =>
          row.status == 'cancelled' ? sum : sum + row.netPayoutAmount,
    );

    return AdminFinancePayoutPeriodSnapshot(
      periodStart: periodStart,
      periodEnd: periodEnd,
      rows: filtered,
      totalNetPayout: totalNetPayout,
      pendingPayout: pendingPayout,
      paidPayout: paidPayout,
      awaitingApprovalCount: awaitingApproval,
      overduePayout: overduePayout,
      periodGmv: periodGmv,
      platformCommission: platformCommission,
    );
  }

  static bool _recordMatchesPeriod(
    SellerPayout record,
    DateTime periodStart,
    DateTime periodEnd,
  ) {
    return !record.periodStart.isAfter(periodEnd) &&
        !record.periodEnd.isBefore(periodStart);
  }

  static String statusLabel(String status) => switch (status) {
    'pending' => 'Bekliyor',
    'approved' => 'Onaylı',
    'paid' => 'Ödendi',
    'disputed' => 'İtirazlı',
    'cancelled' => 'İptal',
    _ => status,
  };
}

class AdminFinancePayoutPeriodSnapshot {
  const AdminFinancePayoutPeriodSnapshot({
    required this.periodStart,
    required this.periodEnd,
    required this.rows,
    required this.totalNetPayout,
    required this.pendingPayout,
    required this.paidPayout,
    required this.awaitingApprovalCount,
    required this.overduePayout,
    required this.periodGmv,
    required this.platformCommission,
  });

  final DateTime periodStart;
  final DateTime periodEnd;
  final List<AdminFinancePayoutSellerRow> rows;
  final double totalNetPayout;
  final double pendingPayout;
  final double paidPayout;
  final int awaitingApprovalCount;
  final double overduePayout;
  final double periodGmv;
  final double platformCommission;
}

class AdminFinancePayoutSellerRow {
  const AdminFinancePayoutSellerRow({
    required this.sellerId,
    required this.storeId,
    required this.storeName,
    required this.grossAmount,
    required this.commissionAmount,
    required this.refundAmount,
    required this.deductionsAmount,
    required this.netPayoutAmount,
    required this.orderCount,
    required this.itemCount,
    required this.status,
    this.payoutRecordId,
    this.paymentReference,
    this.paidAt,
    this.approvedAt,
    this.lastUpdatedAt,
    required this.orderRows,
    this.note,
    this.hasPeriodActivity = true,
  });

  final String sellerId;
  final String storeId;
  final String storeName;
  final double grossAmount;
  final double commissionAmount;
  final double refundAmount;
  final double deductionsAmount;
  final double netPayoutAmount;
  final int orderCount;
  final int itemCount;
  final String status;
  final String? payoutRecordId;
  final String? paymentReference;
  final DateTime? paidAt;
  final DateTime? approvedAt;
  final DateTime? lastUpdatedAt;
  final List<AdminFinancePayoutOrderRow> orderRows;
  final String? note;
  final bool hasPeriodActivity;
}

class AdminFinancePayoutOrderRow {
  const AdminFinancePayoutOrderRow({
    required this.orderId,
    required this.eventDate,
    required this.amount,
    required this.commission,
    required this.payout,
    required this.status,
    required this.isRefund,
  });

  final String orderId;
  final DateTime eventDate;
  final double amount;
  final double commission;
  final double payout;
  final String status;
  final bool isRefund;
}

class _SellerAccumulator {
  _SellerAccumulator({
    required this.sellerId,
    required this.storeName,
  });

  final String sellerId;
  final String storeName;
  double grossAmount = 0;
  double commissionAmount = 0;
  double refundAmount = 0;
  double deductionsAmount = 0;
  int itemCount = 0;
  final Set<String> orderIds = {};
  final List<AdminFinancePayoutOrderRow> orderRows = [];
  final Map<String, AdminFinancePayoutOrderRow> _ordersById = {};

  void addOrderRow({
    required String orderId,
    required DateTime eventDate,
    required double amount,
    required double commission,
    required String status,
    required bool isRefund,
  }) {
    final existing = _ordersById[orderId];
    if (existing == null) {
      final row = AdminFinancePayoutOrderRow(
        orderId: orderId,
        eventDate: eventDate,
        amount: amount,
        commission: commission,
        payout: isRefund ? -amount : amount - commission,
        status: status,
        isRefund: isRefund,
      );
      _ordersById[orderId] = row;
      orderRows.add(row);
      return;
    }
    final merged = AdminFinancePayoutOrderRow(
      orderId: orderId,
      eventDate: eventDate.isAfter(existing.eventDate)
          ? eventDate
          : existing.eventDate,
      amount: existing.amount + amount,
      commission: existing.commission + commission,
      payout: existing.payout + (isRefund ? -amount : amount - commission),
      status: status,
      isRefund: existing.isRefund || isRefund,
    );
    _ordersById[orderId] = merged;
    final index = orderRows.indexWhere((row) => row.orderId == orderId);
    if (index >= 0) orderRows[index] = merged;
  }
}
