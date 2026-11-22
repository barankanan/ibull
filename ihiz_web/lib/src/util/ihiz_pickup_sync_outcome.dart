/// Kuryenin "paketi teslim al" aksiyonunda sunucu yazımının sonucu.
///
/// Arayüz teslimatı iyimser olarak aktif yapar. Sunucu yazımı kesin olarak
/// uygulanmadıysa yerel aktif teslimat geri alınmalıdır; aksi halde kurye
/// sunucuda hiç başlamamış "hayalet" bir teslimata kilitlenir.
enum IhizPickupSyncOutcome {
  /// Sipariş kimliği yok (yalnızca yerel akış); sunucuya yazılacak bir şey yok.
  localOnly,

  /// `order_items` durumu sunucuda güncellendi (yan adımlar başarısız olsa da).
  committed,

  /// Sunucu yazımı kesin olarak uygulanmadı (yetki reddi veya doğrulama
  /// okumasında durumun değişmediği görüldü).
  notApplied,

  /// Ağ hatası: yazımın uygulanıp uygulanmadığı doğrulanamadı.
  unverified;

  /// Yerel aktif teslimat korunmalı mı?
  ///
  /// [unverified] durumunda korunur: yazım uygulanmış olabilir ve geri almak
  /// paketi sunucuda sahipsiz "yolda" bırakabilir.
  bool get keepsActiveDelivery => this != IhizPickupSyncOutcome.notApplied;
}

/// Kurye havuzundaki normal (iade olmayan) bir paketin teslim alınabilmesi için
/// `order_items.status` değerinin sunucuda hâlâ bu olması gerekir. Teslim alma
/// güncellemesi bu koşulla yapılır; böylece iki kurye aynı paketi aynı anda
/// teslim alamaz (ikincinin güncellemesi hiçbir satırı etkilemez).
const String ihizPickupReadyStatus = 'ready_to_ship';

/// Koşullu teslim alma güncellemesi hiçbir satırı etkilemediğinde nedeni ayırır.
///
/// [currentStatus]: güncelleme sonrası sunucudan okunan `order_items.status`
/// (okunamadıysa veya satır görünmüyorsa `null`). `true` dönerse paket artık
/// havuzda değildir (başka kurye aldı ya da satıcı/müşteri durumu değiştirdi);
/// `false` ise neden bilinmiyor veya yetki reddidir.
bool isPickupLostToStatusChange(String? currentStatus) {
  final status = currentStatus?.trim().toLowerCase() ?? '';
  return status.isNotEmpty && status != ihizPickupReadyStatus;
}

/// Birincil yazım (`order_items` güncellemesi) tamamlanmadan hata alındığında
/// sonucu belirler.
///
/// [serverRejected]: sunucu isteği açıkça reddetti (PostgREST hatası veya
/// güncellenen satır yok). [verifiedStatus]: hata sonrası sunucudan okunan
/// güncel `order_items.status`; okunamadıysa `null`.
IhizPickupSyncOutcome resolveFailedPickupOutcome({
  required bool serverRejected,
  required bool isReturnPickup,
  String? verifiedStatus,
}) {
  if (serverRejected) return IhizPickupSyncOutcome.notApplied;
  final status = verifiedStatus?.trim().toLowerCase() ?? '';
  if (status.isEmpty) return IhizPickupSyncOutcome.unverified;
  final pickedUpStatus = isReturnPickup
      ? 'return_shipped_back'
      : 'out_for_delivery';
  return status == pickedUpStatus
      ? IhizPickupSyncOutcome.committed
      : IhizPickupSyncOutcome.notApplied;
}

/// Normal (iade olmayan) bir teslimatın "teslim edildi" olarak yazılmasını
/// engelleyen `order_items.status` değerleri: sipariş zaten sonlanmış
/// (teslim/iptal/iade edilmiş) ya da iade akışına girmiştir. Teslim etme
/// güncellemesi bu durumların üzerine yazmaz; böylece iptal veya iade edilmiş
/// bir sipariş kurye tarafından yeniden "teslim edildi" yapılamaz.
const List<String> ihizDeliveryBlockedStatuses = <String>[
  'delivered',
  'cancelled',
  'return_requested',
  'return_approved',
  'return_shipped_back',
  'return_received',
  'returned',
  'refunded',
];

/// [ihizDeliveryBlockedStatuses] için PostgREST `not.in` filtre değeri.
String get ihizDeliveryBlockedStatusFilter =>
    '(${ihizDeliveryBlockedStatuses.map((s) => '"$s"').join(',')})';

/// Koşullu "teslim edildi" güncellemesi hiçbir satırı etkilemediğinde neden.
enum IhizDeliveryConflict {
  /// Kalem sunucuda zaten `delivered`: tekrar/yanıtı kaybolmuş istek. Teslimat
  /// başarılı sayılır, durum yeniden yazılmaz.
  alreadyDelivered,

  /// Sipariş iptal/iade edilmiş: teslim kaydedilemez, yerel teslimat kapatılır.
  orderClosed,

  /// Durum okunamadı veya engelleyen bir durum değil (ör. yetki reddi).
  unknown,
}

/// [currentStatus]: güncelleme sonrası sunucudan okunan `order_items.status`
/// (okunamadıysa veya satır görünmüyorsa `null`).
IhizDeliveryConflict resolveDeliveryConflict(String? currentStatus) {
  final status = currentStatus?.trim().toLowerCase() ?? '';
  if (status == 'delivered') return IhizDeliveryConflict.alreadyDelivered;
  if (ihizDeliveryBlockedStatuses.contains(status)) {
    return IhizDeliveryConflict.orderClosed;
  }
  return IhizDeliveryConflict.unknown;
}

/// Kurye "paketi iptal et" güncellemesi de [ihizDeliveryBlockedStatuses]
/// koşuluyla yazılır: teslim edilmiş, zaten iptal edilmiş veya iade sürecindeki
/// bir kalemin üzerine `cancelled` yazılmaz. Koşullu güncelleme hiçbir satırı
/// etkilemediğinde kuryeye gösterilecek metni döndürür.
///
/// [currentStatus]: güncelleme sonrası sunucudan okunan `order_items.status`.
/// `null` dönerse sipariş sonlanmış değildir (neden bilinmiyor / yetki reddi);
/// çağıran eski hata yolunu kullanmalıdır.
String? ihizCancelBlockedMessage(String? currentStatus) {
  switch (resolveDeliveryConflict(currentStatus)) {
    case IhizDeliveryConflict.alreadyDelivered:
      return 'Bu sipariş teslim edilmiş olarak kayıtlı; iptal kaydedilmedi. '
          'Teslimat kapatıldı.';
    case IhizDeliveryConflict.orderClosed:
      return 'Bu sipariş zaten iptal edilmiş veya iade sürecine alınmış; '
          'iptal yeniden kaydedilmedi. Teslimat kapatıldı.';
    case IhizDeliveryConflict.unknown:
      return null;
  }
}
