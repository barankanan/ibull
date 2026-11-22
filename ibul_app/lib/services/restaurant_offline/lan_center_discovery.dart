import 'dart:io';

/// Order center for waiter phones. This is not the print-bridge port.
/// Production stays on 18772. A test build can set `IBUL_LAN_PORT`.
const int _lanPortDefine = int.fromEnvironment(
  'IBUL_LAN_PORT',
  defaultValue: 18772,
);
const int lanOrderPort = _lanPortDefine == 3001 ? 18772 : _lanPortDefine;
const String lanOrderServiceType = '_ibul-lan._tcp';
const int lanMaxBodyBytes = 65536;

class LanCenterRecord {
  const LanCenterRecord({
    required this.host,
    required this.port,
    required this.restaurantId,
    required this.machineId,
    required this.fingerprint,
    this.service = 'ibul-lan',
  });

  final String host;
  final int port;
  final String restaurantId;
  final String machineId;
  final String fingerprint;
  final String service;

  String get httpsUri => 'https://$host:$port';
}

class SavedLanCenter {
  const SavedLanCenter({
    required this.restaurantId,
    required this.machineId,
    required this.fingerprint,
  });

  final String restaurantId;
  final String machineId;
  final String fingerprint;
}

enum LanCenterChoice { selected, notFound, wrongRestaurant, fakeCenter, ambiguous, needsQr }

class LanCenterDecision {
  const LanCenterDecision(this.choice, {this.record, required this.message});

  final LanCenterChoice choice;
  final LanCenterRecord? record;
  final String message;
}

/// A first sighting from mDNS is not trust. Trust comes from the QR the
/// operator shows, then later announcements must match that identity.
LanCenterDecision chooseLanCenter({
  required String restaurantId,
  required List<LanCenterRecord> found,
  SavedLanCenter? trusted,
  required bool fromQr,
}) {
  final expected = restaurantId.trim();
  final sameRestaurant = found.where((row) {
    return row.service == 'ibul-lan' &&
        row.restaurantId == expected &&
        row.machineId.isNotEmpty &&
        row.fingerprint.isNotEmpty &&
        _reachableHost(row.host) &&
        row.port == lanOrderPort;
  }).toList(growable: false);
  if (sameRestaurant.isEmpty) {
    final otherRestaurant = found.any(
      (row) => row.service == 'ibul-lan' && row.restaurantId != expected,
    );
    return LanCenterDecision(
      otherRestaurant ? LanCenterChoice.wrongRestaurant : LanCenterChoice.notFound,
      message: otherRestaurant
          ? 'Başka restoranın merkezi seçilmedi.'
          : 'Bu restoranın yerel merkezi görünmüyor.',
    );
  }
  if (trusted == null) {
    if (!fromQr || sameRestaurant.length != 1) {
      return const LanCenterDecision(
        LanCenterChoice.needsQr,
        message: 'İlk eşleştirme QR ile yapılır. Ağ duyurusu tek başına yetmez.',
      );
    }
    return LanCenterDecision(
      LanCenterChoice.selected,
      record: sameRestaurant.single,
      message: 'QR kimliği doğrulandı.',
    );
  }
  final matches = sameRestaurant.where((row) {
    return row.machineId == trusted.machineId &&
        _sameFingerprint(row.fingerprint, trusted.fingerprint) &&
        trusted.restaurantId == expected;
  }).toList(growable: false);
  if (matches.isEmpty) {
    return const LanCenterDecision(
      LanCenterChoice.fakeCenter,
      message: 'Duyurulan merkez kayıtlı kimlikle eşleşmiyor.',
    );
  }
  if (matches.length != 1) {
    return const LanCenterDecision(
      LanCenterChoice.ambiguous,
      message: 'Aynı kimlik için birden fazla merkez var. Sipariş gönderilmedi.',
    );
  }
  return LanCenterDecision(
    LanCenterChoice.selected,
    record: matches.single,
    message: 'Kayıtlı merkez kimliği doğrulandı.',
  );
}

String encodeLanQr(LanCenterRecord record) {
  return Uri(
    scheme: 'ibul-lan',
    host: 'pair',
    queryParameters: <String, String>{
      'v': '1',
      'host': record.host,
      'port': '${record.port}',
      'restaurant': record.restaurantId,
      'machine': record.machineId,
      'fingerprint': record.fingerprint,
    },
  ).toString();
}

LanCenterRecord? decodeLanQr(String raw, {int? expectedPort}) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.scheme != 'ibul-lan' || uri.host != 'pair') return null;
  final host = uri.queryParameters['host']?.trim() ?? '';
  final port = int.tryParse(uri.queryParameters['port'] ?? '');
  final restaurant = uri.queryParameters['restaurant']?.trim() ?? '';
  final machine = uri.queryParameters['machine']?.trim() ?? '';
  final fingerprint = uri.queryParameters['fingerprint']?.trim() ?? '';
  if (port == null ||
      port != (expectedPort ?? lanOrderPort) ||
      restaurant.isEmpty ||
      machine.isEmpty ||
      fingerprint.isEmpty ||
      !_privateHost(host)) {
    return null;
  }
  return LanCenterRecord(
    host: host,
    port: port,
    restaurantId: restaurant,
    machineId: machine,
    fingerprint: fingerprint,
  );
}

List<String> lanAdvertiseArguments(LanCenterRecord record) {
  final short = record.machineId.length <= 8
      ? record.machineId
      : record.machineId.substring(0, 8);
  return <String>[
    '-R',
    'IBUL-$short',
    lanOrderServiceType,
    'local',
    '${record.port}',
    'svc=ibul-lan',
    'rid=${record.restaurantId}',
    'mid=${record.machineId}',
    'fp=${record.fingerprint}',
  ];
}

LanCenterRecord? parseLanLookup(String text) {
  final portMatch = RegExp(r':(\d{2,5})').firstMatch(text);
  final hostMatch = RegExp(r'reached at\s+(\S+?):(\d+)').firstMatch(text);
  final fields = <String, String>{};
  for (final match in RegExp(r'(svc|rid|mid|fp)=([^\s]+)').allMatches(text)) {
    fields[match.group(1)!] = match.group(2)!;
  }
  final parsedPort = int.tryParse(hostMatch?.group(2) ?? portMatch?.group(1) ?? '');
  final host = hostMatch?.group(1)?.replaceAll(RegExp(r'\.$'), '') ?? '';
  if (parsedPort == null || fields['svc'] != 'ibul-lan') return null;
  if (fields['rid'] == null || fields['mid'] == null || fields['fp'] == null) {
    return null;
  }
  return LanCenterRecord(
    host: host,
    port: parsedPort,
    restaurantId: fields['rid']!,
    machineId: fields['mid']!,
    fingerprint: fields['fp']!,
  );
}

bool lanDiscoveryCommandExists() {
  if (Platform.isMacOS) return true;
  return false;
}

String lanDiscoveryUnavailableMessage({required bool isWeb, required String operatingSystem}) {
  if (isWeb) {
    return 'Tarayıcı yerel ağdaki İBUL merkezine güvenli istemci sertifikasıyla bağlanamaz. Garson telefon uygulamasını kullanın.';
  }
  if (operatingSystem.toLowerCase() == 'ios' || operatingSystem.toLowerCase() == 'android') {
    return 'Telefonda otomatik keşif bu kurulumda doğrulanmadı. Mac ekranındaki QR metnini yapıştırın.';
  }
  return 'Bonjour duyurusu bu bilgisayarda dns-sd ile yapılır. QR yedek yoldur.';
}

bool _reachableHost(String host) {
  final name = host.trim().toLowerCase();
  if (name.endsWith('.local') && !name.contains(' ') && name.length < 80) {
    return true;
  }
  return _privateHost(host);
}

bool _privateHost(String host) {
  final parts = host.split('.');
  if (parts.length != 4) return false;
  final bytes = parts.map(int.tryParse).toList(growable: false);
  if (bytes.any((byte) => byte == null || byte < 0 || byte > 255)) return false;
  final a = bytes[0]!;
  final b = bytes[1]!;
  if (a == 10) return true;
  if (a == 172 && b >= 16 && b <= 31) return true;
  if (a == 192 && b == 168) return true;
  return false;
}

bool _sameFingerprint(String left, String right) {
  String norm(String value) => value.replaceAll(':', '').trim().toLowerCase();
  return norm(left).isNotEmpty && norm(left) == norm(right);
}
