import '../models/vehicle_commerce.dart';
import '../models/vehicle_enums.dart';
import 'vehicle_catalog.dart';
import 'vehicle_pricing.dart';

extension VehicleReservationInventory on VehicleReservationStatus {
  /// Confirmed inventory only. Draft/pending/cancelled never lock dates.
  bool get blocksInventory =>
      this == VehicleReservationStatus.confirmed ||
      this == VehicleReservationStatus.reserved ||
      this == VehicleReservationStatus.activeRental ||
      this == VehicleReservationStatus.returnPending;

  bool get isAccountVisible => this != VehicleReservationStatus.pendingDocs;

  bool get canCustomerCancel =>
      this == VehicleReservationStatus.pendingDocs ||
      this == VehicleReservationStatus.pendingSellerReview ||
      this == VehicleReservationStatus.pendingPayment ||
      this == VehicleReservationStatus.confirmed ||
      this == VehicleReservationStatus.reserved;

  bool get isOpenPaymentWindow =>
      this == VehicleReservationStatus.pendingPayment;

  String get ordersStatusType {
    switch (this) {
      case VehicleReservationStatus.completed:
        return 'teslim';
      case VehicleReservationStatus.cancelled:
      case VehicleReservationStatus.rejected:
      case VehicleReservationStatus.sellerCancelled:
        return 'iptal';
      case VehicleReservationStatus.refundPending:
        return 'iade';
      default:
        return 'devam';
    }
  }
}

abstract final class VehicleRentalPaymentCopy {
  static String statusLabel(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'paid':
      case 'authorized':
        return 'Ödendi';
      case 'failed':
        return 'Ödeme başarısız';
      case 'refunded':
      case 'partially_refunded':
        return 'İade edildi';
      case 'refund_pending':
        return 'İade bekleniyor';
      case 'pending':
      case 'unpaid':
      case '':
        return 'Ödeme bekleniyor';
      default:
        return 'Ödeme bekleniyor';
    }
  }

  static bool isPaid(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    return value == 'paid' || value == 'authorized';
  }

  static bool canPay(VehicleReservation item, {DateTime? now}) {
    if (!item.status.isOpenPaymentWindow) return false;
    if (isPaid(item.paymentStatus)) return false;
    final due = item.paymentDueAt;
    if (due == null) return true;
    return !(now ?? DateTime.now()).toUtc().isAfter(due.toUtc());
  }

  static bool isExpired(VehicleReservation item, {DateTime? now}) {
    if (isPaid(item.paymentStatus)) return false;
    if (item.status == VehicleReservationStatus.cancelled &&
        item.cancelReason == 'payment_window_expired') {
      return true;
    }
    if (!item.status.isOpenPaymentWindow) return false;
    final due = item.paymentDueAt;
    if (due == null) return false;
    return !(now ?? DateTime.now()).toUtc().isBefore(due.toUtc());
  }

  static String remainingLabel(DateTime? due, {DateTime? now}) {
    if (due == null) return '';
    var left = due.toUtc().difference((now ?? DateTime.now()).toUtc());
    if (left.isNegative) return 'Süresi doldu';
    final hours = left.inHours;
    final minutes = left.inMinutes.remainder(60);
    final seconds = left.inSeconds.remainder(60);
    String two(int n) => n.toString().padLeft(2, '0');
    if (hours >= 1) {
      return 'Ödeme için ${two(hours)}:${two(minutes)}:${two(seconds)} kaldı';
    }
    return 'Ödeme için ${two(minutes)}:${two(seconds)} kaldı';
  }
}

abstract final class VehicleRentalAccountFeed {
  static const _months = [
    'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];

  static Map<String, dynamic> toOrderCard(VehicleReservation item) {
    final days = VehicleRentalPricing.rentalDays(
      pickupAt: item.pickupAt,
      returnAt: item.returnAt,
    );
    return {
      'recordType': 'vehicle_rental',
      'reservationId': item.id,
      'date': '${_short(item.pickupAt)} → ${_short(item.returnAt)}',
      'itemCount': days,
      'productName': item.listingTitle ?? item.rentalCode ?? 'Araç kiralama',
      'statusText': item.status.labelTr,
      'statusType': item.status.ordersStatusType,
      'totalPrice': VehicleMoney.format(item.total),
      'dateGroup': _dateGroup(item.pickupAt),
      'productImage': item.listingCoverUrl,
      'sortAt': item.pickupAt,
      'rentalCode': item.rentalCode,
      'rentalDays': days,
      'reservation': item,
      'paymentHint': VehicleRentalPaymentCopy.canPay(item)
          ? VehicleRentalPaymentCopy.remainingLabel(item.paymentDueAt)
          : VehicleRentalPaymentCopy.isExpired(item)
              ? 'Süresi doldu'
              : VehicleRentalPaymentCopy.isPaid(item.paymentStatus)
                  ? 'Ödendi'
                  : null,
    };
  }

  static String _short(DateTime value) =>
      '${value.day} ${_months[value.month - 1]}';

  static String _dateGroup(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month) return 'Bu Ay';
    return '${date.month}.${date.year}';
  }
}
