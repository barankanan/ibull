import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/ads/enums/ad_enums.dart';
import 'package:ibul_app/ads/helpers/home_feature_ad_helper.dart';
import 'package:ibul_app/ads/models/ad_campaign.dart';
import 'package:ibul_app/ads/models/home_card_template.dart';

AdCampaign _campaign({
  CampaignStatus status = CampaignStatus.approved,
  Map<String, dynamic>? metadata,
  DateTime? startsAt,
  DateTime? endsAt,
}) {
  final now = DateTime(2026, 7, 8);
  return AdCampaign(
    id: 'hfa-elig-1',
    sellerId: 'seller-test',
    name: 'Elig Test',
    type: AdCampaignType.homeFeature,
    objective: CampaignObjective.storeVisits,
    status: status,
    billingModel: BillingModel.flat,
    dailyBudget: 0,
    totalBudget: 0,
    currency: 'TRY',
    startsAt: startsAt ?? now.subtract(const Duration(days: 1)),
    endsAt: endsAt ?? now.add(const Duration(days: 10)),
    metadata: metadata ??
        const {
          'card_template_id': 'tpl-1',
          'category_name': 'Yemek',
          'banner_images': ['https://example.com/banner.png'],
          'selected_product_ids': ['p1'],
        },
  );
}

void main() {
  final now = DateTime(2026, 7, 8);

  group('HomeFeatureAdHelper.ineligibleReason (home görünürlük kuralları)', () {
    test('pending campaign is hidden on home with clear reason', () {
      final reason = HomeFeatureAdHelper.ineligibleReason(
        _campaign(status: CampaignStatus.pendingReview),
        now: now,
      );
      expect(reason, 'status_not_approved');
    });

    test('rejected / paused campaigns are hidden with reasons', () {
      expect(
        HomeFeatureAdHelper.ineligibleReason(
          _campaign(status: CampaignStatus.rejected),
          now: now,
        ),
        'status_rejected',
      );
      expect(
        HomeFeatureAdHelper.ineligibleReason(
          _campaign(status: CampaignStatus.paused),
          now: now,
        ),
        'status_paused',
      );
    });

    test('approved and active campaigns within dates are shown', () {
      expect(
        HomeFeatureAdHelper.ineligibleReason(
          _campaign(status: CampaignStatus.approved),
          now: now,
        ),
        isNull,
      );
      expect(
        HomeFeatureAdHelper.ineligibleReason(
          _campaign(status: CampaignStatus.active),
          now: now,
        ),
        isNull,
      );
    });

    test('expired approved campaign is hidden', () {
      expect(
        HomeFeatureAdHelper.ineligibleReason(
          _campaign(
            startsAt: now.subtract(const Duration(days: 20)),
            endsAt: now.subtract(const Duration(days: 1)),
          ),
          now: now,
        ),
        'date_expired',
      );
    });

    test('missing template or banner produce explicit reasons', () {
      expect(
        HomeFeatureAdHelper.ineligibleReason(
          _campaign(metadata: const {
            'category_name': 'Yemek',
            'banner_images': ['https://example.com/banner.png'],
          }),
          now: now,
        ),
        'template_missing',
      );
      expect(
        HomeFeatureAdHelper.ineligibleReason(
          _campaign(metadata: const {
            'card_template_id': 'tpl-1',
            'category_name': 'Yemek',
            'banner_images': <String>[],
          }),
          now: now,
        ),
        'no_banner',
      );
    });
  });

  group('active_home_feature_ads view satırı → render edilebilir kampanya', () {
    test('approved view row maps to an eligible campaign', () {
      final campaign = HomeFeatureAdHelper.campaignFromActiveViewRow({
        'id': 'hfa-view-1',
        'seller_id': 'seller-test',
        'store_id': 'store-test',
        'name': 'View Reklam',
        'starts_at':
            now.subtract(const Duration(days: 1)).toUtc().toIso8601String(),
        'ends_at': now.add(const Duration(days: 10)).toUtc().toIso8601String(),
        'card_template_id': 'tpl-1',
        'category_name': 'Yemek',
        'metadata': {
          'banner_images': ['https://example.com/banner.png'],
          'selected_product_ids': ['p1'],
        },
      });

      expect(campaign, isNotNull);
      expect(campaign!.status, CampaignStatus.approved);
      expect(HomeFeatureAdHelper.ineligibleReason(campaign, now: now), isNull);
    });

    test('view row without id is rejected', () {
      expect(HomeFeatureAdHelper.campaignFromActiveViewRow({}), isNull);
    });
  });

  group('Seller panel ana sayfa görünürlük etiketi', () {
    test('pending → admin onayı bekleniyor mesajı', () {
      final label = HomeFeatureAdHelper.sellerHomeVisibilityLabel(
        _campaign(status: CampaignStatus.pendingReview),
        now: now,
      );
      expect(
        label,
        'Admin onayı bekleniyor. Onaylandıktan sonra ana sayfada görünecek.',
      );
    });

    test('approved/active → Yayında', () {
      expect(
        HomeFeatureAdHelper.sellerHomeVisibilityLabel(
          _campaign(status: CampaignStatus.approved),
          now: now,
        ),
        'Yayında',
      );
      expect(
        HomeFeatureAdHelper.sellerHomeVisibilityLabel(
          _campaign(status: CampaignStatus.active),
          now: now,
        ),
        'Yayında',
      );
    });

    test('eksik görsel/ürün → net eksik-asset mesajı', () {
      expect(
        HomeFeatureAdHelper.sellerHomeVisibilityLabel(
          _campaign(metadata: const {
            'card_template_id': 'tpl-1',
            'category_name': 'Yemek',
            'banner_images': <String>[],
            'selected_product_ids': ['p1'],
          }),
          now: now,
        ),
        'Reklam görseli veya ürün bağlantısı eksik',
      );
      expect(
        HomeFeatureAdHelper.sellerHomeVisibilityLabel(
          _campaign(metadata: const {
            'card_template_id': 'tpl-1',
            'category_name': 'Yemek',
            'banner_images': ['https://example.com/banner.png'],
            'selected_product_ids': <String>[],
          }),
          now: now,
        ),
        'Reklam görseli veya ürün bağlantısı eksik',
      );
    });
  });

  group('Kategori hedefleme (yanlış section engeli)', () {
    HomeFeatureCategoryGrouping groupingOf(AdCampaign campaign) =>
        HomeFeatureAdHelper.resolveCategoryGrouping(campaign: campaign)!;

    test('yemek reklamı yemek section ile eşleşir', () {
      final campaign = _campaign(metadata: const {
        'card_template_id': 'tpl-1',
        'category_name': 'Yemek / Yemekler',
        'banner_images': ['https://example.com/banner.png'],
        'selected_product_ids': ['p1'],
        'selected_product_categories': ['Yemek'],
      });
      expect(
        HomeFeatureAdHelper.matchesGroupingCategory(
          campaign,
          groupingOf(campaign),
        ),
        isTrue,
      );
      expect(
        HomeFeatureAdHelper.sellerHomeVisibilityReason(campaign, now: now),
        isNull,
      );
    });

    test('elektronik ürünlü reklam yemek section’ında GÖRÜNMEZ', () {
      final campaign = _campaign(metadata: const {
        'card_template_id': 'tpl-1',
        'category_name': 'Yemek / Yemekler',
        'banner_images': ['https://example.com/banner.png'],
        'selected_product_ids': ['p1'],
        'selected_product_categories': ['Elektronik'],
      });
      expect(
        HomeFeatureAdHelper.matchesGroupingCategory(
          campaign,
          groupingOf(campaign),
        ),
        isFalse,
      );
      expect(
        HomeFeatureAdHelper.sellerHomeVisibilityReason(campaign, now: now),
        'category_conflict',
      );
      expect(
        HomeFeatureAdHelper.sellerHomeVisibilityLabel(campaign, now: now),
        'Seçilen ürünlerin kategorisi reklam hedefiyle uyuşmuyor.',
      );
    });

    test('eski kampanya (ürün kategorisi yok) backward-compatible eşleşir',
        () {
      final campaign = _campaign(); // selected_product_categories alanı yok
      expect(
        HomeFeatureAdHelper.matchesGroupingCategory(
          campaign,
          groupingOf(campaign),
        ),
        isTrue,
      );
    });

    test('çok kategorili seçim: en az biri hedefle eşleşiyorsa görünür', () {
      final campaign = _campaign(metadata: const {
        'card_template_id': 'tpl-1',
        'category_name': 'Yemek',
        'banner_images': ['https://example.com/banner.png'],
        'selected_product_ids': ['p1', 'p2'],
        'selected_product_categories': ['Elektronik', 'Yemekler'],
      });
      expect(
        HomeFeatureAdHelper.matchesGroupingCategory(
          campaign,
          groupingOf(campaign),
        ),
        isTrue,
      );
    });
  });

  group('Home fetch kaynak kuralları (kaynak kod sözleşmesi)', () {
    test('home feature service never uses preview/demo fallback', () {
      final source = File('lib/ads/services/home_feature_ad_service.dart')
          .readAsStringSync();
      expect(source.contains('usePreviewOnFailure: false'), isTrue);
    });

    test('home groups cache never stores empty/unresolved results '
        '(cache cannot hide active campaigns forever)', () {
      final source = File('lib/ads/services/home_feature_ad_service.dart')
          .readAsStringSync();
      expect(
        source.contains(
          'if (groups.isNotEmpty && !_hasUnresolvedAdProducts(groups))',
        ),
        isTrue,
      );
    });

    test('view empty → campaigns fallback path exists and is logged', () {
      final source = File('lib/ads/services/home_feature_ad_service.dart')
          .readAsStringSync();
      expect(
        source.contains('hidden reason=view_empty fallback=campaigns'),
        isTrue,
      );
      // Fallback sorgusu approved+active statuslarını hedefler.
      expect(source.contains(".inFilter('status', ["), isTrue);
    });

    test('missing asset/product reasons are logged release-safe', () {
      final source = File('lib/ads/services/home_feature_ad_service.dart')
          .readAsStringSync();
      expect(source.contains('[HomeAds] missing_asset campaignId='), isTrue);
      expect(source.contains('[HomeAds] missing_product campaignId='), isTrue);
      expect(source.contains('[HomeAds] pending count='), isTrue);
    });

    test('category_match / category_mismatch / display_text logları mevcut',
        () {
      final source = File('lib/ads/services/home_feature_ad_service.dart')
          .readAsStringSync();
      expect(
        source.contains('[HomeAds] category_match campaignId='),
        isTrue,
      );
      expect(
        source.contains('[HomeAds] hidden reason=category_mismatch'),
        isTrue,
      );
      expect(
        source.contains('[HomeAds] hidden reason=missing_category_target'),
        isTrue,
      );
      expect(
        source.contains('[HomeAds] display_text campaignId='),
        isTrue,
      );
    });

    test('seller form seçilen ürünlerin kategorisini metadata\'ya kaydeder',
        () {
      final form =
          File('lib/ads/presentation/pages/home_feature_ad_form_page.dart')
              .readAsStringSync();
      expect(
        form.contains('selectedProductCategories: productCategories'),
        isTrue,
      );
      final helper = File('lib/ads/helpers/home_feature_ad_helper.dart')
          .readAsStringSync();
      expect(
        helper.contains("'selected_product_categories': selectedProductCategories"),
        isTrue,
      );
    });

    test('seller panelde pending onay mesajı mevcut', () {
      final content =
          File('lib/ads/presentation/pages/seller_ads_manager_content.dart')
              .readAsStringSync();
      expect(
        content.contains('Onaylandiktan sonra ana sayfada gorunecek'),
        isTrue,
      );
      expect(
        content.contains('[SellerAds] home_visibility campaignId='),
        isTrue,
      );
    });
  });
}
