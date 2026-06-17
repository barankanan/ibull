import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../models/order_history_models.dart';

class OrderHistoryFilterBar extends StatelessWidget {
  const OrderHistoryFilterBar({
    super.key,
    required this.filter,
    required this.years,
    required this.onChanged,
    required this.onClear,
  });

  final OrderHistoryFilter filter;
  final List<int> years;
  final ValueChanged<OrderHistoryFilter> onChanged;
  final VoidCallback onClear;

  static const _months = [
  'Tümü',
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: filter.month == null
                    ? 'Ay: Tümü'
                    : 'Ay: ${_months[filter.month!]}',
                selected: filter.month != null,
                onTap: () => _pickMonth(context),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: filter.year == null ? 'Yıl: Tümü' : 'Yıl: ${filter.year}',
                selected: filter.year != null,
                onTap: () => _pickYear(context),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Durum: ${filter.status.label}',
                selected: filter.status != OrderHistoryStatusFilter.all,
                onTap: () => _pickStatus(context),
              ),
              if (filter.hasActiveFilters) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onClear,
                  child: const Text('Temizle', style: TextStyle(fontSize: 12)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickMonth(BuildContext context) async {
    final selected = await showModalBottomSheet<int?>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('Tümü'),
              onTap: () => Navigator.pop(context, -1),
            ),
            for (var i = 1; i <= 12; i++)
              ListTile(
                title: Text(_months[i]),
                onTap: () => Navigator.pop(context, i),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    onChanged(
      selected < 0
          ? filter.copyWith(clearMonth: true)
          : filter.copyWith(month: selected),
    );
  }

  Future<void> _pickYear(BuildContext context) async {
    final selected = await showModalBottomSheet<int?>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('Tümü'),
              onTap: () => Navigator.pop(context, -1),
            ),
            for (final year in years)
              ListTile(
                title: Text('$year'),
                onTap: () => Navigator.pop(context, year),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    onChanged(
      selected < 0
          ? filter.copyWith(clearYear: true)
          : filter.copyWith(year: selected),
    );
  }

  Future<void> _pickStatus(BuildContext context) async {
    final selected = await showModalBottomSheet<OrderHistoryStatusFilter>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: OrderHistoryStatusFilter.values
              .map(
                (status) => ListTile(
                  title: Text(status.label),
                  onTap: () => Navigator.pop(context, status),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (selected == null) return;
    onChanged(filter.copyWith(status: selected));
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primary : const Color(0xFF4B5563),
          ),
        ),
      ),
    );
  }
}
