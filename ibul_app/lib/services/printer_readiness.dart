/// One derived answer to "can this restaurant print right now?".
///
/// Every screen (the bottom-right chip, the printer center, the waiter page)
/// asks this function instead of reading its own flag. The inputs are the
/// facts the app already owns: the bridge health result, the saved printer
/// records, the master print permission, this device's print-center choice and
/// the last printer reachability probe. Nothing here stores state.
///
/// "Ready" is reached only when every prerequisite is verified. A green
/// bridge alone is not a printer, and a TCP connection alone is not a printed
/// receipt, so [PrinterReadiness.physicallyVerified] is carried separately.
library;

/// The bridge fact as the app sees it, independent of which service measured
/// it (the print hub and the lifecycle service each have their own enum).
enum ReadinessBridge { unknown, checking, online, offline, error }

enum PrinterReadinessLevel {
  /// The bridge is being checked.
  checking,

  /// The bridge does not answer (or its state is unknown).
  bridgeDown,

  /// The bridge answers but no printer is saved.
  noPrinter,

  /// The master print permission could not be read.
  serviceUnknown,

  /// The master print permission is off.
  serviceOff,

  /// This device only sends orders; another device prints.
  notPrintCenter,

  /// A saved printer address did not answer.
  unreachable,

  /// A printer is saved but its address was not probed yet.
  unverified,

  /// A printer answers but no kitchen/receipt role points at it.
  noStation,

  /// Every prerequisite is verified.
  ready,
}

class PrinterReadiness {
  const PrinterReadiness({
    required this.level,
    required this.chipLabel,
    required this.headline,
    required this.detail,
    required this.physicallyVerified,
  });

  final PrinterReadinessLevel level;

  /// Short text for the small status chip.
  final String chipLabel;

  /// One sentence for the printer center.
  final String headline;
  final String detail;

  /// True only after a real receipt was confirmed on paper.
  final bool physicallyVerified;

  bool get isReady => level == PrinterReadinessLevel.ready;

  /// Nothing may reach a physical printer from this device.
  bool get blocksPhysicalPrint =>
      level == PrinterReadinessLevel.bridgeDown ||
      level == PrinterReadinessLevel.serviceUnknown ||
      level == PrinterReadinessLevel.serviceOff ||
      level == PrinterReadinessLevel.notPrintCenter ||
      level == PrinterReadinessLevel.noPrinter;
}

PrinterReadiness describePrinterReadiness({
  required ReadinessBridge bridge,
  int? registeredPrinters,
  bool? serviceEnabled,
  bool? isPrintCenter,
  bool? printerReachable,
  int? stationAssignments,
  bool physicallyVerified = false,
  int pendingJobs = 0,
}) {
  PrinterReadiness make(
    PrinterReadinessLevel level,
    String chip,
    String headline,
    String detail,
  ) {
    final queue = pendingJobs > 0 ? ' Kuyrukta bekleyen: $pendingJobs.' : '';
    return PrinterReadiness(
      level: level,
      chipLabel: chip,
      headline: headline,
      detail: '$detail$queue',
      physicallyVerified: physicallyVerified,
    );
  }

  if (bridge == ReadinessBridge.checking) {
    return make(
      PrinterReadinessLevel.checking,
      'Kontrol…',
      'Yazıcı servisi kontrol ediliyor',
      'Köprü sağlık yanıtı bekleniyor.',
    );
  }
  if (bridge != ReadinessBridge.online) {
    final failed = bridge == ReadinessBridge.error;
    return make(
      PrinterReadinessLevel.bridgeDown,
      failed ? 'Yazıcı köprüsü hata' : 'Yazıcı köprüsü kapalı',
      failed ? 'Yazıcı köprüsü hata veriyor' : 'Yazıcı köprüsüne ulaşılamıyor',
      'Fiziksel baskı yapılamaz. Siparişler kuyrukta korunur.',
    );
  }
  if (registeredPrinters != null && registeredPrinters <= 0) {
    return make(
      PrinterReadinessLevel.noPrinter,
      'Yazıcı eklenmedi',
      'Yazıcı eklenmedi — Mutfak ve adisyon fişleri basılamaz',
      'Köprü çalışıyor ama kayıtlı yazıcı yok. Yazıcı Ekle ile bir yazıcı tanımlayın.',
    );
  }
  if (serviceEnabled == null) {
    return make(
      PrinterReadinessLevel.serviceUnknown,
      'Servis durumu bilinmiyor',
      'Yazıcı servisi durumu bilinmiyor',
      'Baskı izni okunamadı. Yeni fiziksel baskı gönderilmez.',
    );
  }
  if (!serviceEnabled) {
    return make(
      PrinterReadinessLevel.serviceOff,
      'Yazıcı servisi kapalı',
      'Yazıcı servisi kapalı',
      'Köprü çalışıyor ama baskı izni kapalı. Fiziksel fiş gönderilmez.',
    );
  }
  if (isPrintCenter == false) {
    return make(
      PrinterReadinessLevel.notPrintCenter,
      'Merkez cihaz basar',
      'Bu cihaz yalnızca sipariş gönderir',
      'Fişleri yazıcı merkezi olan cihaz basar. Bu cihazdan fiziksel baskı yapılmaz.',
    );
  }
  if (stationAssignments != null && stationAssignments <= 0) {
    return make(
      PrinterReadinessLevel.noStation,
      'Yazıcı rolü atanmadı',
      'Mutfak/adisyon yazıcısı atanmadı',
      'Yazıcı kayıtlı ama mutfak veya adisyon rolü atanmadığı için fişler yönlenemez. Yazıcıya bir rol atayın.',
    );
  }
  if (printerReachable == false) {
    return make(
      PrinterReadinessLevel.unreachable,
      'Yazıcıya ulaşılamıyor',
      'Yazıcıya ulaşılamıyor',
      'Kayıtlı yazıcı adresi yanıt vermiyor. Kabloyu, IP adresini ve yazıcının açık olduğunu kontrol edin.',
    );
  }
  if (printerReachable == null) {
    return make(
      PrinterReadinessLevel.unverified,
      'Yazıcı doğrulanmadı',
      'Yazıcı bağlantısı henüz doğrulanmadı',
      'Yazıcı kayıtlı ama adresine ulaşıldığı doğrulanmadı.',
    );
  }
  return make(
    PrinterReadinessLevel.ready,
    'Yazıcı Hazır',
    'Yazıcı hazır',
    physicallyVerified
        ? 'Köprü, izin, yazıcı ve istasyon doğrulandı; fiziksel baskı doğrulandı.'
        : 'Bağlantı başarılı, baskı henüz doğrulanmadı. Köprü, izin, yazıcı ve istasyon doğrulandı.',
  );
}
