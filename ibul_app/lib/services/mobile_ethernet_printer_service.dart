// Mobil (Android) direct-TCP Ethernet yazıcı servisi.
//
// Masaüstünde tarama/test/baskı local print bridge (127.0.0.1:3001) üzerinden
// yürür; mobilde bridge YOKTUR. Bu servis aynı akışları telefon üzerinde
// doğrudan TCP socket ile sağlar:
//   - Subnet taraması (port 9100 öncelikli, kısa timeout, concurrency sınırı,
//     iptal edilebilir, progress callback)
//   - TCP bağlantı testi
//   - ESC/POS test fişi (CP857 Türkçe, auto-cut opsiyonel; cash-drawer gibi
//     riskli komutlar GÖNDERİLMEZ)
//
// UI katmanı `printer_ethernet_dialog.dart` mevcut `EthernetScanResult` /
// `EthernetConnectionDiagnostic` modellerini kullanmaya devam eder; bu servis
// aynı modelleri üretir, böylece masaüstü tasarımı/akışı bozulmaz.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'printer_error_messages.dart';

/// Saf yardımcılar — testlerde doğrudan çağrılır.
class MobileEthernetScanMath {
  MobileEthernetScanMath._();

  /// `192.168.1.34` → `192.168.1` (geçersiz IP'de null).
  static String? subnetPrefixOf(String localIp) {
    if (!isValidEthernetIpv4(localIp)) return null;
    final parts = localIp.split('.');
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }

  /// Taranacak host listesi: `prefix.1` … `prefix.254`, telefonun kendi
  /// IP'si hariç.
  static List<String> buildScanHosts(String localIp) {
    final prefix = subnetPrefixOf(localIp);
    if (prefix == null) return const <String>[];
    return <String>[
      for (var i = 1; i <= 254; i++)
        if ('$prefix.$i' != localIp) '$prefix.$i',
    ];
  }

  /// UI progress etiketi: "192.168.1.1 - 192.168.1.254 taranıyor".
  static String scanRangeLabel(String localIp) {
    final prefix = subnetPrefixOf(localIp);
    if (prefix == null) return 'Yerel ağ taranıyor';
    return '$prefix.1 - $prefix.254 taranıyor';
  }

  static bool isValidPort(int? port) =>
      port != null && port >= 1 && port <= 65535;
}

/// Tek bir tarama oturumu; [cancel] ile durdurulabilir.
class MobileEthernetScanSession {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

class MobileEthernetPrinterService {
  MobileEthernetPrinterService({
    this.probeTimeout = const Duration(milliseconds: 400),
    this.concurrency = 32,
  })  : assert(concurrency > 0);

  final Duration probeTimeout;
  final int concurrency;

  /// Telefonun aktif IPv4 adresleri (loopback hariç).
  Future<List<String>> resolveLocalIpv4s() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      return <String>[
        for (final iface in interfaces)
          for (final addr in iface.addresses)
            if (!addr.isLoopback && isValidEthernetIpv4(addr.address))
              addr.address,
      ];
    } catch (e) {
      debugPrint('[MobileEthernet][local_ips_error] $e');
      return const <String>[];
    }
  }

  /// Tek host TCP probe. Başarıda gecikme (ms) döner, aksi halde null.
  Future<int?> probePort(
    String host,
    int port, {
    Duration? timeout,
  }) async {
    final sw = Stopwatch()..start();
    Socket? socket;
    try {
      socket = await Socket.connect(
        host,
        port,
        timeout: timeout ?? probeTimeout,
      );
      sw.stop();
      return sw.elapsedMilliseconds;
    } catch (_) {
      return null;
    } finally {
      try {
        socket?.destroy();
      } catch (_) {}
    }
  }

  /// Subnet taraması. Bulunan cihazlar `latencyMs` sırasıyla döner.
  ///
  /// [onProgress]: (tamamlanan, toplam, aralıkEtiketi).
  Future<EthernetScanResult> scan({
    int port = 9100,
    MobileEthernetScanSession? session,
    void Function(int done, int total, String rangeLabel)? onProgress,
  }) async {
    final sw = Stopwatch()..start();
    final localIps = await resolveLocalIpv4s();
    if (localIps.isEmpty) {
      return const EthernetScanResult(
        ok: false,
        errorCode: 'no_local_network',
        message:
            'Telefonun yerel ağ adresi bulunamadı. Wi-Fi bağlantısını kontrol edin.',
      );
    }

    final hosts = <String>[];
    final subnets = <String>[];
    for (final ip in localIps) {
      final prefix = MobileEthernetScanMath.subnetPrefixOf(ip);
      if (prefix != null && !subnets.contains('$prefix.0/24')) {
        subnets.add('$prefix.0/24');
        hosts.addAll(MobileEthernetScanMath.buildScanHosts(ip));
      }
    }
    final rangeLabel = MobileEthernetScanMath.scanRangeLabel(localIps.first);
    final total = hosts.length;
    var done = 0;
    final found = <EthernetDiscoveredDevice>[];
    final latencies = <String, int>{};

    // Concurrency sınırlı worker havuzu; iptalde kalan hostlar atlanır.
    final queue = List<String>.from(hosts);
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        if (session?.isCancelled ?? false) return;
        final host = queue.removeAt(0);
        final latency = await probePort(host, port);
        done++;
        onProgress?.call(done, total, rangeLabel);
        if (latency != null) {
          latencies[host] = latency;
          found.add(
            EthernetDiscoveredDevice(
              host: host,
              port: port,
              reachable: true,
              portOpen: true,
              sameSubnet: true,
              subnet: subnets.isNotEmpty ? subnets.first : null,
              networkHint: 'Muhtemel ESC/POS yazıcı • ${latency}ms',
              latencyMs: latency,
            ),
          );
        }
      }
    }

    await Future.wait(
      List.generate(concurrency.clamp(1, 64), (_) => worker()),
    );
    sw.stop();

    if (session?.isCancelled ?? false) {
      return EthernetScanResult(
        ok: found.isNotEmpty,
        localIps: localIps,
        subnets: subnets,
        devices: _sortByLatency(found, latencies),
        port: port,
        scanDurationMs: sw.elapsedMilliseconds,
        errorCode: found.isEmpty ? 'scan_cancelled' : null,
        message: found.isEmpty ? 'Tarama iptal edildi.' : '',
      );
    }

    return EthernetScanResult(
      ok: true,
      localIps: localIps,
      subnets: subnets,
      devices: _sortByLatency(found, latencies),
      port: port,
      scanDurationMs: sw.elapsedMilliseconds,
      noDeviceReason: found.isEmpty
          ? 'Ağda $port portu açık cihaz bulunamadı. Yazıcının açık ve '
              'telefonla aynı Wi-Fi ağında olduğundan emin olun; IP adresini '
              'manuel de girebilirsiniz.'
          : '',
    );
  }

  List<EthernetDiscoveredDevice> _sortByLatency(
    List<EthernetDiscoveredDevice> devices,
    Map<String, int> latencies,
  ) {
    final sorted = List<EthernetDiscoveredDevice>.from(devices)
      ..sort(
        (a, b) => (latencies[a.host] ?? 1 << 30)
            .compareTo(latencies[b.host] ?? 1 << 30),
      );
    return sorted;
  }

  /// Bağlantı testi — UI'nin beklediği diagnostic modeliyle döner.
  Future<EthernetConnectionDiagnostic> testConnection({
    required String host,
    required int port,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final localIps = await resolveLocalIpv4s();
    final latency = await probePort(host, port, timeout: timeout);
    if (latency != null) {
      return EthernetConnectionDiagnostic(
        ok: true,
        errorCode: 'ready',
        title: 'Bağlantı başarılı',
        message: 'Yazıcıya ulaşıldı (${latency}ms).',
        host: host,
        port: port,
        localIps: localIps,
        sameSubnet: _sameSubnet(host, localIps),
        reachable: true,
        portOpen: true,
      );
    }
    final sameSubnet = _sameSubnet(host, localIps);
    return EthernetConnectionDiagnostic(
      ok: false,
      errorCode:
          sameSubnet == false ? 'network_mismatch' : 'connection_refused',
      title: 'Yazıcıya ulaşılamadı',
      message: sameSubnet == false
          ? 'Yazıcı ($host) telefonun ağından farklı bir ağda görünüyor. '
              'Telefon ve yazıcı aynı Wi-Fi ağında mı kontrol edin.'
          : 'Yazıcıya ulaşılamadı ($host:$port). Telefon ve yazıcı aynı '
              'Wi-Fi ağında mı kontrol edin; yazıcının açık olduğundan '
              'emin olun.',
      host: host,
      port: port,
      localIps: localIps,
      sameSubnet: sameSubnet,
      reachable: false,
      portOpen: false,
      guidanceSteps: ethernetPrinterIpHelpSteps(),
    );
  }

  bool? _sameSubnet(String host, List<String> localIps) {
    final hostPrefix = MobileEthernetScanMath.subnetPrefixOf(host);
    if (hostPrefix == null || localIps.isEmpty) return null;
    return localIps
        .any((ip) => MobileEthernetScanMath.subnetPrefixOf(ip) == hostPrefix);
  }

  /// ESC/POS byte'larını yazıcıya gönderir.
  Future<EthernetConnectionDiagnostic> sendBytes({
    required String host,
    required int port,
    required List<int> bytes,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: timeout);
      socket.add(bytes);
      await socket.flush().timeout(timeout);
      return EthernetConnectionDiagnostic(
        ok: true,
        errorCode: 'ready',
        title: 'Test fişi gönderildi',
        message: 'Test fişi gönderildi. Yazıcı çıktısını kontrol edin.',
        host: host,
        port: port,
      );
    } on TimeoutException {
      return EthernetConnectionDiagnostic(
        ok: false,
        errorCode: 'timeout',
        title: 'Yazıcı yanıt vermedi',
        message:
            'Veri gönderimi zaman aşımına uğradı. Yazıcı meşgul veya kağıt '
            'bitmiş olabilir; kontrol edip tekrar deneyin.',
        host: host,
        port: port,
      );
    } catch (e) {
      return EthernetConnectionDiagnostic(
        ok: false,
        errorCode: 'connection_refused',
        title: 'Yazıcıya ulaşılamadı',
        message: 'Yazıcıya ulaşılamadı. Telefon ve yazıcı aynı Wi-Fi '
            'ağında mı kontrol edin.',
        technicalDetail: e.toString(),
        host: host,
        port: port,
        guidanceSteps: ethernetPrinterIpHelpSteps(),
      );
    } finally {
      try {
        socket?.destroy();
      } catch (_) {}
    }
  }

  /// Test fişini üretip gönderir.
  Future<EthernetConnectionDiagnostic> printTestReceipt({
    required String host,
    required int port,
    String? sellerName,
    bool autoCut = true,
    int charsPerLine = 32,
    DateTime? now,
  }) {
    final bytes = MobileEscPosTestReceipt.build(
      sellerName: sellerName,
      host: host,
      port: port,
      autoCut: autoCut,
      charsPerLine: charsPerLine,
      now: now ?? DateTime.now(),
    );
    return sendBytes(host: host, port: port, bytes: bytes);
  }
}

/// ESC/POS test fişi üretici — saf, testlenebilir.
class MobileEscPosTestReceipt {
  MobileEscPosTestReceipt._();

  // ESC/POS komutları
  static const List<int> _init = <int>[0x1B, 0x40]; // ESC @
  static const List<int> _codepageCp857 = <int>[0x1B, 0x74, 13]; // ESC t 13
  static const List<int> _alignCenter = <int>[0x1B, 0x61, 1];
  static const List<int> _alignLeft = <int>[0x1B, 0x61, 0];
  static const List<int> _boldOn = <int>[0x1B, 0x45, 1];
  static const List<int> _boldOff = <int>[0x1B, 0x45, 0];
  static const List<int> _doubleSize = <int>[0x1D, 0x21, 0x11]; // GS ! 2x2
  static const List<int> _normalSize = <int>[0x1D, 0x21, 0x00];
  static const List<int> _lf = <int>[0x0A];

  /// GS V 66 0 — feed + partial cut. Cash drawer (ESC p) bilinçli olarak YOK.
  static const List<int> cutCommand = <int>[0x1D, 0x56, 66, 0];

  /// Türkçe karakterlerin CP857 karşılıkları; kalanlar Latin-1/ASCII.
  static const Map<int, int> _cp857Overrides = <int, int>{
    0x00E7: 0x87, // ç
    0x00C7: 0x80, // Ç
    0x011F: 0xA7, // ğ
    0x011E: 0xA6, // Ğ
    0x0131: 0x8D, // ı
    0x0130: 0x98, // İ
    0x00F6: 0x94, // ö
    0x00D6: 0x99, // Ö
    0x015F: 0x9F, // ş
    0x015E: 0x9E, // Ş
    0x00FC: 0x81, // ü
    0x00DC: 0x9A, // Ü
    0x20BA: 0x54, // ₺ → 'T' (CP857'de yok)
  };

  /// Metni CP857 byte'larına çevirir; bilinmeyen karakter '?' olur.
  /// Test fişi VE sipariş fişi builder'ları tarafından paylaşılır.
  static List<int> encodeCp857(String text) {
    return <int>[
      for (final code in text.runes)
        if (_cp857Overrides.containsKey(code))
          _cp857Overrides[code]!
        else if (code <= 0x7F)
          code
        else
          0x3F, // ?
    ];
  }

  static List<int> _line(String text) => <int>[...encodeCp857(text), ..._lf];

  /// İBUL test fişi ESC/POS payload'ı.
  static List<int> build({
    String? sellerName,
    required String host,
    required int port,
    required bool autoCut,
    int charsPerLine = 32,
    required DateTime now,
  }) {
    String two(int v) => v.toString().padLeft(2, '0');
    final dateLine =
        '${two(now.day)}.${two(now.month)}.${now.year} ${two(now.hour)}:${two(now.minute)}';
    final divider = '-' * charsPerLine.clamp(16, 64);
    final trimmedSeller = sellerName?.trim() ?? '';
    return <int>[
      ..._init,
      ..._codepageCp857,
      ..._alignCenter,
      ..._doubleSize,
      ..._boldOn,
      ..._line('İBUL'),
      ..._normalSize,
      ..._boldOff,
      ..._line('Yazıcı Testi'),
      ..._lf,
      ..._alignLeft,
      ..._line(divider),
      ..._line('Tarih: $dateLine'),
      if (trimmedSeller.isNotEmpty) ..._line('Satıcı: $trimmedSeller'),
      ..._line('Yazıcı: $host:$port'),
      ..._line(divider),
      ..._line('Türkçe test: ç ğ ı ö ş ü İ'),
      ..._line(divider),
      ..._alignCenter,
      ..._line('Bağlantı başarılı'),
      ..._lf,
      ..._lf,
      ..._lf,
      if (autoCut) ...cutCommand,
    ];
  }
}
