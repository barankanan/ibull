import 'package:flutter/material.dart';

import '../../helpers/seller_finance_density.dart';

class FinanceDashboardLayout extends StatelessWidget {
  const FinanceDashboardLayout({
    super.key,
    required this.density,
    required this.mainColumn,
    required this.sideColumn,
  });

  final SellerFinanceDensity density;
  final Widget mainColumn;
  final Widget sideColumn;

  @override
  Widget build(BuildContext context) {
    if (!density.dashboardSideBySide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          mainColumn,
          SizedBox(height: density.sectionGap),
          sideColumn,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 7, child: mainColumn),
        SizedBox(width: density.sectionGap),
        Expanded(flex: 4, child: sideColumn),
      ],
    );
  }
}
