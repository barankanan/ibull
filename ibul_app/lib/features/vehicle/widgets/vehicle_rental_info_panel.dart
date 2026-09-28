import 'package:flutter/material.dart';

import '../domain/vehicle_detail_adapter.dart';
import '../models/vehicle_listing.dart';

/// Grouped rental facts: delivery / terms / fees. Only delivery rows are tappable.
class VehicleRentalInfoPanel extends StatelessWidget {
  const VehicleRentalInfoPanel({
    super.key,
    required this.listing,
    this.onSelectDelivery,
    this.compact = false,
  });

  final VehicleListing listing;
  final VoidCallback? onSelectDelivery;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final groups = VehicleDetailAdapter.rentalGroups(listing);
    if (groups.isEmpty) {
      return Text(
        'Kiralama bilgisi eklenmedi.',
        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          if (i > 0) SizedBox(height: compact ? 10 : 12),
          _GroupCard(
            group: groups[i],
            onSelectDelivery: onSelectDelivery,
            compact: compact,
          ),
        ],
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    this.onSelectDelivery,
    required this.compact,
  });

  final VehicleRentalInfoGroup group;
  final VoidCallback? onSelectDelivery;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(14, compact ? 10 : 12, 14, 8),
            child: Row(
              children: [
                Icon(group.icon, size: 16, color: const Color(0xFF673AB7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    group.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          for (var i = 0; i < group.rows.length; i++) ...[
            _InfoRow(
              row: group.rows[i],
              onTap: group.rows[i].interactive ? onSelectDelivery : null,
            ),
            if (i != group.rows.length - 1)
              Divider(
                height: 1,
                indent: 14,
                endIndent: 14,
                color: Colors.grey.shade100,
              ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.row, this.onTap});

  final VehicleRentalInfoRow row;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final interactive = row.interactive && onTap != null;
    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              row.label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              row.value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          if (interactive) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
          ],
        ],
      ),
    );
    if (!interactive) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: body),
    );
  }
}
