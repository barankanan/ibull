import '../../../../ads/enums/ad_enums.dart';
import '../../../../ads/helpers/ad_display_labels.dart';
import '../../../../ads/models/ad_campaign.dart';
import '../../../../ads/models/ad_metrics.dart';
import '../../../../ads/models/ad_revenue_record.dart';
import '../../../../ads/models/ad_wallet_transaction.dart';
import '../../../../services/admin_service.dart';
import 'admin_finance_commission_helper.dart';
import 'admin_finance_manual_revenue_helper.dart';

/// Admin Finans sayfası gelir kırılımı — tek kaynak, KPI ve bölümler buradan beslenir.
class AdminFinanceRevenueHelper {
  const AdminFinanceRevenueHelper._();

  static const Set<CampaignStatus> _eligibleAdStatuses = {
    CampaignStatus.approved,
    CampaignStatus.scheduled,
    CampaignStatus.active,
    CampaignStatus.paused,
    CampaignStatus.completed,
    CampaignStatus.stopped,
  };

  static const List<String> _adTypeOrder = [
    'home_feature',
    'product_boost',
    'store_boost',
    'geo_push',
    'collection_boost',
    'coupon_offer',
    'other',
  ];

  static AdminFinancePeriodSnapshot buildSnapshot({
    required DateTime start,
    required DateTime endExclusive,
    required List<AdminFinanceOrderItem> orderItems,
    required List<AdminFinanceOrder> orders,
    required List<AdCampaign> campaigns,
    required List<AdMetrics> metrics,
    required List<AdRevenueRecord> revenueRecords,
    required List<AdWalletTransaction> walletTransactions,
    required AdminFinanceCommissionConfig commissionConfig,
    required bool Function(String status) isDelivered,
    required bool Function(String status) isRefund,
    required bool Function(String deliveryType) isCourierDelivery,
    List<AdminRevenue> manualRevenues = const [],
  }) {
    final orderCore = _computeOrderCore(
      start: start,
      endExclusive: endExclusive,
      orderItems: orderItems,
      orders: orders,
      commissionConfig: commissionConfig,
      isDelivered: isDelivered,
      isRefund: isRefund,
      isCourierDelivery: isCourierDelivery,
    );

    final adBreakdown = _computeAdBreakdown(
      start: start,
      endExclusive: endExclusive,
      campaigns: campaigns,
      metrics: metrics,
      revenueRecords: revenueRecords,
      walletTransactions: walletTransactions,
    );

    final manual = AdminFinanceManualRevenueHelper.computeBreakdown(
      revenues: manualRevenues,
      start: start,
      endExclusive: endExclusive,
    );
    final propertyRentRevenueResolved = manual.propertyRentReceived;
    final otherRevenueResolved = manual.otherManualReceived;
    final cargoNetWithManual =
        orderCore.cargoNetRevenue + manual.cargoAdjustmentReceived;

    final sourceRows = <AdminFinanceRevenueSourceRow>[
      AdminFinanceRevenueSourceRow(
        key: 'commission',
        label: 'Sipariş Komisyonu',
        amount: orderCore.commission,
        hasData: orderCore.commission > 0,
        emptyNote: 'Kayıt yok',
      ),
      AdminFinanceRevenueSourceRow(
        key: 'ad',
        label: 'Reklam Geliri',
        amount: adBreakdown.totalCollected,
        hasData: adBreakdown.totalCollected > 0,
        emptyNote: adBreakdown.usesPlannedBudgetLabel ? 'Planlanan bütçe' : 'Kayıt yok',
        usesPlannedLabel: adBreakdown.usesPlannedBudgetLabel,
      ),
      AdminFinanceRevenueSourceRow(
        key: 'cargo',
        label: 'Kargo Geliri',
        amount: cargoNetWithManual,
        hasData: orderCore.cargoCollection > 0 ||
            orderCore.deliveredPackages > 0 ||
            manual.cargoAdjustmentReceived > 0,
        emptyNote: 'Kayıt yok',
      ),
      AdminFinanceRevenueSourceRow(
        key: 'property',
        label: 'Emlak / Kira Geliri',
        amount: propertyRentRevenueResolved,
        hasData: propertyRentRevenueResolved > 0,
        emptyNote: propertyRentRevenueResolved > 0 ? 'Manuel kayıt' : 'Kayıt yok',
      ),
      AdminFinanceRevenueSourceRow(
        key: 'other',
        label: 'Diğer Gelir',
        amount: otherRevenueResolved,
        hasData: otherRevenueResolved > 0,
        emptyNote: otherRevenueResolved > 0 ? 'Manuel kayıt' : 'Kayıt yok',
      ),
    ];

    final totalIbulRevenue = sourceRows.fold<double>(
      0,
      (sum, row) => sum + row.amount,
    );
    for (var i = 0; i < sourceRows.length; i++) {
      sourceRows[i] = sourceRows[i].copyWithShare(
        totalIbulRevenue == 0 ? 0 : sourceRows[i].amount / totalIbulRevenue,
      );
    }

    return AdminFinancePeriodSnapshot(
      orderCore: orderCore,
      adBreakdown: adBreakdown,
      sourceRows: sourceRows,
      totalIbulRevenue: totalIbulRevenue,
      propertyRentRevenue: propertyRentRevenueResolved,
      otherRevenue: otherRevenueResolved,
      manualCargoAdjustment: manual.cargoAdjustmentReceived,
    );
  }

  static String resolveAdTypeBucket(AdCampaign campaign) {
    if (campaign.metadata['coupon_enabled'] == true) {
      return 'coupon_offer';
    }
    final type = campaign.type.dbValue;
    if (_adTypeOrder.contains(type)) return type;
    return 'other';
  }

  static String adTypeLabel(String bucket) {
    if (bucket == 'other') return 'Diğer Reklam';
    if (bucket == 'coupon_offer') {
      return AdDisplayLabels.campaignTypeLabel('coupon_offer');
    }
    return AdDisplayLabels.campaignTypeLabel(bucket);
  }

  static AdminFinanceOrderCoreMetrics _computeOrderCore({
    required DateTime start,
    required DateTime endExclusive,
    required List<AdminFinanceOrderItem> orderItems,
    required List<AdminFinanceOrder> orders,
    required AdminFinanceCommissionConfig commissionConfig,
    required bool Function(String status) isDelivered,
    required bool Function(String status) isRefund,
    required bool Function(String deliveryType) isCourierDelivery,
  }) {
    var gmv = 0.0;
    var commission = 0.0;
    var refundAmount = 0.0;
    var refundCount = 0;
    final orderIds = <String>{};

    for (final item in orderItems) {
      if (!_inPeriod(item.createdAt, start, endExclusive)) continue;
      if (isDelivered(item.status)) {
        gmv += item.totalPrice;
        commission += AdminFinanceCommissionHelper.commissionForItem(
          item: item,
          config: commissionConfig,
        );
        if (item.orderId.isNotEmpty) orderIds.add(item.orderId);
      } else if (isRefund(item.status)) {
        refundAmount += item.totalPrice;
        refundCount++;
      }
    }

    var cargoCollection = 0.0;
    var cargoCost = 0.0;
    var freeShippingSubsidy = 0.0;
    var deliveredPackages = 0;
    var cargoCommissionRevenue = 0.0;

    for (final order in orders) {
      if (!_inPeriod(order.createdAt, start, endExclusive)) continue;
      if (!isDelivered(order.status) && !isCourierDelivery(order.deliveryType)) {
        continue;
      }
      final collection = order.shippingAmount > 0
          ? order.shippingAmount
          : order.customerDeliveryFee;
      if (collection > 0 || order.totalDeliveryFee > 0) {
        deliveredPackages++;
      }
      cargoCollection += collection;
      cargoCost += order.sellerDeliveryFee;
      if (collection <= 0 && order.totalDeliveryFee > 0) {
        freeShippingSubsidy += order.totalDeliveryFee;
      }
      cargoCommissionRevenue += AdminFinanceCommissionHelper.cargoCommissionForOrder(
        order: order,
        config: commissionConfig,
        isDelivered: isDelivered,
        isCourierDelivery: isCourierDelivery,
      );
    }

    final legacyCargoNet =
        cargoCollection - cargoCost - freeShippingSubsidy;
    final cargoNetRevenue = cargoCommissionRevenue > 0
        ? cargoCommissionRevenue - cargoCost - freeShippingSubsidy
        : legacyCargoNet;
    final completedOrders = orderIds.length;
    final averageBasket =
        completedOrders == 0 ? 0.0 : gmv / completedOrders;

    return AdminFinanceOrderCoreMetrics(
      gmv: gmv,
      commission: commission,
      refundAmount: refundAmount,
      refundCount: refundCount,
      completedOrders: completedOrders,
      averageBasket: averageBasket,
      cargoCollection: cargoCollection,
      cargoCost: cargoCost,
      freeShippingSubsidy: freeShippingSubsidy,
      cargoNetRevenue: cargoNetRevenue,
      deliveredPackages: deliveredPackages,
    );
  }

  static AdminFinanceAdBreakdown _computeAdBreakdown({
    required DateTime start,
    required DateTime endExclusive,
    required List<AdCampaign> campaigns,
    required List<AdMetrics> metrics,
    required List<AdRevenueRecord> revenueRecords,
    required List<AdWalletTransaction> walletTransactions,
  }) {
    final eligible = campaigns.where((campaign) {
      return _eligibleAdStatuses.contains(campaign.status) &&
          _overlapsPeriod(campaign.startsAt, campaign.endsAt, start, endExclusive);
    }).toList(growable: false);

    final eligibleIds = eligible.map((c) => c.id).toSet();
    final byBucket = <String, _AdBucketAccumulator>{};

    for (final bucket in _adTypeOrder) {
      byBucket[bucket] = _AdBucketAccumulator(bucket: bucket);
    }

    for (final campaign in eligible) {
      final bucket = resolveAdTypeBucket(campaign);
      final acc = byBucket.putIfAbsent(
        bucket,
        () => _AdBucketAccumulator(bucket: bucket),
      );
      acc.campaignCount++;
      acc.budgetTotal += campaign.totalBudget;

      final periodRevenue = _campaignPeriodRevenue(
        campaign: campaign,
        start: start,
        endExclusive: endExclusive,
        revenueRecords: revenueRecords,
        walletTransactions: walletTransactions,
        metrics: metrics,
      );
      acc.collectedAmount += periodRevenue.amount;
      acc.spentAmount += periodRevenue.spent;
      if (periodRevenue.amount <= 0 && campaign.totalBudget > 0) {
        acc.usesPlannedLabel = true;
      }
    }

    for (final metric in metrics) {
      if (!eligibleIds.contains(metric.campaignId)) continue;
      if (!_inPeriod(metric.date, start, endExclusive)) continue;
      final campaign = eligible.firstWhere((c) => c.id == metric.campaignId);
      final acc = byBucket[resolveAdTypeBucket(campaign)]!;
      acc.impressions += metric.impressions;
      acc.clicks += metric.clicks;
    }

    final rows = _adTypeOrder
        .map((bucket) => byBucket[bucket]!.toRow())
        .where(
          (row) =>
              row.campaignCount > 0 ||
              row.collectedAmount > 0 ||
              row.spentAmount > 0 ||
              row.impressions > 0,
        )
        .toList(growable: false);

    final totalCollected = rows.fold<double>(
      0,
      (sum, row) => sum + row.collectedAmount,
    );
    final usesPlanned = rows.any(
      (row) => row.usesPlannedLabel && row.collectedAmount <= 0 && row.budgetTotal > 0,
    );

    return AdminFinanceAdBreakdown(
      totalCollected: totalCollected,
      usesPlannedBudgetLabel: usesPlanned && totalCollected <= 0,
      rows: rows,
    );
  }

  static _CampaignPeriodRevenue _campaignPeriodRevenue({
    required AdCampaign campaign,
    required DateTime start,
    required DateTime endExclusive,
    required List<AdRevenueRecord> revenueRecords,
    required List<AdWalletTransaction> walletTransactions,
    required List<AdMetrics> metrics,
  }) {
    var amount = 0.0;
    var spent = 0.0;
    var usedPlanned = false;

    for (final record in revenueRecords) {
      if (record.campaignId != campaign.id) continue;
      if (!_inPeriod(record.recordedAt, start, endExclusive)) continue;
      if (record.sourceStatus == WalletTransactionStatus.refunded.dbValue) {
        continue;
      }
      amount += record.grossAmount;
    }

    for (final tx in walletTransactions) {
      if (tx.campaignId != campaign.id) continue;
      if (!_inPeriod(tx.createdAt, start, endExclusive)) continue;
      if (tx.type == WalletTransactionType.spend &&
          tx.status == WalletTransactionStatus.succeeded) {
        spent += tx.amount;
        if (amount <= 0) amount += tx.amount;
      }
    }

    if (amount <= 0) {
      for (final metric in metrics) {
        if (metric.campaignId != campaign.id) continue;
        if (!_inPeriod(metric.date, start, endExclusive)) continue;
        if (metric.revenue > 0) {
          amount += metric.revenue;
        } else if (metric.spend > 0) {
          spent += metric.spend;
          amount += metric.spend;
        }
      }
    }

    if (amount <= 0 &&
        campaign.totalBudget > 0 &&
        _overlapsPeriod(campaign.startsAt, campaign.endsAt, start, endExclusive)) {
      usedPlanned = true;
      if (campaign.spentAmount > 0) {
        spent += campaign.spentAmount;
      }
    }

    return _CampaignPeriodRevenue(
      amount: amount,
      spent: spent,
      usedPlannedBudget: usedPlanned,
    );
  }

  static bool _inPeriod(
    DateTime date,
    DateTime start,
    DateTime endExclusive,
  ) {
    return !date.isBefore(start) && date.isBefore(endExclusive);
  }

  static bool _overlapsPeriod(
    DateTime rangeStart,
    DateTime rangeEnd,
    DateTime start,
    DateTime endExclusive,
  ) {
    return !rangeEnd.isBefore(start) && rangeStart.isBefore(endExclusive);
  }
}

class AdminFinancePeriodSnapshot {
  const AdminFinancePeriodSnapshot({
    required this.orderCore,
    required this.adBreakdown,
    required this.sourceRows,
    required this.totalIbulRevenue,
    required this.propertyRentRevenue,
    required this.otherRevenue,
    this.manualCargoAdjustment = 0,
  });

  final AdminFinanceOrderCoreMetrics orderCore;
  final AdminFinanceAdBreakdown adBreakdown;
  final List<AdminFinanceRevenueSourceRow> sourceRows;
  final double totalIbulRevenue;
  final double propertyRentRevenue;
  final double otherRevenue;
  final double manualCargoAdjustment;
}

class AdminFinanceRevenueSourceRow {
  const AdminFinanceRevenueSourceRow({
    required this.key,
    required this.label,
    required this.amount,
    required this.hasData,
    required this.emptyNote,
    this.share = 0,
    this.changePercent,
    this.usesPlannedLabel = false,
  });

  final String key;
  final String label;
  final double amount;
  final bool hasData;
  final String emptyNote;
  final double share;
  final double? changePercent;
  final bool usesPlannedLabel;

  AdminFinanceRevenueSourceRow copyWithShare(double share) {
    return AdminFinanceRevenueSourceRow(
      key: key,
      label: label,
      amount: amount,
      hasData: hasData,
      emptyNote: emptyNote,
      share: share,
      changePercent: changePercent,
      usesPlannedLabel: usesPlannedLabel,
    );
  }

  AdminFinanceRevenueSourceRow copyWithChange(double? changePercent) {
    return AdminFinanceRevenueSourceRow(
      key: key,
      label: label,
      amount: amount,
      hasData: hasData,
      emptyNote: emptyNote,
      share: share,
      changePercent: changePercent,
      usesPlannedLabel: usesPlannedLabel,
    );
  }
}

class AdminFinanceAdBreakdown {
  const AdminFinanceAdBreakdown({
    required this.totalCollected,
    required this.usesPlannedBudgetLabel,
    required this.rows,
  });

  final double totalCollected;
  final bool usesPlannedBudgetLabel;
  final List<AdminFinanceAdTypeRow> rows;
}

class AdminFinanceAdTypeRow {
  const AdminFinanceAdTypeRow({
    required this.typeBucket,
    required this.label,
    required this.campaignCount,
    required this.budgetTotal,
    required this.collectedAmount,
    required this.spentAmount,
    required this.impressions,
    required this.clicks,
    required this.usesPlannedLabel,
  });

  final String typeBucket;
  final String label;
  final int campaignCount;
  final double budgetTotal;
  final double collectedAmount;
  final double spentAmount;
  final int impressions;
  final int clicks;
  final bool usesPlannedLabel;

  double get ctr => impressions == 0 ? 0 : clicks / impressions;
}

class AdminFinanceCargoBreakdown {
  const AdminFinanceCargoBreakdown({
    required this.collection,
    required this.cost,
    required this.freeShippingSubsidy,
    required this.netRevenue,
    required this.packageCount,
    required this.averageCollection,
  });

  final double collection;
  final double cost;
  final double freeShippingSubsidy;
  final double netRevenue;
  final int packageCount;
  final double averageCollection;
}

class AdminFinanceOrderCoreMetrics {
  const AdminFinanceOrderCoreMetrics({
    required this.gmv,
    required this.commission,
    required this.refundAmount,
    required this.refundCount,
    required this.completedOrders,
    required this.averageBasket,
    required this.cargoCollection,
    required this.cargoCost,
    required this.freeShippingSubsidy,
    required this.cargoNetRevenue,
    required this.deliveredPackages,
  });

  final double gmv;
  final double commission;
  final double refundAmount;
  final int refundCount;
  final int completedOrders;
  final double averageBasket;
  final double cargoCollection;
  final double cargoCost;
  final double freeShippingSubsidy;
  final double cargoNetRevenue;
  final int deliveredPackages;
}

class _AdBucketAccumulator {
  _AdBucketAccumulator({required this.bucket});

  final String bucket;
  int campaignCount = 0;
  double budgetTotal = 0;
  double collectedAmount = 0;
  double spentAmount = 0;
  int impressions = 0;
  int clicks = 0;
  bool usesPlannedLabel = false;

  AdminFinanceAdTypeRow toRow() {
    return AdminFinanceAdTypeRow(
      typeBucket: bucket,
      label: AdminFinanceRevenueHelper.adTypeLabel(bucket),
      campaignCount: campaignCount,
      budgetTotal: budgetTotal,
      collectedAmount: collectedAmount,
      spentAmount: spentAmount,
      impressions: impressions,
      clicks: clicks,
      usesPlannedLabel: usesPlannedLabel,
    );
  }
}

class _CampaignPeriodRevenue {
  const _CampaignPeriodRevenue({
    required this.amount,
    required this.spent,
    required this.usedPlannedBudget,
  });

  final double amount;
  final double spent;
  final bool usedPlannedBudget;
}
