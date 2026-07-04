/// Admin/seller UI için reklam enum etiketleri — raw DB değerleri kullanıcıya gösterilmez.
class AdDisplayLabels {
  const AdDisplayLabels._();

  static String campaignTypeLabel(String? raw) {
    switch (_normalize(raw)) {
      case 'home_feature':
        return 'Ana Sayfa Reklamı';
      case 'product_boost':
        return 'Ürün Öne Çıkarma';
      case 'store_boost':
        return 'Mağaza Öne Çıkarma';
      case 'geo_push':
        return 'Konum Bildirimi';
      case 'collection_boost':
        return 'Liste/Koleksiyon Reklamı';
      case 'banner':
        return 'Banner Reklamı';
      case 'category_sponsor':
        return 'Kategori Sponsorluğu';
      case 'coupon_offer':
      case 'coupon_ads':
        return 'Kupon / Teklif Reklamı';
      default:
        return _titleCase(raw);
    }
  }

  static String campaignGoalLabel(String? raw) {
    switch (_normalize(raw)) {
      case 'store_visits':
        return 'Mağaza Ziyareti';
      case 'product_views':
      case 'views':
      case 'impressions':
        return 'Görüntülenme';
      case 'orders':
        return 'Sipariş';
      case 'favorites':
        return 'Favori';
      case 'add_to_cart':
      case 'cart_add':
        return 'Sepete Ekleme';
      case 'collection_discovery':
        return 'Koleksiyon Keşfi';
      case 'drive_nearby_traffic':
      case 'nearby_reminder':
        return 'Yakındaki Kullanıcılara Bildirim';
      default:
        return _titleCase(raw);
    }
  }

  static String campaignStatusLabel(String? raw) {
    switch (_normalize(raw)) {
      case 'active':
        return 'Aktif';
      case 'paused':
        return 'Duraklatıldı';
      case 'expired':
      case 'completed':
        return 'Süresi Bitti';
      case 'pending_review':
      case 'pending':
        return 'Onay Bekliyor';
      case 'rejected':
        return 'Reddedildi';
      case 'approved':
        return 'Onaylandı';
      case 'draft':
        return 'Taslak';
      case 'scheduled':
        return 'Planlandı';
      case 'stopped':
        return 'Durduruldu';
      case 'archived':
        return 'Arşivlendi';
      default:
        return _titleCase(raw);
    }
  }

  static String reviewStatusLabel(String? raw) {
    switch (_normalize(raw)) {
      case 'pending':
        return 'Beklemede';
      case 'approved':
        return 'Onaylandı';
      case 'rejected':
        return 'Reddedildi';
      case 'changes_requested':
        return 'Değişiklik İstendi';
      default:
        return _titleCase(raw);
    }
  }

  static String _normalize(String? raw) =>
      (raw ?? '').trim().toLowerCase().replaceAll(' ', '_');

  static String _titleCase(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return '-';
    return value
        .split(RegExp(r'[_\s]+'))
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}
