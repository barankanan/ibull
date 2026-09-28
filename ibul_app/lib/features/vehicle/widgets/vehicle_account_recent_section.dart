import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../widgets/optimized_image.dart';
import '../domain/vehicle_catalog.dart';
import '../domain/vehicle_pricing.dart';
import '../domain/vehicle_rental_account.dart';
import '../models/vehicle_commerce.dart';
import '../models/vehicle_enums.dart';
import '../screens/vehicle_rental_detail_page.dart';
import '../services/vehicle_service.dart';
import '../widgets/vehicle_rental_chrome.dart';

class VehicleAccountRecentSection extends StatefulWidget {
  const VehicleAccountRecentSection({super.key});

  @override
  State<VehicleAccountRecentSection> createState() =>
      _VehicleAccountRecentSectionState();
}

class _VehicleAccountRecentSectionState
    extends State<VehicleAccountRecentSection> {
  List<VehicleReservation> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await VehicleService.instance.reservations.listMine(
      asSeller: false,
    );
    if (!mounted) return;
    setState(() {
      _items = items.where((row) => row.status.isAccountVisible).take(3).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        const Text(
          'Son Kiralamalar',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),
        for (final item in _items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  final changed = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VehicleRentalDetailPage(reservation: item),
                    ),
                  );
                  if (changed == true) await _load();
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 64,
                          height: 48,
                          child: (item.listingCoverUrl ?? '').isEmpty
                              ? const ColoredBox(color: Color(0xFFF3F4F6))
                              : OptimizedImage(
                                  imageUrlOrPath: item.listingCoverUrl!,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.listingTitle ?? item.rentalCode ?? 'Araç kiralama',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const Text(
                              'Araç Kiralama',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              '${rentalDateLabel(item.pickupAt)} → ${rentalDateLabel(item.returnAt)}'
                              '  ·  ${VehicleRentalPricing.rentalDays(pickupAt: item.pickupAt, returnAt: item.returnAt)} gün',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              item.rentalCode == null
                                  ? item.status.labelTr
                                  : '${item.rentalCode}  ·  ${item.status.labelTr}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (VehicleRentalPaymentCopy.canPay(item) ||
                                VehicleRentalPaymentCopy.isExpired(item))
                              Text(
                                VehicleRentalPaymentCopy.canPay(item)
                                    ? VehicleRentalPaymentCopy.remainingLabel(
                                        item.paymentDueAt,
                                      )
                                    : 'Süresi doldu',
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        VehicleMoney.format(item.total),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
