import '../helpers/ad_json_helper.dart';

class CampaignSchedule {
  const CampaignSchedule({
    required this.timezone,
    this.startHour = 0,
    this.endHour = 23,
    this.activeWeekdays = const [1, 2, 3, 4, 5, 6, 7],
    this.runWeekdays = true,
    this.runWeekends = true,
    this.category = 'general',
    this.metadata = const {},
  });

  final String timezone;
  final int startHour;
  final int endHour;
  final List<int> activeWeekdays;
  final bool runWeekdays;
  final bool runWeekends;
  final String category;
  final Map<String, dynamic> metadata;

  factory CampaignSchedule.fromJson(Map<String, dynamic> json) {
    return CampaignSchedule(
      timezone: AdJsonHelper.asString(
        json['timezone'],
        fallback: 'Europe/Istanbul',
      ),
      startHour: AdJsonHelper.asInt(json['start_hour']),
      endHour: AdJsonHelper.asInt(json['end_hour'], fallback: 23),
      activeWeekdays:
          (json['active_weekdays'] as List<dynamic>? ??
                  const [1, 2, 3, 4, 5, 6, 7])
              .map((item) => AdJsonHelper.asInt(item))
              .toList(growable: false),
      runWeekdays: AdJsonHelper.asBool(json['run_weekdays'], fallback: true),
      runWeekends: AdJsonHelper.asBool(json['run_weekends'], fallback: true),
      category: AdJsonHelper.asString(json['category'], fallback: 'general'),
      metadata: AdJsonHelper.asMap(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timezone': timezone,
      'start_hour': startHour,
      'end_hour': endHour,
      'active_weekdays': activeWeekdays,
      'run_weekdays': runWeekdays,
      'run_weekends': runWeekends,
      'category': category,
      'metadata': metadata,
    };
  }
}
