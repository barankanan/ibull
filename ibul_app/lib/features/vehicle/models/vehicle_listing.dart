import 'vehicle_enums.dart';

class VehicleVerifiedField<T> {
  const VehicleVerifiedField({
    required this.value,
    this.source = VehicleVerificationSource.dealerEntered,
  });

  final T value;
  final VehicleVerificationSource source;

  bool get isDocumentVerified =>
      source == VehicleVerificationSource.documentVerified;
}

class VehicleSpecs {
  const VehicleSpecs({
    required this.brand,
    required this.model,
    this.version,
    required this.year,
    this.bodyType,
    this.fuel,
    this.transmission,
    this.engineCc,
    this.powerHp,
    this.drive,
    this.doors,
    this.seats,
    this.color,
    this.mileageKm,
    this.mileageSource = VehicleVerificationSource.dealerEntered,
    this.hasDamage = false,
    this.tramerAmount,
    this.replacedParts,
    this.paintedParts,
    this.heavyDamage = false,
    this.hasExpertise = false,
    this.serviceHistory,
    this.warranty,
  });

  final String brand;
  final String model;
  final String? version;
  final int year;
  final String? bodyType;
  final String? fuel;
  final String? transmission;
  final int? engineCc;
  final int? powerHp;
  final String? drive;
  final int? doors;
  final int? seats;
  final String? color;
  final int? mileageKm;
  final VehicleVerificationSource mileageSource;
  final bool hasDamage;
  final double? tramerAmount;
  final String? replacedParts;
  final String? paintedParts;
  final bool heavyDamage;
  final bool hasExpertise;
  final String? serviceHistory;
  final String? warranty;

  String get title {
    final pack = (version ?? '').trim();
    return pack.isEmpty ? '$brand $model' : '$brand $model $pack';
  }

  factory VehicleSpecs.fromMap(Map<String, dynamic> map) {
    return VehicleSpecs(
      brand: (map['brand'] ?? '').toString(),
      model: (map['model'] ?? '').toString(),
      version: map['version']?.toString(),
      year: _asInt(map['year']) ?? 0,
      bodyType: map['body_type']?.toString(),
      fuel: map['fuel']?.toString(),
      transmission: map['transmission']?.toString(),
      engineCc: _asInt(map['engine_cc']),
      powerHp: _asInt(map['power_hp']),
      drive: map['drive']?.toString(),
      doors: _asInt(map['doors']),
      seats: _asInt(map['seats']),
      color: map['color']?.toString(),
      mileageKm: _asInt(map['mileage_km']),
      mileageSource: (map['mileage_verified'] == true)
          ? VehicleVerificationSource.documentVerified
          : VehicleVerificationSource.dealerEntered,
      hasDamage: map['has_damage'] == true,
      tramerAmount: _asDouble(map['tramer_amount']),
      replacedParts: map['replaced_parts']?.toString(),
      paintedParts: map['painted_parts']?.toString(),
      heavyDamage: map['heavy_damage'] == true,
      hasExpertise: map['has_expertise'] == true,
      serviceHistory: map['service_history']?.toString(),
      warranty: map['warranty']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'brand': brand,
    'model': model,
    'version': version,
    'year': year,
    'body_type': bodyType,
    'fuel': fuel,
    'transmission': transmission,
    'engine_cc': engineCc,
    'power_hp': powerHp,
    'drive': drive,
    'doors': doors,
    'seats': seats,
    'color': color,
    'mileage_km': mileageKm,
    'mileage_verified':
        mileageSource == VehicleVerificationSource.documentVerified,
    'has_damage': hasDamage,
    'tramer_amount': tramerAmount,
    'replaced_parts': replacedParts,
    'painted_parts': paintedParts,
    'heavy_damage': heavyDamage,
    'has_expertise': hasExpertise,
    'service_history': serviceHistory,
    'warranty': warranty,
  };
}

class VehicleMedia {
  const VehicleMedia({
    required this.id,
    required this.slot,
    required this.url,
    this.sortOrder = 0,
    this.isCover = false,
    this.objectPath,
  });

  final String id;
  final VehicleMediaSlot slot;
  final String url;
  final int sortOrder;
  final bool isCover;
  final String? objectPath;

  bool get isVideo => slot == VehicleMediaSlot.video;
  bool get is360 => slot == VehicleMediaSlot.spin360;

  factory VehicleMedia.fromMap(Map<String, dynamic> map) {
    return VehicleMedia(
      id: (map['id'] ?? '').toString(),
      slot: VehicleMediaSlotX.parse(map['slot']?.toString()),
      url: (map['url'] ?? map['public_url'] ?? '').toString(),
      sortOrder: _asInt(map['sort_order']) ?? 0,
      isCover: map['is_cover'] == true,
      objectPath: map['object_path']?.toString(),
    );
  }

  static List<VehicleMedia> sorted(Iterable<VehicleMedia> media) {
    final copy = [...media];
    copy.sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      if (order != 0) return order;
      if (a.isCover != b.isCover) return a.isCover ? -1 : 1;
      return 0;
    });
    return List<VehicleMedia>.unmodifiable(copy);
  }
}

class VehicleRentalSettings {
  const VehicleRentalSettings({
    required this.dailyPrice,
    this.weeklyPrice,
    this.monthlyPrice,
    this.deposit = 0,
    this.minDays = 1,
    this.maxDays = 30,
    this.kmLimitPerDay,
    this.extraKmPrice,
    this.galleryPickup = true,
    this.mapPointDelivery = false,
    this.homeDelivery = false,
    this.requiresApproval = true,
    this.instantBooking = false,
    this.minDriverAge,
    this.minLicenseYears,
    this.cancellationPolicy = const {},
  });

  final double dailyPrice;
  final double? weeklyPrice;
  final double? monthlyPrice;
  final double deposit;
  final int minDays;
  final int maxDays;
  final int? kmLimitPerDay;
  final double? extraKmPrice;
  final bool galleryPickup;
  final bool mapPointDelivery;
  final bool homeDelivery;
  final bool requiresApproval;
  final bool instantBooking;
  final int? minDriverAge;
  final int? minLicenseYears;
  final Map<String, dynamic> cancellationPolicy;

  bool get rentalEnabled => dailyPrice > 0;

  factory VehicleRentalSettings.fromMap(Map<String, dynamic> map) {
    return VehicleRentalSettings(
      dailyPrice: _asDouble(map['daily_price']) ?? 0,
      weeklyPrice: _asDouble(map['weekly_price']),
      monthlyPrice: _asDouble(map['monthly_price']),
      deposit: _asDouble(map['deposit']) ?? 0,
      minDays: _asInt(map['min_days']) ?? 1,
      maxDays: _asInt(map['max_days']) ?? 30,
      kmLimitPerDay: _asInt(map['km_limit_per_day']),
      extraKmPrice: _asDouble(map['extra_km_price']),
      galleryPickup: map['gallery_pickup'] != false,
      mapPointDelivery: map['map_point_delivery'] == true,
      homeDelivery: map['home_delivery'] == true,
      requiresApproval: map['requires_approval'] != false,
      instantBooking: map['instant_booking'] == true,
      minDriverAge: _asInt(map['min_driver_age']),
      minLicenseYears: _asInt(map['min_license_years']),
      cancellationPolicy: map['cancellation_policy'] is Map
          ? Map<String, dynamic>.from(map['cancellation_policy'] as Map)
          : const {},
    );
  }

  Map<String, dynamic> toMap() => {
    'daily_price': dailyPrice,
    'weekly_price': weeklyPrice,
    'monthly_price': monthlyPrice,
    'deposit': deposit,
    'min_days': minDays,
    'max_days': maxDays,
    'km_limit_per_day': kmLimitPerDay,
    'extra_km_price': extraKmPrice,
    'gallery_pickup': galleryPickup,
    'map_point_delivery': mapPointDelivery,
    'home_delivery': homeDelivery,
    'requires_approval': requiresApproval,
    'instant_booking': instantBooking,
    'min_driver_age': minDriverAge,
    'min_license_years': minLicenseYears,
    'cancellation_policy': cancellationPolicy,
  };

  VehicleRentalSettings copyWith({
    double? dailyPrice,
    double? weeklyPrice,
    double? monthlyPrice,
    double? deposit,
    int? minDays,
    int? maxDays,
    int? kmLimitPerDay,
    double? extraKmPrice,
    bool? galleryPickup,
    bool? mapPointDelivery,
    bool? homeDelivery,
    bool? requiresApproval,
    bool? instantBooking,
    int? minDriverAge,
    int? minLicenseYears,
    Map<String, dynamic>? cancellationPolicy,
  }) {
    return VehicleRentalSettings(
      dailyPrice: dailyPrice ?? this.dailyPrice,
      weeklyPrice: weeklyPrice ?? this.weeklyPrice,
      monthlyPrice: monthlyPrice ?? this.monthlyPrice,
      deposit: deposit ?? this.deposit,
      minDays: minDays ?? this.minDays,
      maxDays: maxDays ?? this.maxDays,
      kmLimitPerDay: kmLimitPerDay ?? this.kmLimitPerDay,
      extraKmPrice: extraKmPrice ?? this.extraKmPrice,
      galleryPickup: galleryPickup ?? this.galleryPickup,
      mapPointDelivery: mapPointDelivery ?? this.mapPointDelivery,
      homeDelivery: homeDelivery ?? this.homeDelivery,
      requiresApproval: requiresApproval ?? this.requiresApproval,
      instantBooking: instantBooking ?? this.instantBooking,
      minDriverAge: minDriverAge ?? this.minDriverAge,
      minLicenseYears: minLicenseYears ?? this.minLicenseYears,
      cancellationPolicy: cancellationPolicy ?? this.cancellationPolicy,
    );
  }
}

class VehicleGallerySummary {
  const VehicleGallerySummary({
    required this.sellerId,
    required this.name,
    this.logoUrl,
    this.coverUrl,
    this.address,
    this.city,
    this.district,
    this.phone,
    this.lat,
    this.lng,
    this.verified = false,
    this.about,
    this.workingHours,
    this.vehicleCount = 0,
    this.rating,
  });

  final String sellerId;
  final String name;
  final String? logoUrl;
  final String? coverUrl;
  final String? address;
  final String? city;
  final String? district;
  final String? phone;
  final double? lat;
  final double? lng;
  final bool verified;
  final String? about;
  final String? workingHours;
  final int vehicleCount;
  final double? rating;

  factory VehicleGallerySummary.fromMap(Map<String, dynamic> map) {
    return VehicleGallerySummary(
      sellerId: (map['seller_id'] ?? map['id'] ?? '').toString(),
      name: (map['business_name'] ?? map['name'] ?? '').toString(),
      logoUrl: map['logo_url']?.toString(),
      coverUrl: map['cover_url']?.toString(),
      address: map['address']?.toString(),
      city: map['city']?.toString(),
      district: map['district']?.toString(),
      phone: (map['phone'] ?? map['support_phone'])?.toString(),
      lat: _asDouble(map['store_lat'] ?? map['lat']),
      lng: _asDouble(map['store_lng'] ?? map['lng']),
      verified:
          map['is_verified'] == true ||
          map['verified_gallery'] == true ||
          map['is_brand_verified'] == true,
      about: (map['about'] ?? map['description'])?.toString(),
      workingHours: map['working_hours']?.toString(),
      vehicleCount: _asInt(map['vehicle_count']) ?? 0,
      rating: _asDouble(map['rating']),
    );
  }
}

class VehicleListing {
  const VehicleListing({
    required this.id,
    required this.sellerId,
    required this.listingType,
    required this.status,
    required this.specs,
    this.salePrice,
    this.negotiable = true,
    this.financing = false,
    this.tradeIn = false,
    this.homeDeliverySale = false,
    this.description,
    this.city,
    this.district,
    this.coverUrl,
    this.media = const [],
    this.rental,
    this.gallery,
    this.favoriteCount = 0,
    this.viewCount = 0,
    this.createdAt,
    this.publishedAt,
    this.extras = const {},
  });

  final String id;
  final String sellerId;
  final VehicleListingType listingType;
  final VehicleListingStatus status;
  final VehicleSpecs specs;
  final double? salePrice;
  final bool negotiable;
  final bool financing;
  final bool tradeIn;
  final bool homeDeliverySale;
  final String? description;
  final String? city;
  final String? district;
  final String? coverUrl;
  final List<VehicleMedia> media;
  final VehicleRentalSettings? rental;
  final VehicleGallerySummary? gallery;
  final int favoriteCount;
  final int viewCount;
  final DateTime? createdAt;
  final DateTime? publishedAt;
  final Map<String, dynamic> extras;

  String get title {
    final custom = extras['title']?.toString().trim() ?? '';
    if (custom.isNotEmpty) return custom;
    return specs.title;
  }

  List<String> get featureIds {
    final raw = extras['features'];
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).toList(growable: false);
  }

  bool get isVerifiedMileage =>
      specs.mileageSource == VehicleVerificationSource.documentVerified;

  factory VehicleListing.fromMap(Map<String, dynamic> map) {
    final specMap = _embedMap(map['vehicle_specs']) ?? map;
    final rentalMap =
        _embedMap(map['vehicle_rental_settings']) ?? _embedMap(map['rental']);
    final mediaRaw = map['vehicle_media'] ?? map['media'];
    final galleryRaw =
        map['gallery'] ?? map['stores'] ?? map['vehicle_galleries'];
    return VehicleListing(
      id: (map['id'] ?? '').toString(),
      sellerId: (map['seller_id'] ?? '').toString(),
      listingType: VehicleListingTypeX.parse(map['listing_type']?.toString()),
      status: VehicleListingStatusX.parse(map['status']?.toString() ?? 'draft'),
      specs: VehicleSpecs.fromMap(Map<String, dynamic>.from(specMap)),
      salePrice: _asDouble(map['sale_price']),
      negotiable: map['negotiable'] != false,
      financing: map['financing'] == true,
      tradeIn: map['trade_in'] == true,
      homeDeliverySale: map['home_delivery_sale'] == true,
      description: map['description']?.toString(),
      city: map['city']?.toString(),
      district: map['district']?.toString(),
      coverUrl: map['cover_url']?.toString(),
      media: mediaRaw is List
          ? VehicleMedia.sorted(
              mediaRaw.whereType<Map>().map(
                (e) => VehicleMedia.fromMap(Map<String, dynamic>.from(e)),
              ),
            )
          : const [],
      rental: rentalMap == null
          ? (_asDouble(map['daily_price']) == null
                ? null
                : VehicleRentalSettings(
                    dailyPrice: _asDouble(map['daily_price'])!,
                  ))
          : VehicleRentalSettings.fromMap(rentalMap),
      gallery: galleryRaw is Map
          ? VehicleGallerySummary.fromMap(Map<String, dynamic>.from(galleryRaw))
          : (galleryRaw is List &&
                    galleryRaw.isNotEmpty &&
                    galleryRaw.first is Map
                ? VehicleGallerySummary.fromMap(
                    Map<String, dynamic>.from(galleryRaw.first as Map),
                  )
                : _galleryFromSearchRow(map)),
      favoriteCount: _asInt(map['favorite_count']) ?? 0,
      viewCount: _asInt(map['view_count']) ?? 0,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
      publishedAt: DateTime.tryParse(map['published_at']?.toString() ?? ''),
      extras: _asMap(map['ai_payload'] ?? map['extras']),
    );
  }

  VehicleListing copyWith({
    VehicleSpecs? specs,
    List<VehicleMedia>? media,
    VehicleGallerySummary? gallery,
    VehicleRentalSettings? rental,
    Map<String, dynamic>? extras,
    VehicleListingStatus? status,
    String? coverUrl,
    String? description,
  }) {
    return VehicleListing(
      id: id,
      sellerId: sellerId,
      listingType: listingType,
      status: status ?? this.status,
      specs: specs ?? this.specs,
      salePrice: salePrice,
      negotiable: negotiable,
      financing: financing,
      tradeIn: tradeIn,
      homeDeliverySale: homeDeliverySale,
      description: description ?? this.description,
      city: city,
      district: district,
      coverUrl: coverUrl ?? this.coverUrl,
      media: media ?? this.media,
      rental: rental ?? this.rental,
      gallery: gallery ?? this.gallery,
      favoriteCount: favoriteCount,
      viewCount: viewCount,
      createdAt: createdAt,
      publishedAt: publishedAt,
      extras: extras ?? this.extras,
    );
  }

  String get vehicleClass {
    final raw = extras['vehicle_class']?.toString().trim();
    if (raw != null && raw.isNotEmpty) return raw;
    return 'automobile';
  }

  String? get rejectionReason {
    final moderation = extras['moderation'];
    if (moderation is Map) {
      final reason = moderation['reason']?.toString().trim();
      if (reason != null && reason.isNotEmpty) return reason;
    }
    return extras['rejection_reason']?.toString();
  }

  bool get isRejected {
    final moderation = extras['moderation'];
    if (moderation is Map) {
      final token = moderation['status']?.toString().trim().toLowerCase();
      if (token == 'approved' || token == 'pending') return false;
      if (token == 'rejected') return true;
    }
    if (status != VehicleListingStatus.draft) return false;
    return (extras['rejection_reason']?.toString() ?? '').trim().isNotEmpty;
  }

  String? get primaryImageUrl {
    final cover = coverUrl?.trim() ?? '';
    if (cover.isNotEmpty) return cover;
    for (final item in media) {
      final url = item.url.trim();
      if (item.isCover && !item.isVideo && !item.is360 && url.isNotEmpty) {
        return url;
      }
    }
    for (final item in media) {
      final url = item.url.trim();
      if (!item.isVideo && !item.is360 && url.isNotEmpty) return url;
    }
    return null;
  }

  bool get isLivePublished {
    if (!status.isPubliclyVisible || isRejected) return false;
    final moderation = extras['moderation'];
    if (moderation is Map) {
      final token = moderation['status']?.toString().trim().toLowerCase() ?? '';
      if (token.isNotEmpty && token != 'approved') return false;
    }
    return true;
  }

  String get statusLabelTr {
    if (isRejected) return 'Reddedildi';
    return status.labelTr;
  }

  Map<String, dynamic> toChatProductMap() => {
    'id': id,
    'name': title,
    'brand': specs.brand,
    'price': salePrice?.toString() ?? '',
    'image': coverUrl ?? '',
    'sellerId': sellerId,
    'vehicleId': id,
    'category': 'Galerici',
  };
}

Map<String, dynamic>? _embedMap(Object? raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is List && raw.isNotEmpty && raw.first is Map) {
    return Map<String, dynamic>.from(raw.first as Map);
  }
  return null;
}

int? _asInt(Object? raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw.toString());
}

double? _asDouble(Object? raw) {
  if (raw == null) return null;
  if (raw is double) return raw;
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw.toString().replaceAll(',', '.'));
}

VehicleGallerySummary? _galleryFromSearchRow(Map<String, dynamic> map) {
  final name = (map['gallery_name'] ?? '').toString().trim();
  if (name.isEmpty) return null;
  return VehicleGallerySummary(
    sellerId: (map['seller_id'] ?? '').toString(),
    name: name,
    verified: map['gallery_verified'] == true,
  );
}

Map<String, dynamic> _asMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return const {};
}
