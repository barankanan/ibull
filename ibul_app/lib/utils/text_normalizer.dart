class TextNormalizer {
  const TextNormalizer._();

  static String normalize(String? value) {
    var text = (value ?? '').toLowerCase().trim();
    text = text.replaceAll('i̇', 'i');
    text = text.replaceAll('ı', 'i').replaceAll('İ', 'i');
    text = text.replaceAll('ş', 's').replaceAll('Ş', 's');
    text = text.replaceAll('ğ', 'g').replaceAll('Ğ', 'g');
    text = text.replaceAll('ü', 'u').replaceAll('Ü', 'u');
    text = text.replaceAll('ö', 'o').replaceAll('Ö', 'o');
    text = text.replaceAll('ç', 'c').replaceAll('Ç', 'c');
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    return text;
  }

  static String productLookupKey({
    required String? name,
    required String? brand,
    String? sellerId,
    String? storeName,
  }) {
    return [
      normalize(name),
      normalize(brand),
      (sellerId ?? '').trim(),
      normalize(storeName),
    ].join('|');
  }
}
