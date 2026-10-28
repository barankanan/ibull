import '../domain/visual_catalog_matcher.dart';
import '../domain/visual_search_analyzer.dart';
import '../domain/visual_search_models.dart';

/// Filename-driven sample analyses used until a real vision model is connected.
class MockVisualSearchAnalyzer implements VisualSearchAnalyzer {
  const MockVisualSearchAnalyzer({VisualCatalogMatcher? matcher})
    : _matcher = matcher ?? const VisualCatalogMatcher();

  final VisualCatalogMatcher _matcher;

  static const demoCatalog = <VisualCatalogItem>[
    VisualCatalogItem(
      id: 'vs-demo-kupa',
      name: 'Seramik Kupa',
      brand: 'Ev Dünyası',
      category: 'Mutfak',
      description: 'Beyaz seramik kupa, kulplu',
      store: 'Ev Dünyası',
      price: '249 TL',
      rating: 4.7,
      reviewCount: 128,
    ),
    VisualCatalogItem(
      id: 'vs-demo-porselen',
      name: 'Beyaz Porselen Kupa',
      brand: 'Sofra',
      category: 'Mutfak',
      description: 'İnce porselen kupa',
      store: 'Sofra Evi',
      price: '189 TL',
      rating: 4.5,
      reviewCount: 86,
    ),
    VisualCatalogItem(
      id: 'vs-demo-kulp',
      name: 'Yedek Kupa Kulpu',
      brand: 'Parça',
      category: 'Yedek Parça',
      description: 'Seramik kupa için kulp',
      store: 'Parça Atölyesi',
      price: '79 TL',
      rating: 4.2,
      reviewCount: 34,
    ),
    VisualCatalogItem(
      id: 'vs-demo-sandalye',
      name: 'Ahşap Sandalye',
      brand: 'Mobilya Evi',
      category: 'Mobilya',
      description: 'Dört ayaklı ahşap sandalye',
      store: 'Mobilya Evi',
      price: '1.290 TL',
      rating: 4.6,
      reviewCount: 54,
    ),
    VisualCatalogItem(
      id: 'vs-demo-ayak',
      name: 'Sandalye Ayağı Yedek Parça',
      brand: 'Mobilya Evi',
      category: 'Yedek Parça',
      description: 'Ön sol sandalye ayağı',
      store: 'Mobilya Evi',
      price: '149 TL',
      rating: 4.4,
      reviewCount: 19,
    ),
    VisualCatalogItem(
      id: 'vs-demo-kosu',
      name: 'Koşu Ayakkabısı',
      brand: 'Sprint',
      category: 'Ayakkabı',
      description: 'Hafif koşu ayakkabısı sneaker',
      store: 'Spor Park',
      price: '1.899 TL',
      rating: 4.8,
      reviewCount: 240,
    ),
    VisualCatalogItem(
      id: 'vs-demo-sneaker',
      name: 'Günlük Sneaker',
      brand: 'Sprint',
      category: 'Ayakkabı',
      description: 'Günlük kullanım ayakkabı',
      store: 'Spor Park',
      price: '1.249 TL',
      rating: 4.6,
      reviewCount: 173,
    ),
  ];

  @override
  Future<VisualSearchAnalysis> analyze({
    required VisualSearchJobType jobType,
    required String fileName,
    required List<int> imageBytes,
    List<VisualCatalogItem> catalog = const [],
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final hint = fileName.toLowerCase();
    if (hint.contains('bos-sonuc') || hint.contains('empty-result')) {
      return const VisualSearchAnalysis(
        summary: 'Bu görsel için eşleşme veya hasar bulunamadı.',
        confidence: 0.22,
        usedMock: true,
      );
    }
    if (_containsAny(hint, const ['kupa', 'fincan', 'cup', 'mug', 'catlak'])) {
      return _crackedMug(catalog);
    }
    if (_containsAny(hint, const ['ayakkabi', 'shoe', 'sneaker', 'kosu'])) {
      return _shoes(jobType, catalog);
    }
    if (_containsAny(hint, const ['sandalye', 'chair']) || _hasToken(hint, 'ayak')) {
      return _missingChairLeg(catalog);
    }
    if (jobType == VisualSearchJobType.visualSearch) {
      return _genericSearch(catalog, hint);
    }
    return _genericIntelligence();
  }

  VisualSearchAnalysis _crackedMug(List<VisualCatalogItem> catalog) {
    return VisualSearchAnalysis(
      summary:
          'Seramik kupada gövde çatlağı ve kırık kulp tespit edildi. Kulpun bir parçası eksik görünüyor.',
      confidence: 0.88,
      usedMock: true,
      damages: [
        DamageDetection(
          id: newVisualSearchId(),
          label: 'Gövde çatlağı',
          confidence: 0.91,
          bbox: const BoundingBox(x: 0.28, y: 0.34, width: 0.36, height: 0.42),
          description: 'Kupanın ön yüzeyinde yukarı doğru ilerleyen çatlak.',
        ),
        DamageDetection(
          id: newVisualSearchId(),
          label: 'Kırık kulp',
          confidence: 0.84,
          bbox: const BoundingBox(x: 0.62, y: 0.28, width: 0.22, height: 0.3),
          description: 'Kulpun üst bağlantısı kopmuş.',
        ),
      ],
      missingParts: [
        MissingPartDetection(
          id: newVisualSearchId(),
          partName: 'Kulp parçası',
          confidence: 0.8,
          bbox: const BoundingBox(x: 0.66, y: 0.3, width: 0.16, height: 0.18),
          details: 'Kulpun dış parçası karede yok.',
        ),
      ],
      matches: _matches('seramik kupa kulp', catalog),
    );
  }

  VisualSearchAnalysis _missingChairLeg(List<VisualCatalogItem> catalog) {
    return VisualSearchAnalysis(
      summary:
          'Ahşap sandalyenin ön sol ayağı görünmüyor. Oturma yüzeyi sağlam, bağlantı noktası boş.',
      confidence: 0.86,
      usedMock: true,
      damages: [
        DamageDetection(
          id: newVisualSearchId(),
          label: 'Bağlantı noktası',
          confidence: 0.77,
          bbox: const BoundingBox(x: 0.22, y: 0.58, width: 0.2, height: 0.16),
          description: 'Ayağın oturduğu köşede boş vida yuvası var.',
        ),
      ],
      missingParts: [
        MissingPartDetection(
          id: newVisualSearchId(),
          partName: 'Ön sol ayak',
          confidence: 0.9,
          bbox: const BoundingBox(x: 0.18, y: 0.6, width: 0.18, height: 0.32),
          details: 'Sandalyenin ön sol ayağı karede yok.',
        ),
      ],
      matches: _matches('ahsap sandalye ayak', catalog),
    );
  }

  VisualSearchAnalysis _shoes(
    VisualSearchJobType jobType,
    List<VisualCatalogItem> catalog,
  ) {
    final matches = _matches('kosu ayakkabi sneaker', catalog);
    if (jobType == VisualSearchJobType.visualSearch ||
        jobType == VisualSearchJobType.combined) {
      return VisualSearchAnalysis(
        summary: matches.isEmpty
            ? 'Ayakkabı görseli okundu, katalogda yakın ürün yok.'
            : 'Koşu ayakkabısına yakın ürünler katalogda eşleşti.',
        confidence: matches.isEmpty ? 0.4 : 0.83,
        usedMock: true,
        matches: matches,
      );
    }
    return VisualSearchAnalysis(
      summary: 'Ayakkabı yüzeyinde belirgin hasar veya eksik parça yok.',
      confidence: 0.7,
      usedMock: true,
      matches: matches,
    );
  }

  VisualSearchAnalysis _genericSearch(
    List<VisualCatalogItem> catalog,
    String hint,
  ) {
    final matches = _matches(hint, catalog);
    return VisualSearchAnalysis(
      summary: matches.isEmpty
          ? 'Katalogda bu görsele yakın ürün bulunamadı.'
          : 'Görsele yakın ürünler listelendi.',
      confidence: matches.isEmpty ? 0.31 : 0.68,
      usedMock: true,
      matches: matches,
    );
  }

  VisualSearchAnalysis _genericIntelligence() {
    return VisualSearchAnalysis(
      summary:
          'Yüzeyde hafif aşınma var. Eksik parça net olarak ayrışmıyor.',
      confidence: 0.64,
      usedMock: true,
      damages: [
        DamageDetection(
          id: newVisualSearchId(),
          label: 'Yüzey aşınması',
          confidence: 0.64,
          bbox: const BoundingBox(x: 0.3, y: 0.32, width: 0.4, height: 0.28),
          description: 'Orta bölgede renk ve doku farkı görülüyor.',
        ),
      ],
    );
  }

  List<ProductMatch> _matches(String hint, List<VisualCatalogItem> catalog) {
    final source = catalog.isEmpty ? demoCatalog : catalog;
    return _matcher.match(hint: hint, catalog: source);
  }

  bool _hasToken(String value, String token) {
    final parts = value.split(RegExp(r'[^a-z0-9]+'));
    return parts.contains(token);
  }

  bool _containsAny(String value, List<String> keys) {
    for (final key in keys) {
      if (value.contains(key)) return true;
    }
    return false;
  }
}
