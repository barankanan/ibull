part of '../../main.dart';

class _Metric {
  const _Metric(
    this.title,
    this.value,
    this.caption, {
    required this.icon,
    required this.accent,
    this.onTap,
  });

  final String title;
  final String value;
  final String caption;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;
}

class _AccountSetting {
  const _AccountSetting(this.title, this.caption, this.icon);

  final String title;
  final String caption;
  final IconData icon;
}

enum _EarningsRange { weekly, monthly }

class _CourierDailyEarning {
  const _CourierDailyEarning({
    required this.date,
    required this.amount,
    required this.completedDeliveries,
  });

  final DateTime date;
  final double amount;
  final int completedDeliveries;
}

class _MapNodeLayout {
  const _MapNodeLayout({
    required this.storeAlignment,
    required this.courierAlignment,
    required this.customerAlignment,
    required this.zoneLabel,
    required this.demandLabel,
    required this.storePoint,
    required this.courierPoint,
    required this.customerPoint,
  });

  final Alignment storeAlignment;
  final Alignment courierAlignment;
  final Alignment customerAlignment;
  final String zoneLabel;
  final String demandLabel;
  final LatLng storePoint;
  final LatLng courierPoint;
  final LatLng customerPoint;
}

class _RegisteredStoreData {
  const _RegisteredStoreData({
    required this.id,
    required this.name,
    required this.address,
    required this.cityLabel,
    required this.point,
    this.customerPoint,
    required this.accent,
    required this.taskTitle,
    required this.customerName,
    required this.customerAddress,
    this.regionLabel = 'Genel',
    this.regionKey = 'genel',
    required this.storePhone,
    required this.customerPhone,
    required this.deliveryCode,
    this.orderItemId,
    this.orderId,
    this.sellerId,
    this.customerId,
    this.orderNumber,
    this.trackingCode,
    this.productName,
    this.returnRequestId,
    this.buyerPickupNote,
    this.pickupWindowStart,
    this.pickupWindowEnd,
    this.isReturnPickup = false,
    required this.earning,
    required this.earningBreakdown,
    required this.eta,
    required this.route,
    required this.label,
    required this.tags,
    required this.isRequestingCourier,
  });

  final String id;
  final String name;
  final String address;
  final String cityLabel;
  final LatLng point;
  final LatLng? customerPoint;
  final Color accent;
  final String taskTitle;
  final String customerName;
  final String customerAddress;
  final String regionLabel;
  final String regionKey;
  final String storePhone;
  final String customerPhone;
  final String deliveryCode;
  final String? orderItemId;
  final String? orderId;
  final String? sellerId;
  final String? customerId;
  final String? orderNumber;
  final String? trackingCode;
  final String? productName;
  final String? returnRequestId;
  final String? buyerPickupNote;
  final DateTime? pickupWindowStart;
  final DateTime? pickupWindowEnd;
  final bool isReturnPickup;
  final String earning;
  final _CourierEarningBreakdown earningBreakdown;
  final String eta;
  final String route;
  final String label;
  final List<String> tags;
  final bool isRequestingCourier;
}

class _LiveStoreMarker {
  const _LiveStoreMarker({
    required this.id,
    required this.name,
    required this.point,
    required this.isOpen,
  });

  final String id;
  final String name;
  final LatLng point;
  final bool isOpen;
}

class _OrderCardData {
  const _OrderCardData({
    required this.title,
    required this.storeName,
    required this.storeAddress,
    required this.storePhone,
    required this.customerName,
    required this.customerAddress,
    this.regionLabel = 'Genel',
    this.regionKey = 'genel',
    required this.customerPhone,
    required this.deliveryCode,
    this.orderItemId,
    this.orderId,
    this.sellerId,
    this.customerId,
    this.orderNumber,
    this.trackingCode,
    this.productName,
    this.returnRequestId,
    this.buyerPickupNote,
    this.pickupWindowStart,
    this.pickupWindowEnd,
    this.isReturnPickup = false,
    required this.earning,
    required this.earningBreakdown,
    required this.eta,
    required this.route,
    required this.label,
    required this.accent,
    required this.tags,
  });

  final String title;
  final String storeName;
  final String storeAddress;
  final String storePhone;
  final String customerName;
  final String customerAddress;
  final String regionLabel;
  final String regionKey;
  final String customerPhone;
  final String deliveryCode;
  final String? orderItemId;
  final String? orderId;
  final String? sellerId;
  final String? customerId;
  final String? orderNumber;
  final String? trackingCode;
  final String? productName;
  final String? returnRequestId;
  final String? buyerPickupNote;
  final DateTime? pickupWindowStart;
  final DateTime? pickupWindowEnd;
  final bool isReturnPickup;
  final String earning;
  final _CourierEarningBreakdown earningBreakdown;
  final String eta;
  final String route;
  final String label;
  final Color accent;
  final List<String> tags;
}

class _CourierPoolOrder {
  const _CourierPoolOrder({
    required this.orderItemId,
    required this.orderId,
    required this.sellerId,
    required this.customerId,
    required this.orderNumber,
    required this.productName,
    required this.productImageUrl,
    required this.storeName,
    required this.storeAddress,
    required this.storePhone,
    required this.storePoint,
    required this.customerName,
    required this.customerAddress,
    required this.customerPhone,
    required this.customerPoint,
    required this.regionLabel,
    required this.regionCity,
    required this.regionKey,
    required this.trackingCode,
    required this.deliveryCode,
    required this.earning,
    required this.earningBreakdown,
    required this.eta,
    required this.route,
    required this.createdAt,
    this.returnRequestId,
    this.buyerPickupNote,
    this.pickupWindowStart,
    this.pickupWindowEnd,
    this.isReturnPickup = false,
  });

  final String orderItemId;
  final String orderId;
  final String sellerId;
  final String customerId;
  final String orderNumber;
  final String productName;
  final String productImageUrl;
  final String storeName;
  final String storeAddress;
  final String storePhone;
  final LatLng storePoint;
  final String customerName;
  final String customerAddress;
  final String customerPhone;
  final LatLng customerPoint;
  final String regionLabel;
  final String regionCity;
  final String regionKey;
  final String trackingCode;
  final String deliveryCode;
  final String earning;
  final _CourierEarningBreakdown earningBreakdown;
  final String eta;
  final String route;
  final DateTime createdAt;
  final String? returnRequestId;
  final String? buyerPickupNote;
  final DateTime? pickupWindowStart;
  final DateTime? pickupWindowEnd;
  final bool isReturnPickup;
}

class _CourierEarningBreakdown {
  const _CourierEarningBreakdown({
    required this.distanceKm,
    required this.baseFee,
    required this.perKmFee,
    required this.distanceFee,
    required this.distanceBasedFee,
    required this.etaMinutes,
    required this.minutePrice,
    required this.etaBasedFee,
    required this.nightBonus,
    required this.rainBonus,
    required this.platformFee,
    required this.deliveryTotal,
    required this.total,
  });

  final double distanceKm;
  final double baseFee;
  final double perKmFee;
  final double distanceFee;
  final double distanceBasedFee;
  final double etaMinutes;
  final double minutePrice;
  final double etaBasedFee;
  final double nightBonus;
  final double rainBonus;
  final double platformFee;
  final double deliveryTotal;
  final double total;
}
