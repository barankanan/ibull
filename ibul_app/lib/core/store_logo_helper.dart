class StoreLogoHelper {
  static String? getStoreLogo(String storeName) {
    // Mağaza adını normalize et (küçük harf, boşlukları kaldır)
    final normalized = storeName.toLowerCase().trim();
    
    // Logo eşleştirmeleri
    final logoMap = {
      'teknosa': 'assets/store_logos/teknosa.jpeg',
      'arçelik': 'assets/store_logos/Arçelik-Logo.wine.png',
      'queen iletişim': 'assets/store_logos/queen iletişim.jpg',
      'flo': 'assets/store_logos/Flo.jpg',
      'lc waikiki': 'assets/store_logos/lc waikiki.webp',
      'koton': 'assets/store_logos/Koton.png',
      'toyzz shop': 'assets/store_logos/toyzz shoğ.png',
      'arsuz parfüm evi': 'assets/store_logos/arsuz parfüm evi.jpeg',
      'eve': 'assets/store_logos/eve.png',
      'a101': 'assets/store_logos/A101.png',
      'şok': 'assets/store_logos/şok.png',
      'bim': 'assets/store_logos/bim.png',
      'migros': 'assets/store_logos/migros.png',
      'işler kitapevi': 'assets/store_logos/işler kitapevi.png',
      'fp pro tamir': 'assets/store_logos/FP PRO tamir.png',
    };
    
    return logoMap[normalized];
  }
  
  static bool hasLogo(String storeName) {
    return getStoreLogo(storeName) != null;
  }
}
