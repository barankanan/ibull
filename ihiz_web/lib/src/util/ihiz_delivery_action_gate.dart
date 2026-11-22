/// Kurye teslimat aksiyonlarının (teslim alma / teslim etme / iptal) aynı anda
/// yalnızca bir kez çalışmasını sağlar. Çift dokunuş veya yavaş ağda tekrar
/// basma, sunucuya mükerrer durum geçişi, geçmiş kaydı ve bildirim yazmasın.
class IhizDeliveryActionGate {
  bool _busy = false;

  bool get isBusy => _busy;

  /// Başka bir aksiyon sürüyorsa [action] çalıştırılmaz ve `null` döner.
  Future<T?> runExclusive<T extends Object>(Future<T> Function() action) async {
    if (_busy) return null;
    _busy = true;
    try {
      return await action();
    } finally {
      _busy = false;
    }
  }
}
