/// Ana sayfa reklam bloğu için profesyonel başlık/metin çözümü.
///
/// Amaç: "Yemek / Yemekler / destina" gibi amatör tekrarları engellemek.
/// Kampanya adı profesyonelse onu kullanır; zayıf/dummy ise gerçek store +
/// kategori bilgisinden doğal bir başlık üretir. Hardcoded demo veri yok —
/// tüm metinler gerçek Supabase kampanya/store/kategori verisinden türetilir.
class HomeFeatureAdDisplayText {
  const HomeFeatureAdDisplayText({
    required this.sectionTitle,
    required this.cardTitle,
    required this.storeLabel,
    required this.badgeLabel,
    required this.cardTitleSource,
  });

  /// Kategori bölüm başlığı (ör. "Yemek").
  final String sectionTitle;

  /// Kart başlığı (ör. "Destina'dan Öne Çıkan Lezzetler").
  final String cardTitle;

  /// Küçük/zarif gösterilecek mağaza etiketi (ör. "Destina").
  final String storeLabel;

  /// Reklam rozeti (ör. "Sponsorlu").
  final String badgeLabel;

  /// Teşhis için: campaign_name | template | fallback.
  final String cardTitleSource;

  static const _weakTitles = <String>{
    'test',
    'asdf',
    'deneme',
    'baslik',
    'reklam',
    'kampanya',
    'yeni kampanya',
    'ad',
    'ads',
    'banner',
    'ana sayfa',
    'ana sayfa reklami',
  };

  static const _foodKeywords = <String>{
    'yemek', 'yemekler', 'restoran', 'restaurant', 'cafe', 'kafe',
    'pastane', 'tatli', 'burger', 'pizza', 'doner', 'kebap', 'kahvalti',
    'lokanta', 'food', 'mutfak',
  };

  static const _electronicsKeywords = <String>{
    'elektronik', 'teknoloji', 'telefon', 'bilgisayar', 'tablet',
    'televizyon', 'beyaz esya', 'aksesuar teknoloji', 'electronics',
  };

  static const _fashionKeywords = <String>{
    'moda', 'giyim', 'ayakkabi', 'canta', 'aksesuar', 'tekstil', 'fashion',
  };

  /// Türkçe karakterleri sadeleştirip normalize eder (karşılaştırma için).
  static String normalize(String value) {
    var v = value.trim().toLowerCase();
    const map = {
      'ı': 'i', 'İ': 'i', 'ş': 's', 'Ş': 's', 'ç': 'c', 'Ç': 'c',
      'ğ': 'g', 'Ğ': 'g', 'ü': 'u', 'Ü': 'u', 'ö': 'o', 'Ö': 'o',
      'â': 'a', 'î': 'i', 'û': 'u', '’': "'", '‘': "'",
    };
    map.forEach((from, to) => v = v.replaceAll(from, to));
    return v.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Çoğul eklerini atarak kök karşılaştırma ("yemekler" ≈ "yemek").
  static String _stem(String normalized) {
    var v = normalized;
    for (final suffix in const ['leri', 'lari', 'ler', 'lar']) {
      if (v.length > suffix.length + 2 && v.endsWith(suffix)) {
        return v.substring(0, v.length - suffix.length);
      }
    }
    return v;
  }

  /// İki başlık aynı/benzer mi? ("Yemek" vs "Yemekler" → true)
  static bool isSimilarTitle(String? a, String? b) {
    if (a == null || b == null) return false;
    final na = normalize(a);
    final nb = normalize(b);
    if (na.isEmpty || nb.isEmpty) return false;
    if (na == nb) return true;
    final sa = _stem(na);
    final sb = _stem(nb);
    return sa == sb;
  }

  /// Başlık zayıf/dummy mi? ("asdf", "test", kategori tekrarı, store tekrarı)
  static bool isWeakTitle(
    String? title, {
    String? categoryName,
    String? storeName,
  }) {
    if (title == null) return true;
    final n = normalize(title);
    if (n.length < 4) return true;
    if (_weakTitles.contains(n)) return true;
    // Tek karakterin tekrarı ("aaaa") veya harf içermeyen başlık.
    if (!RegExp(r'[a-z]').hasMatch(n)) return true;
    if (RegExp(r'^(.)\1+$').hasMatch(n.replaceAll(' ', ''))) return true;
    if (isSimilarTitle(title, categoryName)) return true;
    if (isSimilarTitle(title, storeName)) return true;
    // Otomatik üretilen "Ana Sayfa — <kategori>" adları da tekrardır.
    final stripped = n
        .replaceAll(RegExp(r'ana sayfa'), '')
        .replaceAll(RegExp(r'[—\-/|:]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (stripped.isEmpty) return true;
    if (categoryName != null && isSimilarTitle(stripped, categoryName)) {
      return true;
    }
    if (storeName != null && isSimilarTitle(stripped, storeName)) return true;
    // Tüm kelimeler kategori/store tekrarıysa ("yemek yemekler") başlık zayıf.
    final tokens = stripped.split(' ').where((t) => t.isNotEmpty);
    if (tokens.isNotEmpty &&
        tokens.every(
          (t) =>
              isSimilarTitle(t, categoryName) || isSimilarTitle(t, storeName),
        )) {
      return true;
    }
    return false;
  }

  /// Store adını zarif gösterim için baş harfleri büyütür ("destina"→"Destina").
  static String prettyStoreName(String storeName) {
    final trimmed = storeName.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed
        .split(RegExp(r'\s+'))
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  static String _segmentFallbackTitle({
    required String storeName,
    required String categoryLeaf,
  }) {
    final store = prettyStoreName(storeName);
    final leaf = _stem(normalize(categoryLeaf));
    bool inSet(Set<String> keywords) =>
        keywords.any((k) => _stem(normalize(k)) == leaf || leaf.contains(_stem(normalize(k))));

    if (store.isEmpty) {
      if (inSet(_foodKeywords)) return 'Öne Çıkan Lezzetler';
      if (inSet(_electronicsKeywords)) return 'Teknoloji Fırsatları';
      if (inSet(_fashionKeywords)) return 'Seçili Ürünler';
      return 'Bugünün Öne Çıkanları';
    }
    if (inSet(_foodKeywords)) return "$store'dan Öne Çıkan Lezzetler";
    if (inSet(_electronicsKeywords)) return "$store'dan Teknoloji Fırsatları";
    if (inSet(_fashionKeywords)) return "$store'dan Seçili Ürünler";
    return "$store'dan Öne Çıkanlar";
  }

  /// Ana çözümleyici.
  ///
  /// [categoryName]: bölüm başlığı ("Yemek").
  /// [rawCardTitle]: template başlığı / grouping alt başlığı ("Yemekler").
  /// [campaignName]: seller'ın verdiği kampanya adı.
  /// [storeName]: gerçek mağaza adı.
  static HomeFeatureAdDisplayText resolve({
    required String categoryName,
    String? rawCardTitle,
    String? campaignName,
    required String storeName,
  }) {
    final section = categoryName.trim().isEmpty ? 'Öne Çıkanlar' : categoryName.trim();
    final store = prettyStoreName(storeName);

    String cardTitle;
    String source;
    if (!isWeakTitle(campaignName, categoryName: section, storeName: storeName)) {
      cardTitle = campaignName!.trim();
      source = 'campaign_name';
    } else if (!isWeakTitle(
      rawCardTitle,
      categoryName: section,
      storeName: storeName,
    )) {
      cardTitle = rawCardTitle!.trim();
      source = 'template';
    } else {
      cardTitle = _segmentFallbackTitle(
        storeName: storeName,
        categoryLeaf: rawCardTitle?.trim().isNotEmpty == true
            ? rawCardTitle!.trim()
            : section,
      );
      source = 'fallback';
    }

    // Son emniyet: kart başlığı bölüm başlığıyla asla aynı/benzer olmasın.
    if (isSimilarTitle(cardTitle, section)) {
      cardTitle = _segmentFallbackTitle(
        storeName: storeName,
        categoryLeaf: section,
      );
      source = 'fallback';
    }

    return HomeFeatureAdDisplayText(
      sectionTitle: section,
      cardTitle: cardTitle,
      storeLabel: store,
      badgeLabel: 'Sponsorlu',
      cardTitleSource: source,
    );
  }
}
