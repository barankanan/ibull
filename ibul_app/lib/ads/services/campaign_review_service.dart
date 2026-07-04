import '../helpers/ad_reviewer_helper.dart';
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
    String? reviewerId,
    String? note,
    String adminSource = 'admin-panel',
  }) async {
    await _repository.setCampaignStatus(campaignId, CampaignStatus.approved);
    return _repository.submitCampaignReview(
      CampaignReview(
        id: 'review-${DateTime.now().microsecondsSinceEpoch}',
        campaignId: campaignId,
        sellerId: sellerId,
        reviewerId: AdReviewerHelper.isValidUuid(reviewerId)
            ? reviewerId
            : AdReviewerHelper.resolveReviewerId(),
        status: CampaignReviewStatus.approved,
        note: note ?? 'Admin tarafından onaylandı.',
        metadata: AdReviewerHelper.isValidUuid(reviewerId)
            ? const {}
            : AdReviewerHelper.adminSourceMetadata(source: adminSource),
        createdAt: DateTime.now(),
        reviewedAt: DateTime.now(),
      ),
    );
  }

  Future<CampaignReview> rejectCampaign({
    required String campaignId,
    required String sellerId,
    String? reviewerId,
    required List<String> reasons,
    String? note,
    String adminSource = 'admin-panel',
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
        reviewerId: AdReviewerHelper.isValidUuid(reviewerId)
            ? reviewerId
            : AdReviewerHelper.resolveReviewerId(),
        status: CampaignReviewStatus.rejected,
        note: note ?? 'Admin tarafından reddedildi.',
        reasons: reasons,
        metadata: AdReviewerHelper.isValidUuid(reviewerId)
            ? const {}
            : AdReviewerHelper.adminSourceMetadata(source: adminSource),
        createdAt: DateTime.now(),
        reviewedAt: DateTime.now(),
      ),
    );
  }

  Future<CampaignReview> requestChanges({
    required String campaignId,
    required String sellerId,
    String? reviewerId,
    required List<String> reasons,
    String? note,
    String adminSource = 'admin-panel',
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
        reviewerId: AdReviewerHelper.isValidUuid(reviewerId)
            ? reviewerId
            : AdReviewerHelper.resolveReviewerId(),
        status: CampaignReviewStatus.changesRequested,
        note: note ?? 'Admin değişiklik istedi.',
        reasons: reasons,
        metadata: AdReviewerHelper.isValidUuid(reviewerId)
            ? const {}
            : AdReviewerHelper.adminSourceMetadata(source: adminSource),
        createdAt: DateTime.now(),
        reviewedAt: DateTime.now(),
      ),
    );
  }
}
