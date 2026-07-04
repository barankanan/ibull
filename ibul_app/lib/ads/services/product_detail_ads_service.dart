import 'package:flutter/foundation.dart';

import '../helpers/home_feature_ad_helper.dart';
import '../models/home_card_template.dart';
import '../services/home_feature_ad_service.dart';
import '../../core/runtime_diagnostic_logger.dart';

/// Category-aware product detail ads below the product block.
class ProductDetailAdsService {
  ProductDetailAdsService({HomeFeatureAdService? homeFeatureAdService})
      : _homeFeatureAdService = homeFeatureAdService;

  final HomeFeatureAdService? _homeFeatureAdService;

  Future<HomeCategoryCardGroup?> loadCategoryAds({
    required String? mainCategory,
    String? subCategory,
  }) async {
    final category = (mainCategory ?? '').trim();
    final sub = (subCategory ?? '').trim();
    RuntimeDiagnosticLogger.productDetailAds(
      'loading category=$category subCategory=$sub',
    );

    try {
      final service = _homeFeatureAdService ?? HomeFeatureAdService();
      final groups = await service.loadHomePageGroups();
      return _resolveFromGroups(
        groups,
        mainCategory: category,
        subCategory: sub,
      );
    } catch (e, stackTrace) {
      RuntimeDiagnosticLogger.logFailure(
        'ProductDetailAds',
        e,
        stackTrace,
        context: 'loadCategoryAds',
      );
      return null;
    }
  }

  @visibleForTesting
  HomeCategoryCardGroup? loadCategoryAdsSyncForTest({
    required List<HomeCategoryCardGroup> groups,
    required String? mainCategory,
    String? subCategory,
  }) {
    return _resolveFromGroups(
      groups,
      mainCategory: (mainCategory ?? '').trim(),
      subCategory: (subCategory ?? '').trim(),
    );
  }

  HomeCategoryCardGroup? _resolveFromGroups(
    List<HomeCategoryCardGroup> groups, {
    required String mainCategory,
    required String subCategory,
  }) {
    if (groups.isEmpty) {
      RuntimeDiagnosticLogger.productDetailAds('empty hidden');
      return null;
    }

    final matched = _findMatchingGroup(
      groups,
      mainCategory: mainCategory,
      subCategory: subCategory,
    );
    if (matched != null && _hasDisplayableAds(matched)) {
      final count = _adCount(matched);
      RuntimeDiagnosticLogger.productDetailAds('loaded count=$count');
      return matched;
    }

    final generic = groups.firstWhere(
      _hasDisplayableAds,
      orElse: () => const HomeCategoryCardGroup(categoryName: '', cards: []),
    );
    if (!_hasDisplayableAds(generic)) {
      RuntimeDiagnosticLogger.productDetailAds('empty hidden');
      return null;
    }

    final count = _adCount(generic);
    RuntimeDiagnosticLogger.productDetailAds('loaded count=$count (generic)');
    return generic;
  }

  HomeCategoryCardGroup? _findMatchingGroup(
    List<HomeCategoryCardGroup> groups, {
    required String mainCategory,
    required String subCategory,
  }) {
    final candidates = <String>{
      if (mainCategory.isNotEmpty) HomeFeatureAdHelper.normalizeCategoryLeaf(mainCategory),
      if (subCategory.isNotEmpty) HomeFeatureAdHelper.normalizeCategoryLeaf(subCategory),
    }..removeWhere((value) => value.isEmpty);

    if (candidates.isEmpty) return null;

    for (final group in groups) {
      final groupLeaf = HomeFeatureAdHelper.normalizeCategoryLeaf(
        group.categoryName,
      );
      if (_categoryMatches(candidates, groupLeaf)) return group;
      for (final card in group.cards) {
        for (final ad in card.ads) {
          final adLeaf = HomeFeatureAdHelper.normalizeCategoryLeaf(
            ad.categoryName,
          );
          if (_categoryMatches(candidates, adLeaf)) return group;
        }
      }
    }
    return null;
  }

  bool _categoryMatches(Set<String> productLeaves, String groupLeaf) {
    if (groupLeaf.isEmpty) return false;
    for (final productLeaf in productLeaves) {
      if (productLeaf.isEmpty) continue;
      if (productLeaf == groupLeaf) return true;
      if (productLeaf.startsWith(groupLeaf) || groupLeaf.startsWith(productLeaf)) {
        return true;
      }
      if (productLeaf.contains(groupLeaf) || groupLeaf.contains(productLeaf)) {
        return true;
      }
    }
    return false;
  }

  bool _hasDisplayableAds(HomeCategoryCardGroup group) {
    for (final card in group.cards) {
      for (final ad in card.ads) {
        if (ad.bannerUrls.isNotEmpty) return true;
      }
    }
    return false;
  }

  int _adCount(HomeCategoryCardGroup group) {
    var count = 0;
    for (final card in group.cards) {
      count += card.ads.where((ad) => ad.bannerUrls.isNotEmpty).length;
    }
    return count;
  }
}
