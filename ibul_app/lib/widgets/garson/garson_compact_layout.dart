import 'package:flutter/material.dart';

/// Garson board uses compact density on mobile and tablet widths.
const double kGarsonCompactLayoutMaxWidth = 900;

bool isGarsonCompactLayout(double width) => width < kGarsonCompactLayoutMaxWidth;

/// Thin area filter row for compact garson board header.
class GarsonAreaFilterCompact extends StatelessWidget {
  const GarsonAreaFilterCompact({
    super.key,
    required this.selectedKey,
    required this.options,
    required this.onChanged,
  });

  final String selectedKey;
  final List<({String key, String label})> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeKey = options.any((o) => o.key == selectedKey)
        ? selectedKey
        : 'all';

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.map_outlined, size: 15, color: Color(0xFF64748B)),
          const SizedBox(width: 6),
          const Text(
            'Alan:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isDense: true,
                isExpanded: true,
                value: safeKey,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: Color(0xFF94A3B8),
                ),
                items: options
                    .map(
                      (o) => DropdownMenuItem<String>(
                        value: o.key,
                        child: Text(
                          o.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  final next = (value ?? 'all').trim();
                  if (next.isEmpty) return;
                  onChanged(next);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single-line summary for compact garson board header.
class GarsonCompactStatsRow extends StatelessWidget {
  const GarsonCompactStatsRow({
    super.key,
    required this.totalTables,
    required this.occupiedTables,
    required this.newCount,
  });

  final int totalTables;
  final int occupiedTables;
  final int newCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, top: 2),
      child: Text(
        '$totalTables masa · $occupiedTables dolu · $newCount yeni',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700,
          height: 1.2,
        ),
      ),
    );
  }
}

/// Compact area section header above grouped table grids.
class GarsonAreaSectionHeaderCompact extends StatelessWidget {
  const GarsonAreaSectionHeaderCompact({
    super.key,
    required this.areaName,
    required this.totalCount,
    required this.occupiedCount,
  });

  final String areaName;
  final int totalCount;
  final int occupiedCount;

  @override
  Widget build(BuildContext context) {
    final emptyCount = (totalCount - occupiedCount).clamp(0, totalCount);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            areaName.toUpperCase(),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$totalCount masa · $occupiedCount dolu · $emptyCount boş',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
