import '../helpers/ad_json_helper.dart';

class AdRevenueOverview {
  const AdRevenueOverview({
    required this.totalRevenue,
    required this.todayRevenue,
    required this.weekRevenue,
    required this.monthRevenue,
    required this.pendingPayments,
    required this.approvedPayments,
    required this.refundedPayments,
    required this.walletTopUps,
    required this.currency,
    required this.generatedAt,
    this.campaignRevenue = const {},
    this.sellerSpend = const {},
  });

  final double totalRevenue;
  final double todayRevenue;
  final double weekRevenue;
  final double monthRevenue;
  final double pendingPayments;
  final double approvedPayments;
  final double refundedPayments;
  final double walletTopUps;
  final String currency;
  final DateTime generatedAt;
  final Map<String, double> campaignRevenue;
  final Map<String, double> sellerSpend;

  factory AdRevenueOverview.fromJson(Map<String, dynamic> json) {
    Map<String, double> asDoubleMap(dynamic value) {
      final map = AdJsonHelper.asMap(value);
      return map.map(
        (key, dynamic item) => MapEntry(key, AdJsonHelper.asDouble(item)),
      );
    }

    return AdRevenueOverview(
      totalRevenue: AdJsonHelper.asDouble(json['total_revenue']),
      todayRevenue: AdJsonHelper.asDouble(json['today_revenue']),
      weekRevenue: AdJsonHelper.asDouble(json['week_revenue']),
      monthRevenue: AdJsonHelper.asDouble(json['month_revenue']),
      pendingPayments: AdJsonHelper.asDouble(json['pending_payments']),
      approvedPayments: AdJsonHelper.asDouble(json['approved_payments']),
      refundedPayments: AdJsonHelper.asDouble(json['refunded_payments']),
      walletTopUps: AdJsonHelper.asDouble(json['wallet_top_ups']),
      currency: AdJsonHelper.asString(json['currency'], fallback: 'TRY'),
      generatedAt:
          AdJsonHelper.asDateTime(json['generated_at']) ?? DateTime.now(),
      campaignRevenue: asDoubleMap(json['campaign_revenue']),
      sellerSpend: asDoubleMap(json['seller_spend']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_revenue': totalRevenue,
      'today_revenue': todayRevenue,
      'week_revenue': weekRevenue,
      'month_revenue': monthRevenue,
      'pending_payments': pendingPayments,
      'approved_payments': approvedPayments,
      'refunded_payments': refundedPayments,
      'wallet_top_ups': walletTopUps,
      'currency': currency,
      'generated_at': generatedAt.toUtc().toIso8601String(),
      'campaign_revenue': campaignRevenue,
      'seller_spend': sellerSpend,
    };
  }
}
