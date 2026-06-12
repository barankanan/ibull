import '../models/ad_campaign.dart';
import '../models/ad_revenue_overview.dart';
import '../models/ad_revenue_record.dart';
import '../models/ad_wallet_transaction.dart';
import '../enums/ad_enums.dart';

class AdWalletHelper {
  const AdWalletHelper._();

  static double availableBalance(Iterable<AdWalletTransaction> transactions) {
    if (transactions.isEmpty) return 0;
    final sorted = transactions.toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.first.balanceAfter;
  }

  static AdWalletTransaction buildTopUpTransaction({
    required String id,
    required String sellerId,
    required double amount,
    required double currentBalance,
    String? note,
    String? reference,
  }) {
    return AdWalletTransaction(
      id: id,
      sellerId: sellerId,
      type: WalletTransactionType.topUp,
      status: WalletTransactionStatus.succeeded,
      amount: amount,
      balanceBefore: currentBalance,
      balanceAfter: currentBalance + amount,
      note: note,
      reference: reference,
      createdAt: DateTime.now(),
    );
  }

  static AdWalletTransaction buildSpendTransaction({
    required String id,
    required String sellerId,
    required String campaignId,
    required double amount,
    required double currentBalance,
    String? note,
  }) {
    if (currentBalance < amount) {
      throw StateError('Insufficient ad wallet balance for campaign spend.');
    }
    return AdWalletTransaction(
      id: id,
      sellerId: sellerId,
      campaignId: campaignId,
      type: WalletTransactionType.spend,
      status: WalletTransactionStatus.succeeded,
      amount: amount,
      balanceBefore: currentBalance,
      balanceAfter: currentBalance - amount,
      reference: campaignId,
      note: note,
      createdAt: DateTime.now(),
    );
  }

  static AdWalletTransaction buildRefundTransaction({
    required String id,
    required String sellerId,
    required double amount,
    required double currentBalance,
    String? campaignId,
    String? note,
  }) {
    return AdWalletTransaction(
      id: id,
      sellerId: sellerId,
      campaignId: campaignId,
      type: WalletTransactionType.refund,
      status: WalletTransactionStatus.refunded,
      amount: amount,
      balanceBefore: currentBalance,
      balanceAfter: currentBalance + amount,
      reference: campaignId,
      note: note,
      createdAt: DateTime.now(),
    );
  }

  static AdRevenueRecord buildRevenueRecord({
    required String id,
    required AdCampaign campaign,
    required AdWalletTransaction transaction,
    String status = 'approved', // Default approved status
    double taxRate = 0.2,
    double platformFeeRate = 0.06,
  }) {
    final grossAmount = transaction.amount;
    final taxAmount = grossAmount * taxRate;
    final platformFee = grossAmount * platformFeeRate;
    final netAmount = (grossAmount - taxAmount - platformFee).clamp(
      0.0,
      grossAmount,
    );
    final recordedAt = DateTime.now();
    return AdRevenueRecord(
      id: id,
      campaignId: campaign.id,
      sellerId: campaign.sellerId,
      walletTransactionId: transaction.id,
      grossAmount: grossAmount,
      netAmount: netAmount,
      taxAmount: taxAmount,
      platformFee: platformFee,
      currency: campaign.currency,
      recordedAt: recordedAt,
      sourceStatus: status,
      periodKey:
          '${recordedAt.year}-${recordedAt.month.toString().padLeft(2, '0')}',
      metadata: <String, dynamic>{
        'billing_model': campaign.billingModel.dbValue,
        'campaign_type': campaign.type.dbValue,
      },
    );
  }

  static AdRevenueOverview buildAdminRevenueSummary({
    required Iterable<AdRevenueRecord> records,
    required Iterable<AdWalletTransaction> walletTransactions,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final startOfDay = DateTime(current.year, current.month, current.day);
    final startOfWeek = startOfDay.subtract(
      Duration(days: current.weekday - 1),
    );
    final startOfMonth = DateTime(current.year, current.month);

    double sumWhere(bool Function(AdRevenueRecord record) test) {
      return records
          .where(test)
          .where((record) => record.sourceStatus != 'refunded')
          .fold<double>(0, (sum, record) => sum + record.grossAmount);
    }

    final campaignRevenue = <String, double>{};
    final sellerSpend = <String, double>{};
    for (final record in records) {
      if (record.campaignId != null) {
        campaignRevenue[record.campaignId!] =
            (campaignRevenue[record.campaignId!] ?? 0) + record.grossAmount;
      }
      if (record.sellerId != null) {
        sellerSpend[record.sellerId!] =
            (sellerSpend[record.sellerId!] ?? 0) + record.grossAmount;
      }
    }

    return AdRevenueOverview(
      totalRevenue: records.fold<double>(
        0,
        (sum, record) => sum + record.grossAmount,
      ),
      todayRevenue: sumWhere(
        (record) => !record.recordedAt.isBefore(startOfDay),
      ),
      weekRevenue: sumWhere(
        (record) => !record.recordedAt.isBefore(startOfWeek),
      ),
      monthRevenue: sumWhere(
        (record) => !record.recordedAt.isBefore(startOfMonth),
      ),
      pendingPayments: records
          .where((record) => record.sourceStatus == CampaignReviewStatus.pending.dbValue)
          .fold<double>(0, (sum, record) => sum + record.grossAmount),
      approvedPayments: records
          .where((record) => record.sourceStatus == CampaignStatus.approved.dbValue)
          .fold<double>(0, (sum, record) => sum + record.grossAmount),
      refundedPayments: records
          .where((record) => record.sourceStatus == WalletTransactionStatus.refunded.dbValue)
          .fold<double>(0, (sum, record) => sum + record.grossAmount),
      walletTopUps: availableBalance(walletTransactions),
      currency: records.isNotEmpty ? records.first.currency : 'TRY',
      generatedAt: current,
      campaignRevenue: campaignRevenue,
      sellerSpend: sellerSpend,
    );
  }

  static Map<String, double> buildSellerSpendSummary({
    required Iterable<AdWalletTransaction> transactions,
    required Iterable<AdRevenueRecord> records,
  }) {
    return <String, double>{
      'top_up_total': transactions
          .where((item) => item.type == WalletTransactionType.topUp)
          .fold<double>(0, (sum, item) => sum + item.amount),
      'spend_total': transactions
          .where((item) => item.type == WalletTransactionType.spend)
          .fold<double>(0, (sum, item) => sum + item.amount),
      'refund_total': transactions
          .where((item) => item.type == WalletTransactionType.refund)
          .fold<double>(0, (sum, item) => sum + item.amount),
      'approved_revenue_total': records
          .where((item) => item.sourceStatus == CampaignStatus.approved.dbValue)
          .fold<double>(0, (sum, item) => sum + item.grossAmount),
    };
  }
}
