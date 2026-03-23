import '../models/campaign_schedule.dart';
import '../models/user_product_event.dart';

class CampaignScheduleHelper {
  const CampaignScheduleHelper._();

  static const Map<String, List<int>> _categoryHours = <String, List<int>>{
    'electronics': <int>[12, 13, 20, 21],
    'ayakkabi & canta': <int>[18, 19, 20, 21],
    'saat & aksesuar': <int>[19, 20, 21],
    'ev & yasam': <int>[10, 11, 20],
    'otel': <int>[9, 12, 18],
    'restoran': <int>[12, 13, 19, 20],
    'general': <int>[12, 18, 20, 21],
  };

  static CampaignSchedule fromMetadata(Map<String, dynamic> metadata) {
    final raw = metadata['schedule'];
    if (raw is Map<String, dynamic>) {
      return CampaignSchedule.fromJson(raw);
    }
    if (raw is Map) {
      return CampaignSchedule.fromJson(Map<String, dynamic>.from(raw));
    }
    return const CampaignSchedule(timezone: 'Europe/Istanbul');
  }

  static bool isActiveAt(CampaignSchedule schedule, DateTime at) {
    final weekday = at.weekday;
    final isWeekend =
        weekday == DateTime.saturday || weekday == DateTime.sunday;
    if (!schedule.activeWeekdays.contains(weekday)) {
      return false;
    }
    if (isWeekend && !schedule.runWeekends) {
      return false;
    }
    if (!isWeekend && !schedule.runWeekdays) {
      return false;
    }
    final hour = at.hour;
    if (schedule.startHour <= schedule.endHour) {
      return hour >= schedule.startHour && hour <= schedule.endHour;
    }
    return hour >= schedule.startHour || hour <= schedule.endHour;
  }

  static List<String> preview(CampaignSchedule schedule) {
    final labels = <String>[
      '${schedule.startHour.toString().padLeft(2, '0')}:00 - ${schedule.endHour.toString().padLeft(2, '0')}:00',
      schedule.runWeekdays ? 'hafta ici acik' : 'hafta ici kapali',
      schedule.runWeekends ? 'hafta sonu acik' : 'hafta sonu kapali',
    ];
    if (schedule.activeWeekdays.length != 7) {
      labels.add('aktif gunler: ${schedule.activeWeekdays.join(', ')}');
    }
    return labels;
  }

  static List<int> bestHourSuggestions({
    required String category,
    Iterable<UserProductEvent> recentEvents = const [],
  }) {
    final eventCounts = <int, int>{};
    for (final event in recentEvents) {
      eventCounts[event.createdAt.hour] =
          (eventCounts[event.createdAt.hour] ?? 0) + 1;
    }
    if (eventCounts.isNotEmpty) {
      final sorted = eventCounts.entries.toList(growable: false)
        ..sort((a, b) => b.value.compareTo(a.value));
      return sorted.take(4).map((entry) => entry.key).toList(growable: false);
    }
    return _categoryHours[category.trim().toLowerCase()] ??
        _categoryHours['general']!;
  }
}
