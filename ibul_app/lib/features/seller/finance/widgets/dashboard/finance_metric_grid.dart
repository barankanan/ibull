import 'package:flutter/material.dart';

import '../../helpers/seller_finance_density.dart';
import 'finance_metric_card.dart';

class FinanceMetricGrid extends StatelessWidget {
  const FinanceMetricGrid({
    super.key,
    required this.density,
    required this.items,
    this.loading = false,
  });

  final SellerFinanceDensity density;
  final List<FinanceMetricItem> items;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final columns = density.kpiColumns;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (loading && items.isEmpty) {
          return _buildGrid(
            columns: columns,
            children: List.generate(
              10,
              (_) => FinanceMetricCardSkeleton(density: density),
            ),
          );
        }
        return _buildGrid(
          columns: columns,
          children: items
              .map((item) => FinanceMetricCard(item: item, density: density))
              .toList(growable: false),
        );
      },
    );
  }

  Widget _buildGrid({
    required int columns,
    required List<Widget> children,
  }) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: children.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: density.gridSpacing,
        crossAxisSpacing: density.gridSpacing,
        mainAxisExtent: density.kpiCardHeight,
      ),
      itemBuilder: (_, index) => children[index],
    );
  }
}
