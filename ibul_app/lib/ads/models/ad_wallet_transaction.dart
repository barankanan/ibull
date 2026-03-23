import '../enums/ad_enums.dart';
import '../helpers/ad_json_helper.dart';

class AdWalletTransaction {
  const AdWalletTransaction({
    required this.id,
    required this.sellerId,
    required this.type,
    required this.status,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.createdAt,
    this.campaignId,
    this.reference,
    this.approvedBy,
    this.note,
    this.metadata = const {},
  });

  final String id;
  final String sellerId;
  final String? campaignId;
  final WalletTransactionType type;
  final WalletTransactionStatus status;
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String? reference;
  final String? approvedBy;
  final String? note;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  factory AdWalletTransaction.fromJson(Map<String, dynamic> json) {
    return AdWalletTransaction(
      id: AdJsonHelper.asString(json['id']),
      sellerId: AdJsonHelper.asString(json['seller_id']),
      campaignId: AdJsonHelper.asNullableString(json['campaign_id']),
      type: WalletTransactionTypeParser.fromDbValue(json['type']?.toString()),
      status: WalletTransactionStatusParser.fromDbValue(
        json['status']?.toString(),
      ),
      amount: AdJsonHelper.asDouble(json['amount']),
      balanceBefore: AdJsonHelper.asDouble(json['balance_before']),
      balanceAfter: AdJsonHelper.asDouble(json['balance_after']),
      reference: AdJsonHelper.asNullableString(json['reference']),
      approvedBy: AdJsonHelper.asNullableString(json['approved_by']),
      note: AdJsonHelper.asNullableString(json['note']),
      metadata: AdJsonHelper.asMap(json['metadata']),
      createdAt: AdJsonHelper.asDateTime(json['created_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'seller_id': sellerId,
      'campaign_id': campaignId,
      'type': type.dbValue,
      'status': status.dbValue,
      'amount': amount,
      'balance_before': balanceBefore,
      'balance_after': balanceAfter,
      'reference': reference,
      'approved_by': approvedBy,
      'note': note,
      'metadata': metadata,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}
