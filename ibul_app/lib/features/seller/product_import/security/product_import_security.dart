import 'dart:io';

/// SSRF Koruması, Girdi Doğrulama ve Temizleme Yardımcısı
class ProductImportSecurity {
  const ProductImportSecurity._();

  static const List<String> _forbiddenIpPrefixes = [
    '0.',
    '10.',
    '127.',
    '169.254.', // Link-local & AWS/GCP/Azure Metadata (169.254.169.254)
    '192.168.',
    '224.',
    '240.',
    '255.255.255.255',
  ];

  /// URL'nin SSRF ve güvenlik kurallarına uygunluğunu doğrular.
  static ({bool isValid, String? error, Uri? uri}) validateUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return (isValid: false, error: 'URL boş olamaz.', uri: null);
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return (isValid: false, error: 'Geçersiz URL formatı.', uri: null);
    }

    // 1. Protokol kontrolü: Sadece HTTP ve HTTPS
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return (
        isValid: false,
        error: 'Güvenlik nedeniyle yalnızca HTTP ve HTTPS protokolleri kabul edilir.',
        uri: null
      );
    }

    // 2. Kullanıcı kimlik bilgisi kontrolü (userInfo)
    if (uri.userInfo.isNotEmpty) {
      return (
        isValid: false,
        error: 'URL içerisinde kimlik bilgisi (kullanıcı/şifre) bulunamaz.',
        uri: null
      );
    }

    // 3. Hostname kontrolü
    final host = uri.host.toLowerCase().trim();
    if (host.isEmpty) {
      return (isValid: false, error: 'URL host alanı eksik.', uri: null);
    }

    // Localhost ve yerel ağ adreslerini engelle
    if (host == 'localhost' ||
        host.endsWith('.local') ||
        host.endsWith('.internal') ||
        host.endsWith('.localhost') ||
        host.endsWith('.corp')) {
      return (
        isValid: false,
        error: 'Yerel ve iç ağ adreslerine (SSRF) erişim engellendi.',
        uri: null
      );
    }

    // Özel / Yasaklı IP kontrolü
    if (_isForbiddenIp(host)) {
      return (
        isValid: false,
        error: 'Özel IP ve bulut metadata adreslerine (SSRF) erişim engellendi.',
        uri: null
      );
    }

    return (isValid: true, error: null, uri: uri);
  }

  /// IP adresinin yasaklı aralıklarda (Loopback, Private RFC 1918, Link-local, Cloud metadata) olup olmadığını kontrol eder.
  static bool _isForbiddenIp(String ip) {
    final lower = ip.toLowerCase();
    if (lower == 'localhost' ||
        lower == '::1' ||
        lower.startsWith('fe80:') ||
        lower.startsWith('fc00:') ||
        lower.startsWith('fd00:')) {
      return true;
    }

    for (final prefix in _forbiddenIpPrefixes) {
      if (lower.startsWith(prefix)) return true;
    }

    // 172.16.0.0/12 kontrolü (172.16.x.x - 172.31.x.x)
    if (lower.startsWith('172.')) {
      final parts = lower.split('.');
      if (parts.length >= 2) {
        final second = int.tryParse(parts[1]);
        if (second != null && second >= 16 && second <= 31) return true;
      }
    }

    // 100.64.0.0/10 kontrolü (Carrier-Grade NAT)
    if (lower.startsWith('100.')) {
      final parts = lower.split('.');
      if (parts.length >= 2) {
        final second = int.tryParse(parts[1]);
        if (second != null && second >= 64 && second <= 127) return true;
      }
    }

    return false;
  }

  /// DNS çözümlemesi ile host'un gerçek IP adresini kontrol eder (Desktop / Mobile platformlarında).
  static Future<({bool isValid, String? error})> verifyDnsResolution(String host) async {
    try {
      final addresses = await InternetAddress.lookup(host);
      for (final addr in addresses) {
        if (_isForbiddenIp(addr.address)) {
          return (
            isValid: false,
            error: 'Alan adı özel/yerel bir IP adresine çözümlendi (${addr.address}).',
          );
        }
      }
      return (isValid: true, error: null);
    } catch (_) {
      // DNS çözülemiyorsa fetch aşamasında hata verecektir
      return (isValid: true, error: null);
    }
  }

  /// Metin içeriğini XSS ve zararlı HTML kodlarından arındırır.
  static String sanitizeText(String? input) {
    if (input == null) return '';
    var text = input;

    // Script ve stil etiketlerini tamamen kaldır
    text = text.replaceAll(RegExp(r'<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'<iframe\b[^<]*(?:(?!<\/iframe>)<[^<]*)*<\/iframe>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'<object\b[^<]*(?:(?!<\/object>)<[^<]*)*<\/object>', caseSensitive: false), '');

    // JavaScript protokolü ve event handler'lar
    text = text.replaceAll(RegExp(r'javascript:', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '');

    // HTML etiketlerini kaldır ve sadece temiz metni bırak (isteğe bağlı basit koruma)
    text = text.replaceAll(RegExp(r'<[^>]*>'), ' ');

    // Standart HTML entity çözümü
    text = text
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return text;
  }

  /// Fiyat metnini güvenli bir şekilde sayıya çevirir (Türkçe veya Uluslararası format).
  static double? parsePrice(dynamic input) {
    if (input == null) return null;
    if (input is num) return input.toDouble();

    String s = input.toString().trim();
    if (s.isEmpty) return null;

    // Para birimi sembollerini ve gereksiz harfleri temizle
    s = s.replaceAll(RegExp(r'[^\d.,]'), '').trim();
    if (s.isEmpty) return null;

    // Format 1: 1.499,90 (Türkçe: nokta binlik, virgül ondalık)
    if (s.contains('.') && s.contains(',')) {
      final lastDot = s.lastIndexOf('.');
      final lastComma = s.lastIndexOf(',');
      if (lastComma > lastDot) {
        // Türkçe format: 1.499,90
        s = s.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // İngilizce format: 1,499.90
        s = s.replaceAll(',', '');
      }
    } else if (s.contains(',')) {
      // Yalnızca virgül var: "1499,90" -> "1499.90"
      s = s.replaceAll(',', '.');
    }

    return double.tryParse(s);
  }

  /// Para birimini normalize eder.
  static String parseCurrency(String? raw) {
    if (raw == null) return 'TRY';
    final s = raw.trim().toUpperCase();
    if (s.contains('TL') || s.contains('TRY') || s.contains('₺')) return 'TRY';
    if (s.contains('USD') || s.contains('\$')) return 'USD';
    if (s.contains('EUR') || s.contains('€')) return 'EUR';
    if (s.contains('GBP') || s.contains('£')) return 'GBP';
    return s.isEmpty ? 'TRY' : s;
  }
}
