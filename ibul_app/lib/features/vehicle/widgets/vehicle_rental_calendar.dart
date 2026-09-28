import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../domain/vehicle_availability.dart';
import 'vehicle_rental_chrome.dart';

class VehicleRentalCalendar extends StatelessWidget {
  const VehicleRentalCalendar({
    super.key,
    required this.month,
    required this.firstDate,
    required this.lastDate,
    required this.busy,
    required this.selected,
    required this.onSelect,
    required this.onMonth,
    this.rangeStart,
    this.rangeEnd,
  });

  final DateTime month;
  final DateTime firstDate;
  final DateTime lastDate;
  final List<VehicleBusyInterval> busy;
  final DateTime selected;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<DateTime> onMonth;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday - 1;
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => onMonth(DateTime(month.year, month.month - 1)),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                rentalDateLabel(first).replaceFirst(RegExp(r'^\d+ '), ''),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              onPressed: () => onMonth(DateTime(month.year, month.month + 1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Row(
          children: [
            for (final d in const ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'])
              Expanded(
                child: Text(
                  d,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var row = 0; row < 6; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(child: _cell(lead, daysInMonth, row * 7 + col)),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          children: const [
            _Legend(color: Color(0xFF16A34A), label: 'Müsait'),
            _Legend(color: Color(0xFFF59E0B), label: 'Rezerve'),
            _Legend(color: Color(0xFF3B82F6), label: 'Bakımda'),
            _Legend(color: Color(0xFF9CA3AF), label: 'Kapalı'),
          ],
        ),
      ],
    );
  }

  Widget _cell(int lead, int daysInMonth, int slot) {
    final dayNum = slot - lead + 1;
    if (dayNum < 1 || dayNum > daysInMonth) {
      return const SizedBox(height: 34);
    }
    final day = DateTime(month.year, month.month, dayNum);
    final kind = VehicleBusyInterval.kindOnDay(day, busy);
    final enabled = !day.isBefore(DateTime(firstDate.year, firstDate.month, firstDate.day)) &&
        !day.isAfter(DateTime(lastDate.year, lastDate.month, lastDate.day)) &&
        kind == null;
    final isSelected = selected.year == day.year &&
        selected.month == day.month &&
        selected.day == day.day;
    final inRange = _inRange(day);
    Color bg = Colors.transparent;
    Color fg = enabled ? AppColors.ink : AppColors.iconMuted;
    if (kind == 'reserved') {
      bg = const Color(0xFFFFF4E5);
      fg = const Color(0xFFF59E0B);
    } else if (kind == 'maintenance') {
      bg = const Color(0xFFDBEAFE);
      fg = const Color(0xFF3B82F6);
    } else if (kind == 'closed') {
      bg = const Color(0xFFF3F4F6);
      fg = const Color(0xFF9CA3AF);
    } else if (isSelected) {
      bg = AppColors.primary;
      fg = Colors.white;
    } else if (inRange) {
      bg = AppColors.softPurple;
    }
    return InkWell(
      onTap: enabled ? () => onSelect(day) : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$dayNum',
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }

  bool _inRange(DateTime day) {
    final start = rangeStart;
    final end = rangeEnd;
    if (start == null || end == null) return false;
    final d = DateTime(day.year, day.month, day.day);
    final a = DateTime(start.year, start.month, start.day);
    final b = DateTime(end.year, end.month, end.day);
    return !d.isBefore(a) && !d.isAfter(b);
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
      ],
    );
  }
}
