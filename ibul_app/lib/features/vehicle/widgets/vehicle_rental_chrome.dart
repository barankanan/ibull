import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../widgets/optimized_image.dart';
import '../domain/vehicle_catalog.dart';
import '../models/vehicle_listing.dart';

const _months = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

String rentalDateLabel(DateTime value) {
  return '${value.day} ${_months[value.month - 1]} ${value.year}';
}

String rentalTimeLabel(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)}';
}

class VehicleRentalStepper extends StatelessWidget {
  const VehicleRentalStepper({
    super.key,
    required this.labels,
    required this.index,
  });

  final List<String> labels;
  final int index;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0)
              Container(
                width: compact ? 10 : 18,
                height: 1,
                color: i <= index ? AppColors.primary : AppColors.border,
              ),
            CircleAvatar(
              radius: 11,
              backgroundColor: i <= index ? AppColors.primary : AppColors.border,
              foregroundColor: i <= index ? Colors.white : AppColors.textGrey,
              child: Text(
                '${i + 1}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
            if (!compact || i == index) ...[
              const SizedBox(width: 6),
              Text(
                labels[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: i == index ? FontWeight.w800 : FontWeight.w600,
                  color: i == index ? AppColors.ink : AppColors.textGrey,
                ),
              ),
            ],
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class VehicleRentalSummaryPanel extends StatelessWidget {
  const VehicleRentalSummaryPanel({
    super.key,
    required this.listing,
    required this.pickup,
    required this.returnAt,
    required this.days,
    required this.rental,
    required this.delivery,
    required this.deposit,
    required this.total,
    this.deliveryText,
    this.pickupLabel,
    this.dropoffLabel,
    this.collapsed = false,
  });

  final VehicleListing listing;
  final DateTime pickup;
  final DateTime returnAt;
  final int days;
  final double rental;
  final double delivery;
  final double deposit;
  final double total;
  final String? deliveryText;
  final String? pickupLabel;
  final String? dropoffLabel;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 64,
                    height: 48,
                    child: listing.coverUrl == null || listing.coverUrl!.isEmpty
                        ? const ColoredBox(color: Color(0xFFF3F4F6))
                        : OptimizedImage(
                            imageUrlOrPath: listing.coverUrl!,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    listing.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${rentalDateLabel(pickup)} ${rentalTimeLabel(pickup)}  →  ${rentalDateLabel(returnAt)} ${rentalTimeLabel(returnAt)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
            ),
            Text('$days gün', style: const TextStyle(fontWeight: FontWeight.w700)),
            if (pickupLabel != null) Text('Teslim: $pickupLabel', style: const TextStyle(fontSize: 12)),
            if (dropoffLabel != null) Text('İade: $dropoffLabel', style: const TextStyle(fontSize: 12)),
            if (!collapsed) ...[
              const Divider(height: 24),
              _row('Kiralama', VehicleMoney.format(rental)),
              _row('Teslim', deliveryText ?? VehicleMoney.format(delivery)),
              _row('Depozito', '${VehicleMoney.format(deposit)}  ·  İade edilebilir'),
              const Divider(height: 24),
              _row('Toplam', VehicleMoney.format(total), bold: true),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class VehicleRentalErrorBanner extends StatelessWidget {
  const VehicleRentalErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class VehicleRentalSectionCard extends StatelessWidget {
  const VehicleRentalSectionCard({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
