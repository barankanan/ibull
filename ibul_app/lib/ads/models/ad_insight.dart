import '../helpers/ad_json_helper.dart';

class AdInsight {
  const AdInsight({
    required this.id,
    required this.campaignId,
    required this.title,
    required this.description,
    required this.value,
    required this.deltaPercentage,
    required this.severity,
    required this.actionLabel,
    this.metadata = const {},
  });

  final String id;
  final String campaignId;
  final String title;
  final String description;
  final double value;
  final double deltaPercentage;
  final String severity;
  final String actionLabel;
  final Map<String, dynamic> metadata;

  factory AdInsight.fromJson(Map<String, dynamic> json) {
    return AdInsight(
      id: AdJsonHelper.asString(json['id']),
      campaignId: AdJsonHelper.asString(json['campaign_id']),
      title: AdJsonHelper.asString(json['title']),
      description: AdJsonHelper.asString(json['description']),
      value: AdJsonHelper.asDouble(json['value']),
      deltaPercentage: AdJsonHelper.asDouble(json['delta_percentage']),
      severity: AdJsonHelper.asString(json['severity']),
      actionLabel: AdJsonHelper.asString(json['action_label']),
      metadata: AdJsonHelper.asMap(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'campaign_id': campaignId,
      'title': title,
      'description': description,
      'value': value,
      'delta_percentage': deltaPercentage,
      'severity': severity,
      'action_label': actionLabel,
      'metadata': metadata,
    };
  }
}
