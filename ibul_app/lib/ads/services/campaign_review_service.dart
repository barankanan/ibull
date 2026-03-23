import '../enums/ad_enums.dart';
import '../models/campaign_review.dart';
import '../repositories/ads_repository.dart';

class CampaignReviewService {
  CampaignReviewService({AdsRepository? repository})
    : _repository = repository ?? AdsRepository();

  final AdsRepository _repository;

  Future<List<CampaignReview>> getPendingReviews() {
    return _repository.getCampaignReviews(status: CampaignReviewStatus.pending);
  }

  Future<List<CampaignReview>> getCampaignReviews(String campaignId) {
    return _repository.getCampaignReviews(campaignId: campaignId);
  }

  Future<CampaignReview> approveCampaign({
    required String campaignId,
    required String sellerId,
    required String reviewerId,
    String? note,
  }) async {
    await _repository.setCampaignStatus(campaignId, CampaignStatus.approved);
    return _repository.submitCampaignReview(
      CampaignReview(
        id: 'review-${DateTime.now().microsecondsSinceEpoch}',
        campaignId: campaignId,
        sellerId: sellerId,
        reviewerId: reviewerId,
        status: CampaignReviewStatus.approved,
        note: note ?? 'Approved by admin review.',
        createdAt: DateTime.now(),
        reviewedAt: DateTime.now(),
      ),
    );
  }

  Future<CampaignReview> rejectCampaign({
    required String campaignId,
    required String sellerId,
    required String reviewerId,
    required List<String> reasons,
    String? note,
  }) async {
    await _repository.setCampaignStatus(
      campaignId,
      CampaignStatus.rejected,
      reviewNotes: note,
    );
    return _repository.submitCampaignReview(
      CampaignReview(
        id: 'review-${DateTime.now().microsecondsSinceEpoch}',
        campaignId: campaignId,
        sellerId: sellerId,
        reviewerId: reviewerId,
        status: CampaignReviewStatus.rejected,
        note: note ?? 'Rejected by admin review.',
        reasons: reasons,
        createdAt: DateTime.now(),
        reviewedAt: DateTime.now(),
      ),
    );
  }

  Future<CampaignReview> requestChanges({
    required String campaignId,
    required String sellerId,
    required String reviewerId,
    required List<String> reasons,
    String? note,
  }) async {
    await _repository.setCampaignStatus(
      campaignId,
      CampaignStatus.draft,
      reviewNotes: note,
    );
    return _repository.submitCampaignReview(
      CampaignReview(
        id: 'review-${DateTime.now().microsecondsSinceEpoch}',
        campaignId: campaignId,
        sellerId: sellerId,
        reviewerId: reviewerId,
        status: CampaignReviewStatus.changesRequested,
        note: note ?? 'Changes requested by admin.',
        reasons: reasons,
        createdAt: DateTime.now(),
        reviewedAt: DateTime.now(),
      ),
    );
  }
}
