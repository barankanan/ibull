import '../helpers/ad_json_helper.dart';

class AdCreditCode {
  const AdCreditCode({
    required this.id,
    required this.batchId,
    required this.code,
    required this.amount,
    required this.status,
    required this.isActive,
    required this.usageLimit,
    required this.usedCount,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.targetSellerId,
    this.redeemedBy,
    this.redeemedWalletTransactionId,
    this.lastRedeemedBy,
    this.note,
    this.metadata = const <String, dynamic>{},
    this.expiresAt,
    this.redeemedAt,
    this.lastRedeemedAt,
  });

  final String id;
  final String batchId;
  final String code;
  final double amount;
  final String status;
  final bool isActive;
  final int usageLimit;
  final int usedCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? targetSellerId;
  final String? redeemedBy;
  final String? redeemedWalletTransactionId;
  final String? lastRedeemedBy;
  final String? note;
  final Map<String, dynamic> metadata;
  final DateTime? expiresAt;
  final DateTime? redeemedAt;
  final DateTime? lastRedeemedAt;

  bool get isRedeemed => status == 'redeemed';
  int get remainingUses => usageLimit - usedCount;
  bool get isExhausted => remainingUses <= 0;

  factory AdCreditCode.fromJson(Map<String, dynamic> json) {
    final amount = AdJsonHelper.asDouble(
      json['credit_amount'] ?? json['amount'],
    );
    final status = AdJsonHelper.asString(json['status'], fallback: 'active');
    final usedCount = AdJsonHelper.asInt(json['used_count']);
    final usageLimit = AdJsonHelper.asInt(json['usage_limit'], fallback: 1);
    return AdCreditCode(
      id: AdJsonHelper.asString(json['id']),
      batchId: AdJsonHelper.asString(json['batch_id']),
      code: AdJsonHelper.asString(json['code']),
      amount: amount,
      status: status,
      isActive: AdJsonHelper.asBool(
        json['is_active'],
        fallback: status == 'active' && usedCount < usageLimit,
      ),
      usageLimit: usageLimit <= 0 ? 1 : usageLimit,
      usedCount: usedCount < 0 ? 0 : usedCount,
      createdAt: AdJsonHelper.asDateTime(json['created_at']) ?? DateTime.now(),
      updatedAt: AdJsonHelper.asDateTime(json['updated_at']) ?? DateTime.now(),
      createdBy: AdJsonHelper.asNullableString(json['created_by']),
      targetSellerId: AdJsonHelper.asNullableString(
        json['seller_id'] ?? json['target_seller_id'],
      ),
      redeemedBy: AdJsonHelper.asNullableString(json['redeemed_by']),
      redeemedWalletTransactionId: AdJsonHelper.asNullableString(
        json['redeemed_wallet_transaction_id'],
      ),
      lastRedeemedBy: AdJsonHelper.asNullableString(json['last_redeemed_by']),
      note: AdJsonHelper.asNullableString(json['note']),
      metadata: AdJsonHelper.asMap(json['metadata']),
      expiresAt: AdJsonHelper.asDateTime(json['expires_at']),
      redeemedAt: AdJsonHelper.asDateTime(json['redeemed_at']),
      lastRedeemedAt: AdJsonHelper.asDateTime(json['last_redeemed_at']),
    );
  }
}

class AdCreditCodePreview {
  const AdCreditCodePreview({
    required this.code,
    required this.amount,
    required this.status,
    required this.canRedeem,
    required this.reason,
    required this.isActive,
    required this.usageLimit,
    required this.usedCount,
    this.targetSellerId,
    this.note,
    this.expiresAt,
  });

  final String code;
  final double amount;
  final String status;
  final bool canRedeem;
  final String reason;
  final bool isActive;
  final int usageLimit;
  final int usedCount;
  final String? targetSellerId;
  final String? note;
  final DateTime? expiresAt;

  bool get isKnown => status != 'missing';
  int get remainingUses => usageLimit - usedCount;
  bool get isExhausted => remainingUses <= 0;

  AdCreditCodePreview copyWith({
    String? code,
    double? amount,
    String? status,
    bool? canRedeem,
    String? reason,
    bool? isActive,
    int? usageLimit,
    int? usedCount,
    String? targetSellerId,
    String? note,
    DateTime? expiresAt,
  }) {
    return AdCreditCodePreview(
      code: code ?? this.code,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      canRedeem: canRedeem ?? this.canRedeem,
      reason: reason ?? this.reason,
      isActive: isActive ?? this.isActive,
      usageLimit: usageLimit ?? this.usageLimit,
      usedCount: usedCount ?? this.usedCount,
      targetSellerId: targetSellerId ?? this.targetSellerId,
      note: note ?? this.note,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  factory AdCreditCodePreview.fromJson(Map<String, dynamic> json) {
    final status = AdJsonHelper.asString(json['status'], fallback: 'missing');
    final usageLimit = AdJsonHelper.asInt(json['usage_limit'], fallback: 1);
    final usedCount = AdJsonHelper.asInt(json['used_count']);
    return AdCreditCodePreview(
      code: AdJsonHelper.asString(json['code']),
      amount: AdJsonHelper.asDouble(json['credit_amount'] ?? json['amount']),
      status: status,
      canRedeem: json['can_redeem'] == true,
      reason: AdJsonHelper.asString(json['reason'], fallback: 'unknown'),
      isActive: AdJsonHelper.asBool(
        json['is_active'],
        fallback: status == 'active' && usedCount < usageLimit,
      ),
      usageLimit: usageLimit <= 0 ? 1 : usageLimit,
      usedCount: usedCount < 0 ? 0 : usedCount,
      targetSellerId: AdJsonHelper.asNullableString(
        json['seller_id'] ?? json['target_seller_id'],
      ),
      note: AdJsonHelper.asNullableString(json['note']),
      expiresAt: AdJsonHelper.asDateTime(json['expires_at']),
    );
  }
}

class AdCreditCodeRedemptionResult {
  const AdCreditCodeRedemptionResult({
    required this.code,
    required this.amount,
    required this.balanceAfter,
    required this.walletTransactionId,
    required this.redemptionId,
    required this.sellerId,
  });

  final String code;
  final double amount;
  final double balanceAfter;
  final String walletTransactionId;
  final String redemptionId;
  final String sellerId;

  factory AdCreditCodeRedemptionResult.fromJson(Map<String, dynamic> json) {
    return AdCreditCodeRedemptionResult(
      code: AdJsonHelper.asString(json['code']),
      amount: AdJsonHelper.asDouble(json['credit_amount'] ?? json['amount']),
      balanceAfter: AdJsonHelper.asDouble(json['balance_after']),
      walletTransactionId: AdJsonHelper.asString(json['wallet_transaction_id']),
      redemptionId: AdJsonHelper.asString(json['redemption_id']),
      sellerId: AdJsonHelper.asString(json['seller_id']),
    );
  }
}

class AdCreditRedemption {
  const AdCreditRedemption({
    required this.id,
    required this.codeId,
    required this.code,
    required this.sellerId,
    required this.redeemedBy,
    required this.creditedAmount,
    required this.status,
    required this.redeemedAt,
    this.campaignId,
    this.note,
  });

  final String id;
  final String codeId;
  final String code;
  final String sellerId;
  final String redeemedBy;
  final double creditedAmount;
  final String status;
  final DateTime redeemedAt;
  final String? campaignId;
  final String? note;

  factory AdCreditRedemption.fromJson(Map<String, dynamic> json) {
    return AdCreditRedemption(
      id: AdJsonHelper.asString(json['id']),
      codeId: AdJsonHelper.asString(json['code_id']),
      code: AdJsonHelper.asString(json['code']),
      sellerId: AdJsonHelper.asString(json['seller_id']),
      redeemedBy: AdJsonHelper.asString(json['redeemed_by']),
      creditedAmount: AdJsonHelper.asDouble(json['credited_amount']),
      status: AdJsonHelper.asString(json['status'], fallback: 'succeeded'),
      redeemedAt:
          AdJsonHelper.asDateTime(json['redeemed_at']) ?? DateTime.now(),
      campaignId: AdJsonHelper.asNullableString(json['campaign_id']),
      note: AdJsonHelper.asNullableString(json['note']),
    );
  }
}
