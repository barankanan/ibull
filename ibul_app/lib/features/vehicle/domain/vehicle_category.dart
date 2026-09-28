/// Gallery vertical detector. Does not treat generic "Otomotiv & Motosiklet"
/// parts shops as dealerships.
bool isSellerVehicleGalleryCategory(String? category) {
  final normalized = _normalize(category);
  if (normalized.isEmpty) return false;
  const keywords = <String>[
    'galerici',
    'oto galeri',
    'otogaleri',
    'arac galeri',
    'araç galeri',
    'arac kiralama',
    'araç kiralama',
    'rent a car',
    'rentacar',
    'car dealer',
    'dealership',
  ];
  if (normalized == 'galeri') return true;
  return keywords.any(normalized.contains);
}

String? vehicleGalleryStoreCategoryLabel() => 'Galerici';

bool isVehicleHubShortcutTitle(String title) {
  final normalized = _normalize(title);
  return normalized == 'arac' ||
      normalized == 'araclar' ||
      normalized == 'galeri' ||
      normalized == 'galerici';
}

String _normalize(String? value) {
  return (value ?? '')
      .trim()
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');
}
