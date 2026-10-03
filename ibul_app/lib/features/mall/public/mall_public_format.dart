import 'mall_public_repository.dart';

/// UI labels only. Backend floor names stay unchanged.
String mallFloorPresentationLabel(MallPublicFloor floor) {
  final level = floor.levelNumber;
  final raw = floor.name.trim();
  if (level != null) {
    if (level <= -1) {
      final basement = 'B${level.abs()}';
      return _looksLikeParking(raw) && level == -1 ? '$basement / Otopark' : basement;
    }
    if (level == 0) return 'Zemin Kat';
    return '$level. Kat';
  }
  return mallFloorLabelFromName(raw);
}

String mallFloorChipLabel(MallPublicFloor floor) {
  final full = mallFloorPresentationLabel(floor);
  if (full == 'Zemin Kat') return 'Zemin';
  return full;
}

String mallFloorLabelFromName(String raw) {
  final compact = raw.toLowerCase().replaceAll(' ', '');
  final basement = RegExp(r'-?\s*(\d+)').firstMatch(raw);
  if (compact.contains('otopark') && compact.contains('-2')) return 'B2';
  if (compact.contains('otopark') || compact == 'b1') {
    return basement != null && basement.group(1) == '2' ? 'B2' : 'B1 / Otopark';
  }
  if (compact.contains('zemin')) return 'Zemin Kat';
  final dotted = RegExp(r'(\d+)\s*\.?\s*kat').firstMatch(compact);
  if (dotted != null) return '${dotted.group(1)}. Kat';
  return raw;
}

String mallPlaceLabel(MallPublicDetail detail) =>
    [detail.city, detail.district].whereType<String>().where((part) => part.trim().isNotEmpty).join(' • ');

String mallCountLine(int floors, int stores) => '$floors kat • $stores mağaza';

/// Compact status for the mall card, for example `Açık • 08:00 – 22:00`.
String mallHoursCompactLine(MallHoursPresentation hours) {
  if (hours.isOpen == true) return 'Açık • ${hours.range}';
  if (hours.isOpen == false) return 'Kapalı • ${hours.range}';
  return hours.range;
}

class MallHoursPresentation {
  const MallHoursPresentation({required this.range, this.openUntil, this.isOpen});

  final String range;
  final String? openUntil;
  final bool? isOpen;

  String? get statusLine {
    if (isOpen == true && openUntil != null) return 'Açık • $openUntil\'ye kadar';
    if (isOpen == true) return 'Açık';
    if (isOpen == false) return 'Kapalı';
    return null;
  }
}

MallHoursPresentation? mallHoursPresentation(String? raw, {DateTime? now}) {
  final text = raw?.trim();
  if (text == null || text.isEmpty) return null;
  final match = RegExp(r'(\d{1,2})[:.](\d{2})\s*[-–]\s*(\d{1,2})[:.](\d{2})').firstMatch(text);
  if (match == null) return MallHoursPresentation(range: text);
  final open = Duration(hours: int.parse(match.group(1)!), minutes: int.parse(match.group(2)!));
  final close = Duration(hours: int.parse(match.group(3)!), minutes: int.parse(match.group(4)!));
  final clock = now ?? DateTime.now();
  final current = Duration(hours: clock.hour, minutes: clock.minute);
  final openNow = close <= open
      ? current >= open || current < close
      : current >= open && current < close;
  final closeLabel = '${match.group(3)!.padLeft(2, '0')}:${match.group(4)}';
  return MallHoursPresentation(
    range: '${match.group(1)!.padLeft(2, '0')}:${match.group(2)} – $closeLabel',
    openUntil: closeLabel,
    isOpen: openNow,
  );
}

String mallInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return 'A';
  if (parts.length == 1) {
    final text = parts.first;
    return text.substring(0, text.length < 2 ? text.length : 2).toUpperCase();
  }
  return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
}

bool _looksLikeParking(String raw) => raw.toLowerCase().contains('otopark');
