import 'package:flutter/material.dart';

import '../helpers/admin_finance_analytics_helper.dart';
import '../helpers/admin_panel_density.dart';

class AdminFinanceSummaryTablePanel extends StatelessWidget {
  const AdminFinanceSummaryTablePanel({
    super.key,
    required this.density,
    required this.rows,
    required this.periodLabel,
    required this.formatCurrency,
    required this.formatPercent,
  });

  final AdminPanelDensity density;
  final List<AdminFinanceReportRow> rows;
  final String periodLabel;
  final String Function(double) formatCurrency;
  final String Function(double?) formatPercent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(density.financeSectionPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(density.financeSectionRadius),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Genel Finans Özeti',
            style: TextStyle(
              fontSize: density.financeSectionTitleFontSize,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Bu dönem / önceki dönem · $periodLabel',
            style: TextStyle(
              fontSize: density.financeSectionSubtitleFontSize,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Text(
              'Bu dönem veri yok.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 32,
                dataRowMinHeight: 34,
                columnSpacing: 14,
                columns: const [
                  DataColumn(label: Text('Metrik', style: TextStyle(fontSize: 10))),
                  DataColumn(label: Text('Bu dönem', style: TextStyle(fontSize: 10))),
                  DataColumn(label: Text('Önceki', style: TextStyle(fontSize: 10))),
                  DataColumn(label: Text('Değişim', style: TextStyle(fontSize: 10))),
                ],
                rows: rows.map((row) {
                  return DataRow(
                    cells: [
                      DataCell(Text(row.label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                      DataCell(Align(alignment: Alignment.centerRight, child: Text(formatCurrency(row.current), style: const TextStyle(fontSize: 10)))),
                      DataCell(Align(alignment: Alignment.centerRight, child: Text(formatCurrency(row.previous), style: const TextStyle(fontSize: 10)))),
                      DataCell(Align(alignment: Alignment.centerRight, child: Text(formatPercent(row.changePercent), style: const TextStyle(fontSize: 10)))),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
