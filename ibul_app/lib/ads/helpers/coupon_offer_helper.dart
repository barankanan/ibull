import '../enums/ad_enums.dart';
import '../models/ad_campaign.dart';
import '../models/user_product_event.dart';

class CouponOfferHelper {
  const CouponOfferHelper._();

  static bool isEligible({
    required AdCampaign campaign,
    required Iterable<UserProductEvent> events,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final metadata = campaign.metadata;
    if (metadata['coupon_enabled'] != true &&
        metadata['offer_enabled'] != true) {
      return false;
    }

    final lookbackDays =
        int.tryParse(metadata['coupon_lookback_days']?.toString() ?? '') ?? 14;
    final cutoff = current.subtract(Duration(days: lookbackDays));
    final relevantEvents = events.where(
      (event) => !event.createdAt.isBefore(cutoff),
    );
    final hasPurchase = relevantEvents.any(
      (event) => event.eventType == UserEventType.purchase,
    );
    if (hasPurchase && metadata['coupon_for_repeat_buyers'] != true) {
      return false;
    }

    final cartAbandoner =
        relevantEvents.any(
          (event) => event.eventType == UserEventType.addToCart,
        ) &&
        !hasPurchase;
    final viewedProduct = relevantEvents.any(
      (event) => event.eventType == UserEventType.detailView,
    );
    final firstOrderCoupon = metadata['first_order_coupon'] == true;
    return cartAbandoner || viewedProduct || firstOrderCoupon;
  }

  static Map<String, dynamic> formatOfferCampaign(AdCampaign campaign) {
    final metadata = campaign.metadata;
    return <String, dynamic>{
      'campaign_id': campaign.id,
      'campaign_name': campaign.name,
      'discount_type': metadata['discount_type'] ?? 'percentage',
      'discount_value': metadata['discount_value'] ?? 10,
      'coupon_code': metadata['coupon_code'] ?? 'SPON10',
      'label': metadata['offer_label'] ?? 'Sponsorlu ozel teklif',
      'trigger': metadata['offer_trigger'] ?? campaign.type.dbValue,
    };
  }

  static String buildPreview({
    required AdCampaign campaign,
    required String storeName,
  }) {
    final offer = formatOfferCampaign(campaign);
    final value = offer['discount_value'];
    final type = offer['discount_type'];
    final discountLabel = type == 'amount' ? '$value TL' : '%$value';
    return '$storeName icin $discountLabel indirim. Kod: ${offer['coupon_code']}';
  }
}
