class VehicleClass {
  const VehicleClass({required this.id, required this.label});

  final String id;
  final String label;
}

class VehicleClassGroup {
  const VehicleClassGroup({
    required this.id,
    required this.label,
    required this.types,
  });

  final String id;
  final String label;
  final List<VehicleClass> types;
}

class VehicleTypeSchema {
  const VehicleTypeSchema({
    required this.classId,
    required this.groupId,
    required this.requiredFields,
    required this.visibleFields,
    required this.featureGroupIds,
    this.hasDamagePanel = false,
    this.subtypes = const [],
  });

  final String classId;
  final String groupId;
  final Set<String> requiredFields;
  final Set<String> visibleFields;
  final List<String> featureGroupIds;
  final bool hasDamagePanel;
  final List<VehicleClass> subtypes;

  bool shows(String field) => visibleFields.contains(field);
}

abstract final class VehicleTypeCatalog {
  static const landTypes = <VehicleClass>[
    VehicleClass(id: 'automobile', label: 'Otomobil'),
    VehicleClass(id: 'suv', label: 'SUV'),
    VehicleClass(id: 'pickup', label: 'Pick-up'),
    VehicleClass(id: 'light_commercial', label: 'Hafif Ticari'),
    VehicleClass(id: 'minibus', label: 'Minibüs'),
    VehicleClass(id: 'van', label: 'Kamyonet'),
    VehicleClass(id: 'truck', label: 'Kamyon'),
    VehicleClass(id: 'tractor_unit', label: 'Çekici'),
    VehicleClass(id: 'bus', label: 'Otobüs'),
    VehicleClass(id: 'caravan', label: 'Karavan'),
    VehicleClass(id: 'atv', label: 'ATV'),
    VehicleClass(id: 'utv', label: 'UTV'),
  ];

  static const motorcycleTypes = <VehicleClass>[
    VehicleClass(id: 'motorcycle', label: 'Motosiklet'),
  ];

  static const motorcycleSubtypes = <VehicleClass>[
    VehicleClass(id: 'scooter', label: 'Scooter'),
    VehicleClass(id: 'naked', label: 'Naked'),
    VehicleClass(id: 'sport', label: 'Sport'),
    VehicleClass(id: 'touring', label: 'Touring'),
    VehicleClass(id: 'enduro', label: 'Enduro'),
    VehicleClass(id: 'cross', label: 'Cross'),
    VehicleClass(id: 'cruiser', label: 'Cruiser'),
    VehicleClass(id: 'commuter', label: 'Commuter'),
    VehicleClass(id: 'electric_moto', label: 'Elektrikli motosiklet'),
    VehicleClass(id: 'moto_other', label: 'Diğer'),
  ];

  static const marineTypes = <VehicleClass>[
    VehicleClass(id: 'jetski', label: 'Jet Ski'),
    VehicleClass(id: 'boat', label: 'Tekne'),
    VehicleClass(id: 'yacht', label: 'Yat'),
    VehicleClass(id: 'speedboat', label: 'Sürat Teknesi'),
    VehicleClass(id: 'dinghy', label: 'Bot'),
    VehicleClass(id: 'marine_other', label: 'Diğer deniz aracı'),
  ];

  static const otherTypes = <VehicleClass>[
    VehicleClass(id: 'farm', label: 'Tarım aracı'),
    VehicleClass(id: 'machinery', label: 'İş makinesi'),
    VehicleClass(id: 'special', label: 'Özel amaçlı araç'),
    VehicleClass(id: 'commercial', label: 'Ticari Araç'),
    VehicleClass(id: 'other', label: 'Diğer'),
  ];

  static const groups = <VehicleClassGroup>[
    VehicleClassGroup(id: 'land', label: 'Kara araçları', types: landTypes),
    VehicleClassGroup(
      id: 'motorcycle',
      label: 'Motosiklet',
      types: motorcycleTypes,
    ),
    VehicleClassGroup(
      id: 'marine',
      label: 'Deniz araçları',
      types: marineTypes,
    ),
    VehicleClassGroup(id: 'other', label: 'Diğer', types: otherTypes),
  ];

  static List<VehicleClass> get allTypes => [
    ...landTypes,
    ...motorcycleTypes,
    ...marineTypes,
    ...otherTypes,
  ];

  static VehicleClass? typeById(String id) {
    for (final type in allTypes) {
      if (type.id == id) return type;
    }
    for (final type in motorcycleSubtypes) {
      if (type.id == id) return type;
    }
    return null;
  }

  static VehicleTypeSchema of(String classId) {
    final id = classId.trim().isEmpty ? 'automobile' : classId;
    if (id == 'motorcycle' || motorcycleSubtypes.any((t) => t.id == id)) {
      return VehicleTypeSchema(
        classId: id == 'motorcycle' ? 'motorcycle' : id,
        groupId: 'motorcycle',
        requiredFields: {
          'brand',
          'model',
          'year',
          'mileageKm',
          'fuel',
          'title',
        },
        visibleFields: {
          'mileageKm',
          'fuel',
          'engineCc',
          'powerHp',
          'cylinders',
          'color',
          'cooling',
        },
        featureGroupIds: const ['safety', 'motorcycle'],
        subtypes: motorcycleSubtypes,
      );
    }
    if (_marineIds.contains(id)) {
      return VehicleTypeSchema(
        classId: id,
        groupId: 'marine',
        requiredFields: {'brand', 'model', 'year', 'title'},
        visibleFields: {
          'hoursOperated',
          'engineCc',
          'powerHp',
          'passengerCapacity',
          'color',
          'hullType',
        },
        featureGroupIds: const ['marine'],
      );
    }
    if (id == 'truck' || id == 'tractor_unit' || id == 'bus') {
      return const VehicleTypeSchema(
        classId: 'truck',
        groupId: 'land',
        requiredFields: {
          'brand',
          'model',
          'year',
          'mileageKm',
          'fuel',
          'title',
        },
        visibleFields: {
          'mileageKm',
          'fuel',
          'transmission',
          'engineCc',
          'powerHp',
          'color',
          'axles',
          'payloadKg',
          'bodyType',
        },
        featureGroupIds: ['safety', 'drive'],
      );
    }
    if (id == 'caravan') {
      return const VehicleTypeSchema(
        classId: 'caravan',
        groupId: 'land',
        requiredFields: {
          'brand',
          'model',
          'year',
          'mileageKm',
          'fuel',
          'title',
        },
        visibleFields: {
          'mileageKm',
          'fuel',
          'transmission',
          'color',
          'berths',
          'passengerCapacity',
          'kitchen',
          'shower',
          'wc',
          'solar',
        },
        featureGroupIds: ['comfort', 'media', 'exterior'],
        hasDamagePanel: true,
      );
    }
    if (id == 'farm' || id == 'machinery' || id == 'special' || id == 'other') {
      return VehicleTypeSchema(
        classId: id,
        groupId: 'other',
        requiredFields: const {'brand', 'model', 'year', 'title'},
        visibleFields: const {
          'mileageKm',
          'hoursOperated',
          'fuel',
          'powerHp',
          'color',
        },
        featureGroupIds: const ['drive'],
      );
    }
    if (id == 'atv' || id == 'utv') {
      return VehicleTypeSchema(
        classId: id,
        groupId: 'land',
        requiredFields: const {
          'brand',
          'model',
          'year',
          'mileageKm',
          'fuel',
          'title',
        },
        visibleFields: const {
          'mileageKm',
          'fuel',
          'transmission',
          'engineCc',
          'powerHp',
          'drive',
          'color',
        },
        featureGroupIds: const ['safety', 'offroad'],
      );
    }
    return VehicleTypeSchema(
      classId: id,
      groupId: 'land',
      requiredFields: const {
        'brand',
        'model',
        'year',
        'mileageKm',
        'fuel',
        'transmission',
        'title',
      },
      visibleFields: const {
        'mileageKm',
        'fuel',
        'transmission',
        'bodyType',
        'drive',
        'color',
        'engineCc',
        'powerHp',
        'torqueNm',
        'cylinders',
        'zeroToHundred',
        'topSpeedKmh',
        'doors',
        'seats',
      },
      featureGroupIds: const [
        'safety',
        'comfort',
        'media',
        'exterior',
        'drive',
        'lighting',
        'park',
      ],
      hasDamagePanel: true,
    );
  }

  static const _marineIds = {
    'jetski',
    'boat',
    'yacht',
    'speedboat',
    'dinghy',
    'marine_other',
  };
}
