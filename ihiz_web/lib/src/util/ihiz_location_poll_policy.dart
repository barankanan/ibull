/// Web'de kurye konumu sabit aralıklı zamanlayıcıyla sorgulanır. Bu politika,
/// her zamanlayıcı tikinde gerçekten GPS sorgusu yapılıp yapılmayacağına karar
/// verir: aktif teslimatta sık, boşta/çevrimdışıyken seyrek sorgu yaparak pil
/// ve veri tüketimini azaltır. Ayrıca art arda başarısız sorguları sayar ki
/// arayüz eski "güncellendi" bilgisini göstermeye devam etmesin.
class IhizLocationPollPolicy {
  IhizLocationPollPolicy({
    this.activeDeliveryInterval = const Duration(seconds: 5),
    this.onlineIdleInterval = const Duration(seconds: 15),
    this.offlineInterval = const Duration(seconds: 60),
    this.staleFailureThreshold = 3,
  });

  final Duration activeDeliveryInterval;
  final Duration onlineIdleInterval;
  final Duration offlineInterval;

  /// Bu kadar art arda başarısız sorgudan sonra konum "bayat" sayılır.
  final int staleFailureThreshold;

  DateTime? _lastPollAt;
  int _consecutiveFailures = 0;

  int get consecutiveFailures => _consecutiveFailures;

  bool get isStale => _consecutiveFailures >= staleFailureThreshold;

  Duration intervalFor({
    required bool hasActiveDelivery,
    required bool courierOnline,
  }) {
    if (hasActiveDelivery) return activeDeliveryInterval;
    if (courierOnline) return onlineIdleInterval;
    return offlineInterval;
  }

  /// Sorgu yapılacaksa `true` döner ve sorgu zamanını kaydeder.
  bool shouldPoll({
    required DateTime now,
    required bool hasActiveDelivery,
    required bool courierOnline,
  }) {
    final last = _lastPollAt;
    if (last != null) {
      final elapsed = now.difference(last);
      final interval = intervalFor(
        hasActiveDelivery: hasActiveDelivery,
        courierOnline: courierOnline,
      );
      // Saat geri alınırsa (negatif süre) sorguyu engelleme.
      if (!elapsed.isNegative && elapsed < interval) return false;
    }
    _lastPollAt = now;
    return true;
  }

  void recordSuccess() {
    _consecutiveFailures = 0;
  }

  /// Konum tam bu çağrıyla "bayat" eşiğine ulaştıysa `true` döner; böylece
  /// uyarı her başarısız sorguda değil yalnızca bir kez gösterilir.
  bool recordFailure() {
    _consecutiveFailures += 1;
    return _consecutiveFailures == staleFailureThreshold;
  }
}
