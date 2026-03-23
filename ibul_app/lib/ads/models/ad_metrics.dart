import '../helpers/ad_json_helper.dart';

class AdMetrics {
  const AdMetrics({
    required this.campaignId,
    required this.date,
    this.impressions = 0,
    this.clicks = 0,
    this.detailViews = 0,
    this.favorites = 0,
    this.addToCarts = 0,
    this.checkouts = 0,
    this.orders = 0,
    this.storeVisits = 0,
    this.collectionOpens = 0,
    this.notificationsSent = 0,
    this.notificationsOpened = 0,
    this.uniqueUsers = 0,
    this.conversions = 0,
    this.spend = 0,
    this.revenue = 0,
  });

  final String campaignId;
  final DateTime date;
  final int impressions;
  final int clicks;
  final int detailViews;
  final int favorites;
  final int addToCarts;
  final int checkouts;
  final int orders;
  final int storeVisits;
  final int collectionOpens;
  final int notificationsSent;
  final int notificationsOpened;
  final int uniqueUsers;
  final int conversions;
  final double spend;
  final double revenue;

  double get ctr => impressions == 0 ? 0 : clicks / impressions;
  double get conversionRate => clicks == 0 ? 0 : conversions / clicks;
  double get roas => spend == 0 ? 0 : revenue / spend;
  double get cpc => clicks == 0 ? 0 : spend / clicks;
  double get cpm => impressions == 0 ? 0 : (spend / impressions) * 1000;
  double get frequencyProxy => uniqueUsers == 0 ? 0 : impressions / uniqueUsers;
  double get spendProgress =>
      revenue == 0 ? 0 : (spend / revenue).clamp(0.0, 5.0);
  double get engagementRate => impressions == 0
      ? 0
      : (clicks + favorites + addToCarts + checkouts) / impressions;

  factory AdMetrics.fromJson(Map<String, dynamic> json) {
    return AdMetrics(
      campaignId: AdJsonHelper.asString(json['campaign_id']),
      date:
          AdJsonHelper.asDateTime(json['metric_date'] ?? json['date']) ??
          DateTime.now(),
      impressions: AdJsonHelper.asInt(json['impressions']),
      clicks: AdJsonHelper.asInt(json['clicks']),
      detailViews: AdJsonHelper.asInt(json['detail_views']),
      favorites: AdJsonHelper.asInt(json['favorites']),
      addToCarts: AdJsonHelper.asInt(json['add_to_carts']),
      checkouts: AdJsonHelper.asInt(json['checkouts']),
      orders: AdJsonHelper.asInt(json['orders']),
      storeVisits: AdJsonHelper.asInt(json['store_visits']),
      collectionOpens: AdJsonHelper.asInt(json['collection_opens']),
      notificationsSent: AdJsonHelper.asInt(json['notifications_sent']),
      notificationsOpened: AdJsonHelper.asInt(json['notifications_opened']),
      uniqueUsers: AdJsonHelper.asInt(json['unique_users']),
      conversions: AdJsonHelper.asInt(json['conversions']),
      spend: AdJsonHelper.asDouble(json['spend']),
      revenue: AdJsonHelper.asDouble(json['revenue']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'campaign_id': campaignId,
      'metric_date': date.toUtc().toIso8601String(),
      'impressions': impressions,
      'clicks': clicks,
      'detail_views': detailViews,
      'favorites': favorites,
      'add_to_carts': addToCarts,
      'checkouts': checkouts,
      'orders': orders,
      'store_visits': storeVisits,
      'collection_opens': collectionOpens,
      'notifications_sent': notificationsSent,
      'notifications_opened': notificationsOpened,
      'unique_users': uniqueUsers,
      'conversions': conversions,
      'spend': spend,
      'revenue': revenue,
    };
  }

  AdMetrics copyWith({
    String? campaignId,
    DateTime? date,
    int? impressions,
    int? clicks,
    int? detailViews,
    int? favorites,
    int? addToCarts,
    int? checkouts,
    int? orders,
    int? storeVisits,
    int? collectionOpens,
    int? notificationsSent,
    int? notificationsOpened,
    int? uniqueUsers,
    int? conversions,
    double? spend,
    double? revenue,
  }) {
    return AdMetrics(
      campaignId: campaignId ?? this.campaignId,
      date: date ?? this.date,
      impressions: impressions ?? this.impressions,
      clicks: clicks ?? this.clicks,
      detailViews: detailViews ?? this.detailViews,
      favorites: favorites ?? this.favorites,
      addToCarts: addToCarts ?? this.addToCarts,
      checkouts: checkouts ?? this.checkouts,
      orders: orders ?? this.orders,
      storeVisits: storeVisits ?? this.storeVisits,
      collectionOpens: collectionOpens ?? this.collectionOpens,
      notificationsSent: notificationsSent ?? this.notificationsSent,
      notificationsOpened: notificationsOpened ?? this.notificationsOpened,
      uniqueUsers: uniqueUsers ?? this.uniqueUsers,
      conversions: conversions ?? this.conversions,
      spend: spend ?? this.spend,
      revenue: revenue ?? this.revenue,
    );
  }
}
