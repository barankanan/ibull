import 'package:flutter/material.dart';

import '../../models/restaurant_ops_models.dart';
import '../../utils/past_tables_history_groups.dart';

/// Section header for a date group on the past tables screen.
class PastTablesSectionHeader extends StatelessWidget {
  const PastTablesSectionHeader({
    super.key,
    required this.label,
    this.itemCount,
  });

  final String label;
  final int? itemCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (itemCount != null && itemCount! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$itemCount masa',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
        ],
      ),
    );
  }
}

/// Responsive wrap grid for past table cards.
class PastTablesResponsiveGrid extends StatelessWidget {
  const PastTablesResponsiveGrid({
    super.key,
    required this.records,
    required this.cardBuilder,
    this.minCardWidth = 240,
    this.maxCardWidth = 280,
    this.spacing = 14,
  });

  final List<TableOrderHistoryRecord> records;
  final Widget Function(TableOrderHistoryRecord record) cardBuilder;
  final double minCardWidth;
  final double maxCardWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (maxWidth <= 0 || records.isEmpty) {
          return const SizedBox.shrink();
        }

        var columns =
            ((maxWidth + spacing) / (minCardWidth + spacing)).floor();
        if (columns < 1) columns = 1;

        var cardWidth =
            (maxWidth - spacing * (columns - 1)) / columns;
        if (cardWidth > maxCardWidth) {
          columns =
              ((maxWidth + spacing) / (maxCardWidth + spacing)).floor();
          if (columns < 1) columns = 1;
          cardWidth = (maxWidth - spacing * (columns - 1)) / columns;
        }
        cardWidth = cardWidth.clamp(minCardWidth, maxCardWidth);

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final record in records)
              SizedBox(
                width: cardWidth,
                child: cardBuilder(record),
              ),
          ],
        );
      },
    );
  }
}

/// Builds grouped past-table sections from raw records.
class PastTablesGroupedSections extends StatelessWidget {
  const PastTablesGroupedSections({
    super.key,
    required this.records,
    required this.cardBuilder,
    this.bottomPadding = 0,
  });

  final List<TableOrderHistoryRecord> records;
  final Widget Function(TableOrderHistoryRecord record) cardBuilder;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final groups = groupPastTableHistoryRecords(records);
    if (groups.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          PastTablesSectionHeader(
            label: groups[i].label,
            itemCount: groups[i].items.length,
          ),
          PastTablesResponsiveGrid(
            records: groups[i].items,
            cardBuilder: cardBuilder,
          ),
          if (i < groups.length - 1) const SizedBox(height: 18),
        ],
        if (bottomPadding > 0) SizedBox(height: bottomPadding),
      ],
    );
  }
}

/// Shared filter chip styling for past tables screens.
class PastTablesPeriodChip extends StatelessWidget {
  const PastTablesPeriodChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? const Color(0xFF2563EB)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: selected ? Colors.white : const Color(0xFF475569),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}