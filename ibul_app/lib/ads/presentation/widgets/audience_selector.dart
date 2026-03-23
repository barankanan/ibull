import 'package:flutter/material.dart';

class AudienceTargetingState {
  const AudienceTargetingState({
    this.primaryCategory,
    this.subcategories = const <String>{},
    this.gender,
    this.ageRange = const RangeValues(18, 45),
    this.maritalStatuses = const <String>{},
    this.educationLevels = const <String>{},
    this.occupations = const <String>{},
    this.incomeLevels = const <String>{},
    this.interests = const <String>{},
    this.shoppingBehaviors = const <String>{},
    this.appBehaviors = const <String>{},
    this.loyaltySignals = const <String>{},
    this.locationType,
    this.devices = const <String>{},
    this.deviceBrands = const <String>{},
    this.connectionTypes = const <String>{},
    this.engagementSignals = const <String>{},
    this.retargetingSegments = const <String>{},
    this.lookalikeSeed,
  });

  final String? primaryCategory;
  final Set<String> subcategories;
  final String? gender;
  final RangeValues ageRange;
  final Set<String> maritalStatuses;
  final Set<String> educationLevels;
  final Set<String> occupations;
  final Set<String> incomeLevels;
  final Set<String> interests;
  final Set<String> shoppingBehaviors;
  final Set<String> appBehaviors;
  final Set<String> loyaltySignals;
  final String? locationType;
  final Set<String> devices;
  final Set<String> deviceBrands;
  final Set<String> connectionTypes;
  final Set<String> engagementSignals;
  final Set<String> retargetingSegments;
  final String? lookalikeSeed;

  bool get hasAnySelection =>
      (primaryCategory ?? '').isNotEmpty ||
      subcategories.isNotEmpty ||
      (gender ?? '').isNotEmpty ||
      maritalStatuses.isNotEmpty ||
      educationLevels.isNotEmpty ||
      occupations.isNotEmpty ||
      incomeLevels.isNotEmpty ||
      interests.isNotEmpty ||
      shoppingBehaviors.isNotEmpty ||
      appBehaviors.isNotEmpty ||
      loyaltySignals.isNotEmpty ||
      (locationType ?? '').isNotEmpty ||
      devices.isNotEmpty ||
      deviceBrands.isNotEmpty ||
      connectionTypes.isNotEmpty ||
      engagementSignals.isNotEmpty ||
      retargetingSegments.isNotEmpty ||
      (lookalikeSeed ?? '').isNotEmpty;

  List<String> get summaryTokens {
    final result = <String>[
      if ((primaryCategory ?? '').isNotEmpty) primaryCategory!,
      ...subcategories.take(2),
      if ((gender ?? '').isNotEmpty) gender!,
      if (interests.isNotEmpty) interests.first,
      if (shoppingBehaviors.isNotEmpty) shoppingBehaviors.first,
      if (retargetingSegments.isNotEmpty) retargetingSegments.first,
    ];
    return result;
  }

  AudienceTargetingState copyWith({
    Object? primaryCategory = _unset,
    Set<String>? subcategories,
    Object? gender = _unset,
    RangeValues? ageRange,
    Set<String>? maritalStatuses,
    Set<String>? educationLevels,
    Set<String>? occupations,
    Set<String>? incomeLevels,
    Set<String>? interests,
    Set<String>? shoppingBehaviors,
    Set<String>? appBehaviors,
    Set<String>? loyaltySignals,
    Object? locationType = _unset,
    Set<String>? devices,
    Set<String>? deviceBrands,
    Set<String>? connectionTypes,
    Set<String>? engagementSignals,
    Set<String>? retargetingSegments,
    Object? lookalikeSeed = _unset,
  }) {
    return AudienceTargetingState(
      primaryCategory: primaryCategory == _unset
          ? this.primaryCategory
          : primaryCategory as String?,
      subcategories: subcategories ?? this.subcategories,
      gender: gender == _unset ? this.gender : gender as String?,
      ageRange: ageRange ?? this.ageRange,
      maritalStatuses: maritalStatuses ?? this.maritalStatuses,
      educationLevels: educationLevels ?? this.educationLevels,
      occupations: occupations ?? this.occupations,
      incomeLevels: incomeLevels ?? this.incomeLevels,
      interests: interests ?? this.interests,
      shoppingBehaviors: shoppingBehaviors ?? this.shoppingBehaviors,
      appBehaviors: appBehaviors ?? this.appBehaviors,
      loyaltySignals: loyaltySignals ?? this.loyaltySignals,
      locationType: locationType == _unset
          ? this.locationType
          : locationType as String?,
      devices: devices ?? this.devices,
      deviceBrands: deviceBrands ?? this.deviceBrands,
      connectionTypes: connectionTypes ?? this.connectionTypes,
      engagementSignals: engagementSignals ?? this.engagementSignals,
      retargetingSegments: retargetingSegments ?? this.retargetingSegments,
      lookalikeSeed: lookalikeSeed == _unset
          ? this.lookalikeSeed
          : lookalikeSeed as String?,
    );
  }

  Map<String, dynamic> toMetadata() {
    return <String, dynamic>{
      'primary_category': primaryCategory,
      'subcategories': subcategories.toList(growable: false),
      'gender': gender,
      'age_min': ageRange.start.round(),
      'age_max': ageRange.end.round(),
      'marital_statuses': maritalStatuses.toList(growable: false),
      'education_levels': educationLevels.toList(growable: false),
      'occupations': occupations.toList(growable: false),
      'income_levels': incomeLevels.toList(growable: false),
      'interests': interests.toList(growable: false),
      'shopping_behaviors': shoppingBehaviors.toList(growable: false),
      'app_behaviors': appBehaviors.toList(growable: false),
      'loyalty_signals': loyaltySignals.toList(growable: false),
      'location_type': locationType,
      'devices': devices.toList(growable: false),
      'device_brands': deviceBrands.toList(growable: false),
      'connection_types': connectionTypes.toList(growable: false),
      'engagement_signals': engagementSignals.toList(growable: false),
      'retargeting_segments': retargetingSegments.toList(growable: false),
      'lookalike_seed': lookalikeSeed,
    };
  }

  factory AudienceTargetingState.fromMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null || metadata.isEmpty) {
      return const AudienceTargetingState();
    }
    Set<String> readSet(String key) {
      final raw = metadata[key];
      if (raw is List) {
        return raw.map((item) => item.toString()).toSet();
      }
      return <String>{};
    }

    return AudienceTargetingState(
      primaryCategory: metadata['primary_category']?.toString(),
      subcategories: readSet('subcategories'),
      gender: metadata['gender']?.toString(),
      ageRange: RangeValues(
        ((metadata['age_min'] as num?)?.toDouble() ?? 18).clamp(13, 65),
        ((metadata['age_max'] as num?)?.toDouble() ?? 45).clamp(13, 65),
      ),
      maritalStatuses: readSet('marital_statuses'),
      educationLevels: readSet('education_levels'),
      occupations: readSet('occupations'),
      incomeLevels: readSet('income_levels'),
      interests: readSet('interests'),
      shoppingBehaviors: readSet('shopping_behaviors'),
      appBehaviors: readSet('app_behaviors'),
      loyaltySignals: readSet('loyalty_signals'),
      locationType: metadata['location_type']?.toString(),
      devices: readSet('devices'),
      deviceBrands: readSet('device_brands'),
      connectionTypes: readSet('connection_types'),
      engagementSignals: readSet('engagement_signals'),
      retargetingSegments: readSet('retargeting_segments'),
      lookalikeSeed: metadata['lookalike_seed']?.toString(),
    );
  }
}

class AudienceSelector extends StatelessWidget {
  const AudienceSelector({
    required this.categories,
    required this.subcategoryMap,
    required this.targetingState,
    required this.onTargetingChanged,
    required this.onOpenCitySelector,
    required this.cityLabel,
    required this.locationLocked,
    required this.distanceEnabled,
    required this.distanceKm,
    required this.onDistanceToggle,
    required this.onDistanceChanged,
    super.key,
  });

  final List<String> categories;
  final Map<String, List<String>> subcategoryMap;
  final AudienceTargetingState targetingState;
  final ValueChanged<AudienceTargetingState> onTargetingChanged;
  final VoidCallback onOpenCitySelector;
  final String cityLabel;
  final bool locationLocked;
  final bool distanceEnabled;
  final double distanceKm;
  final ValueChanged<bool> onDistanceToggle;
  final ValueChanged<double> onDistanceChanged;

  static const List<String> _genders = <String>[
    'Erkek',
    'Kadin',
    'Belirtmek istemeyen',
    'Tumu',
  ];

  static const List<String> _maritalStatuses = <String>[
    'Bekar',
    'Evli',
    'Nisanli',
    'Bosanmis',
    'Dul',
    'Belirtilmemis',
  ];

  static const List<String> _educationLevels = <String>[
    'Lise ogrencisi',
    'Lise mezunu',
    'Universite ogrencisi',
    'Universite mezunu',
    'Yuksek lisans',
    'Doktora',
  ];

  static const List<String> _occupations = <String>[
    'Ogrenci',
    'Muhendis',
    'Doktor',
    'Avukat',
    'Ogretmen',
    'Freelancer',
    'Yazilimci',
    'Girisimci',
    'Esnaf',
    'Ev hanimi',
    'Yonetici',
  ];

  static const List<String> _incomeLevels = <String>[
    'Dusuk gelir',
    'Orta gelir',
    'Yuksek gelir',
    'Premium tuketici',
  ];

  static const List<String> _interests = <String>[
    'Akilli telefon',
    'Bilgisayar',
    'Gaming',
    'Yazilim',
    'Yapay zeka',
    'Startuplar',
    'Blockchain',
    'Kripto',
    'Kadin giyim',
    'Erkek giyim',
    'Ayakkabi',
    'Canta',
    'Taki',
    'Saat',
    'Luks moda',
    'Otomobil meraklilari',
    'SUV',
    'Elektrikli arac',
    'Ev dekorasyonu',
    'Mobilya',
    'Minimal yasam',
    'Bahce',
    'Evcil hayvan',
    'Fitness',
    'Kosu',
    'Futbol',
    'Basketbol',
    'Yoga',
    'Bodybuilding',
    'Tatil',
    'Otel',
    'Yurtdisi seyahat',
    'Kamp',
    'Online alisveris yapan',
    'Sepete ekleyen',
    'Indirim takip eden',
    'Premium marka tuketicisi',
  ];

  static const List<String> _shoppingBehaviors = <String>[
    'Son 7 gun alisveris yapan',
    'Son 30 gun alisveris yapan',
    'Sepete ekleyip satin almayan',
    'Favorilere ekleyen',
  ];

  static const List<String> _appBehaviors = <String>[
    'Uygulamayi sik kullanan',
    'Pasif kullanici',
    'Yeni kullanici',
  ];

  static const List<String> _loyaltySignals = <String>[
    'Ayni magazadan sik alisveris yapan',
    'Belirli kategoriye sadik kullanici',
  ];

  static const List<String> _locationTypes = <String>[
    'Bu bolgede yasayan',
    'Bu bolgede calisan',
    'Bu bolgeyi ziyaret eden',
  ];

  static const List<String> _devices = <String>[
    'iOS',
    'Android',
    'Web',
    'Tablet',
  ];

  static const List<String> _deviceBrands = <String>[
    'iPhone',
    'Samsung',
    'Xiaomi',
  ];

  static const List<String> _connectionTypes = <String>['WiFi', 'Mobil veri'];

  static const List<String> _engagementSignals = <String>[
    'Urun goruntuledi',
    'Favorilere ekledi',
    'Sepete ekledi',
    'Satin aldi',
  ];

  static const List<String> _retargetingSegments = <String>[
    'Sepete ekleyip almayan',
    'Urun sayfasina bakan',
    'Magazayi ziyaret eden',
    'Push bildirimi acan',
  ];

  static const List<String> _lookalikes = <String>[
    'Satin alanlara benzeyen kullanicilar',
    'Yuksek sepet tutari olanlara benzeyen kullanicilar',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subcategories =
        subcategoryMap[targetingState.primaryCategory] ?? const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kategori secin',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: categories
              .map((category) {
                final selected = targetingState.primaryCategory == category;
                return ChoiceChip(
                  selected: selected,
                  onSelected: (_) {
                    onTargetingChanged(
                      targetingState.copyWith(
                        primaryCategory: category,
                        subcategories: <String>{},
                      ),
                    );
                  },
                  label: Text(category),
                  showCheckmark: false,
                  selectedColor: const Color(0xFFDBEAFE),
                  backgroundColor: const Color(0xFFF8FAFC),
                  side: BorderSide(
                    color: selected
                        ? const Color(0xFF60A5FA)
                        : const Color(0xFFE2E8F0),
                  ),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? const Color(0xFF1D4ED8)
                        : const Color(0xFF334155),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                );
              })
              .toList(growable: false),
        ),
        if ((targetingState.primaryCategory ?? '').isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Alt kategori secin',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: subcategories
                .map((item) {
                  final selected = targetingState.subcategories.contains(item);
                  return FilterChip(
                    selected: selected,
                    onSelected: (_) {
                      final next = {...targetingState.subcategories};
                      if (selected) {
                        next.remove(item);
                      } else {
                        next.add(item);
                      }
                      onTargetingChanged(
                        targetingState.copyWith(subcategories: next),
                      );
                    },
                    label: Text(item),
                    showCheckmark: false,
                    selectedColor: const Color(0xFFE0F2FE),
                    backgroundColor: const Color(0xFFFFFFFF),
                    pressElevation: 0,
                    side: BorderSide(
                      color: selected
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFFD7DFEA),
                    ),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? const Color(0xFF0F4C81)
                          : const Color(0xFF475569),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  );
                })
                .toList(growable: false),
          ),
          const SizedBox(height: 24),
          _SectionCard(
            title: 'Detayli hedefleme',
            subtitle:
                'Demografik, ilgi alani, davranis, cihaz ve retargeting parametrelerini buradan secin.',
            child: Column(
              children: [
                _ExpansionSection(
                  title: 'Demografik Hedefleme',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SingleChoiceWrap(
                        title: 'Cinsiyet',
                        options: _genders,
                        selectedValue: targetingState.gender,
                        onSelected: (value) {
                          onTargetingChanged(
                            targetingState.copyWith(gender: value),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Yas araligi: ${targetingState.ageRange.start.round()} - ${targetingState.ageRange.end.round()}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      RangeSlider(
                        values: targetingState.ageRange,
                        min: 13,
                        max: 65,
                        divisions: 52,
                        labels: RangeLabels(
                          targetingState.ageRange.start.round().toString(),
                          targetingState.ageRange.end.round().toString(),
                        ),
                        onChanged: (value) {
                          onTargetingChanged(
                            targetingState.copyWith(ageRange: value),
                          );
                        },
                      ),
                      _MultiChoiceWrap(
                        title: 'Medeni durum',
                        options: _maritalStatuses,
                        selectedValues: targetingState.maritalStatuses,
                        onChanged: (values) {
                          onTargetingChanged(
                            targetingState.copyWith(maritalStatuses: values),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      _MultiChoiceWrap(
                        title: 'Egitim durumu',
                        options: _educationLevels,
                        selectedValues: targetingState.educationLevels,
                        onChanged: (values) {
                          onTargetingChanged(
                            targetingState.copyWith(educationLevels: values),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      _MultiChoiceWrap(
                        title: 'Meslek',
                        options: _occupations,
                        selectedValues: targetingState.occupations,
                        onChanged: (values) {
                          onTargetingChanged(
                            targetingState.copyWith(occupations: values),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      _MultiChoiceWrap(
                        title: 'Gelir seviyesi',
                        options: _incomeLevels,
                        selectedValues: targetingState.incomeLevels,
                        onChanged: (values) {
                          onTargetingChanged(
                            targetingState.copyWith(incomeLevels: values),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                _ExpansionSection(
                  title: 'Ilgi Alani ve Davranis',
                  child: Column(
                    children: [
                      _MultiChoiceWrap(
                        title: 'Ilgi alanlari',
                        options: _interests,
                        selectedValues: targetingState.interests,
                        onChanged: (values) {
                          onTargetingChanged(
                            targetingState.copyWith(interests: values),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      _MultiChoiceWrap(
                        title: 'Alisveris davranisi',
                        options: _shoppingBehaviors,
                        selectedValues: targetingState.shoppingBehaviors,
                        onChanged: (values) {
                          onTargetingChanged(
                            targetingState.copyWith(shoppingBehaviors: values),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      _MultiChoiceWrap(
                        title: 'Uygulama davranisi',
                        options: _appBehaviors,
                        selectedValues: targetingState.appBehaviors,
                        onChanged: (values) {
                          onTargetingChanged(
                            targetingState.copyWith(appBehaviors: values),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      _MultiChoiceWrap(
                        title: 'Marka sadakati',
                        options: _loyaltySignals,
                        selectedValues: targetingState.loyaltySignals,
                        onChanged: (values) {
                          onTargetingChanged(
                            targetingState.copyWith(loyaltySignals: values),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                _ExpansionSection(
                  title: 'Konum ve Cihaz',
                  child: Column(
                    children: [
                      _SingleChoiceWrap(
                        title: 'Konum turu',
                        options: _locationTypes,
                        selectedValue: targetingState.locationType,
                        onSelected: (value) {
                          onTargetingChanged(
                            targetingState.copyWith(locationType: value),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      _MultiChoiceWrap(
                        title: 'Cihaz',
                        options: _devices,
                        selectedValues: targetingState.devices,
                        onChanged: (values) {
                          onTargetingChanged(
                            targetingState.copyWith(devices: values),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      _MultiChoiceWrap(
                        title: 'Telefon modeli / marka',
                        options: _deviceBrands,
                        selectedValues: targetingState.deviceBrands,
                        onChanged: (values) {
                          onTargetingChanged(
                            targetingState.copyWith(deviceBrands: values),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      _MultiChoiceWrap(
                        title: 'Internet turu',
                        options: _connectionTypes,
                        selectedValues: targetingState.connectionTypes,
                        onChanged: (values) {
                          onTargetingChanged(
                            targetingState.copyWith(connectionTypes: values),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                _ExpansionSection(
                  title: 'Etkilesim, Retargeting ve Lookalike',
                  child: Column(
                    children: [
                      _MultiChoiceWrap(
                        title: 'Reklam etkilesim hedefleme',
                        options: _engagementSignals,
                        selectedValues: targetingState.engagementSignals,
                        onChanged: (values) {
                          onTargetingChanged(
                            targetingState.copyWith(engagementSignals: values),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      _MultiChoiceWrap(
                        title: 'Retargeting',
                        options: _retargetingSegments,
                        selectedValues: targetingState.retargetingSegments,
                        onChanged: (values) {
                          onTargetingChanged(
                            targetingState.copyWith(
                              retargetingSegments: values,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      _SingleChoiceWrap(
                        title: 'Lookalike',
                        options: _lookalikes,
                        selectedValue: targetingState.lookalikeSeed,
                        onSelected: (value) {
                          onTargetingChanged(
                            targetingState.copyWith(lookalikeSeed: value),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'Il / Ilce secimi',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: locationLocked ? null : onOpenCitySelector,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_city_rounded,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    cityLabel,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
                Icon(
                  locationLocked
                      ? Icons.lock_outline_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
        if (locationLocked) ...[
          const SizedBox(height: 10),
          const Text(
            'Bu hedefte konum magaza adresinize gore otomatik secilir ve degistirilemez.',
            style: TextStyle(color: Color(0xFF64748B), height: 1.45),
          ),
        ],
        const SizedBox(height: 20),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: distanceEnabled,
          onChanged: locationLocked ? null : onDistanceToggle,
          title: const Text('Mesafe hedefleme'),
          subtitle: const Text(
            'Sehir icinde belirli capta kullanicilara teslim et.',
          ),
        ),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: distanceEnabled ? 1 : 0.45,
          child: IgnorePointer(
            ignoring: !distanceEnabled,
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'Mesafe',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${distanceKm.toStringAsFixed(0)} km',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: distanceKm,
                  min: 1,
                  max: 50,
                  divisions: 49,
                  label: '${distanceKm.toStringAsFixed(0)} km',
                  onChanged: onDistanceChanged,
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Text(
                    'Sectiginiz sehir icerisinde bulundugunuz konumdan ${distanceKm.toStringAsFixed(0)} km mesafedeki kullanicilara reklam gosterilir. Tum sehir kapsami icin mesafe ozelligini kapatabilirsiniz.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF1E3A8A),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF64748B), height: 1.5),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ExpansionSection extends StatelessWidget {
  const _ExpansionSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 12),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        children: [child],
      ),
    );
  }
}

class _SingleChoiceWrap extends StatelessWidget {
  const _SingleChoiceWrap({
    required this.title,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  final String title;
  final List<String> options;
  final String? selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: options
              .map((item) {
                final selected = selectedValue == item;
                return ChoiceChip(
                  selected: selected,
                  onSelected: (_) => onSelected(item),
                  label: Text(item),
                  showCheckmark: false,
                  selectedColor: const Color(0xFF7C3AED),
                  backgroundColor: const Color(0xFFFFFFFF),
                  pressElevation: 0,
                  side: BorderSide(
                    color: selected
                        ? const Color(0xFF7C3AED)
                        : const Color(0xFFD7DFEA),
                  ),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : const Color(0xFF475569),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _MultiChoiceWrap extends StatelessWidget {
  const _MultiChoiceWrap({
    required this.title,
    required this.options,
    required this.selectedValues,
    required this.onChanged,
  });

  final String title;
  final List<String> options;
  final Set<String> selectedValues;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: options
              .map((item) {
                final selected = selectedValues.contains(item);
                return FilterChip(
                  selected: selected,
                  onSelected: (_) {
                    final next = {...selectedValues};
                    if (selected) {
                      next.remove(item);
                    } else {
                      next.add(item);
                    }
                    onChanged(next);
                  },
                  label: Text(item),
                  showCheckmark: false,
                  selectedColor: const Color(0xFF7C3AED),
                  backgroundColor: const Color(0xFFFFFFFF),
                  pressElevation: 0,
                  side: BorderSide(
                    color: selected
                        ? const Color(0xFF7C3AED)
                        : const Color(0xFFD7DFEA),
                  ),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : const Color(0xFF475569),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ],
    );
  }
}

const Object _unset = Object();
