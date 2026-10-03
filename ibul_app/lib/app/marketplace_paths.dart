import 'package:flutter/foundation.dart';

/// Public marketplace URLs. Resolve always by stable id; slug is cosmetic.
abstract final class MarketplacePaths {
  static const home = '/';
  static const productRoot = '/urun';
  static const storeRoot = '/magaza';
  static const vehicleRoot = '/arac';
  static const categoryRoot = '/kategori';
  static const account = '/hesabim';
  static const orders = '/hesabim/siparisler';
  static const rentals = '/hesabim/kiralamalar';
  static const favorites = '/hesabim/favoriler';
  static const coupons = '/hesabim/kuponlar';
  static const following = '/hesabim/takip-ettiklerim';
  static const addresses = '/hesabim/adresler';
  static const cards = '/hesabim/kartlar';
  static const reviews = '/hesabim/degerlendirmeler';
  static const support = '/hesabim/musteri-hizmetleri';
  static const settings = '/hesabim/ayarlar';
  static const ai = '/hesabim/yapay-zeka';
  static const mallHub = '/avm';
  static const mallLogin = '/avm/giris';
  static const mallRegister = '/avm/kayit';
  static const mallApplication = '/avm/basvuru';
  static const legacyMallApplication = '/hesabim/avm-basvurusu';
  static const legacyPublicMallApplication = '/avm-basvurusu';
  static const mallManagement = '/avm/yonetim';
  static const legacyMallManagement = '/avm-yonetim';

  static String mallManagementMall(String mallId) =>
      '$mallManagement/${Uri.encodeComponent(mallId)}';

  static String mallFloor(String mallId, String floorId) =>
      '${mallManagementMall(mallId)}/katlar/${Uri.encodeComponent(floorId)}';

  static const mallProfileRoot = '/avm/profil';

  static String mallProfile(String mallId, {String? floorId, String? storeId}) {
    final path = '$mallProfileRoot/${Uri.encodeComponent(mallId)}';
    final query = <String, String>{
      if ((floorId ?? '').isNotEmpty) 'kat': floorId!,
      if ((storeId ?? '').isNotEmpty) 'magaza': storeId!,
    };
    return query.isEmpty ? path : Uri(path: path, queryParameters: query).toString();
  }

  static bool isMallManagementPath(String path) {
    final normalized = path.split('?').first;
    return normalized == mallManagement ||
        normalized.startsWith('$mallManagement/');
  }

  static String product(String id, {String? slug}) =>
      _idPath(productRoot, id, slug);

  static String store(String id, {String? slug}) =>
      _idPath(storeRoot, id, slug);

  static String vehicle(String id, {String? slug}) =>
      _idPath(vehicleRoot, id, slug);

  static String category(String mainCategoryId, String subCategoryId, {String? slug}) {
    final suffix = slugify(slug ?? '');
    final path = '$categoryRoot/${Uri.encodeComponent(mainCategoryId)}/${Uri.encodeComponent(subCategoryId)}';
    return suffix.isEmpty ? path : '$path/$suffix';
  }

  static bool isAccountPath(String path) {
    final normalized = path.split('?').first;
    return normalized == account ||
        normalized == orders ||
        normalized == rentals ||
        normalized.startsWith('$account/');
  }

  static bool isProductPath(String path) =>
      path.split('?').first.startsWith('$productRoot/');

  static bool isStorePath(String path) =>
      path.split('?').first.startsWith('$storeRoot/');

  static String? idFrom(String path, String root) {
    final normalized = path.split('?').first;
    final prefix = '$root/';
    if (!normalized.startsWith(prefix)) return null;
    final rest = normalized.substring(prefix.length);
    if (rest.isEmpty) return null;
    return rest.split('/').first;
  }

  static String slugify(String raw) {
    final lowered = raw.trim().toLowerCase();
    if (lowered.isEmpty) return '';
    const from = 'ığüşöçâîû';
    const to = 'igusocaiu';
    final buffer = StringBuffer();
    for (final unit in lowered.runes) {
      final char = String.fromCharCode(unit);
      final index = from.indexOf(char);
      final mapped = index >= 0 ? to[index] : char;
      if (RegExp(r'[a-z0-9]').hasMatch(mapped)) {
        buffer.write(mapped);
      } else if (buffer.isNotEmpty && !buffer.toString().endsWith('-')) {
        buffer.write('-');
      }
    }
    final slug = buffer.toString().replaceAll(RegExp(r'-+'), '-');
    return slug.replaceAll(RegExp(r'^-|-$'), '');
  }

  static String shareUrl(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    if (kIsWeb) return '${Uri.base.origin}$normalized';
    return 'https://ibul.com.tr$normalized';
  }

  static bool syncsBrowserUrl() => kIsWeb;

  static String _idPath(String root, String id, String? slug) {
    final safeId = id.trim();
    if (safeId.isEmpty) return root;
    final safeSlug = slugify(slug ?? '');
    if (safeSlug.isEmpty) return '$root/$safeId';
    return '$root/$safeId/$safeSlug';
  }
}
