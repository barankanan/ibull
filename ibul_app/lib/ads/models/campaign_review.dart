import '../enums/ad_enums.dart';
import '../helpers/ad_json_helper.dart';

class CampaignReview {
  const CampaignReview({
    required this.id,
    required this.campaignId,
    required this.sellerId,
    required this.status,
    required this.createdAt,
    this.reviewerId,
    this.note,
    this.reasons = const [],
    this.reviewedAt,
    this.metadata = const {},
  });

  final String id;
  final String campaignId;
  final String sellerId;
  final String? reviewerId;
  final CampaignReviewStatus status;
  final String? note;
  final List<String> reasons;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  factory CampaignReview.fromJson(Map<String, dynamic> json) {
    return CampaignReview(
      id: AdJsonHelper.asString(json['id']),
      campaignId: AdJsonHelper.asString(json['campaign_id']),
      sellerId: AdJsonHelper.asString(json['seller_id']),
      reviewerId: AdJsonHelper.asNullableString(json['reviewer_id']),
      status: CampaignReviewStatusParser.fromDbValue(
        json['status']?.toString(),
      ),
      note: AdJsonHelper.asNullableString(json['note']),
      reasons: AdJsonHelper.asStringList(json['reasons']),
      reviewedAt: AdJsonHelper.asDateTime(json['reviewed_at']),
      createdAt: AdJsonHelper.asDateTime(json['created_at']) ?? DateTime.now(),
      metadata: AdJsonHelper.asMap(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'campaign_id': campaignId,
      'seller_id': sellerId,
      'reviewer_id': reviewerId,
      'status': status.dbValue,
      'note': note,
      'reasons': reasons,
      'reviewed_at': reviewedAt?.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'metadata': metadata,
    };
  }
}
