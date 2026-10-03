class MallUnitType {
  const MallUnitType._();

  static const values = <String>[
    'store',
    'restaurant',
    'cafe',
    'kiosk',
    'cinema',
    'service',
    'other',
  ];

  static String label(String value) {
    return switch (value) {
      'store' => 'Mağaza',
      'restaurant' => 'Restoran',
      'cafe' => 'Kafe',
      'kiosk' => 'Kiosk',
      'cinema' => 'Sinema',
      'service' => 'Hizmet',
      _ => 'Diğer',
    };
  }
}

class MallUnitOccupancy {
  const MallUnitOccupancy._();

  /// Panelin yazabildiği durumlar. occupied yalnız onaylı mağaza bağlantısıyla oluşur.
  static const editable = <String>['vacant', 'reserved', 'temporarily_closed'];

  static String label(String value) {
    return switch (value) {
      'occupied' => 'Dolu',
      'reserved' => 'Rezerve',
      'temporarily_closed' => 'Geçici kapalı',
      _ => 'Boş',
    };
  }
}

class MallUnit {
  const MallUnit({
    required this.id,
    required this.mallId,
    required this.floorId,
    required this.unitCode,
    required this.unitType,
    required this.occupancy,
    required this.sortOrder,
    this.name,
    this.areaM2,
    this.isActive = true,
    this.mapX,
    this.mapY,
  });

  final String id;
  final String mallId;
  final String floorId;
  final String unitCode;
  final String? name;
  final String unitType;
  final String occupancy;
  final double? areaM2;
  final int sortOrder;
  final bool isActive;
  final double? mapX;
  final double? mapY;

  bool get isPlaced => mapX != null && mapY != null;
  bool get isVacant => occupancy == 'vacant';

  factory MallUnit.fromMap(Map<String, dynamic> map) {
    return MallUnit(
      id: map['id'].toString(),
      mallId: map['mall_id'].toString(),
      floorId: map['floor_id'].toString(),
      unitCode: map['unit_code']?.toString() ?? '',
      name: _blank(map['name']),
      unitType: map['unit_type']?.toString() ?? 'other',
      occupancy: map['occupancy']?.toString() ?? 'vacant',
      areaM2: _double(map['area_m2']),
      sortOrder: int.tryParse(map['sort_order']?.toString() ?? '') ?? 0,
      isActive: map['is_active'] != false,
      mapX: _double(map['map_x']),
      mapY: _double(map['map_y']),
    );
  }
}

class MallUnitDraft {
  const MallUnitDraft({
    required this.floorId,
    required this.unitCode,
    required this.unitType,
    this.name,
    this.occupancy = 'vacant',
    this.areaM2,
    this.sortOrder = 0,
  });

  final String floorId;
  final String unitCode;
  final String? name;
  final String unitType;
  final String occupancy;
  final double? areaM2;
  final int sortOrder;
}

class MallUnitValidation {
  static String? codeError(String raw) {
    final code = raw.trim();
    if (code.isEmpty) return 'Mağaza no gerekli.';
    if (code.length > 40) return 'Mağaza no en fazla 40 karakter olabilir.';
    return null;
  }

  static String? occupancyError(String value) {
    if (value == 'occupied') {
      return 'Doluluk, mağaza bağlantısı onaylandığında belirlenir.';
    }
    if (!MallUnitOccupancy.editable.contains(value)) {
      return 'Geçersiz alan durumu.';
    }
    return null;
  }

  static String? typeError(String value) {
    if (!MallUnitType.values.contains(value)) return 'Geçersiz alan türü.';
    return null;
  }

  static String? areaError(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final area = double.tryParse(text.replaceAll(',', '.'));
    if (area == null || area <= 0 || area > 100000) {
      return 'Alan 0 ile 100000 m² arasında olmalı.';
    }
    return null;
  }
}

/// Natural order for store numbers: Z01, Z02, 101, 102, 105A.
int compareMallUnitCodes(String a, String b) {
  final pattern = RegExp(r'(\d+)|(\D+)');
  final pa = pattern.allMatches(a.toLowerCase()).map((m) => m.group(0)!).toList();
  final pb = pattern.allMatches(b.toLowerCase()).map((m) => m.group(0)!).toList();
  for (var i = 0; i < pa.length && i < pb.length; i++) {
    final na = int.tryParse(pa[i]);
    final nb = int.tryParse(pb[i]);
    final cmp = na != null && nb != null ? na.compareTo(nb) : pa[i].compareTo(pb[i]);
    if (cmp != 0) return cmp;
  }
  return pa.length.compareTo(pb.length);
}

String? _blank(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

double? _double(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
