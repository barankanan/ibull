import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../widgets/optimized_image.dart';
import '../domain/vehicle_catalog.dart';
import '../domain/vehicle_pricing.dart';
import '../domain/vehicle_rental_account.dart';
import '../models/vehicle_commerce.dart';
import '../models/vehicle_enums.dart';
import '../widgets/vehicle_rental_chrome.dart';

class VehicleRentalBookingCard extends StatelessWidget {
  const VehicleRentalBookingCard({
    super.key,
    required this.item,
    this.title,
    this.coverUrl,
    this.onDetail,
    this.onApprove,
    this.onReject,
    this.onCancel,
    this.onHandover,
    this.docsReady = false,
  });

  final VehicleReservation item;
  final String? title;
  final String? coverUrl;
  final VoidCallback? onDetail;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onCancel;
  final VoidCallback? onHandover;
  final bool docsReady;

  @override
  Widget build(BuildContext context) {
    final days = VehicleRentalPricing.rentalDays(
      pickupAt: item.pickupAt,
      returnAt: item.returnAt,
    );
    final name = title ?? item.listingTitle ?? item.customerName ?? item.status.labelTr;
    final photo = coverUrl ?? item.listingCoverUrl;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 72,
                    height: 52,
                    child: photo == null || photo.isEmpty
                        ? const ColoredBox(color: Color(0xFFF3F4F6))
                        : OptimizedImage(imageUrlOrPath: photo, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        item.status.labelTr,
                        style: const TextStyle(fontSize: 12, color: AppColors.primary),
                      ),
                      if (item.rentalCode != null)
                        Text(
                          item.rentalCode!,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (item.customerName != null)
              Text('Müşteri: ${item.customerName}', maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              '${rentalDateLabel(item.pickupAt)} – ${rentalDateLabel(item.returnAt)}  ·  $days gün',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text('Teslim: ${item.deliveryMode.wire.replaceAll('_', ' ')}'),
            Text(
              'Toplam  ${VehicleMoney.format(item.total)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              VehicleRentalPaymentCopy.isPaid(item.paymentStatus)
                  ? 'Ödeme: ✓ Tamamlandı'
                  : VehicleRentalPaymentCopy.isExpired(item)
                      ? 'Süresi doldu'
                      : VehicleRentalPaymentCopy.canPay(item)
                          ? VehicleRentalPaymentCopy.remainingLabel(
                              item.paymentDueAt,
                            )
                          : 'Ödeme: ${VehicleRentalPaymentCopy.statusLabel(item.paymentStatus)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
            ),
            Text(
              docsReady ? 'Belge: ✓ Yüklendi' : 'Belge: kontrol edin',
              style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (onDetail != null)
                  OutlinedButton(onPressed: onDetail, child: const Text('Detay')),
                if (onApprove != null)
                  FilledButton(onPressed: onApprove, child: const Text('Onayla')),
                if (onReject != null)
                  OutlinedButton(onPressed: onReject, child: const Text('Reddet')),
                if (onCancel != null)
                  TextButton(onPressed: onCancel, child: const Text('İptal Et')),
                if (onHandover != null)
                  FilledButton(onPressed: onHandover, child: const Text('Aracı Teslim Et')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
