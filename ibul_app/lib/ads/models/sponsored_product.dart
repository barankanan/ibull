import '../enums/ad_enums.dart';
import '../helpers/ad_json_helper.dart';

class SponsoredProduct {
  const SponsoredProduct({
    required this.campaignId,
    required this.productId,
    required this.sellerId,
    required this.score,
    this.bidAmount = 0,
    this.boostFactor = 1,
    this.placements = const [],
    this.label,
    this.imageUrl,
    this.metadata = const {},
  });

  final String campaignId;
  final String productId;
  final String sellerId;
  final double score;
  final double bidAmount;
  final double boostFactor;
  final List<AdPlacement> placements;
  final String? label;
  final String? imageUrl;
  final Map<String, dynamic> metadata;

  factory SponsoredProduct.fromJson(Map<String, dynamic> json) {
    return SponsoredProduct(
      campaignId: AdJsonHelper.asString(json['campaign_id']),
      productId: AdJsonHelper.asString(json['product_id']),
      sellerId: AdJsonHelper.asString(json['seller_id']),
      score: AdJsonHelper.asDouble(json['score']),
      bidAmount: AdJsonHelper.asDouble(json['bid_amount']),
      boostFactor: AdJsonHelper.asDouble(json['boost_factor'], fallback: 1),
      placements: AdJsonHelper.asStringList(
        json['placements'],
      ).map(AdPlacementParser.fromDbValue).toList(growable: false),
      label: AdJsonHelper.asNullableString(json['label']),
      imageUrl: AdJsonHelper.asNullableString(json['image_url']),
      metadata: AdJsonHelper.asMap(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'campaign_id': campaignId,
      'product_id': productId,
      'seller_id': sellerId,
      'score': score,
      'bid_amount': bidAmount,
      'boost_factor': boostFactor,
      'placements': placements.map((item) => item.dbValue).toList(),
      'label': label,
      'image_url': imageUrl,
      'metadata': metadata,
    };
  }
}
