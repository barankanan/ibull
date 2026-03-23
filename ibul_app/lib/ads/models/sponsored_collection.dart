import '../enums/ad_enums.dart';
import '../helpers/ad_json_helper.dart';

class SponsoredCollection {
  const SponsoredCollection({
    required this.campaignId,
    required this.collectionId,
    required this.sellerId,
    required this.score,
    this.bidAmount = 0,
    this.boostFactor = 1,
    this.placements = const [],
    this.title,
    this.coverUrl,
    this.productIds = const [],
    this.metadata = const {},
  });

  final String campaignId;
  final String collectionId;
  final String sellerId;
  final double score;
  final double bidAmount;
  final double boostFactor;
  final List<AdPlacement> placements;
  final String? title;
  final String? coverUrl;
  final List<String> productIds;
  final Map<String, dynamic> metadata;

  factory SponsoredCollection.fromJson(Map<String, dynamic> json) {
    return SponsoredCollection(
      campaignId: AdJsonHelper.asString(json['campaign_id']),
      collectionId: AdJsonHelper.asString(json['collection_id']),
      sellerId: AdJsonHelper.asString(json['seller_id']),
      score: AdJsonHelper.asDouble(json['score']),
      bidAmount: AdJsonHelper.asDouble(json['bid_amount']),
      boostFactor: AdJsonHelper.asDouble(json['boost_factor'], fallback: 1),
      placements: AdJsonHelper.asStringList(
        json['placements'],
      ).map(AdPlacementParser.fromDbValue).toList(growable: false),
      title: AdJsonHelper.asNullableString(json['title']),
      coverUrl: AdJsonHelper.asNullableString(json['cover_url']),
      productIds: AdJsonHelper.asStringList(json['product_ids']),
      metadata: AdJsonHelper.asMap(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'campaign_id': campaignId,
      'collection_id': collectionId,
      'seller_id': sellerId,
      'score': score,
      'bid_amount': bidAmount,
      'boost_factor': boostFactor,
      'placements': placements.map((item) => item.dbValue).toList(),
      'title': title,
      'cover_url': coverUrl,
      'product_ids': productIds,
      'metadata': metadata,
    };
  }
}
