class IhizDeliveryStatus {
  const IhizDeliveryStatus._();

  static const created = 'created';
  static const preparing = 'preparing';
  static const readyForPickup = 'ready_for_pickup';
  static const courierAssigned = 'courier_assigned';
  static const courierPickedUp = 'courier_picked_up';
  static const inTransit = 'in_transit';
  static const delivered = 'delivered';
  static const cancelled = 'cancelled';

  static const List<String> timelineOrder = <String>[
    created,
    preparing,
    readyForPickup,
    courierAssigned,
    courierPickedUp,
    inTransit,
    delivered,
  ];

  static const Set<String> liveStatuses = <String>{
    courierPickedUp,
    inTransit,
    'out_for_delivery',
  };

  static const Set<String> terminalStatuses = <String>{
    delivered,
    cancelled,
  };

  static String normalize(String? raw) => (raw ?? '').trim().toLowerCase();

  static bool isLive(String? raw) => liveStatuses.contains(normalize(raw));

  static bool isTerminal(String? raw) =>
      terminalStatuses.contains(normalize(raw));

  static String fromIbulItemStatus(String? raw) {
    switch (normalize(raw)) {
      case 'new':
      case 'confirmed':
        return created;
      case 'preparing':
        return preparing;
      case 'ready_to_ship':
        return readyForPickup;
      case 'out_for_delivery':
      case 'shipped':
        return courierPickedUp;
      case 'delivered':
        return delivered;
      case 'cancelled':
      case 'canceled':
        return cancelled;
      default:
        return created;
    }
  }

  static String label(String? raw) {
    switch (normalize(raw)) {
      case created:
        return 'Sipariş oluşturuldu';
      case preparing:
        return 'Paket hazırlanıyor';
      case readyForPickup:
        return 'Kurye bekleniyor';
      case courierAssigned:
        return 'Kurye atandı';
      case courierPickedUp:
        return 'Kuryeye teslim edildi';
      case inTransit:
      case 'out_for_delivery':
        return 'Teslimat yapılıyor';
      case delivered:
        return 'Teslim edildi';
      case cancelled:
        return 'Bu teslimat iptal edildi.';
      default:
        return 'Teslimat takip ediliyor';
    }
  }

  static String friendlyMessage(String? raw) {
    switch (normalize(raw)) {
      case created:
      case preparing:
        return 'Kurye atanması bekleniyor.';
      case readyForPickup:
        return 'Kurye atanması bekleniyor.';
      case courierAssigned:
        return 'Kurye hazırlanıyor.';
      case courierPickedUp:
      case inTransit:
        return 'Teslimatınız yolda.';
      case delivered:
        return 'Teslimat tamamlandı.';
      case cancelled:
        return 'Bu teslimat iptal edildi.';
      default:
        return 'Teslimat durumu güncelleniyor.';
    }
  }
}
