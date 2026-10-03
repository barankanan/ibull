import '../../../../utils/text_normalizer.dart';

class MallFloor {
  const MallFloor({
    required this.id,
    required this.mallId,
    required this.name,
    required this.sortOrder,
    this.levelNumber,
    this.isActive = true,
    this.planUrl,
    this.unitCount = 0,
  });

  final String id;
  final String mallId;
  final String name;
  final int? levelNumber;
  final int sortOrder;
  final bool isActive;
  final String? planUrl;
  final int unitCount;

  bool get hasPlan => planUrl?.trim().isNotEmpty ?? false;

  /// Short level badge: B2, B1, Z, 1, 2.
  String get shortLabel {
    final level = levelNumber;
    if (level == null) return name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase();
    if (level < 0) return 'B${-level}';
    if (level == 0) return 'Z';
    return '$level';
  }

  MallFloor copyWith({int? unitCount}) {
    return MallFloor(
      id: id,
      mallId: mallId,
      name: name,
      levelNumber: levelNumber,
      sortOrder: sortOrder,
      isActive: isActive,
      planUrl: planUrl,
      unitCount: unitCount ?? this.unitCount,
    );
  }

  factory MallFloor.fromMap(Map<String, dynamic> map) {
    final plan = map['plan_url']?.toString().trim() ?? '';
    return MallFloor(
      id: map['id'].toString(),
      mallId: map['mall_id'].toString(),
      name: map['name']?.toString() ?? '',
      levelNumber: map['level_number'] == null
          ? null
          : int.tryParse(map['level_number'].toString()),
      sortOrder: int.tryParse(map['sort_order']?.toString() ?? '') ?? 0,
      isActive: map['is_active'] != false,
      planUrl: plan.isEmpty ? null : plan,
    );
  }
}

class MallFloorDraft {
  const MallFloorDraft({
    required this.name,
    required this.sortOrder,
    this.levelNumber,
  });

  final String name;
  final int? levelNumber;
  final int sortOrder;
}

/// Floor levels: -2 B2, -1 B1, 0 Zemin Kat, 1 1. Kat ...
class MallFloorLevels {
  const MallFloorLevels._();

  static const choices = <int>[-3, -2, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

  static String defaultName(int level) {
    if (level < 0) return 'B${-level}';
    if (level == 0) return 'Zemin Kat';
    return '$level. Kat';
  }

  /// Customer-facing title derived from the level so free-typed names
  /// ("1.kat", "otopark") read consistently: 1. Kat, B1 / Otopark, Zemin Kat.
  static String displayName(String name, int? level) {
    final raw = name.trim();
    if (level == null) return raw.isEmpty ? 'Kat' : raw;
    final canonical = defaultName(level);
    final key = TextNormalizer.normalize(raw).replaceAll(RegExp(r'[^a-z0-9-]'), '');
    final redundant = <String>{
      '',
      '$level',
      TextNormalizer.normalize(canonical).replaceAll(RegExp(r'[^a-z0-9-]'), ''),
      if (level > 0) '${level}kat',
      if (level == 0) ...{'zemin', 'z'},
    };
    if (redundant.contains(key)) return canonical;
    final title = raw.substring(0, 1) == 'i' ? 'İ${raw.substring(1)}' : '${raw.substring(0, 1).toUpperCase()}${raw.substring(1)}';
    return '$canonical / $title';
  }

  static String levelLabel(int? level) {
    if (level == null) return 'Seviye belirtilmedi';
    if (level < 0) return 'Bodrum ${-level} (B${-level})';
    if (level == 0) return 'Zemin';
    return '$level. kat seviyesi';
  }
}

/// Bottom to top: level ascending (unset levels last), then sort order, then name.
List<MallFloor> sortMallFloors(Iterable<MallFloor> floors) {
  final list = floors.toList();
  list.sort((a, b) {
    final la = a.levelNumber;
    final lb = b.levelNumber;
    if (la != lb) {
      if (la == null) return 1;
      if (lb == null) return -1;
      return la.compareTo(lb);
    }
    final bySort = a.sortOrder.compareTo(b.sortOrder);
    return bySort != 0 ? bySort : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return list;
}

class MallFloorValidation {
  static String? nameError(String raw) {
    final name = raw.trim();
    if (name.isEmpty) return 'Kat adı gerekli.';
    if (name.length > 80) return 'Kat adı en fazla 80 karakter olabilir.';
    return null;
  }

  static String? levelError(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final level = int.tryParse(text);
    if (level == null || level < -20 || level > 200) {
      return 'Seviye -20 ile 200 arasında olmalı.';
    }
    return null;
  }

  static int? parseLevel(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }
}
