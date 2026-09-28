import 'vehicle_catalog_data.dart';
import 'vehicle_type_schema.dart';

export 'vehicle_type_schema.dart'
    show VehicleClass, VehicleClassGroup, VehicleTypeSchema, VehicleTypeCatalog;

class VehicleFeature {
  const VehicleFeature({required this.id, required this.label});
  final String id;
  final String label;
}

class VehicleFeatureGroup {
  const VehicleFeatureGroup({
    required this.id,
    required this.label,
    required this.items,
  });
  final String id;
  final String label;
  final List<VehicleFeature> items;
}

class VehicleDamagePart {
  const VehicleDamagePart({required this.id, required this.label});
  final String id;
  final String label;
}

class VehicleTypeConfig {
  const VehicleTypeConfig({
    required this.classId,
    required this.requiredFields,
    this.optionalFields = const {},
    this.visibleFields = const {},
    this.featureGroupIds = const [],
    this.hasDamagePanel = false,
  });

  final String classId;
  final Set<String> requiredFields;
  final Set<String> optionalFields;
  final Set<String> visibleFields;
  final List<String> featureGroupIds;
  final bool hasDamagePanel;

  bool shows(String field) =>
      visibleFields.isEmpty || visibleFields.contains(field);

  static VehicleTypeConfig of(String classId) {
    final schema = VehicleTypeCatalog.of(classId);
    return VehicleTypeConfig(
      classId: schema.classId,
      requiredFields: schema.requiredFields,
      visibleFields: schema.visibleFields,
      featureGroupIds: schema.featureGroupIds,
      hasDamagePanel: schema.hasDamagePanel,
    );
  }
}

abstract final class VehicleCatalog {
  static List<VehicleClass> get classes => VehicleTypeCatalog.allTypes;

  static const fuels = [
    'Benzin',
    'Dizel',
    'LPG',
    'Benzin & LPG',
    'Hibrit',
    'Plugin Hibrit',
    'Elektrik',
  ];

  static const transmissions = ['Manuel', 'Otomatik', 'Yarı Otomatik', 'CVT'];

  static const drives = ['Önden Çekiş', 'Arkadan İtiş', '4x4', 'AWD'];

  static const bodyTypes = [
    'Sedan',
    'Hatchback',
    'Station Wagon',
    'Coupe',
    'Cabrio',
    'SUV',
    'Crossover',
    'MPV',
    'Pick-up',
    'Van',
    'Minibüs',
  ];

  static const colors = [
    'Siyah',
    'Beyaz',
    'Gri',
    'Gümüş',
    'Kırmızı',
    'Mavi',
    'Lacivert',
    'Yeşil',
    'Kahverengi',
    'Bej',
    'Turuncu',
    'Sarı',
    'Mor',
    'Diğer',
  ];

  static const plateStatuses = ['TR Plaka', 'Plakasız', 'Kayıtlı değil'];

  static const importStatuses = ['TR Çıkışlı', 'İthal', 'Diplomatik'];

  static const lienStatuses = [
    'Rehin / haciz yok (beyan)',
    'Rehin var (beyan)',
    'Haciz var (beyan)',
  ];

  static const damageStates = [
    'original',
    'painted',
    'local_painted',
    'replaced',
  ];

  static const damageStateLabels = {
    'original': 'Orijinal',
    'painted': 'Boyalı',
    'local_painted': 'Lokal boyalı',
    'replaced': 'Değişen',
  };

  static const damageParts = <VehicleDamagePart>[
    VehicleDamagePart(id: 'hood', label: 'Ön Kaput'),
    VehicleDamagePart(id: 'rf_fender', label: 'Sağ Ön Çamurluk'),
    VehicleDamagePart(id: 'lf_fender', label: 'Sol Ön Çamurluk'),
    VehicleDamagePart(id: 'rf_door', label: 'Sağ Ön Kapı'),
    VehicleDamagePart(id: 'lf_door', label: 'Sol Ön Kapı'),
    VehicleDamagePart(id: 'rr_door', label: 'Sağ Arka Kapı'),
    VehicleDamagePart(id: 'lr_door', label: 'Sol Arka Kapı'),
    VehicleDamagePart(id: 'rr_fender', label: 'Sağ Arka Çamurluk'),
    VehicleDamagePart(id: 'lr_fender', label: 'Sol Arka Çamurluk'),
    VehicleDamagePart(id: 'trunk', label: 'Bagaj'),
    VehicleDamagePart(id: 'roof', label: 'Tavan'),
    VehicleDamagePart(id: 'front_bumper', label: 'Ön Tampon'),
    VehicleDamagePart(id: 'rear_bumper', label: 'Arka Tampon'),
  ];

  static const featureGroups = <VehicleFeatureGroup>[
    VehicleFeatureGroup(
      id: 'safety',
      label: 'Güvenlik',
      items: [
        VehicleFeature(id: 'abs', label: 'ABS'),
        VehicleFeature(id: 'esp', label: 'ESP'),
        VehicleFeature(id: 'airbag', label: 'Airbag'),
        VehicleFeature(id: 'hill_start', label: 'Yokuş Kalkış Desteği'),
        VehicleFeature(id: 'lane_keep', label: 'Şerit Takip'),
        VehicleFeature(id: 'blind_spot', label: 'Kör Nokta Uyarı'),
        VehicleFeature(id: 'acc', label: 'Adaptif Cruise Control'),
        VehicleFeature(id: 'collision', label: 'Çarpışma Önleme'),
        VehicleFeature(id: 'park_sensor', label: 'Park Sensörü'),
        VehicleFeature(id: 'rear_camera', label: 'Geri Görüş Kamerası'),
      ],
    ),
    VehicleFeatureGroup(
      id: 'comfort',
      label: 'Konfor',
      items: [
        VehicleFeature(id: 'ac', label: 'Klima'),
        VehicleFeature(id: 'dual_ac', label: 'Çift Bölgeli Klima'),
        VehicleFeature(id: 'leather', label: 'Deri Koltuk'),
        VehicleFeature(id: 'heated_seat', label: 'Isıtmalı Koltuk'),
        VehicleFeature(id: 'power_seat', label: 'Elektrikli Koltuk'),
        VehicleFeature(id: 'memory_seat', label: 'Hafızalı Koltuk'),
        VehicleFeature(id: 'keyless', label: 'Anahtarsız Giriş'),
        VehicleFeature(id: 'start_stop', label: 'Start/Stop'),
      ],
    ),
    VehicleFeatureGroup(
      id: 'media',
      label: 'Multimedya',
      items: [
        VehicleFeature(id: 'carplay', label: 'Apple CarPlay'),
        VehicleFeature(id: 'android_auto', label: 'Android Auto'),
        VehicleFeature(id: 'bluetooth', label: 'Bluetooth'),
        VehicleFeature(id: 'nav', label: 'Navigasyon'),
        VehicleFeature(id: 'usb', label: 'USB'),
        VehicleFeature(id: 'wireless_charge', label: 'Kablosuz Şarj'),
      ],
    ),
    VehicleFeatureGroup(
      id: 'exterior',
      label: 'Dış Donanım',
      items: [
        VehicleFeature(id: 'led', label: 'LED Far'),
        VehicleFeature(id: 'xenon', label: 'Xenon'),
        VehicleFeature(id: 'sunroof', label: 'Sunroof'),
        VehicleFeature(id: 'pano', label: 'Panoramik Cam Tavan'),
        VehicleFeature(id: 'power_tailgate', label: 'Elektrikli Bagaj'),
        VehicleFeature(id: 'rain_sensor', label: 'Yağmur Sensörü'),
        VehicleFeature(id: 'light_sensor', label: 'Far Sensörü'),
      ],
    ),
    VehicleFeatureGroup(
      id: 'drive',
      label: 'Sürüş',
      items: [
        VehicleFeature(id: 'cruise', label: 'Hız Sabitleyici'),
        VehicleFeature(id: 'drive_modes', label: 'Sürüş Modları'),
        VehicleFeature(id: 'hud', label: 'Head-Up Display'),
      ],
    ),
    VehicleFeatureGroup(
      id: 'lighting',
      label: 'Aydınlatma',
      items: [
        VehicleFeature(id: 'led', label: 'LED Far'),
        VehicleFeature(id: 'matrix', label: 'Matrix Far'),
        VehicleFeature(id: 'fog', label: 'Sis Farı'),
      ],
    ),
    VehicleFeatureGroup(
      id: 'park',
      label: 'Park & Kamera',
      items: [
        VehicleFeature(id: 'park_sensor', label: 'Park Sensörü'),
        VehicleFeature(id: 'rear_camera', label: 'Geri Görüş Kamerası'),
        VehicleFeature(id: '360_cam', label: '360 Kamera'),
      ],
    ),
    VehicleFeatureGroup(
      id: 'offroad',
      label: 'Offroad',
      items: [
        VehicleFeature(id: 'diff_lock', label: 'Diferansiyel Kilidi'),
        VehicleFeature(id: 'low_range', label: 'Alçak Seviye'),
        VehicleFeature(id: 'skid', label: 'Karter Muhafazası'),
      ],
    ),
    VehicleFeatureGroup(
      id: 'motorcycle',
      label: 'Motosiklet Özellikleri',
      items: [
        VehicleFeature(id: 'abs', label: 'ABS'),
        VehicleFeature(id: 'tcs', label: 'Çekiş Kontrolü'),
        VehicleFeature(id: 'quickshifter', label: 'Quickshifter'),
        VehicleFeature(id: 'heated_grip', label: 'Isıtmalı Elcik'),
        VehicleFeature(id: 'top_box', label: 'Arka Çanta'),
      ],
    ),
    VehicleFeatureGroup(
      id: 'marine',
      label: 'Deniz Aracı Özellikleri',
      items: [
        VehicleFeature(id: 'trailer', label: 'Römork dahil'),
        VehicleFeature(id: 'gps_marine', label: 'GPS'),
        VehicleFeature(id: 'sound_system', label: 'Ses sistemi'),
        VehicleFeature(id: 'bimini', label: 'Bimini tavan'),
        VehicleFeature(id: 'anchor', label: 'Çapa'),
      ],
    ),
  ];

  static const titleMax = 80;
  static const descriptionMax = 5000;
  static const minPhotos = 3;
  static const maxPhotos = 20;
  static const minYear = 1990;

  static int get maxYear => DateTime.now().year + 1;

  static List<int> years() {
    final out = <int>[];
    for (var y = maxYear; y >= minYear; y--) {
      out.add(y);
    }
    return out;
  }

  static List<String> brands({String query = ''}) {
    return _filter(kVehicleBrandModels.keys.toList(growable: false), query);
  }

  static List<String> modelsFor(String brand, {String query = ''}) {
    if (brand.trim().isEmpty) return const [];
    final models =
        kVehicleBrandModels[brand] ??
        kVehicleBrandModels[_matchKey(kVehicleBrandModels.keys, brand)] ??
        const <String>[];
    return _filter(models, query);
  }

  static List<String> trimsFor(
    String brand,
    String model, {
    String query = '',
  }) {
    if (brand.trim().isEmpty || model.trim().isEmpty) return const [];
    final key = '$brand|$model';
    final trims =
        kVehicleTrims[key] ??
        kVehicleTrims[_matchKey(kVehicleTrims.keys, key)] ??
        const <String>[];
    return _filter(trims, query);
  }

  static String fold(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
  }

  static List<String> _filter(List<String> items, String query) {
    final q = fold(query);
    if (q.isEmpty) return items;
    return items
        .where((item) => fold(item).contains(q))
        .toList(growable: false);
  }

  static String? _matchKey(Iterable<String> keys, String raw) {
    final folded = fold(raw);
    for (final key in keys) {
      if (fold(key) == folded) return key;
    }
    return null;
  }

  static List<VehicleFeatureGroup> featureGroupsFor(String classId) {
    final ids = VehicleTypeCatalog.of(classId).featureGroupIds.toSet();
    return featureGroups
        .where((g) => ids.contains(g.id))
        .toList(growable: false);
  }

  static String? featureLabel(String id) {
    for (final group in featureGroups) {
      for (final item in group.items) {
        if (item.id == id) return item.label;
      }
    }
    return null;
  }

  static String? matchListed(List<String> items, String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    if (items.contains(raw)) return raw;
    final folded = fold(raw);
    for (final item in items) {
      if (fold(item) == folded) return item;
    }
    return raw;
  }
}

abstract final class VehicleMoney {
  static double? parse(String raw) {
    var text = raw.trim().toUpperCase();
    text = text.replaceAll('₺', '').replaceAll('TL', '').replaceAll(' ', '');
    if (text.isEmpty) return null;
    if (text.contains(',')) {
      text = text.replaceAll('.', '').replaceAll(',', '.');
    } else {
      text = text.replaceAll('.', '');
    }
    return double.tryParse(text);
  }

  static String format(num value, {bool withSuffix = true}) {
    final digits = value.round().abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      buf.write(digits[i]);
      if (remaining > 1 && remaining % 3 == 1) buf.write('.');
    }
    final body = buf.toString();
    if (!withSuffix) return body;
    return '$body TL';
  }

  static String km(num value) {
    return '${format(value, withSuffix: false)} km';
  }
}
