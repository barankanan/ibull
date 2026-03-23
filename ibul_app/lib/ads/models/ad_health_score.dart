import '../helpers/ad_json_helper.dart';

class AdHealthScore {
  const AdHealthScore({
    required this.campaignId,
    required this.score,
    required this.budgetPacingScore,
    required this.creativeScore,
    required this.targetingScore,
    required this.conversionScore,
    required this.fatigueScore,
    required this.reviewStatusScore,
    required this.reasons,
    required this.generatedAt,
  });

  final String campaignId;
  final int score;
  final int budgetPacingScore;
  final int creativeScore;
  final int targetingScore;
  final int conversionScore;
  final int fatigueScore;
  final int reviewStatusScore;
  final List<String> reasons;
  final DateTime generatedAt;

  factory AdHealthScore.fromJson(Map<String, dynamic> json) {
    return AdHealthScore(
      campaignId: AdJsonHelper.asString(json['campaign_id']),
      score: AdJsonHelper.asInt(json['score']),
      budgetPacingScore: AdJsonHelper.asInt(json['budget_pacing_score']),
      creativeScore: AdJsonHelper.asInt(json['creative_score']),
      targetingScore: AdJsonHelper.asInt(json['targeting_score']),
      conversionScore: AdJsonHelper.asInt(json['conversion_score']),
      fatigueScore: AdJsonHelper.asInt(json['fatigue_score']),
      reviewStatusScore: AdJsonHelper.asInt(json['review_status_score']),
      reasons: AdJsonHelper.asStringList(json['reasons']),
      generatedAt:
          AdJsonHelper.asDateTime(json['generated_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'campaign_id': campaignId,
      'score': score,
      'budget_pacing_score': budgetPacingScore,
      'creative_score': creativeScore,
      'targeting_score': targetingScore,
      'conversion_score': conversionScore,
      'fatigue_score': fatigueScore,
      'review_status_score': reviewStatusScore,
      'reasons': reasons,
      'generated_at': generatedAt.toUtc().toIso8601String(),
    };
  }
}
