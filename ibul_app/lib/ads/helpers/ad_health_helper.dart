import '../models/ad_health_score.dart';
import '../models/ad_metrics.dart';

class AdHealthHelper {
  const AdHealthHelper._();

  static AdHealthScore calculate({
    required String campaignId,
    required AdMetrics metrics,
    required bool isPendingReview,
    double qualityScore = 0.7,
    double fatigueScore = 0.0,
  }) {
    final ctrScore = (metrics.ctr / 0.03 * 100).clamp(10, 100).round();
    final conversionScore = (metrics.conversionRate / 0.08 * 100)
        .clamp(10, 100)
        .round();
    final cpcEfficiencyScore = metrics.cpc == 0
        ? 30
        : (100 - ((metrics.cpc / 12) * 100)).clamp(10, 100).round();
    final repetitionScore = (100 - ((fatigueScore / 3) * 100))
        .clamp(10, 100)
        .round();
    final qualityComponent = (qualityScore * 100).clamp(10, 100).round();
    final engagementScore = (metrics.engagementRate / 0.12 * 100)
        .clamp(10, 100)
        .round();
    final reviewStatusScore = isPendingReview ? 35 : 100;
    final totalScore =
        ((ctrScore +
                    conversionScore +
                    cpcEfficiencyScore +
                    repetitionScore +
                    qualityComponent +
                    engagementScore +
                    reviewStatusScore) /
                7)
            .round();

    return AdHealthScore(
      campaignId: campaignId,
      score: totalScore,
      budgetPacingScore: cpcEfficiencyScore,
      creativeScore: ctrScore,
      targetingScore: qualityComponent,
      conversionScore: conversionScore,
      fatigueScore: repetitionScore,
      reviewStatusScore: reviewStatusScore,
      reasons: generateWarnings(
        metrics: metrics,
        fatigueScore: fatigueScore,
        qualityScore: qualityScore,
        isPendingReview: isPendingReview,
      ),
      generatedAt: DateTime.now(),
    );
  }

  static String labelForScore(int score) {
    if (score >= 85) return 'cok iyi';
    if (score >= 70) return 'iyi';
    if (score >= 50) return 'gelistirilmeli';
    return 'zayif';
  }

  static List<String> generateWarnings({
    required AdMetrics metrics,
    required double fatigueScore,
    required double qualityScore,
    required bool isPendingReview,
  }) {
    final warnings = <String>[];
    if (metrics.ctr < 0.012) {
      warnings.add('CTR dusuk, gorsel ve baslik yenilenmeli.');
    }
    if (metrics.conversionRate < 0.02) {
      warnings.add(
        'Tiklamadan siparise gecis zayif, retargeting penceresi daraltin.',
      );
    }
    if (metrics.cpc > 8) {
      warnings.add(
        'CPC yukselmis, hedefleme ve teklif stratejisini optimize edin.',
      );
    }
    if (fatigueScore > 1.7) {
      warnings.add(
        'Ayni kullanicilara fazla tekrar var, frequency cap dusurulmeli.',
      );
    }
    if (qualityScore < 0.45) {
      warnings.add(
        'Reklam kalitesi dusuk, landing ve kreatif uyumu artirilmali.',
      );
    }
    if (isPendingReview) {
      warnings.add('Kampanya admin onayi bekliyor.');
    }
    return warnings;
  }
}
