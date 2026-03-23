import '../enums/ad_enums.dart';
import '../helpers/ad_json_helper.dart';

class SponsoredStore {
  const SponsoredStore({
    required this.campaignId,
    required this.storeId,
    required this.sellerId,
    required this.score,
    this.bidAmount = 0,
    this.boostFactor = 1,
    this.placements = const [],
    this.headline,
    this.logoUrl,
    this.distanceKm,
    this.metadata = const {},
  });

  final String campaignId;
  final String storeId;
  final String sellerId;
  final double score;
  final double bidAmount;
  final double boostFactor;
  final List<AdPlacement> placements;
  final String? headline;
  final String? logoUrl;
  final double? distanceKm;
  final Map<String, dynamic> metadata;

  factory SponsoredStore.fromJson(Map<String, dynamic> json) {
    return SponsoredStore(
      campaignId: AdJsonHelper.asString(json['campaign_id']),
      storeId: AdJsonHelper.asString(json['store_id']),
      sellerId: AdJsonHelper.asString(json['seller_id']),
      score: AdJsonHelper.asDouble(json['score']),
      bidAmount: AdJsonHelper.asDouble(json['bid_amount']),
      boostFactor: AdJsonHelper.asDouble(json['boost_factor'], fallback: 1),
      placements: AdJsonHelper.asStringList(
        json['placements'],
      ).map(AdPlacementParser.fromDbValue).toList(growable: false),
      headline: AdJsonHelper.asNullableString(json['headline']),
      logoUrl: AdJsonHelper.asNullableString(json['logo_url']),
      distanceKm: json['distance_km'] == null
          ? null
          : AdJsonHelper.asDouble(json['distance_km']),
      metadata: AdJsonHelper.asMap(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'campaign_id': campaignId,
      'store_id': storeId,
      'seller_id': sellerId,
      'score': score,
      'bid_amount': bidAmount,
      'boost_factor': boostFactor,
      'placements': placements.map((item) => item.dbValue).toList(),
      'headline': headline,
      'logo_url': logoUrl,
      'distance_km': distanceKm,
      'metadata': metadata,
    };
  }
}
