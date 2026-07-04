import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/ads/helpers/home_feature_ad_helper.dart';
import 'package:ibul_app/ads/models/home_card_template.dart';
import 'package:ibul_app/ads/services/product_detail_ads_service.dart';

HomeCategoryCardGroup _group(String categoryName) {
  return HomeCategoryCardGroup(
    categoryName: categoryName,
    cards: [
      HomeCardDisplayGroup(
        templateId: 'tpl-1',
        cardTitle: categoryName,
        templateSortOrder: 0,
        ads: [
          HomeFeatureDisplayAd(
            campaignId: 'c1',
            sellerId: 's1',
            storeName: 'Test Store',
            cardTemplateId: 'tpl-1',
            cardTitle: categoryName,
            categoryName: categoryName,
            bannerUrls: const ['https://img.test/banner.jpg'],
            productIds: const ['p1'],
            sortOrder: 0,
          ),
        ],
      ),
    ],
  );
}

void main() {
  group('ProductDetailAdsService category matching', () {
    test('yemek category matches yemekler leaf from ad group', () {
      final groups = [
        _group('Yemek / Yemekler'),
        _group('Elektronik'),
      ];
      final service = ProductDetailAdsService();
      final matched = service.loadCategoryAdsSyncForTest(
        groups: groups,
        mainCategory: 'Yemek',
        subCategory: 'Yemekler',
      );
      expect(matched?.categoryName, 'Yemek / Yemekler');
    });

    test('generic fallback when no category match', () {
      final groups = [
        _group('Elektronik'),
        _group('Giyim'),
      ];
      final service = ProductDetailAdsService();
      final matched = service.loadCategoryAdsSyncForTest(
        groups: groups,
        mainCategory: 'Oyuncak',
        subCategory: null,
      );
      expect(matched?.categoryName, 'Elektronik');
    });
  });

  group('legacy Hatay Yemekleri title', () {
    test('normalizeCategoryLeaf does not hardcode Hatay Yemekleri', () {
      expect(
        HomeFeatureAdHelper.normalizeCategoryLeaf('Hatay Yemekleri'),
        'hatay yemekleri',
      );
      expect(
        HomeFeatureAdHelper.normalizeCategoryLeaf('Yemek / Yemekler'),
        'yemekler',
      );
    });
  });
}
