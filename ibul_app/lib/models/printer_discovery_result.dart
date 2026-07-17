// Yazıcı keşfi ortak modeli + adlandırma yardımcıları.
//
// Android direct-TCP taraması, masaüstü agent (local print bridge) taraması
// ve manuel giriş aynı sonucu bu model üzerinden taşır; kart UI'sı tek
// tasarımla üçünü de gösterebilir. Adlandırma yardımcıları SAF fonksiyondur
// ve testlerde doğrudan çağrılır.

import '../services/printer_error_messages.dart';

/// Keşif kaynağı — kart üzerinde rozet/telemetri için.
enum PrinterDiscoverySource {
  androidDirect('android_direct'),
  desktopAgent('desktop_agent'),
  manual('manual');

  const PrinterDiscoverySource(this.value);

  final String value;
}

/// Kart üzerinde gösterilen tek keşif sonucu.
class PrinterDiscoveryResult {
  const PrinterDiscoveryResult({
    required this.id,
    required this.ipAddress,
    required this.port,
    this.latencyMs,
    required this.suggestedName,
    required this.editableName,
    required this.profileId,
    this.role = '',
    required this.source,
    this.testStatus = PrinterDiscoveryTestStatus.notTested,
  });

  final String id;
  final String ipAddress;
  final int port;
  final int? latencyMs;
  final String suggestedName;
  final String editableName;
  final String profileId;
  final String role;
  final PrinterDiscoverySource source;
  final PrinterDiscoveryTestStatus testStatus;

  factory PrinterDiscoveryResult.fromDevice(
    EthernetDiscoveredDevice device, {
    required PrinterDiscoverySource source,
    required String suggestedName,
    required String profileId,
    String? editableName,
  }) {
    return PrinterDiscoveryResult(
      id: device.endpointLabel,
      ipAddress: device.host,
      port: device.port,
      latencyMs: device.latencyMs,
      suggestedName: suggestedName,
      editableName: editableName ?? suggestedName,
      profileId: profileId,
      source: source,
    );
  }
}

enum PrinterDiscoveryTestStatus { notTested, testing, success, failed }

/// Bulunan yazıcılar için ad üretimi / çakışma çözümü.
class PrinterDiscoveryNaming {
  PrinterDiscoveryNaming._();

  /// Hızlı ad şablonları (kartta chip olarak sunulur).
  static const List<String> quickNameTemplates = <String>[
    'Kasa Yazıcısı',
    'Mutfak Yazıcısı',
    'Bar Yazıcısı',
    'Adisyon Yazıcısı',
    'Paket Yazıcısı',
  ];

  /// `192.168.1.45` → `45`; çözülemezse IP'nin kendisi.
  static String lastOctet(String ip) {
    final parts = ip.trim().split('.');
    if (parts.length == 4 && parts.last.isNotEmpty) return parts.last;
    return ip.trim();
  }

  static String _normalize(String name) => name.trim().toLowerCase();

  /// Aynı seller içinde ad çakışması var mı (case-insensitive, trim).
  static bool isDuplicateName(String name, Iterable<String> existingNames) {
    final normalized = _normalize(name);
    if (normalized.isEmpty) return false;
    return existingNames.any((n) => _normalize(n) == normalized);
  }

  /// Taramada bulunan cihaz için varsayılan ad: "POS Yazıcı - 45".
  /// Çakışırsa tam IP'ye genişler: "POS Yazıcı - 192.168.1.45".
  static String defaultNameFor(
    String ip, {
    Iterable<String> existingNames = const <String>[],
  }) {
    final withOctet = 'POS Yazıcı - ${lastOctet(ip)}';
    if (!isDuplicateName(withOctet, existingNames)) return withOctet;
    final withIp = 'POS Yazıcı - ${ip.trim()}';
    if (!isDuplicateName(withIp, existingNames)) return withIp;
    var counter = 2;
    while (isDuplicateName('$withIp ($counter)', existingNames)) {
      counter++;
    }
    return '$withIp ($counter)';
  }

  /// [base] adını benzersizleştirir:
  /// 1. `base`            (çakışmıyorsa)
  /// 2. `base - oktet`    ("POS Yazıcı - 45")
  /// 3. `base - ip`       ("POS Yazıcı - 192.168.1.45")
  /// 4. `base - ip (n)`   (aynı IP birden çok kez — teorik)
  static String resolveUniqueName(
    String base,
    String ip, {
    Iterable<String> existingNames = const <String>[],
  }) {
    final trimmedBase = base.trim().isEmpty ? 'POS Yazıcı' : base.trim();
    if (!isDuplicateName(trimmedBase, existingNames)) return trimmedBase;
    final withOctet = '$trimmedBase - ${lastOctet(ip)}';
    if (!isDuplicateName(withOctet, existingNames)) return withOctet;
    final withIp = '$trimmedBase - ${ip.trim()}';
    if (!isDuplicateName(withIp, existingNames)) return withIp;
    var counter = 2;
    while (isDuplicateName('$withIp ($counter)', existingNames)) {
      counter++;
    }
    return '$withIp ($counter)';
  }

  /// Şablon seçilince kullanılacak ad (çakışmada IP eklenir).
  static String applyTemplate(
    String template,
    String ip, {
    Iterable<String> existingNames = const <String>[],
  }) {
    return resolveUniqueName(template, ip, existingNames: existingNames);
  }

  /// Şablon adından rol önerisi: mutfak/bar → mutfak; diğerleri → adisyon.
  static String suggestedRoleForTemplate(String template) {
    final lower = template.trim().toLowerCase();
    if (lower.contains('mutfak') || lower.contains('bar')) return 'mutfak';
    return 'adisyon';
  }
}
