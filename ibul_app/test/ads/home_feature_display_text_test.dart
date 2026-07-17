import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/ads/helpers/home_feature_ad_display_text.dart';

void main() {
  group('isSimilarTitle', () {
    test('kategori tekrarını yakalar (Yemek ≈ Yemekler)', () {
      expect(
        HomeFeatureAdDisplayText.isSimilarTitle('Yemek', 'Yemekler'),
        isTrue,
      );
      expect(
        HomeFeatureAdDisplayText.isSimilarTitle('yemekler', 'YEMEK'),
        isTrue,
      );
    });

    test('farklı kategoriler benzer sayılmaz', () {
      expect(
        HomeFeatureAdDisplayText.isSimilarTitle('Yemek', 'Elektronik'),
        isFalse,
      );
      expect(
        HomeFeatureAdDisplayText.isSimilarTitle('Moda', 'Teknoloji'),
        isFalse,
      );
    });
  });

  group('resolve — duplicate/zayıf başlık kuralları', () {
    test('Yemek/Yemekler tekrarı yerine profesyonel başlık üretilir', () {
      final text = HomeFeatureAdDisplayText.resolve(
        categoryName: 'Yemek',
        rawCardTitle: 'Yemekler',
        campaignName: 'Ana Sayfa — Yemek / Yemekler',
        storeName: 'destina',
      );

      expect(text.sectionTitle, 'Yemek');
      expect(text.cardTitle, "Destina'dan Öne Çıkan Lezzetler");
      expect(text.cardTitleSource, 'fallback');
      expect(text.storeLabel, 'Destina');
      expect(
        HomeFeatureAdDisplayText.isSimilarTitle(
          text.cardTitle,
          text.sectionTitle,
        ),
        isFalse,
      );
    });

    test('zayıf kampanya adları (asdf/test) fallback başlığa düşer', () {
      for (final weak in ['asdf', 'test', 'Başlık', 'Yemekler', 'aaaa']) {
        final text = HomeFeatureAdDisplayText.resolve(
          categoryName: 'Yemek',
          rawCardTitle: 'Yemekler',
          campaignName: weak,
          storeName: 'destina',
        );
        expect(text.cardTitle, "Destina'dan Öne Çıkan Lezzetler",
            reason: 'weak title "$weak" fallback üretmeli');
      }
    });

    test('profesyonel kampanya adı korunur', () {
      final text = HomeFeatureAdDisplayText.resolve(
        categoryName: 'Yemek',
        rawCardTitle: 'Yemekler',
        campaignName: 'Odun Ateşinde Lezzet',
        storeName: 'destina',
      );
      expect(text.cardTitle, 'Odun Ateşinde Lezzet');
      expect(text.cardTitleSource, 'campaign_name');
    });

    test('elektronik kategorisi teknoloji fallback başlığı üretir', () {
      final text = HomeFeatureAdDisplayText.resolve(
        categoryName: 'Elektronik',
        rawCardTitle: 'Elektronik',
        campaignName: 'test',
        storeName: 'techno market',
      );
      expect(text.cardTitle, "Techno Market'dan Teknoloji Fırsatları");
    });

    test('bilinmeyen kategori genel fallback üretir', () {
      final text = HomeFeatureAdDisplayText.resolve(
        categoryName: 'Hobi',
        rawCardTitle: null,
        campaignName: null,
        storeName: 'destina',
      );
      expect(text.cardTitle, "Destina'dan Öne Çıkanlar");
    });

    test('store adı zarif etikete dönüşür', () {
      expect(HomeFeatureAdDisplayText.prettyStoreName('destina'), 'Destina');
      expect(
        HomeFeatureAdDisplayText.prettyStoreName('techno market'),
        'Techno Market',
      );
    });
  });
}
