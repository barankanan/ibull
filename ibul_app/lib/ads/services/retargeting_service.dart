import '../enums/ad_enums.dart';
import '../helpers/retargeting_helper.dart';
import '../helpers/user_interest_engine_helper.dart';
import '../models/ad_campaign.dart';
import '../models/retargeting_recommendation.dart';
import '../models/user_interest.dart';
import '../models/user_product_event.dart';
import '../repositories/ads_repository.dart';

class RetargetingService {
  RetargetingService({AdsRepository? repository})
    : _repository = repository ?? AdsRepository();

  final AdsRepository _repository;

  Future<List<UserInterest>> getUserInterestProfile(String userId) async {
    final stored = await _repository.getUserInterests(userId: userId);
    final events = await getRetargetableEvents(userId, lookbackDays: 30);
    return UserInterestEngineHelper.buildInterestProfile(
      userId: userId,
      events: events,
      existing: stored,
    );
  }

  Future<List<UserProductEvent>> getRetargetableEvents(
    String userId, {
    int lookbackDays = 14,
  }) {
    return _repository.getUserEvents(
      userId: userId,
      from: DateTime.now().subtract(Duration(days: lookbackDays)),
    );
  }

  Future<Set<String>> getRetargetableEntityIds(
    String userId, {
    int lookbackDays = 14,
  }) async {
    final events = await getRetargetableEvents(
      userId,
      lookbackDays: lookbackDays,
    );
    final ids = <String>{};
    for (final event in events) {
      if ((event.productId ?? '').isNotEmpty) ids.add(event.productId!);
      if ((event.storeId ?? '').isNotEmpty) ids.add(event.storeId!);
      if ((event.collectionId ?? '').isNotEmpty) ids.add(event.collectionId!);
    }
    return ids;
  }

  Future<Map<String, double>> getInterestWeights(String userId) async {
    final interests = await getUserInterestProfile(userId);
    final result = <String, double>{};
    for (final interest in interests) {
      result[interest.interestKey] = interest.affinityScore;
    }
    return result;
  }

  Future<Set<RetargetingSegment>> resolveSegments(
    String userId, {
    int lookbackDays = 45,
  }) async {
    final events = await getRetargetableEvents(
      userId,
      lookbackDays: lookbackDays,
    );
    return RetargetingHelper.resolveSegments(events);
  }

  Future<bool> isCampaignEligible({
    required String userId,
    required AdCampaign campaign,
    int lookbackDays = 45,
  }) async {
    final events = await getRetargetableEvents(
      userId,
      lookbackDays: lookbackDays,
    );
    final segments = RetargetingHelper.resolveSegments(events);
    return RetargetingHelper.isCampaignEligible(
      campaign: campaign,
      segments: segments,
      events: events,
    );
  }

  Future<List<RetargetingRecommendation>> buildRecommendations(
    String userId, {
    int lookbackDays = 45,
  }) async {
    final events = await getRetargetableEvents(
      userId,
      lookbackDays: lookbackDays,
    );
    final segments = RetargetingHelper.resolveSegments(events);
    return RetargetingHelper.buildRecommendations(
      segments: segments,
      events: events,
    );
  }
}
