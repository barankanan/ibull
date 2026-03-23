import 'package:flutter/material.dart';

import '../models/db_category.dart';

const String deletedManagedCategoryIconName = '__ibul_deleted__';

class MobileCategoryNode {
  const MobileCategoryNode({
    required this.name,
    required this.orderIndex,
    this.id,
    this.parentId,
    this.imageUrl,
    this.iconName,
    this.fallbackAssetPath,
    this.isActive = true,
    this.subCategories = const [],
  });

  final int? id;
  final int? parentId;
  final String name;
  final String? imageUrl;
  final String? iconName;
  final String? fallbackAssetPath;
  final int orderIndex;
  final bool isActive;
  final List<MobileCategoryNode> subCategories;

  bool get isMainCategory => parentId == null;

  MobileCategoryNode copyWith({
    int? id,
    int? parentId,
    String? name,
    String? imageUrl,
    String? iconName,
    String? fallbackAssetPath,
    int? orderIndex,
    bool? isActive,
    List<MobileCategoryNode>? subCategories,
  }) {
    return MobileCategoryNode(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      iconName: iconName ?? this.iconName,
      fallbackAssetPath: fallbackAssetPath ?? this.fallbackAssetPath,
      orderIndex: orderIndex ?? this.orderIndex,
      isActive: isActive ?? this.isActive,
      subCategories: subCategories ?? this.subCategories,
    );
  }

  DBCategory toDbCategory() {
    return DBCategory(
      id: id,
      name: name,
      iconName: iconName,
      imageUrl: imageUrl,
      orderIndex: orderIndex,
      parentId: parentId,
      isActive: isActive,
    );
  }
}

class MobileCategorySeed {
  const MobileCategorySeed({
    required this.name,
    required this.orderIndex,
    this.iconName,
    this.fallbackAssetPath,
    this.subCategories = const [],
  });

  final String name;
  final int orderIndex;
  final String? iconName;
  final String? fallbackAssetPath;
  final List<MobileCategorySeed> subCategories;
}

const List<MobileCategorySeed> defaultMobileCategorySeeds = [
  MobileCategorySeed(
    name: 'Yakın Lokasyon',
    orderIndex: 1,
    fallbackAssetPath: 'assets/category_icons/Yakın lokasyon.png',
    iconName: 'near_me',
    subCategories: [
      MobileCategorySeed(
        name: 'Yemek',
        orderIndex: 1,
        fallbackAssetPath: 'assets/subcategory_icons/yemek.png',
        iconName: 'restaurant_menu',
      ),
      MobileCategorySeed(
        name: 'Market',
        orderIndex: 2,
        fallbackAssetPath: 'assets/subcategory_icons/market.png',
        iconName: 'shopping_cart',
      ),
      MobileCategorySeed(
        name: 'Keşfet (Popüler Mekanlar)',
        orderIndex: 3,
        iconName: 'explore',
      ),
    ],
  ),
  MobileCategorySeed(
    name: 'Erkek',
    orderIndex: 2,
    iconName: 'man',
    subCategories: [
      MobileCategorySeed(name: 'Giyim', orderIndex: 1, iconName: 'checkroom'),
      MobileCategorySeed(name: 'Saat', orderIndex: 2, iconName: 'watch'),
      MobileCategorySeed(name: 'Aksesuar', orderIndex: 3, iconName: 'style'),
      MobileCategorySeed(
        name: 'Ayakkabı & Çanta',
        orderIndex: 4,
        iconName: 'hiking',
      ),
      MobileCategorySeed(
        name: 'Spor & Outdoor',
        orderIndex: 5,
        iconName: 'directions_run',
      ),
      MobileCategorySeed(
        name: 'Kişisel Bakım',
        orderIndex: 6,
        iconName: 'face',
      ),
      MobileCategorySeed(
        name: 'Büyük Beden',
        orderIndex: 7,
        iconName: 'accessibility_new',
      ),
    ],
  ),
  MobileCategorySeed(
    name: 'Kadın',
    orderIndex: 3,
    iconName: 'woman',
    subCategories: [
      MobileCategorySeed(name: 'Giyim', orderIndex: 1, iconName: 'checkroom'),
      MobileCategorySeed(
        name: 'Kozmetik',
        orderIndex: 2,
        iconName: 'brush',
      ),
      MobileCategorySeed(name: 'Aksesuar', orderIndex: 3, iconName: 'style'),
      MobileCategorySeed(
        name: 'Ayakkabı & Çanta',
        orderIndex: 4,
        iconName: 'shopping_bag',
      ),
      MobileCategorySeed(
        name: 'Ev & İç Giyim',
        orderIndex: 5,
        iconName: 'hotel',
      ),
      MobileCategorySeed(
        name: 'Spor & Outdoor',
        orderIndex: 6,
        iconName: 'directions_run',
      ),
      MobileCategorySeed(
        name: 'Büyük Beden',
        orderIndex: 7,
        iconName: 'accessibility_new',
      ),
    ],
  ),
  MobileCategorySeed(
    name: 'Elektronik',
    orderIndex: 4,
    fallbackAssetPath: 'assets/category_icons/elektronik.png',
    iconName: 'devices',
    subCategories: [
      MobileCategorySeed(
        name: 'Gaming',
        orderIndex: 1,
        iconName: 'sports_esports',
      ),
      MobileCategorySeed(
        name: 'Telefonlar',
        orderIndex: 2,
        iconName: 'phone_iphone',
      ),
      MobileCategorySeed(
        name: 'Laptop & Tablet',
        orderIndex: 3,
        iconName: 'laptop',
      ),
      MobileCategorySeed(
        name: 'Televizyon',
        orderIndex: 4,
        iconName: 'tv',
      ),
      MobileCategorySeed(
        name: 'Bilgisayar Bileşenleri',
        orderIndex: 5,
        iconName: 'memory',
      ),
      MobileCategorySeed(
        name: 'Beyaz Eşya',
        orderIndex: 6,
        iconName: 'kitchen',
      ),
      MobileCategorySeed(
        name: 'Kişisel Bakım',
        orderIndex: 7,
        iconName: 'face',
      ),
      MobileCategorySeed(
        name: 'Isıtma & Soğutma',
        orderIndex: 8,
        iconName: 'ac_unit',
      ),
      MobileCategorySeed(
        name: 'Oyuncu Ekipmanları',
        orderIndex: 9,
        iconName: 'keyboard',
      ),
      MobileCategorySeed(
        name: 'Oyun Konsolları',
        orderIndex: 10,
        iconName: 'gamepad',
      ),
      MobileCategorySeed(
        name: 'Sinema & Ses Sistemleri',
        orderIndex: 11,
        iconName: 'speaker_group',
      ),
      MobileCategorySeed(
        name: 'Telefon Aksesuarları',
        orderIndex: 12,
        fallbackAssetPath: 'assets/subcategory_icons/telefon & aksesuar.png',
        iconName: 'headphones',
      ),
      MobileCategorySeed(
        name: 'Giyilebilir Teknoloji',
        orderIndex: 13,
        iconName: 'watch',
      ),
      MobileCategorySeed(
        name: 'Bilgisayar Aksesuarları',
        orderIndex: 14,
        iconName: 'mouse',
      ),
      MobileCategorySeed(
        name: 'Hoparlör',
        orderIndex: 15,
        iconName: 'speaker',
      ),
      MobileCategorySeed(
        name: 'Monitör',
        orderIndex: 16,
        iconName: 'monitor',
      ),
      MobileCategorySeed(
        name: 'Yazıcı & Tarayıcı',
        orderIndex: 17,
        iconName: 'print',
      ),
    ],
  ),
  MobileCategorySeed(
    name: 'Ayakkabı & Çanta',
    orderIndex: 5,
    iconName: 'shopping_bag',
    subCategories: [
      MobileCategorySeed(
        name: 'Kadın Ayakkabı',
        orderIndex: 1,
        iconName: 'girl',
      ),
      MobileCategorySeed(
        name: 'Erkek Ayakkabı',
        orderIndex: 2,
        iconName: 'man',
      ),
      MobileCategorySeed(
        name: 'Çocuk Ayakkabı',
        orderIndex: 3,
        iconName: 'child_care',
      ),
      MobileCategorySeed(
        name: 'Kadın Çanta',
        orderIndex: 4,
        iconName: 'shopping_bag',
      ),
      MobileCategorySeed(
        name: 'Erkek Çanta',
        orderIndex: 5,
        iconName: 'backpack',
      ),
      MobileCategorySeed(
        name: 'Çocuk Çanta',
        orderIndex: 6,
        iconName: 'school',
      ),
      MobileCategorySeed(
        name: 'Valiz & Bavul',
        orderIndex: 7,
        iconName: 'luggage',
      ),
    ],
  ),
  MobileCategorySeed(
    name: 'Saat & Aksesuar',
    orderIndex: 6,
    iconName: 'watch',
    subCategories: [
      MobileCategorySeed(
        name: 'Kadın Saat & Takı',
        orderIndex: 1,
        iconName: 'watch',
      ),
      MobileCategorySeed(
        name: 'Erkek Saat & Takı',
        orderIndex: 2,
        iconName: 'watch_later',
      ),
      MobileCategorySeed(
        name: 'Akıllı Saatler',
        orderIndex: 3,
        iconName: 'watch_outlined',
      ),
      MobileCategorySeed(
        name: 'Çocuk Saatleri',
        orderIndex: 4,
        iconName: 'child_friendly',
      ),
      MobileCategorySeed(
        name: 'Güneş Gözlüğü',
        orderIndex: 5,
        iconName: 'wb_sunny',
      ),
    ],
  ),
  MobileCategorySeed(
    name: 'Ev & Yaşam',
    orderIndex: 7,
    fallbackAssetPath: 'assets/category_icons/Ev & Yaşam.png',
    iconName: 'home',
    subCategories: [
      MobileCategorySeed(
        name: 'Sofra & Mutfak',
        orderIndex: 1,
        iconName: 'restaurant',
      ),
      MobileCategorySeed(
        name: 'Ev Tekstili',
        orderIndex: 2,
        iconName: 'bed',
      ),
      MobileCategorySeed(
        name: 'Mobilya',
        orderIndex: 3,
        iconName: 'chair',
      ),
      MobileCategorySeed(
        name: 'Aydınlatma',
        orderIndex: 4,
        iconName: 'lightbulb',
      ),
      MobileCategorySeed(
        name: 'Banyo & Mutfak',
        orderIndex: 5,
        iconName: 'bathtub',
      ),
      MobileCategorySeed(
        name: 'Elektrikli Ev Aletleri',
        orderIndex: 6,
        iconName: 'iron',
      ),
      MobileCategorySeed(
        name: 'Ev Dekorasyonu',
        orderIndex: 7,
        iconName: 'home',
      ),
      MobileCategorySeed(
        name: 'Akıllı Ev & Güvenlik Sistemleri',
        orderIndex: 8,
        iconName: 'security',
      ),
      MobileCategorySeed(
        name: 'Su Arıtma Ürünleri',
        orderIndex: 9,
        iconName: 'water_drop',
      ),
    ],
  ),
  MobileCategorySeed(
    name: 'Kırtasiye & Ofis',
    orderIndex: 8,
    iconName: 'edit_note',
    subCategories: [
      MobileCategorySeed(
        name: 'Ofis Mobilyaları',
        orderIndex: 1,
        iconName: 'desk',
      ),
      MobileCategorySeed(
        name: 'Ofis Malzemeleri',
        orderIndex: 2,
        iconName: 'attach_file',
      ),
      MobileCategorySeed(
        name: 'Yazı Gereçleri',
        orderIndex: 3,
        iconName: 'edit',
      ),
      MobileCategorySeed(
        name: 'Defterler',
        orderIndex: 4,
        iconName: 'book',
      ),
      MobileCategorySeed(
        name: 'Kitaplar',
        orderIndex: 5,
        iconName: 'menu_book',
      ),
      MobileCategorySeed(
        name: 'Sanatsal Malzemeler (Boya vb.)',
        orderIndex: 6,
        iconName: 'palette',
      ),
      MobileCategorySeed(
        name: 'Okul Setleri',
        orderIndex: 7,
        iconName: 'backpack',
      ),
    ],
  ),
  MobileCategorySeed(
    name: 'Oto, Bahçe, Yapı Market',
    orderIndex: 9,
    iconName: 'directions_car',
    subCategories: [
      MobileCategorySeed(
        name: 'Otomobil & Motosiklet',
        orderIndex: 1,
        iconName: 'directions_car',
      ),
      MobileCategorySeed(
        name: 'Yapı Market & Hırdavat',
        orderIndex: 2,
        iconName: 'build',
      ),
      MobileCategorySeed(
        name: 'Bahçe Ürünleri',
        orderIndex: 3,
        iconName: 'grass',
      ),
      MobileCategorySeed(
        name: 'Banyo Ürünleri & Tesisat',
        orderIndex: 4,
        iconName: 'plumbing',
      ),
      MobileCategorySeed(
        name: 'Elektrikli Araç Ürünleri',
        orderIndex: 5,
        iconName: 'electric_car',
      ),
      MobileCategorySeed(
        name: 'Oto Ses & Görüntü Sistemleri',
        orderIndex: 6,
        iconName: 'speaker_group',
      ),
      MobileCategorySeed(
        name: 'Oto Yedek Parça',
        orderIndex: 7,
        iconName: 'settings',
      ),
      MobileCategorySeed(
        name: 'Araç Bakım & Temizlik',
        orderIndex: 8,
        iconName: 'cleaning_services',
      ),
      MobileCategorySeed(
        name: 'Oto Aksesuar (Paspas, Silecek vb.)',
        orderIndex: 9,
        iconName: 'car_repair',
      ),
      MobileCategorySeed(
        name: 'Karavan Aksesuarları',
        orderIndex: 10,
        iconName: 'airport_shuttle',
      ),
      MobileCategorySeed(
        name: 'Oto Buzdolapları',
        orderIndex: 11,
        iconName: 'kitchen',
      ),
      MobileCategorySeed(
        name: 'Seyahat Ürünleri',
        orderIndex: 12,
        iconName: 'luggage',
      ),
      MobileCategorySeed(
        name: 'Bahçe & Tarım Makineleri',
        orderIndex: 13,
        iconName: 'agriculture',
      ),
      MobileCategorySeed(
        name: 'Mangal & Barbekü',
        orderIndex: 14,
        iconName: 'outdoor_grill',
      ),
      MobileCategorySeed(
        name: 'Havuz Malzemeleri',
        orderIndex: 15,
        iconName: 'pool',
      ),
      MobileCategorySeed(
        name: 'İş Güvenliği',
        orderIndex: 16,
        iconName: 'health_and_safety',
      ),
    ],
  ),
  MobileCategorySeed(
    name: 'Oyuncak, Müzik, Film',
    orderIndex: 10,
    iconName: 'toys',
    subCategories: [
      MobileCategorySeed(name: 'Oyuncaklar', orderIndex: 1, iconName: 'toys'),
      MobileCategorySeed(
        name: 'Hobi & Eğlence Oyunları',
        orderIndex: 2,
        iconName: 'extension',
      ),
      MobileCategorySeed(
        name: 'Müzik Enstrümanları ve Ekipmanları',
        orderIndex: 3,
        iconName: 'music_note',
      ),
      MobileCategorySeed(
        name: 'Müzik Albümleri',
        orderIndex: 4,
        iconName: 'album',
      ),
      MobileCategorySeed(
        name: 'Filmler',
        orderIndex: 5,
        iconName: 'movie',
      ),
      MobileCategorySeed(
        name: 'Etkinlik Biletleri',
        orderIndex: 6,
        iconName: 'confirmation_number',
      ),
      MobileCategorySeed(
        name: 'Dijital Oyun & Eğitim',
        orderIndex: 7,
        iconName: 'games',
      ),
    ],
  ),
  MobileCategorySeed(
    name: 'Spor & Outdoor',
    orderIndex: 11,
    fallbackAssetPath: 'assets/category_icons/spor & Outdoor.png',
    iconName: 'sports_soccer',
    subCategories: [
      MobileCategorySeed(
        name: 'Spor Giyim & Ayakkabı',
        orderIndex: 1,
        iconName: 'checkroom',
      ),
      MobileCategorySeed(
        name: 'Outdoor Giyim & Ayakkabı',
        orderIndex: 2,
        iconName: 'hiking',
      ),
      MobileCategorySeed(
        name: 'Fitness & Kondisyon Ürünleri',
        orderIndex: 3,
        fallbackAssetPath: 'assets/subcategory_icons/fitness & kondisyon.png',
        iconName: 'fitness_center',
      ),
      MobileCategorySeed(
        name: 'Spor Branşları (Basketbol, Futbol vb.)',
        orderIndex: 4,
        iconName: 'sports_basketball',
      ),
      MobileCategorySeed(
        name: 'Kamp & Kampçılık',
        orderIndex: 5,
        iconName: 'cabin',
      ),
      MobileCategorySeed(
        name: 'Bisiklet',
        orderIndex: 6,
        iconName: 'directions_bike',
      ),
      MobileCategorySeed(
        name: 'Elektrikli Scooter, Paten & Kaykay',
        orderIndex: 7,
        iconName: 'electric_scooter',
      ),
      MobileCategorySeed(
        name: 'Şişme Su Ürünleri',
        orderIndex: 8,
        iconName: 'pool',
      ),
      MobileCategorySeed(
        name: 'Balıkçılık & Avcılık',
        orderIndex: 9,
        iconName: 'phishing',
      ),
      MobileCategorySeed(
        name: 'Tekne Malzemeleri',
        orderIndex: 10,
        iconName: 'sailing',
      ),
      MobileCategorySeed(
        name: 'Doğa Sporları',
        orderIndex: 11,
        iconName: 'landscape',
      ),
      MobileCategorySeed(
        name: 'Kış & Su Sporları',
        orderIndex: 12,
        iconName: 'snowboarding',
      ),
      MobileCategorySeed(
        name: 'Askeri Malzeme & Giyim',
        orderIndex: 13,
        iconName: 'shield',
      ),
      MobileCategorySeed(
        name: 'Dürbün, Teleskop & Navigasyon',
        orderIndex: 14,
        iconName: 'visibility',
      ),
      MobileCategorySeed(
        name: 'Taraftar Ürünleri',
        orderIndex: 15,
        iconName: 'flag',
      ),
    ],
  ),
  MobileCategorySeed(
    name: 'Kozmetik & Kişisel Bakım',
    orderIndex: 12,
    fallbackAssetPath: 'assets/category_icons/kozmetik & Kişisel Bakım.png',
    iconName: 'spa',
    subCategories: [
      MobileCategorySeed(
        name: 'Kişisel Bakım',
        orderIndex: 1,
        iconName: 'face',
      ),
      MobileCategorySeed(name: 'Makyaj', orderIndex: 2, iconName: 'brush'),
      MobileCategorySeed(
        name: 'Saç Bakımı',
        orderIndex: 3,
        iconName: 'content_cut',
      ),
      MobileCategorySeed(
        name: 'Parfüm & Deodorant',
        orderIndex: 4,
        iconName: 'science',
      ),
      MobileCategorySeed(
        name: 'Profesyonel Saç Bakımı',
        orderIndex: 5,
        iconName: 'spa',
      ),
      MobileCategorySeed(
        name: 'Cilt Bakımı',
        orderIndex: 6,
        iconName: 'face_retouching_natural',
      ),
      MobileCategorySeed(
        name: 'Ağız Bakımı',
        orderIndex: 7,
        iconName: 'clean_hands',
      ),
      MobileCategorySeed(
        name: 'Güneş Kremleri',
        orderIndex: 8,
        iconName: 'wb_sunny',
      ),
      MobileCategorySeed(
        name: 'Besin Takviyeleri',
        orderIndex: 9,
        iconName: 'medication',
      ),
      MobileCategorySeed(
        name: 'Duş & Banyo Ürünleri',
        orderIndex: 10,
        iconName: 'shower',
      ),
      MobileCategorySeed(
        name: 'Erkek Tıraş Ürünleri',
        orderIndex: 11,
        iconName: 'content_cut',
      ),
      MobileCategorySeed(
        name: 'Cinsel Sağlık',
        orderIndex: 12,
        iconName: 'favorite',
      ),
      MobileCategorySeed(
        name: 'Sağlık Ürünleri',
        orderIndex: 13,
        iconName: 'health_and_safety',
      ),
      MobileCategorySeed(
        name: 'Lüks Kozmetik',
        orderIndex: 14,
        iconName: 'diamond',
      ),
    ],
  ),
  MobileCategorySeed(
    name: 'Pet Shop',
    orderIndex: 13,
    iconName: 'pets',
    subCategories: [
      MobileCategorySeed(name: 'Köpek', orderIndex: 1, iconName: 'pets'),
      MobileCategorySeed(
        name: 'Kedi',
        orderIndex: 2,
        iconName: 'cruelty_free',
      ),
      MobileCategorySeed(
        name: 'Kuş',
        orderIndex: 3,
        iconName: 'flutter_dash',
      ),
      MobileCategorySeed(
        name: 'Balık',
        orderIndex: 4,
        iconName: 'set_meal',
      ),
      MobileCategorySeed(
        name: 'Kemirgen & Sürüngen',
        orderIndex: 5,
        iconName: 'pest_control',
      ),
    ],
  ),
];

List<String> defaultMobileCategoryNames() {
  return defaultMobileCategoryNamesExcluding();
}

List<String> defaultMobileCategoryNamesExcluding({
  Set<String> excludedNames = const <String>{},
}) {
  final excludedKeys = excludedNames
      .map(normalizeCategoryNameForLookup)
      .toSet();
  return defaultMobileCategorySeeds
      .where(
        (seed) => !excludedKeys.contains(
          normalizeCategoryNameForLookup(seed.name),
        ),
      )
      .map((seed) => seed.name)
      .toList(growable: false);
}

MobileCategorySeed? findDefaultMobileCategorySeed(String categoryName) {
  final normalized = _normalizeCategoryName(categoryName);
  for (final seed in defaultMobileCategorySeeds) {
    if (_normalizeCategoryName(seed.name) == normalized) {
      return seed;
    }
  }
  return null;
}

IconData iconDataForCategoryName(String? iconName) {
  switch (iconName) {
    case 'near_me':
      return Icons.near_me;
    case 'restaurant_menu':
      return Icons.restaurant_menu;
    case 'shopping_cart':
      return Icons.shopping_cart;
    case 'explore':
      return Icons.explore;
    case 'man':
      return Icons.man;
    case 'woman':
      return Icons.woman;
    case 'checkroom':
      return Icons.checkroom;
    case 'watch':
      return Icons.watch;
    case 'style':
      return Icons.style;
    case 'hiking':
      return Icons.hiking;
    case 'directions_run':
      return Icons.directions_run;
    case 'face':
      return Icons.face;
    case 'accessibility_new':
      return Icons.accessibility_new;
    case 'brush':
      return Icons.brush;
    case 'shopping_bag':
      return Icons.shopping_bag;
    case 'hotel':
      return Icons.hotel;
    case 'devices':
      return Icons.devices;
    case 'sports_esports':
      return Icons.sports_esports;
    case 'phone_iphone':
      return Icons.phone_iphone;
    case 'laptop':
      return Icons.laptop;
    case 'tv':
      return Icons.tv;
    case 'memory':
      return Icons.memory;
    case 'kitchen':
      return Icons.kitchen;
    case 'ac_unit':
      return Icons.ac_unit;
    case 'keyboard':
      return Icons.keyboard;
    case 'gamepad':
      return Icons.gamepad;
    case 'speaker_group':
      return Icons.speaker_group;
    case 'headphones':
      return Icons.headphones;
    case 'mouse':
      return Icons.mouse;
    case 'speaker':
      return Icons.speaker;
    case 'monitor':
      return Icons.monitor;
    case 'print':
      return Icons.print;
    case 'girl':
      return Icons.girl;
    case 'child_care':
      return Icons.child_care;
    case 'backpack':
      return Icons.backpack;
    case 'school':
      return Icons.school;
    case 'luggage':
      return Icons.luggage;
    case 'watch_later':
      return Icons.watch_later;
    case 'watch_outlined':
      return Icons.watch_outlined;
    case 'child_friendly':
      return Icons.child_friendly;
    case 'wb_sunny':
      return Icons.wb_sunny;
    case 'home':
      return Icons.home;
    case 'restaurant':
      return Icons.restaurant;
    case 'bed':
      return Icons.bed;
    case 'chair':
      return Icons.chair;
    case 'lightbulb':
      return Icons.lightbulb;
    case 'bathtub':
      return Icons.bathtub;
    case 'iron':
      return Icons.iron;
    case 'security':
      return Icons.security;
    case 'water_drop':
      return Icons.water_drop;
    case 'edit_note':
      return Icons.edit_note;
    case 'desk':
      return Icons.desk;
    case 'attach_file':
      return Icons.attach_file;
    case 'edit':
      return Icons.edit;
    case 'book':
      return Icons.book;
    case 'menu_book':
      return Icons.menu_book;
    case 'palette':
      return Icons.palette;
    case 'directions_car':
      return Icons.directions_car;
    case 'build':
      return Icons.build;
    case 'grass':
      return Icons.grass;
    case 'plumbing':
      return Icons.plumbing;
    case 'electric_car':
      return Icons.electric_car;
    case 'settings':
      return Icons.settings;
    case 'cleaning_services':
      return Icons.cleaning_services;
    case 'car_repair':
      return Icons.car_repair;
    case 'airport_shuttle':
      return Icons.airport_shuttle;
    case 'agriculture':
      return Icons.agriculture;
    case 'outdoor_grill':
      return Icons.outdoor_grill;
    case 'pool':
      return Icons.pool;
    case 'health_and_safety':
      return Icons.health_and_safety;
    case 'toys':
      return Icons.toys;
    case 'extension':
      return Icons.extension;
    case 'music_note':
      return Icons.music_note;
    case 'album':
      return Icons.album;
    case 'movie':
      return Icons.movie;
    case 'confirmation_number':
      return Icons.confirmation_number;
    case 'games':
      return Icons.games;
    case 'sports_soccer':
      return Icons.sports_soccer;
    case 'fitness_center':
      return Icons.fitness_center;
    case 'sports_basketball':
      return Icons.sports_basketball;
    case 'cabin':
      return Icons.cabin;
    case 'directions_bike':
      return Icons.directions_bike;
    case 'electric_scooter':
      return Icons.electric_scooter;
    case 'phishing':
      return Icons.phishing;
    case 'sailing':
      return Icons.sailing;
    case 'landscape':
      return Icons.landscape;
    case 'snowboarding':
      return Icons.snowboarding;
    case 'shield':
      return Icons.shield;
    case 'visibility':
      return Icons.visibility;
    case 'flag':
      return Icons.flag;
    case 'spa':
      return Icons.spa;
    case 'content_cut':
      return Icons.content_cut;
    case 'science':
      return Icons.science;
    case 'face_retouching_natural':
      return Icons.face_retouching_natural;
    case 'clean_hands':
      return Icons.clean_hands;
    case 'medication':
      return Icons.medication;
    case 'shower':
      return Icons.shower;
    case 'favorite':
      return Icons.favorite;
    case 'diamond':
      return Icons.diamond;
    case 'pets':
      return Icons.pets;
    case 'cruelty_free':
      return Icons.cruelty_free;
    case 'flutter_dash':
      return Icons.flutter_dash;
    case 'set_meal':
      return Icons.set_meal;
    case 'pest_control':
      return Icons.pest_control;
    default:
      return Icons.category;
  }
}

List<MobileCategoryNode> buildMobileCategoryTree(
  List<CategoryWithSubcategories> remote, {
  bool includeUnmatchedMainCategories = true,
  Set<String> excludedNames = const <String>{},
  bool includeMissingDefaultCategories = true,
}
) {
  final remoteMainByKey = <String, CategoryWithSubcategories>{};
  final deletedMainKeys = <String>{};
  for (final item in remote) {
    final key = _normalizeCategoryName(item.mainCategory.name);
    if (item.mainCategory.iconName == deletedManagedCategoryIconName) {
      deletedMainKeys.add(key);
      continue;
    }
    remoteMainByKey[key] = item;
  }

  final result = <MobileCategoryNode>[];
  final usedKeys = <String>{};
  final excludedKeys = {
    ...excludedNames.map(_normalizeCategoryName),
    ...deletedMainKeys,
  };

  for (final seed in defaultMobileCategorySeeds) {
    final key = _normalizeCategoryName(seed.name);
    if (excludedKeys.contains(key)) {
      continue;
    }
    final remoteItem = remoteMainByKey[key];
    if (remoteItem == null && !includeMissingDefaultCategories) {
      continue;
    }
    usedKeys.add(key);
    result.add(
      _mergeMainCategory(
        seed,
        remoteItem,
        includeMissingDefaultCategories: includeMissingDefaultCategories,
      ),
    );
  }

  if (includeUnmatchedMainCategories) {
    for (final item in remote) {
      final key = _normalizeCategoryName(item.mainCategory.name);
      if (usedKeys.contains(key) || excludedKeys.contains(key)) {
        continue;
      }
      result.add(
        MobileCategoryNode(
          id: item.mainCategory.id,
          parentId: item.mainCategory.parentId,
          name: item.mainCategory.name,
          imageUrl: item.mainCategory.imageUrl,
          iconName: item.mainCategory.iconName,
          orderIndex: item.mainCategory.orderIndex,
          isActive: item.mainCategory.isActive,
          subCategories: item.subCategories
              .map(
                (sub) => MobileCategoryNode(
                  id: sub.id,
                  parentId: sub.parentId,
                  name: sub.name,
                  imageUrl: sub.imageUrl,
                  iconName: sub.iconName,
                  orderIndex: sub.orderIndex,
                  isActive: sub.isActive,
                ),
              )
              .toList()
            ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex)),
        ),
      );
    }
  }

  result.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  return result;
}

MobileCategoryNode _mergeMainCategory(
  MobileCategorySeed seed,
  CategoryWithSubcategories? remoteItem,
  {
  required bool includeMissingDefaultCategories,
}
) {
  final remoteMain = remoteItem?.mainCategory;
  final remoteSubs = remoteItem?.subCategories ?? const <DBCategory>[];
  final remoteSubByKey = <String, DBCategory>{};
  final deletedChildKeys = <String>{};
  for (final sub in remoteSubs) {
    final key = _normalizeCategoryName(sub.name);
    if (sub.iconName == deletedManagedCategoryIconName) {
      deletedChildKeys.add(key);
      continue;
    }
    remoteSubByKey[key] = sub;
  }

  final children = <MobileCategoryNode>[];
  final usedChildKeys = <String>{};

  for (final childSeed in seed.subCategories) {
    final key = _normalizeCategoryName(childSeed.name);
    if (deletedChildKeys.contains(key)) {
      continue;
    }
    usedChildKeys.add(key);
    final remoteChild = remoteSubByKey[key];
    if (remoteChild == null && !includeMissingDefaultCategories) {
      continue;
    }
    if (remoteChild == null && remoteMain != null && !remoteMain.isActive) {
      children.add(
        MobileCategoryNode(
          parentId: remoteMain.id,
          name: childSeed.name,
          iconName: childSeed.iconName,
          fallbackAssetPath: childSeed.fallbackAssetPath,
          orderIndex: childSeed.orderIndex,
          isActive: false,
        ),
      );
      continue;
    }
    children.add(
      MobileCategoryNode(
        id: remoteChild?.id,
        parentId: remoteChild?.parentId ?? remoteMain?.id,
        name: remoteChild?.name ?? childSeed.name,
        imageUrl: remoteChild?.imageUrl,
        iconName: remoteChild?.iconName ?? childSeed.iconName,
        fallbackAssetPath: childSeed.fallbackAssetPath,
        orderIndex: remoteChild?.orderIndex ?? childSeed.orderIndex,
        isActive: remoteChild?.isActive ?? true,
      ),
    );
  }

  for (final sub in remoteSubs) {
    final key = _normalizeCategoryName(sub.name);
    if (usedChildKeys.contains(key) || deletedChildKeys.contains(key)) {
      continue;
    }
    children.add(
      MobileCategoryNode(
        id: sub.id,
        parentId: sub.parentId,
        name: sub.name,
        imageUrl: sub.imageUrl,
        iconName: sub.iconName,
        orderIndex: sub.orderIndex,
        isActive: sub.isActive,
      ),
    );
  }

  children.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

  return MobileCategoryNode(
    id: remoteMain?.id,
    parentId: remoteMain?.parentId,
    name: remoteMain?.name ?? seed.name,
    imageUrl: remoteMain?.imageUrl,
    iconName: remoteMain?.iconName ?? seed.iconName,
    fallbackAssetPath: seed.fallbackAssetPath,
    orderIndex: remoteMain?.orderIndex ?? seed.orderIndex,
    isActive: remoteMain?.isActive ?? true,
    subCategories: children,
  );
}

String normalizeCategoryNameForLookup(String value) {
  return _normalizeCategoryName(value);
}

String _normalizeCategoryName(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('İ', 'i')
      .replaceAll('ş', 's')
      .replaceAll('Ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('Ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('Ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('Ö', 'o')
      .replaceAll('ç', 'c')
      .replaceAll('Ç', 'c');
}
