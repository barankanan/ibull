import '../helpers/ad_json_helper.dart';

class UserInterest {
  const UserInterest({
    required this.userId,
    required this.interestKey,
    required this.interestType,
    required this.affinityScore,
    this.sourceEventCount = 0,
    this.lastInteractionAt,
    this.metadata = const {},
  });

  final String userId;
  final String interestKey;
  final String interestType;
  final double affinityScore;
  final int sourceEventCount;
  final DateTime? lastInteractionAt;
  final Map<String, dynamic> metadata;

  factory UserInterest.fromJson(Map<String, dynamic> json) {
    return UserInterest(
      userId: AdJsonHelper.asString(json['user_id']),
      interestKey: AdJsonHelper.asString(json['interest_key']),
      interestType: AdJsonHelper.asString(json['interest_type']),
      affinityScore: AdJsonHelper.asDouble(json['affinity_score']),
      sourceEventCount: AdJsonHelper.asInt(json['source_event_count']),
      lastInteractionAt: AdJsonHelper.asDateTime(json['last_interaction_at']),
      metadata: AdJsonHelper.asMap(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'interest_key': interestKey,
      'interest_type': interestType,
      'affinity_score': affinityScore,
      'source_event_count': sourceEventCount,
      'last_interaction_at': lastInteractionAt?.toUtc().toIso8601String(),
      'metadata': metadata,
    };
  }
}
