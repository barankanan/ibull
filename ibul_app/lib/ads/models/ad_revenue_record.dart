import '../helpers/ad_json_helper.dart';

class AdRevenueRecord {
  const AdRevenueRecord({
    required this.id,
    required this.grossAmount,
    required this.netAmount,
    required this.taxAmount,
    required this.platformFee,
    required this.currency,
    required this.recordedAt,
    this.campaignId,
    this.sellerId,
    this.walletTransactionId,
    this.sourceStatus = 'approved',
    this.periodKey,
    this.metadata = const {},
  });

  final String id;
  final String? campaignId;
  final String? sellerId;
  final String? walletTransactionId;
  final double grossAmount;
  final double netAmount;
  final double taxAmount;
  final double platformFee;
  final String currency;
  final DateTime recordedAt;
  final String sourceStatus;
  final String? periodKey;
  final Map<String, dynamic> metadata;

  factory AdRevenueRecord.fromJson(Map<String, dynamic> json) {
    return AdRevenueRecord(
      id: AdJsonHelper.asString(json['id']),
      campaignId: AdJsonHelper.asNullableString(json['campaign_id']),
      sellerId: AdJsonHelper.asNullableString(json['seller_id']),
      walletTransactionId: AdJsonHelper.asNullableString(
        json['wallet_transaction_id'],
      ),
      grossAmount: AdJsonHelper.asDouble(json['gross_amount']),
      netAmount: AdJsonHelper.asDouble(json['net_amount']),
      taxAmount: AdJsonHelper.asDouble(json['tax_amount']),
      platformFee: AdJsonHelper.asDouble(json['platform_fee']),
      currency: AdJsonHelper.asString(json['currency'], fallback: 'TRY'),
      recordedAt:
          AdJsonHelper.asDateTime(json['recorded_at']) ?? DateTime.now(),
      sourceStatus: AdJsonHelper.asString(
        json['source_status'],
        fallback: 'approved',
      ),
      periodKey: AdJsonHelper.asNullableString(json['period_key']),
      metadata: AdJsonHelper.asMap(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'campaign_id': campaignId,
      'seller_id': sellerId,
      'wallet_transaction_id': walletTransactionId,
      'gross_amount': grossAmount,
      'net_amount': netAmount,
      'tax_amount': taxAmount,
      'platform_fee': platformFee,
      'currency': currency,
      'recorded_at': recordedAt.toUtc().toIso8601String(),
      'source_status': sourceStatus,
      'period_key': periodKey,
      'metadata': metadata,
    };
  }
}
