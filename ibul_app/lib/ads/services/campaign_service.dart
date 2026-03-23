import '../constants/ads_defaults.dart';
import '../enums/ad_enums.dart';
import '../helpers/ad_campaign_helper.dart';
import '../models/ad_campaign.dart';
import '../models/ad_campaign_page.dart';
import '../models/campaign_asset.dart';
import '../models/campaign_target.dart';
import '../repositories/ads_repository.dart';

class CampaignService {
  CampaignService({AdsRepository? repository})
    : _repository = repository ?? AdsRepository();

  final AdsRepository _repository;

  Future<List<AdCampaign>> getCampaignsForSeller(String sellerId) {
    return _repository.getCampaigns(sellerId: sellerId, limit: 100);
  }

  Future<AdCampaignPage> getCampaignPageForSeller({
    required String sellerId,
    List<CampaignStatus>? statuses,
    AdCampaignType? type,
    CampaignObjective? objective,
    String? searchQuery,
    DateTime? from,
    DateTime? to,
    required int page,
    required int pageSize,
    String sortField = 'starts_at',
    bool ascending = false,
  }) {
    return _repository.getCampaignPage(
      sellerId: sellerId,
      statuses: statuses,
      type: type,
      objective: objective,
      searchQuery: searchQuery,
      from: from,
      to: to,
      page: page,
      pageSize: pageSize,
      sortField: sortField,
      ascending: ascending,
    );
  }

  Future<List<AdCampaign>> getCampaignsForAdmin() {
    return _repository.getCampaigns(limit: 200);
  }

  List<String> validateCampaign(AdCampaign campaign) {
    final issues = <String>[];
    if (campaign.name.trim().isEmpty) issues.add('Campaign name is required.');
    if (campaign.dailyBudget <= 0) issues.add('Daily budget must be positive.');
    if (campaign.totalBudget < campaign.dailyBudget) {
      issues.add('Total budget must be greater than or equal to daily budget.');
    }
    if (campaign.endsAt.isBefore(campaign.startsAt)) {
      issues.add('End date must be after the start date.');
    }
    if (campaign.assets.isEmpty) {
      issues.add('At least one campaign asset is required.');
    }
    if (campaign.target == null) {
      issues.add('Campaign target configuration is missing.');
    }
    if (!AdCampaignHelper.supportsTypeForObjective(
      objective: campaign.objective,
      type: campaign.type,
    )) {
      issues.add(
        'Selected ad format is not compatible with the campaign objective.',
      );
    }
    if (campaign.type == AdCampaignType.geoPush &&
        (campaign.target?.radiusMeters ?? 0) <= 0) {
      issues.add('Geo push campaigns need a positive radius.');
    }
    return issues;
  }

  Future<AdCampaign> createDraftCampaign({
    required String sellerId,
    required String name,
    required CampaignObjective objective,
    required AdCampaignType type,
    String? storeId,
    String? description,
    List<CampaignAsset> assets = const [],
    CampaignTarget? target,
    bool premiumPlacement = false,
    bool useAiSuggestions = true,
    DateTime? startsAt,
    DateTime? endsAt,
  }) {
    final now = DateTime.now();
    final campaignId = 'cmp-${now.microsecondsSinceEpoch}';
    final dailyBudget = AdCampaignHelper.suggestedDailyBudget(
      objective: objective,
      premiumPlacement: premiumPlacement,
    );
    final campaign = AdCampaign(
      id: campaignId,
      sellerId: sellerId,
      storeId: storeId,
      name: name,
      description: description,
      type: type,
      objective: objective,
      status: CampaignStatus.draft,
      billingModel: AdCampaignHelper.defaultBillingModelForObjective(objective),
      dailyBudget: dailyBudget,
      totalBudget: dailyBudget * 10,
      spentAmount: 0,
      remainingBalance: dailyBudget * 10,
      bidAmount: AdsDefaults.defaultBidAmount,
      currency: AdsDefaults.defaultCurrency,
      startsAt: startsAt ?? now,
      endsAt: endsAt ?? now.add(const Duration(days: 14)),
      isPremiumPlacementEnabled: premiumPlacement,
      useAiSuggestions: useAiSuggestions,
      frequencyCapPerUser: AdsDefaults.defaultFrequencyCapPerUser,
      target:
          target ??
          CampaignTarget(
            campaignId: campaignId,
            objective: objective,
            placements: AdCampaignHelper.defaultPlacementsForType(type),
            eventLookbackDays: AdsDefaults.defaultLookbackDays,
            frequencyCapPerDay: AdsDefaults.defaultFrequencyCapPerUser,
            retargetingWindowDays: AdsDefaults.defaultRetargetingWindowDays,
            radiusMeters: type == AdCampaignType.geoPush
                ? AdsDefaults.defaultGeoRadiusMeters
                : null,
          ),
      assets: assets,
      createdAt: now,
      updatedAt: now,
    );

    return _repository.upsertCampaign(campaign);
  }

  Future<AdCampaign> saveCampaign(AdCampaign campaign) async {
    final issues = validateCampaign(campaign);
    if (issues.isNotEmpty && campaign.status != CampaignStatus.draft) {
      throw StateError(issues.join(' '));
    }
    return _repository.upsertCampaign(
      campaign.copyWith(
        remainingBalance: (campaign.totalBudget - campaign.spentAmount).clamp(
          0,
          campaign.totalBudget,
        ),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<AdCampaign> submitForReview(AdCampaign campaign) async {
    final issues = validateCampaign(campaign);
    if (issues.isNotEmpty) {
      throw StateError(issues.join(' '));
    }
    final updated = campaign.copyWith(
      status: CampaignStatus.pendingReview,
      updatedAt: DateTime.now(),
    );
    return _repository.upsertCampaign(updated);
  }

  Future<AdCampaign?> pauseCampaign(String campaignId) {
    return _repository.setCampaignStatus(campaignId, CampaignStatus.paused);
  }

  Future<AdCampaign?> resumeCampaign(String campaignId) {
    return _repository.setCampaignStatus(campaignId, CampaignStatus.active);
  }

  Future<AdCampaign?> stopCampaign(String campaignId) {
    return _repository.setCampaignStatus(campaignId, CampaignStatus.stopped);
  }

  Future<void> deleteCampaign(String campaignId) {
    return _repository.deleteCampaign(campaignId);
  }

  List<AdCampaignType> getRecommendedTypes(CampaignObjective objective) {
    return AdCampaignHelper.recommendedTypesForObjective(objective);
  }

  List<AdCampaignType> getAvailableTypes(CampaignObjective objective) {
    return AdCampaignHelper.supportedTypesForObjective(objective);
  }
}
