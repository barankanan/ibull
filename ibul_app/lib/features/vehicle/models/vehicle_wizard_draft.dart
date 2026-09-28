import 'dart:typed_data';

import '../domain/vehicle_catalog.dart';
import 'vehicle_enums.dart';
import 'vehicle_listing.dart';

class VehicleDraftPhoto {
  VehicleDraftPhoto({
    required this.localId,
    this.id,
    this.url,
    this.objectPath,
    this.previewBytes,
    this.uploading = false,
    this.failed = false,
    this.error,
    this.isCover = false,
    this.sortOrder = 0,
  });

  final String localId;
  String? id;
  String? url;
  String? objectPath;
  Uint8List? previewBytes;
  bool uploading;
  bool failed;
  String? error;
  bool isCover;
  int sortOrder;

  bool get ready => url != null && url!.isNotEmpty && !failed && !uploading;
}

class VehicleWizardDraft {
  VehicleListingType listingType = VehicleListingType.sale;
  String vehicleClass = 'automobile';
  bool isNew = false;
  String brand = '';
  String model = '';
  String version = '';
  int year = DateTime.now().year;
  String? bodyType;
  String? fuel;
  String? transmission;
  int? engineCc;
  int? powerHp;
  String? drive;
  int? doors;
  int? seats;
  String? color;
  int? mileageKm;
  int? cylinders;
  int? torqueNm;
  String? zeroToHundred;
  String? topSpeedKmh;
  bool hasDamage = false;
  double? tramerAmount;
  String? replacedParts;
  String? paintedParts;
  Map<String, String> damageParts = {
    for (final part in VehicleCatalog.damageParts) part.id: 'original',
  };
  bool heavyDamage = false;
  bool hasExpertise = false;
  String? serviceHistory;
  String? warranty;
  String? plateStatus;
  String? importStatus;
  String? lienStatus;
  bool creditEligible = false;
  bool vatIncluded = false;
  double? salePrice;
  bool negotiable = true;
  bool financing = false;
  bool tradeIn = false;
  VehicleRentalSettings? rental;
  String title = '';
  bool titleManual = false;
  String? description;
  String? city;
  String? district;
  Set<String> features = <String>{};
  VehicleListingStatus publishStatus = VehicleListingStatus.draft;
  String subtype = '';
  int? hoursOperated;
  int? passengerCapacity;
  int? berths;
  int? axles;
  int? payloadKg;
  String? cooling;
  String? hullType;
  bool kitchen = false;
  bool shower = false;
  bool wc = false;
  bool solar = false;
  String vatStatus = 'unspecified';
  int? minDriverAge;
  int? minLicenseYears;
  Map<String, dynamic> sourceExtras = const {};

  String get suggestedTitle {
    final parts = <String>[
      if (year > 0) '$year',
      if (brand.trim().isNotEmpty) brand.trim(),
      if (model.trim().isNotEmpty) model.trim(),
      if (version.trim().isNotEmpty) version.trim(),
      if (transmission != null && transmission!.trim().isNotEmpty)
        transmission!.trim(),
      if (mileageKm != null && mileageKm! > 0 && mileageKm! < 30000) 'Düşük KM',
    ];
    var text = parts.join(' ').trim();
    if (text.length > VehicleCatalog.titleMax) {
      text = text.substring(0, VehicleCatalog.titleMax);
    }
    return text;
  }

  String get displayTitle {
    final custom = title.trim();
    if (custom.isNotEmpty) return custom;
    return suggestedTitle;
  }

  bool get isRejected {
    final moderation = sourceExtras['moderation'];
    if (moderation is Map) {
      final token = moderation['status']?.toString().trim().toLowerCase();
      if (token == 'approved' || token == 'pending') return false;
      if (token == 'rejected') return true;
    }
    if (publishStatus != VehicleListingStatus.draft) return false;
    return (sourceExtras['rejection_reason']?.toString() ?? '').isNotEmpty;
  }

  String get rejectionNote {
    final moderation = sourceExtras['moderation'];
    if (moderation is Map) {
      final reason = moderation['reason']?.toString().trim() ?? '';
      if (reason.isNotEmpty) return reason;
    }
    return sourceExtras['rejection_reason']?.toString() ?? '';
  }

  void applySuggestedTitleIfNeeded() {
    if (titleManual && title.trim().isNotEmpty) return;
    title = suggestedTitle;
  }

  VehicleSpecs toSpecs() {
    final painted = damageParts.entries
        .where((e) => e.value == 'painted' || e.value == 'local_painted')
        .map(_partLabel)
        .join(', ');
    final replaced = damageParts.entries
        .where((e) => e.value == 'replaced')
        .map(_partLabel)
        .join(', ');
    final damaged = damageParts.values.any((v) => v != 'original');
    return VehicleSpecs(
      brand: brand.trim(),
      model: model.trim(),
      version: version.trim().isEmpty ? null : version.trim(),
      year: year,
      bodyType: bodyType,
      fuel: fuel,
      transmission: transmission,
      engineCc: engineCc,
      powerHp: powerHp,
      drive: drive,
      doors: doors,
      seats: seats,
      color: color,
      mileageKm: mileageKm,
      hasDamage: hasDamage || damaged || (tramerAmount ?? 0) > 0,
      tramerAmount: tramerAmount,
      replacedParts: replaced.isEmpty ? replacedParts : replaced,
      paintedParts: painted.isEmpty ? paintedParts : painted,
      heavyDamage: heavyDamage,
      hasExpertise: hasExpertise,
      serviceHistory: serviceHistory,
      warranty: warranty,
    );
  }

  Map<String, dynamic> toExtras() => {
    'title': displayTitle,
    'vehicle_class': vehicleClass,
    if (subtype.trim().isNotEmpty) 'vehicle_subtype': subtype.trim(),
    'condition': isNew ? 'new' : 'used',
    'features': features.toList()..sort(),
    'damage_parts': Map<String, String>.from(damageParts),
    'plate_status': plateStatus,
    'import_status': importStatus,
    'lien_status': lienStatus,
    'credit_eligible': creditEligible,
    'vat_included': vatStatus == 'included',
    'vat_status': vatStatus,
    if (cylinders != null) 'cylinders': cylinders,
    if (torqueNm != null) 'torque_nm': torqueNm,
    if (zeroToHundred != null && zeroToHundred!.trim().isNotEmpty)
      'zero_to_100': zeroToHundred!.trim(),
    if (topSpeedKmh != null && topSpeedKmh!.trim().isNotEmpty)
      'top_speed_kmh': topSpeedKmh!.trim(),
    if (hoursOperated != null) 'hours_operated': hoursOperated,
    if (passengerCapacity != null) 'passenger_capacity': passengerCapacity,
    if (berths != null) 'berths': berths,
    if (axles != null) 'axles': axles,
    if (payloadKg != null) 'payload_kg': payloadKg,
    if (cooling != null) 'cooling': cooling,
    if (hullType != null) 'hull_type': hullType,
    'kitchen': kitchen,
    'shower': shower,
    'wc': wc,
    'solar': solar,
    if (minDriverAge != null) 'min_driver_age': minDriverAge,
    if (minLicenseYears != null) 'min_license_years': minLicenseYears,
    if (sourceExtras['moderation'] != null)
      'moderation': sourceExtras['moderation'],
    if (sourceExtras['rejection_reason'] != null)
      'rejection_reason': sourceExtras['rejection_reason'],
  };

  void applyListing(VehicleListing listing) {
    listingType = listing.listingType;
    brand = listing.specs.brand;
    model = listing.specs.model;
    version = listing.specs.version ?? '';
    year = listing.specs.year;
    bodyType = VehicleCatalog.matchListed(
      VehicleCatalog.bodyTypes,
      listing.specs.bodyType,
    );
    fuel = VehicleCatalog.matchListed(VehicleCatalog.fuels, listing.specs.fuel);
    transmission = VehicleCatalog.matchListed(
      VehicleCatalog.transmissions,
      listing.specs.transmission,
    );
    engineCc = listing.specs.engineCc;
    powerHp = listing.specs.powerHp;
    drive = VehicleCatalog.matchListed(
      VehicleCatalog.drives,
      listing.specs.drive,
    );
    doors = listing.specs.doors;
    seats = listing.specs.seats;
    color = VehicleCatalog.matchListed(
      VehicleCatalog.colors,
      listing.specs.color,
    );
    mileageKm = listing.specs.mileageKm;
    hasDamage = listing.specs.hasDamage;
    tramerAmount = listing.specs.tramerAmount;
    replacedParts = listing.specs.replacedParts;
    paintedParts = listing.specs.paintedParts;
    heavyDamage = listing.specs.heavyDamage;
    hasExpertise = listing.specs.hasExpertise;
    serviceHistory = listing.specs.serviceHistory;
    warranty = listing.specs.warranty;
    salePrice = listing.salePrice;
    negotiable = listing.negotiable;
    financing = listing.financing;
    tradeIn = listing.tradeIn;
    rental = listing.rental;
    description = listing.description;
    city = listing.city;
    district = listing.district;
    publishStatus = listing.status;
    sourceExtras = Map<String, dynamic>.from(listing.extras);
    final extras = listing.extras;
    title = (extras['title'] ?? listing.title).toString();
    titleManual = title.trim().isNotEmpty;
    vehicleClass = (extras['vehicle_class'] ?? 'automobile').toString();
    subtype = (extras['vehicle_subtype'] ?? '').toString();
    isNew = extras['condition'] == 'new';
    plateStatus = VehicleCatalog.matchListed(
      VehicleCatalog.plateStatuses,
      extras['plate_status']?.toString(),
    );
    importStatus = VehicleCatalog.matchListed(
      VehicleCatalog.importStatuses,
      extras['import_status']?.toString(),
    );
    lienStatus = VehicleCatalog.matchListed(
      VehicleCatalog.lienStatuses,
      extras['lien_status']?.toString(),
    );
    creditEligible = extras['credit_eligible'] == true;
    vatIncluded = extras['vat_included'] == true;
    vatStatus =
        extras['vat_status']?.toString() ??
        (vatIncluded ? 'included' : 'unspecified');
    cylinders = extras['cylinders'] is num
        ? (extras['cylinders'] as num).toInt()
        : int.tryParse('${extras['cylinders'] ?? ''}');
    torqueNm = extras['torque_nm'] is num
        ? (extras['torque_nm'] as num).toInt()
        : int.tryParse('${extras['torque_nm'] ?? ''}');
    zeroToHundred = extras['zero_to_100']?.toString();
    topSpeedKmh = extras['top_speed_kmh']?.toString();
    hoursOperated = _asInt(extras['hours_operated']);
    passengerCapacity = _asInt(extras['passenger_capacity']);
    berths = _asInt(extras['berths']);
    axles = _asInt(extras['axles']);
    payloadKg = _asInt(extras['payload_kg']);
    cooling = extras['cooling']?.toString();
    hullType = extras['hull_type']?.toString();
    kitchen = extras['kitchen'] == true;
    shower = extras['shower'] == true;
    wc = extras['wc'] == true;
    solar = extras['solar'] == true;
    minDriverAge = _asInt(extras['min_driver_age']);
    minLicenseYears = _asInt(extras['min_license_years']);
    final rawFeatures = extras['features'];
    if (rawFeatures is List) {
      features = rawFeatures.map((e) => e.toString()).toSet();
    }
    final rawDamage = extras['damage_parts'];
    if (rawDamage is Map) {
      damageParts = {
        for (final part in VehicleCatalog.damageParts)
          part.id: (rawDamage[part.id] ?? 'original').toString(),
      };
    }
  }

  static int? _asInt(Object? raw) {
    if (raw is num) return raw.toInt();
    return int.tryParse('${raw ?? ''}');
  }

  static String _partLabel(MapEntry<String, String> entry) {
    for (final part in VehicleCatalog.damageParts) {
      if (part.id == entry.key) return part.label;
    }
    return entry.key;
  }
}
