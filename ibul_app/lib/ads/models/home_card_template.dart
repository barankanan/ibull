import '../../models/db_product.dart';
import '../helpers/ad_json_helper.dart';

class HomeCardTemplate {
  const HomeCardTemplate({
    required this.id,
    required this.title,
    this.categoryId,
    this.categoryName,
    required this.slug,
    this.description,
    this.isActive = true,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String? categoryId;
  final String? categoryName;
  final String slug;
  final String? description;
  final bool isActive;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayLabel {
    final cat = categoryName?.trim();
    if (cat != null && cat.isNotEmpty) return '$cat / $title';
    return title;
  }

  factory HomeCardTemplate.fromJson(Map<String, dynamic> json) {
    return HomeCardTemplate(
      id: AdJsonHelper.asString(json['id']),
      title: AdJsonHelper.asString(json['title'], fallback: '-'),
      categoryId: AdJsonHelper.asNullableString(json['category_id']),
      categoryName: AdJsonHelper.asNullableString(json['category_name']),
      slug: AdJsonHelper.asString(json['slug'], fallback: ''),
      description: AdJsonHelper.asNullableString(json['description']),
      isActive: AdJsonHelper.asBool(json['is_active'], fallback: true),
      sortOrder: AdJsonHelper.asInt(json['sort_order']),
      createdAt: AdJsonHelper.asDateTime(json['created_at']),
      updatedAt: AdJsonHelper.asDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    final parsedCategoryId = int.tryParse(categoryId ?? '');
    return {
      'id': id,
      'title': title,
      'category_id': parsedCategoryId,
      'category_name': categoryName,
      'slug': slug,
      'description': description,
      'is_active': isActive,
      'sort_order': sortOrder,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  HomeCardTemplate copyWith({
    String? id,
    String? title,
    String? categoryId,
    String? categoryName,
    String? slug,
    String? description,
    bool? isActive,
    int? sortOrder,
  }) {
    return HomeCardTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// Kategori gruplama anahtarı + ekranda gösterilecek başlıklar.
class HomeFeatureCategoryGrouping {
  const HomeFeatureCategoryGrouping({
    required this.key,
    required this.displayName,
    required this.canonicalLeaf,
    this.subtitle,
  });

  final String key;
  final String displayName;
  final String? subtitle;
  final String canonicalLeaf;
}

/// Ana sayfada gösterilecek onaylı reklam + şablon birleşimi.
class HomeFeatureDisplayAd {
  const HomeFeatureDisplayAd({
    required this.campaignId,
    required this.sellerId,
    this.storeId,
    required this.storeName,
    this.storeLogoUrl,
    required this.cardTemplateId,
    required this.cardTitle,
    required this.categoryName,
    required this.bannerUrls,
    required this.productIds,
    required this.sortOrder,
    this.sortMode = 'manual',
    this.createdAt,
    this.resolvedProducts = const [],
  });

  final String campaignId;
  final String sellerId;
  final String? storeId;
  final String storeName;
  final String? storeLogoUrl;
  final String cardTemplateId;
  final String cardTitle;
  final String categoryName;
  final List<String> bannerUrls;
  final List<String> productIds;
  final int sortOrder;
  final String sortMode;
  final DateTime? createdAt;
  final List<DBProduct> resolvedProducts;

  HomeFeatureDisplayAd copyWithResolvedProducts(List<DBProduct> products) {
    return HomeFeatureDisplayAd(
      campaignId: campaignId,
      sellerId: sellerId,
      storeId: storeId,
      storeName: storeName,
      storeLogoUrl: storeLogoUrl,
      cardTemplateId: cardTemplateId,
      cardTitle: cardTitle,
      categoryName: categoryName,
      bannerUrls: bannerUrls,
      productIds: productIds,
      sortOrder: sortOrder,
      sortMode: sortMode,
      createdAt: createdAt,
      resolvedProducts: products,
    );
  }
}

/// Kategori > kart > reklamlar hiyerarşisi.
class HomeCategoryCardGroup {
  const HomeCategoryCardGroup({
    required this.categoryName,
    required this.cards,
  });

  final String categoryName;
  final List<HomeCardDisplayGroup> cards;
}

class HomeCardDisplayGroup {
  const HomeCardDisplayGroup({
    required this.templateId,
    required this.cardTitle,
    required this.templateSortOrder,
    required this.ads,
  });

  final String templateId;
  final String cardTitle;
  final int templateSortOrder;
  final List<HomeFeatureDisplayAd> ads;
}

class HomeFeatureMetrics {
  const HomeFeatureMetrics({
    this.impressionsCount = 0,
    this.bannerClicksCount = 0,
    this.profileOpensCount = 0,
    this.productClicksCount = 0,
    this.favoritesCount = 0,
    this.messageClicksCount = 0,
  });

  final int impressionsCount;
  final int bannerClicksCount;
  final int profileOpensCount;
  final int productClicksCount;
  final int favoritesCount;
  final int messageClicksCount;

  factory HomeFeatureMetrics.fromMetadata(Map<String, dynamic> metadata) {
    final raw = AdJsonHelper.asMap(metadata['home_metrics']);
    return HomeFeatureMetrics(
      impressionsCount: AdJsonHelper.asInt(raw['impressions_count']),
      bannerClicksCount: AdJsonHelper.asInt(raw['banner_clicks_count']),
      profileOpensCount: AdJsonHelper.asInt(raw['profile_opens_count']),
      productClicksCount: AdJsonHelper.asInt(raw['product_clicks_count']),
      favoritesCount: AdJsonHelper.asInt(raw['favorites_count']),
      messageClicksCount: AdJsonHelper.asInt(raw['message_clicks_count']),
    );
  }
}
