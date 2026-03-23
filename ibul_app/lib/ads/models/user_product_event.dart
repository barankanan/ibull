import '../enums/ad_enums.dart';
import '../helpers/ad_json_helper.dart';

class UserProductEvent {
  const UserProductEvent({
    required this.id,
    required this.userId,
    required this.eventType,
    required this.createdAt,
    this.productId,
    this.storeId,
    this.collectionId,
    this.sourcePlacement,
    this.campaignId,
    this.quantity = 1,
    this.cityCode,
    this.latitude,
    this.longitude,
    this.metadata = const {},
  });

  final String id;
  final String userId;
  final String? productId;
  final String? storeId;
  final String? collectionId;
  final UserEventType eventType;
  final AdPlacement? sourcePlacement;
  final String? campaignId;
  final int quantity;
  final String? cityCode;
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  factory UserProductEvent.fromJson(Map<String, dynamic> json) {
    return UserProductEvent(
      id: AdJsonHelper.asString(json['id']),
      userId: AdJsonHelper.asString(json['user_id']),
      productId: AdJsonHelper.asNullableString(json['product_id']),
      storeId: AdJsonHelper.asNullableString(json['store_id']),
      collectionId: AdJsonHelper.asNullableString(json['collection_id']),
      eventType: UserEventTypeParser.fromDbValue(
        json['event_type']?.toString(),
      ),
      sourcePlacement: json['source_placement'] == null
          ? null
          : AdPlacementParser.fromDbValue(json['source_placement']?.toString()),
      campaignId: AdJsonHelper.asNullableString(json['campaign_id']),
      quantity: AdJsonHelper.asInt(json['quantity'], fallback: 1),
      cityCode: AdJsonHelper.asNullableString(json['city_code']),
      latitude: json['latitude'] == null
          ? null
          : AdJsonHelper.asDouble(json['latitude']),
      longitude: json['longitude'] == null
          ? null
          : AdJsonHelper.asDouble(json['longitude']),
      metadata: AdJsonHelper.asMap(json['metadata']),
      createdAt: AdJsonHelper.asDateTime(json['created_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'product_id': productId,
      'store_id': storeId,
      'collection_id': collectionId,
      'event_type': eventType.dbValue,
      'source_placement': sourcePlacement?.dbValue,
      'campaign_id': campaignId,
      'quantity': quantity,
      'city_code': cityCode,
      'latitude': latitude,
      'longitude': longitude,
      'metadata': metadata,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}
