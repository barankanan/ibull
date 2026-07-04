import 'package:flutter/material.dart';

import '../../helpers/seller_finance_density.dart';

class FinanceMetricItem {
  const FinanceMetricItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
    this.subtitle,
    this.onTap,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;
}

class FinanceMetricCard extends StatefulWidget {
  const FinanceMetricCard({
    super.key,
    required this.item,
    required this.density,
  });

  final FinanceMetricItem item;
  final SellerFinanceDensity density;

  @override
  State<FinanceMetricCard> createState() => _FinanceMetricCardState();
}

class _FinanceMetricCardState extends State<FinanceMetricCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final d = widget.density;
    final interactive = item.onTap != null;

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: d.kpiCardHeight,
      padding: EdgeInsets.all(d.kpiCardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(d.cardRadius),
        border: Border.all(
          color: _hovered && interactive
              ? item.accent.withValues(alpha: 0.45)
              : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _hovered ? 0.06 : 0.03),
            blurRadius: _hovered ? 12 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: item.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, size: 15, color: item.accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: d.kpiTitleFontSize,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
              if (interactive)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: item.accent.withValues(alpha: 0.7),
                ),
            ],
          ),
          const Spacer(),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: d.kpiValueFontSize,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
              letterSpacing: -0.3,
            ),
          ),
          if (item.subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              item.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: d.kpiSubtitleFontSize,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ],
      ),
    );

    if (interactive) {
      card = MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: item.onTap,
            borderRadius: BorderRadius.circular(d.cardRadius),
            child: card,
          ),
        ),
      );
    }

    return card;
  }
}

class FinanceMetricCardSkeleton extends StatelessWidget {
  const FinanceMetricCardSkeleton({super.key, required this.density});

  final SellerFinanceDensity density;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: density.kpiCardHeight,
      padding: EdgeInsets.all(density.kpiCardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(density.cardRadius),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const Spacer(),
          Container(
            height: 14,
            width: 90,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 10,
            width: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}
