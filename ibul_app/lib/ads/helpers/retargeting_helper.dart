import '../enums/ad_enums.dart';
import '../models/ad_campaign.dart';
import '../models/retargeting_recommendation.dart';
import '../models/user_product_event.dart';

class RetargetingHelper {
  const RetargetingHelper._();

  static Set<RetargetingSegment> resolveSegments(
    Iterable<UserProductEvent> events, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final eventList = events.toList(growable: false);
    final segments = <RetargetingSegment>{};

    bool hasPurchaseFor({
      String? productId,
      String? storeId,
      String? collectionId,
    }) {
      return eventList.any((event) {
        return event.eventType == UserEventType.purchase &&
            ((productId != null && event.productId == productId) ||
                (storeId != null && event.storeId == storeId) ||
                (collectionId != null && event.collectionId == collectionId));
      });
    }

    for (final event in eventList) {
      if (event.eventType == UserEventType.detailView &&
          !hasPurchaseFor(productId: event.productId)) {
        segments.add(RetargetingSegment.viewedNotPurchased);
      }
      if (event.eventType == UserEventType.addToCart &&
          !hasPurchaseFor(productId: event.productId)) {
        segments.add(RetargetingSegment.cartAbandoned);
      }
      if (event.eventType == UserEventType.storeVisit &&
          !hasPurchaseFor(storeId: event.storeId)) {
        segments.add(RetargetingSegment.storeVisitedNoOrder);
      }
      if (event.eventType == UserEventType.collectionOpen) {
        final hasFollowupClick = eventList.any((candidate) {
          return candidate.collectionId == event.collectionId &&
              candidate.createdAt.isAfter(event.createdAt) &&
              candidate.eventType == UserEventType.click;
        });
        if (!hasFollowupClick) {
          segments.add(RetargetingSegment.collectionViewedNoClick);
        }
      }
    }

    final recent7d = eventList.any(
      (event) =>
          event.createdAt.isAfter(current.subtract(const Duration(days: 7))),
    );
    if (recent7d) {
      segments.add(RetargetingSegment.active7d);
    }

    final recent30d = eventList.any(
      (event) =>
          event.createdAt.isAfter(current.subtract(const Duration(days: 30))),
    );
    if (!recent30d && eventList.isNotEmpty) {
      segments.add(RetargetingSegment.passive30d);
    }

    final totalCartValue = eventList.fold<double>(0, (sum, event) {
      if (event.eventType != UserEventType.addToCart) return sum;
      return sum + ((event.metadata['cart_value'] as num?)?.toDouble() ?? 0);
    });
    if (totalCartValue >= 1500) {
      segments.add(RetargetingSegment.highCartValue);
    }

    final purchaseCount = eventList
        .where(
          (event) =>
              event.eventType == UserEventType.purchase &&
              event.createdAt.isAfter(
                current.subtract(const Duration(days: 60)),
              ),
        )
        .length;
    if (purchaseCount >= 3) {
      segments.add(RetargetingSegment.frequentBuyer);
    }

    return segments;
  }

  static bool isCampaignEligible({
    required AdCampaign campaign,
    required Set<RetargetingSegment> segments,
    required Iterable<UserProductEvent> events,
  }) {
    final metadataSegments =
        (campaign.metadata['retargeting_segments'] as List<dynamic>? ??
                const [])
            .map(
              (item) => RetargetingSegmentParser.fromDbValue(item.toString()),
            )
            .toSet();
    if (metadataSegments.isNotEmpty &&
        metadataSegments.intersection(segments).isEmpty) {
      return false;
    }

    final entityIds = campaign.assets
        .map((asset) => asset.entityId)
        .whereType<String>()
        .toSet();
    if (entityIds.isEmpty) return segments.isNotEmpty;

    for (final event in events) {
      if (entityIds.contains(event.productId) ||
          entityIds.contains(event.storeId) ||
          entityIds.contains(event.collectionId)) {
        return true;
      }
    }
    return metadataSegments.isEmpty ? segments.isNotEmpty : false;
  }

  static List<RetargetingRecommendation> buildRecommendations({
    required Set<RetargetingSegment> segments,
    required Iterable<UserProductEvent> events,
  }) {
    final entityIds = <String>{
      for (final event in events) ...[
        if ((event.productId ?? '').isNotEmpty) event.productId!,
        if ((event.storeId ?? '').isNotEmpty) event.storeId!,
        if ((event.collectionId ?? '').isNotEmpty) event.collectionId!,
      ],
    };

    final recommendations = <RetargetingRecommendation>[];
    if (segments.contains(RetargetingSegment.cartAbandoned)) {
      recommendations.add(
        RetargetingRecommendation(
          segment: RetargetingSegment.cartAbandoned,
          reason: 'Sepete eklenen urunler satin almaya donusmemis.',
          priorityScore: 0.96,
          suggestedCampaignType: AdCampaignType.productBoost,
          entityIds: entityIds.toList(growable: false),
        ),
      );
    }
    if (segments.contains(RetargetingSegment.storeVisitedNoOrder)) {
      recommendations.add(
        RetargetingRecommendation(
          segment: RetargetingSegment.storeVisitedNoOrder,
          reason: 'Magaza ziyareti var ancak siparis yok.',
          priorityScore: 0.82,
          suggestedCampaignType: AdCampaignType.storeBoost,
          entityIds: entityIds.toList(growable: false),
        ),
      );
    }
    if (segments.contains(RetargetingSegment.collectionViewedNoClick)) {
      recommendations.add(
        RetargetingRecommendation(
          segment: RetargetingSegment.collectionViewedNoClick,
          reason: 'Liste goruldu ancak derin etkilesim dusuk kaldi.',
          priorityScore: 0.71,
          suggestedCampaignType: AdCampaignType.collectionBoost,
          entityIds: entityIds.toList(growable: false),
        ),
      );
    }
    if (segments.contains(RetargetingSegment.highCartValue)) {
      recommendations.add(
        RetargetingRecommendation(
          segment: RetargetingSegment.highCartValue,
          reason: 'Yuksek sepet degeri olan kullanici icin ozel teklif uygun.',
          priorityScore: 0.9,
          suggestedCampaignType: AdCampaignType.geoPush,
          entityIds: entityIds.toList(growable: false),
        ),
      );
    }
    return recommendations
      ..sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
  }
}
