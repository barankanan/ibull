import '../enums/ad_enums.dart';
import '../models/ad_campaign.dart';
import '../models/ad_metrics.dart';
import '../models/funnel_metrics.dart';

class FunnelHelper {
  const FunnelHelper._();

  static double ctr(AdMetrics metrics) => metrics.ctr;

  static double cpc(AdMetrics metrics) => metrics.cpc;

  static double cpm(AdMetrics metrics) => metrics.cpm;

  static double conversionRate(AdMetrics metrics) => metrics.conversionRate;

  static double spendProgress({
    required double spent,
    required double totalBudget,
  }) {
    if (totalBudget <= 0) return 0;
    return (spent / totalBudget).clamp(0.0, 1.0);
  }

  static double remainingBudget({
    required double totalBudget,
    required double spent,
  }) {
    return (totalBudget - spent).clamp(0.0, totalBudget);
  }

  static FunnelMetrics buildFunnel({
    required String campaignId,
    required AdMetrics metrics,
    int windowDays = 30,
  }) {
    final awareness = metrics.impressions;
    final consideration = metrics.clicks;
    final intent = metrics.detailViews + metrics.favorites + metrics.addToCarts;
    final checkout = metrics.checkouts;
    final conversion = metrics.orders;
    final retention = metrics.notificationsOpened;
    final dropOffRate = awareness == 0
        ? 0.0
        : (1 - (conversion / awareness)).clamp(0.0, 1.0);

    return FunnelMetrics(
      campaignId: campaignId,
      awarenessCount: awareness,
      considerationCount: consideration,
      intentCount: intent,
      checkoutCount: checkout,
      conversionCount: conversion,
      retentionCount: retention,
      dropOffRate: dropOffRate,
      windowDays: windowDays,
      updatedAt: DateTime.now(),
    );
  }

  static Map<String, double> buildChain(FunnelMetrics funnel) {
    final awareness = funnel.awarenessCount.toDouble();
    final consideration = funnel.considerationCount.toDouble();
    final intent = funnel.intentCount.toDouble();
    final checkout = funnel.checkoutCount.toDouble();
    final conversion = funnel.conversionCount.toDouble();
    return {
      'impression_to_click': awareness == 0 ? 0 : consideration / awareness,
      'click_to_intent': consideration == 0 ? 0 : intent / consideration,
      'intent_to_checkout': intent == 0 ? 0 : checkout / intent,
      'checkout_to_order': checkout == 0 ? 0 : conversion / checkout,
    };
  }

  static CampaignStatus resolveStatus(AdCampaign campaign, {DateTime? now}) {
    final current = now ?? DateTime.now();
    if (campaign.status == CampaignStatus.rejected ||
        campaign.status == CampaignStatus.archived ||
        campaign.status == CampaignStatus.stopped) {
      return campaign.status;
    }
    if (campaign.remainingBalance <= 0 ||
        campaign.spentAmount >= campaign.totalBudget) {
      return CampaignStatus.completed;
    }
    if (campaign.startsAt.isAfter(current)) {
      return CampaignStatus.scheduled;
    }
    if (campaign.endsAt.isBefore(current)) {
      return CampaignStatus.completed;
    }
    if (campaign.status == CampaignStatus.paused) {
      return CampaignStatus.paused;
    }
    if (campaign.status == CampaignStatus.pendingReview) {
      return CampaignStatus.pendingReview;
    }
    return CampaignStatus.active;
  }
}
