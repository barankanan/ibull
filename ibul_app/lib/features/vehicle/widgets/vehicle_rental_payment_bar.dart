import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../domain/vehicle_rental_account.dart';
import '../models/vehicle_commerce.dart';

class VehicleRentalPaymentActionBar extends StatelessWidget {
  const VehicleRentalPaymentActionBar({
    super.key,
    required this.item,
    required this.now,
    required this.busy,
    required this.onPay,
    required this.onCancel,
  });

  final VehicleReservation item;
  final DateTime now;
  final bool busy;
  final VoidCallback onPay;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final canPay = VehicleRentalPaymentCopy.canPay(item, now: now);
    final paid = VehicleRentalPaymentCopy.isPaid(item.paymentStatus);
    final expired = VehicleRentalPaymentCopy.isExpired(item, now: now);
    final wide = MediaQuery.sizeOf(context).width >= 600;
    return Material(
      color: Colors.white,
      elevation: 10,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                paid
                    ? '✓ Ödeme tamamlandı'
                    : expired
                        ? 'Süresi doldu'
                        : VehicleRentalPaymentCopy.remainingLabel(
                            item.paymentDueAt,
                            now: now,
                          ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: paid ? AppColors.success : AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              if (canPay && wide)
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: busy ? null : onPay,
                        child: const Text('ÖDEME YAP'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: busy ? null : onCancel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                        ),
                        child: const Text('KİRALAMAYI İPTAL ET'),
                      ),
                    ),
                  ],
                )
              else if (canPay) ...[
                FilledButton(
                  onPressed: busy ? null : onPay,
                  child: const Text('ÖDEME YAP'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: busy ? null : onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                  child: const Text('KİRALAMAYI İPTAL ET'),
                ),
              ] else if (item.status.canCustomerCancel)
                OutlinedButton(
                  onPressed: busy ? null : onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                  child: Text(
                    item.status.blocksInventory
                        ? 'Rezervasyonu İptal Et'
                        : 'Kiralamayı İptal Et',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class VehicleRentalClock extends StatefulWidget {
  const VehicleRentalClock({super.key, required this.builder});

  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  State<VehicleRentalClock> createState() => _VehicleRentalClockState();
}

class _VehicleRentalClockState extends State<VehicleRentalClock> {
  late DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _now);
}
