class MallProfile {
  const MallProfile({
    required this.id,
    required this.name,
    required this.city,
    required this.district,
    required this.addressText,
    required this.status,
    required this.isVerified,
    this.legalName,
    this.phone,
    this.website,
    this.openingHours,
    this.logoUrl,
    this.coverUrl,
    this.latitude,
    this.longitude,
  });

  final double? latitude;
  final double? longitude;

  bool get hasLocation =>
      latitude != null && longitude != null && !(latitude == 0 && longitude == 0);

  final String id;
  final String name;
  final String? legalName;
  final String city;
  final String district;
  final String addressText;
  final String? phone;
  final String? website;
  final String? openingHours;
  final String? logoUrl;
  final String? coverUrl;
  final String status;
  final bool isVerified;

  bool get hasLogoAndCover =>
      (logoUrl?.trim().isNotEmpty ?? false) &&
      (coverUrl?.trim().isNotEmpty ?? false);

  bool get hasOpeningHours => openingHours?.trim().isNotEmpty ?? false;

  String get locationLabel =>
      [city, district].where((part) => part.trim().isNotEmpty).join(' / ');

  MallProfile copyWithMedia({String? logoUrl, String? coverUrl}) {
    return MallProfile(
      id: id,
      name: name,
      city: city,
      district: district,
      addressText: addressText,
      status: status,
      isVerified: isVerified,
      legalName: legalName,
      phone: phone,
      website: website,
      openingHours: openingHours,
      logoUrl: logoUrl ?? this.logoUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      latitude: latitude,
      longitude: longitude,
    );
  }

  String get publishLabel => switch (status) {
        'active' => 'Yayında',
        'suspended' => 'Askıda',
        'archived' => 'Arşiv',
        _ => 'Kurulum Aşamasında',
      };

  factory MallProfile.fromMap(Map<String, dynamic> map) {
    return MallProfile(
      id: map['id'].toString(),
      name: map['name']?.toString() ?? '',
      legalName: _text(map['legal_name']),
      city: map['city']?.toString() ?? '',
      district: map['district']?.toString() ?? '',
      addressText: map['address_text']?.toString() ?? '',
      phone: _text(map['phone']),
      website: _text(map['website']),
      openingHours: _text(map['opening_hours']),
      logoUrl: _text(map['logo_url']),
      coverUrl: _text(map['cover_url']),
      status: map['status']?.toString() ?? 'draft',
      isVerified: map['is_verified'] == true,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }
}

class MallMembership {
  const MallMembership({
    required this.mallId,
    required this.role,
    required this.mall,
  });

  final String mallId;
  final String role;
  final MallProfile mall;

  String get roleLabel => mallRoleLabel(role);

  factory MallMembership.fromMap(Map<String, dynamic> map) {
    final nested = map['malls'];
    final mallMap = nested is Map
        ? Map<String, dynamic>.from(nested)
        : nested is List && nested.isNotEmpty && nested.first is Map
            ? Map<String, dynamic>.from(nested.first as Map)
            : <String, dynamic>{
                'id': map['mall_id'],
                'name': 'AVM',
                'city': '',
                'district': '',
                'address_text': '',
                'status': 'draft',
                'is_verified': false,
              };
    return MallMembership(
      mallId: map['mall_id']?.toString() ?? mallMap['id'].toString(),
      role: map['role']?.toString() ?? '',
      mall: MallProfile.fromMap(mallMap),
    );
  }
}

class MallAccount {
  const MallAccount({required this.name, this.email = ''});

  final String name;
  final String email;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first.substring(0, 1);
    return parts.length == 1 ? first.toUpperCase() : '$first${parts.last.substring(0, 1)}'.toUpperCase();
  }
}

/// UI mirror of the server role checks. The RPCs enforce the same lists.
class MallManagementAccess {
  const MallManagementAccess({this.role, this.adminViewer = false});

  final String? role;
  final bool adminViewer;

  bool _is(List<String> roles) => role != null && roles.contains(role);

  bool get canEnter => role != null || adminViewer;
  bool get canEditProfile => _is(const ['mall_manager', 'mall_content_editor']);
  bool get canManageFloors => _is(const ['mall_manager', 'mall_store_manager']);
  bool get canManageUnits => canManageFloors;
  bool get canManageStores => canManageFloors;
  bool get canManageCampaigns => _is(const ['mall_manager', 'mall_content_editor']);
  bool get canManageAds => _is(const ['mall_manager', 'mall_ad_manager']);
  bool get canManageTeam => _is(const ['mall_manager']);
  bool get canPublish => _is(const ['mall_manager']);
}

const mallRoles = <String>[
  'mall_manager',
  'mall_store_manager',
  'mall_content_editor',
  'mall_ad_manager',
];

String mallRoleLabel(String role) {
  return switch (role) {
    'mall_manager' => 'AVM Yöneticisi',
    'mall_store_manager' => 'Mağaza Operasyonları',
    'mall_content_editor' => 'İçerik Editörü',
    'mall_ad_manager' => 'Reklam Yöneticisi',
    _ => role,
  };
}

String? _text(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
