import 'package:flutter/material.dart';

import '../../helpers/seller_finance_density.dart';
import '../finance_widgets.dart';

class FinanceSecondaryNavTab {
  const FinanceSecondaryNavTab({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;
}

class FinanceSecondaryNav extends StatelessWidget {
  const FinanceSecondaryNav({
    super.key,
    required this.density,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    required this.quickActions,
  });

  final SellerFinanceDensity density;
  final List<FinanceSecondaryNavTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget quickActions;

  @override
  Widget build(BuildContext context) {
    return FinSurfaceCard(
      padding: EdgeInsets.all(density.isCompact ? 12 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Muhasebe Modülleri',
                  style: TextStyle(
                    fontSize: density.sectionTitleFontSize,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
              Text(
                'Hızlı İşlemler',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          quickActions,
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(tabs.length, (index) {
                final tab = tabs[index];
                final selected = selectedIndex == index;
                return Padding(
                  padding: EdgeInsets.only(
                    right: index == tabs.length - 1 ? 0 : 8,
                  ),
                  child: FinSectionSwitchChip(
                    label: tab.label,
                    icon: tab.icon,
                    selected: selected,
                    onTap: () => onSelected(index),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
