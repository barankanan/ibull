import '../helpers/ab_test_helper.dart';
import '../models/ab_test_variant.dart';
import '../repositories/ads_repository.dart';

class AbTestingService {
  AbTestingService({AdsRepository? repository})
    : _repository = repository ?? AdsRepository();

  final AdsRepository _repository;

  Future<List<AbTestVariant>> getVariants(String campaignId) {
    return _repository.getAbTestVariants(campaignId);
  }

  Future<AbTestVariant?> resolveVariant({
    required String campaignId,
    required String userId,
  }) async {
    final variants = await getVariants(campaignId);
    return AbTestHelper.resolveVariant(
      seed: '$campaignId:$userId',
      variants: variants,
    );
  }

  Future<Map<String, double>> getImpressionSplit(String campaignId) async {
    final variants = await getVariants(campaignId);
    return AbTestHelper.impressionSplit(variants);
  }

  Future<AbTestVariant?> getWinner(String campaignId) async {
    final variants = await getVariants(campaignId);
    return AbTestHelper.winner(variants: variants);
  }

  Future<List<Map<String, dynamic>>> comparePerformance(
    String campaignId,
  ) async {
    final variants = await getVariants(campaignId);
    return AbTestHelper.comparePerformance(variants);
  }
}
