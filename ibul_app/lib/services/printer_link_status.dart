import 'package:flutter/foundation.dart' show ValueNotifier;

/// Bridge `/health` and the physical printer are different facts.
class PrinterLinkStatus {
  const PrinterLinkStatus({
    required this.bridgeUp,
    required this.printerReachable,
    required this.label,
    required this.detail,
  });

  final bool bridgeUp;

  /// Null when no printer address is configured to probe.
  final bool? printerReachable;
  final String label;
  final String detail;
}

/// One operator sentence. Bridge health, TCP, the master permission and the
/// print-station consumer are separate facts and must not be renamed into
/// each other.
class PrinterCanonicalStatus {
  const PrinterCanonicalStatus({
    required this.bridgeUp,
    required this.printerReachable,
    required this.serviceEnabled,
    required this.stationConsumerEnabled,
    required this.label,
    required this.detail,
    this.pendingJobs = 0,
    this.quarantinedJobs = 0,
  });

  final bool bridgeUp;
  final bool? printerReachable;

  /// Master permission. Null means the bridge did not say, so sending is closed.
  final bool? serviceEnabled;

  /// PRINT_STATION_ENABLED. False does not mean the printer is off.
  final bool? stationConsumerEnabled;
  final String label;
  final String detail;
  final int pendingJobs;
  final int quarantinedJobs;
}

PrinterCanonicalStatus describeCanonicalPrinterStatus({
  required bool bridgeUp,
  bool? printerReachable,
  bool? serviceEnabled,
  bool? stationConsumerEnabled,
  int pendingJobs = 0,
  int quarantinedJobs = 0,
}) {
  final stationNote = stationConsumerEnabled == false
      ? ' Otomatik kuyruk tüketicisi kapalı; bu, yazıcının kapalı olduğu anlamına gelmez.'
      : '';
  final queueNote = pendingJobs > 0 || quarantinedJobs > 0
      ? ' Bekleyen $pendingJobs, karantina $quarantinedJobs.'
      : '';
  if (!bridgeUp && serviceEnabled != false) {
    // A bridge that does not answer is a connection fault. It is never shown
    // as "servis kapalı" or "durum bilinmiyor": the operator did not switch
    // anything off.
    return PrinterCanonicalStatus(
      bridgeUp: false,
      printerReachable: printerReachable,
      serviceEnabled: serviceEnabled,
      stationConsumerEnabled: stationConsumerEnabled,
      pendingJobs: pendingJobs,
      quarantinedJobs: quarantinedJobs,
      label: 'Yazıcı köprüsüne ulaşılamıyor',
      detail:
          'Bu cihazdaki yazıcı köprüsü yanıt vermiyor. Fiziksel baskı yapılamaz; siparişler kuyrukta korunur.$stationNote$queueNote',
    );
  }
  if (serviceEnabled != true) {
    final unknown = serviceEnabled == null;
    return PrinterCanonicalStatus(
      bridgeUp: bridgeUp,
      printerReachable: printerReachable,
      serviceEnabled: serviceEnabled,
      stationConsumerEnabled: stationConsumerEnabled,
      pendingJobs: pendingJobs,
      quarantinedJobs: quarantinedJobs,
      label: unknown
          ? 'Yazıcı servisi durumu bilinmiyor'
          : 'Yazıcı servisi kapalı',
      detail: unknown
          ? 'İzin okunamadı. Yeni fiziksel baskı gönderilmez.$stationNote$queueNote'
          : 'Yazıcı servisi kapalı. Köprü veya TCP yanıtı fiş gönderildiği anlamına gelmez.$stationNote$queueNote',
    );
  }
  if (!bridgeUp) {
    return PrinterCanonicalStatus(
      bridgeUp: false,
      printerReachable: printerReachable,
      serviceEnabled: true,
      stationConsumerEnabled: stationConsumerEnabled,
      pendingJobs: pendingJobs,
      quarantinedJobs: quarantinedJobs,
      label: 'Yazıcı köprüsüne ulaşılamıyor',
      detail:
          'Yazıcı servisi açık görünüyor fakat bu cihazdaki köprü yanıt vermiyor.$stationNote$queueNote',
    );
  }
  if (printerReachable == false) {
    return PrinterCanonicalStatus(
      bridgeUp: true,
      printerReachable: false,
      serviceEnabled: true,
      stationConsumerEnabled: stationConsumerEnabled,
      pendingJobs: pendingJobs,
      quarantinedJobs: quarantinedJobs,
      label: 'Yazıcıya ulaşılamıyor',
      detail:
          'Yazıcı servisi açık. Kayıtlı yazıcı adresine bağlantı kurulamadı.$stationNote$queueNote',
    );
  }
  if (printerReachable == null) {
    return PrinterCanonicalStatus(
      bridgeUp: true,
      printerReachable: null,
      serviceEnabled: true,
      stationConsumerEnabled: stationConsumerEnabled,
      pendingJobs: pendingJobs,
      quarantinedJobs: quarantinedJobs,
      label: 'Yazıcı servisi açık',
      detail:
          'İzin açık. Yazıcı adresi henüz doğrulanmadı. Bu, fişin basıldığı anlamına gelmez.$stationNote$queueNote',
    );
  }
  return PrinterCanonicalStatus(
    bridgeUp: true,
    printerReachable: true,
    serviceEnabled: true,
    stationConsumerEnabled: stationConsumerEnabled,
    pendingJobs: pendingJobs,
    quarantinedJobs: quarantinedJobs,
    label: 'Yazıcı servisi açık',
    detail:
        'İzin açık ve kayıtlı adrese bağlantı kuruldu. TCP yanıtı fişin çıktığını kanıtlamaz.$stationNote$queueNote',
  );
}

PrinterLinkStatus describePrinterLink({
  required bool bridgeUp,
  bool? printerReachable,
  bool? serviceEnabled,
  bool? stationConsumerEnabled,
}) {
  if (serviceEnabled != null || stationConsumerEnabled != null) {
    final status = describeCanonicalPrinterStatus(
      bridgeUp: bridgeUp,
      printerReachable: printerReachable,
      serviceEnabled: serviceEnabled,
      stationConsumerEnabled: stationConsumerEnabled,
    );
    return PrinterLinkStatus(
      bridgeUp: status.bridgeUp,
      printerReachable: status.printerReachable,
      label: status.label,
      detail: status.detail,
    );
  }
  if (!bridgeUp) {
    return const PrinterLinkStatus(
      bridgeUp: false,
      printerReachable: null,
      label: 'Servis yanıt vermiyor',
      detail:
          'Portun açık olması servisin çalıştığı anlamına gelmez. Kullanıcı müdahalesi gerekebilir.',
    );
  }
  if (printerReachable == null) {
    return const PrinterLinkStatus(
      bridgeUp: true,
      printerReachable: null,
      label: 'Kullanıcı müdahalesi gerekiyor',
      detail:
          'Yazıcı servisi yanıt verdi. Kayıtlı yazıcı bağlantısı henüz doğrulanmadı.',
    );
  }
  if (!printerReachable) {
    return const PrinterLinkStatus(
      bridgeUp: true,
      printerReachable: false,
      label: 'Yazıcı bağlantısı kesildi',
      detail:
          'Yazıcıya ulaşılamıyor. Ethernet kablosunu ve ağ bağlantısını kontrol edin.',
    );
  }
  return const PrinterLinkStatus(
    bridgeUp: true,
    printerReachable: true,
    label: 'Yazıcı hazır',
    detail:
        'Servis yanıt verdi ve kayıtlı yazıcı adresine bağlantı kuruldu. '
        'Bu, fişin basıldığı anlamına gelmez.',
  );
}

bool? _parsePrintBool(Object? raw) {
  if (raw is bool) return raw;
  if (raw == null) return null;
  final text = raw.toString().trim().toLowerCase();
  if (text == 'true' || text == '1' || text == 'yes' || text == 'on') {
    return true;
  }
  if (text == 'false' || text == '0' || text == 'no' || text == 'off') {
    return false;
  }
  return null;
}

/// Master permission from `/health`. `enabled` on the station block is the
/// consumer switch and is intentionally ignored here.
bool? printSystemEnabledFromHealth(Map<String, dynamic>? health) {
  if (health == null) return null;
  if (health.containsKey('print_system_enabled') ||
      health.containsKey('printSystemEnabled')) {
    return _parsePrintBool(
      health['print_system_enabled'] ?? health['printSystemEnabled'],
    );
  }
  final station = health['print_station'];
  if (station is Map) {
    final map = Map<String, dynamic>.from(station);
    final queue = map['queue'];
    final nested = queue is Map ? Map<String, dynamic>.from(queue) : map;
    if (nested.containsKey('print_system_enabled') ||
        nested.containsKey('printSystemEnabled')) {
      return _parsePrintBool(
        nested['print_system_enabled'] ?? nested['printSystemEnabled'],
      );
    }
  }
  return null;
}

bool? printStationConsumerEnabledFromHealth(Map<String, dynamic>? health) {
  if (health == null) return null;
  if (health.containsKey('print_station_enabled')) {
    return _parsePrintBool(health['print_station_enabled']);
  }
  final station = health['print_station'];
  if (station is! Map) return null;
  final map = Map<String, dynamic>.from(station);
  final queue = map['queue'];
  final nested = queue is Map ? Map<String, dynamic>.from(queue) : map;
  if (!nested.containsKey('enabled')) return null;
  return _parsePrintBool(nested['enabled']);
}

/// Last known master permission. Unknown does not allow a send.
class PhysicalPrintGate {
  static bool? allowed;
  static bool? cloudEnabled;
  static DateTime? cloudNotedAt;
  static DateTime? observedAt;
  static DateTime? suppressJobsCreatedBefore;
  static PrinterCanonicalStatus? published;

  /// The answer about the SAVED printers (the ones tickets are routed to),
  /// measured by the print hub for every screen. While it is fresh it is the
  /// only source of "is the printer reachable": a screen that probed some
  /// other address (the last one the bridge wrote to) cannot overrule it.
  static bool? savedPrintersReachable;
  static DateTime? savedPrintersCheckedAt;
  static const Duration savedPrintersVerdictTtl = Duration(minutes: 3);

  static void noteSavedPrinters(bool? reachable, {DateTime? now}) {
    savedPrintersReachable = reachable;
    savedPrintersCheckedAt = reachable == null ? null : (now ?? DateTime.now());
  }

  static bool? freshSavedPrintersVerdict({DateTime? now}) {
    final at = savedPrintersCheckedAt;
    if (savedPrintersReachable == null || at == null) return null;
    final age = (now ?? DateTime.now()).difference(at);
    return age > savedPrintersVerdictTtl ? null : savedPrintersReachable;
  }

  static void observe(bool? value, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    if (value == true && allowed == false) {
      suppressJobsCreatedBefore = clock;
    }
    allowed = value;
    observedAt = clock;
  }

  static void noteCloud(bool enabled) {
    cloudEnabled = enabled;
    cloudNotedAt = DateTime.now();
  }

  /// Cloud and the bridge are one permission. A local "off" is not reopened
  /// by a stale cloud "on". Unknown stays closed.
  static void noteAuthoritative(bool enabled) {
    noteCloud(enabled);
    if (!enabled) {
      observe(false);
    } else if (allowed != false) {
      observe(true);
    }
  }

  /// One label for every screen. A later health check that did not probe the
  /// printer keeps the last TCP result instead of pretending the printer is fine.
  static void publish({
    required bool bridgeUp,
    bool? printerReachable,
    bool? serviceEnabled,
    bool? stationConsumerEnabled,
    int pendingJobs = 0,
    int quarantinedJobs = 0,
    bool probedPrinter = false,
  }) {
    final previous = published;
    final saved = freshSavedPrintersVerdict();
    final next = describeCanonicalPrinterStatus(
      bridgeUp: bridgeUp,
      printerReachable: saved ??
          (probedPrinter
              ? printerReachable
              : (printerReachable ?? previous?.printerReachable)),
      serviceEnabled: serviceEnabled,
      stationConsumerEnabled:
          stationConsumerEnabled ?? previous?.stationConsumerEnabled,
      pendingJobs: pendingJobs,
      quarantinedJobs: quarantinedJobs,
    );
    published = next;
    if (previous == null ||
        previous.label != next.label ||
        previous.printerReachable != next.printerReachable ||
        previous.bridgeUp != next.bridgeUp ||
        previous.serviceEnabled != next.serviceEnabled) {
      changes.value += 1;
    }
  }

  /// Ticks when the published answer changes, whoever published it, so every
  /// indicator redraws together instead of at its own next poll.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static bool get allowsSend => allowed == true;

  /// Jobs created while the service was off are not printed when it opens.
  static bool shouldAutoDispatch({DateTime? createdAt}) {
    if (allowed != true) return false;
    final cutoff = suppressJobsCreatedBefore;
    if (cutoff == null) return true;
    if (createdAt == null) return false;
    return !createdAt.isBefore(cutoff);
  }

  static void resetForTests() {
    allowed = null;
    cloudEnabled = null;
    cloudNotedAt = null;
    observedAt = null;
    suppressJobsCreatedBefore = null;
    published = null;
    savedPrintersReachable = null;
    savedPrintersCheckedAt = null;
  }
}

/// One saved network printer a ticket can be routed to.
typedef SavedPrinterTarget = ({String host, int port, bool hasRole});

/// The addresses the readiness answer is about: saved network printers that
/// carry a kitchen/receipt role. When no saved printer has a role yet, every
/// saved network printer is asked. USB / system-queue printers have no
/// address to ask, so they are not part of this answer.
List<({String host, int port})> savedPrinterProbeTargets(
  Iterable<SavedPrinterTarget> printers,
) {
  final valid = printers
      .where((p) => p.host.trim().isNotEmpty && p.port > 0)
      .toList(growable: false);
  final routed = valid.where((p) => p.hasRole).toList(growable: false);
  final seen = <String>{};
  return <({String host, int port})>[
    for (final p in routed.isEmpty ? valid : routed)
      if (seen.add('${p.host.trim()}:${p.port}'))
        (host: p.host.trim(), port: p.port),
  ];
}

/// Opens and closes a connection to every target; nothing is printed.
/// Null: there is nothing to ask. False: at least one printer a ticket would
/// go to does not answer (asked twice, a first "no" on a quiet network is
/// not trusted). True: all of them answer.
Future<bool?> probeSavedPrinters(
  List<({String host, int port})> targets,
  Future<bool> Function(String host, int port) probe, {
  Duration retryDelay = const Duration(seconds: 1),
}) async {
  if (targets.isEmpty) return null;
  for (final target in targets) {
    var ok = await _askPrinter(probe, target.host, target.port);
    if (!ok) {
      await Future<void>.delayed(retryDelay);
      ok = await _askPrinter(probe, target.host, target.port);
    }
    if (!ok) return false;
  }
  return true;
}

Future<bool> _askPrinter(
  Future<bool> Function(String host, int port) probe,
  String host,
  int port,
) async {
  try {
    return await probe(host, port);
  } catch (_) {
    return false;
  }
}

int pendingJobsFromHealth(Map<String, dynamic>? health) {
  final queue = health?['queue'];
  if (queue is! Map) return 0;
  final depths = queue['queueDepthByPrinter'];
  if (depths is! Map) return 0;
  var sum = 0;
  for (final value in depths.values) {
    sum += value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  }
  return sum;
}

/// Host from the bridge health body. No print is sent to this address.
({String host, int port})? printerTargetFromHealth(Map<String, dynamic>? health) {
  if (health == null) return null;
  final last = health['last_kitchen_tcp'];
  if (last is Map) {
    final host = last['host']?.toString().trim() ?? '';
    final port = int.tryParse('${last['port']}') ?? 9100;
    if (host.isNotEmpty && port > 0) return (host: host, port: port);
  }
  final host = health['network_host']?.toString().trim() ?? '';
  if (host.isEmpty) return null;
  final port = int.tryParse('${health['network_port']}') ?? 9100;
  if (port <= 0) return null;
  return (host: host, port: port);
}

/// What the waiter may read. Exception class names stay out of this string.
String waiterFacingPrintError(Object error) {
  final raw = error.toString();
  final lower = raw.toLowerCase();
  if (lower.contains('print_outcome_unknown') ||
      lower.contains('timeoutexception') ||
      lower.contains('client_timeout') ||
      lower.contains('localprintserviceexception') ||
      lower.contains('baskı sonucu belirsiz') ||
      lower.contains('zaman asimina') ||
      lower.contains('zaman aşımına')) {
    return 'Sipariş kaydı baskıdan ayrıdır. Baskı sonucu belirsiz. '
        'Otomatik yeniden baskı yapılmadı.';
  }
  if (lower.contains('bridge_unreachable') ||
      lower.contains('connection refused') ||
      lower.contains('yazici servisine baglanilamadi')) {
    return 'Yazıcı servisine ulaşılamadı. Sipariş kaydı baskıdan ayrıdır.';
  }
  if (lower.contains('tcp_timeout') || lower.contains('tcp_refused')) {
    return 'Yazıcıya ulaşılamıyor. Ethernet kablosunu ve ağ bağlantısını kontrol edin. Fiş yeniden basılmadı.';
  }
  final cleaned = raw
      .replaceFirst('Exception: ', '')
      .replaceFirst('Bad state: ', '')
      .trim();
  if (cleaned.startsWith('LocalPrintServiceException') ||
      cleaned.startsWith('TimeoutException')) {
    return 'Baskı sonucu belirsiz. Otomatik yeniden baskı yapılmadı.';
  }
  return cleaned.isEmpty
      ? 'Fiş yazıcıya iletilemedi. Sipariş kaydı duruyor.'
      : cleaned;
}
