import 'package:flutter/material.dart';

import '../helpers/admin_finance_analytics_helper.dart';
import '../helpers/admin_finance_revenue_helper.dart';
import '../helpers/admin_finance_payout_helper.dart';
import '../helpers/admin_panel_density.dart';
import 'admin_finance_segment_header.dart';

class AdminFinanceReportHeroMetric {
  const AdminFinanceReportHeroMetric({
    required this.label,
    required this.value,
    required this.accent,
    this.subtitle,
    this.icon,
  });

  final String label;
  final String value;
  final Color accent;
  final String? subtitle;
  final IconData? icon;
}

class AdminFinanceReportsPanel extends StatelessWidget {
  const AdminFinanceReportsPanel({
    super.key,
    required this.density,
    required this.bundle,
    required this.periodLabel,
    required this.payoutSnapshot,
    required this.formatCurrency,
    required this.formatPercent,
    required this.onExportCsv,
    this.heroMetrics = const [],
  });

  final AdminPanelDensity density;
  final AdminFinanceAnalyticsBundle bundle;
  final String periodLabel;
  final AdminFinancePayoutPeriodSnapshot payoutSnapshot;
  final String Function(double) formatCurrency;
  final String Function(double?) formatPercent;
  final VoidCallback onExportCsv;
  final List<AdminFinanceReportHeroMetric> heroMetrics;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminFinanceSegmentHeader(
          density: density,
          title: 'Finans Raporları',
          subtitle: 'Dönem karşılaştırmalı gelir, gider ve hakediş analizi.',
          periodLabel: periodLabel,
          icon: Icons.assessment_outlined,
          accent: const Color(0xFF1E40AF),
        ),
        SizedBox(height: density.sectionGap),
        _toolbar(context),
        if (heroMetrics.isNotEmpty) ...[
          SizedBox(height: density.gridSpacing),
          _kpiStrip(),
        ],
        SizedBox(height: density.sectionGap),
        _section(
          title: 'Dönem Karşılaştırması',
          subtitle: periodLabel,
          icon: Icons.compare_arrows_outlined,
          accent: const Color(0xFF2563EB),
          child: _summaryTable(bundle.summaryRows),
        ),
        SizedBox(height: density.gridSpacing),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final sanity = _sanityCard(bundle.sanityReport);
            final revenue = _section(
              title: 'Gelir Kaynakları',
              subtitle: 'Komisyon, reklam, kargo kırılımı',
              icon: Icons.pie_chart_outline,
              accent: const Color(0xFF7C3AED),
              child: _revenueSourceTable(bundle.revenueSourceRows),
            );
            if (!wide) {
              return Column(
                children: [
                  sanity,
                  SizedBox(height: density.gridSpacing),
                  revenue,
                ],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 2, child: revenue),
                  SizedBox(width: density.gridSpacing),
                  Expanded(child: sanity),
                ],
              ),
            );
          },
        ),
        SizedBox(height: density.gridSpacing),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final cargo = _section(
              title: 'Kargo',
              subtitle: 'Tahsilat · maliyet · net',
              icon: Icons.local_shipping_outlined,
              accent: const Color(0xFF0284C7),
              child: _cargoReport(bundle.cargoReport),
            );
            final payout = _section(
              title: 'Hakediş',
              subtitle: 'Satıcı ödeme durumu',
              icon: Icons.payments_outlined,
              accent: const Color(0xFF6D28D9),
              child: _payoutReport(),
            );
            if (!wide) {
              return Column(
                children: [
                  cargo,
                  SizedBox(height: density.gridSpacing),
                  payout,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cargo),
                SizedBox(width: density.gridSpacing),
                Expanded(child: payout),
              ],
            );
          },
        ),
        SizedBox(height: density.gridSpacing),
        _section(
          title: 'Reklam Performansı',
          subtitle: 'Kampanya türü bazlı',
          icon: Icons.campaign_outlined,
          accent: const Color(0xFFDB2777),
          child: _adReportTable(bundle.adTypeRows),
        ),
        SizedBox(height: density.gridSpacing),
        _section(
          title: 'Gider Analizi',
          subtitle: 'Kategori bazlı',
          icon: Icons.receipt_long_outlined,
          accent: const Color(0xFFEA580C),
          child: _expenseReportTable(bundle.expenseCategoryRows),
        ),
      ],
    );
  }

  Widget _toolbar(BuildContext context) {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: onExportCsv,
          icon: const Icon(Icons.download_outlined, size: 16),
          label: const Text('CSV dışa aktar'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
          label: const Text('PDF (yakında)'),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            periodLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ),
      ],
    );
  }

  Widget _kpiStrip() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth >= 1200
            ? (constraints.maxWidth - density.gridSpacing * 3) / 4
            : constraints.maxWidth >= 700
            ? (constraints.maxWidth - density.gridSpacing) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: density.gridSpacing,
          runSpacing: density.gridSpacing,
          children: heroMetrics.take(4).map((metric) {
            return SizedBox(
              width: itemWidth,
              child: _kpiTile(metric),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _kpiTile(AdminFinanceReportHeroMetric metric) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: metric.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              metric.icon ?? Icons.insights_outlined,
              size: 18,
              color: metric.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  metric.value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                    height: 1.2,
                  ),
                ),
                if (metric.subtitle != null)
                  Text(
                    metric.subtitle!,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(density.financeSectionRadius),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: density.financeSectionPadding,
              vertical: density.financeSectionPadding - 2,
            ),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.04),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(density.financeSectionRadius),
              ),
              border: Border(
                bottom: BorderSide(color: accent.withValues(alpha: 0.12)),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: density.financeSectionTitleFontSize,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: density.financeSectionSubtitleFontSize,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(density.financeSectionPadding),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _payoutReport() {
    final snap = payoutSnapshot;
    if (snap.rows.isEmpty && snap.totalNetPayout <= 0) {
      return _empty();
    }
    return _metricGrid([
      _MetricCell('Net hakediş', formatCurrency(snap.totalNetPayout)),
      _MetricCell('Bekleyen', formatCurrency(snap.pendingPayout)),
      _MetricCell('Ödenen', formatCurrency(snap.paidPayout)),
      _MetricCell('Geciken', formatCurrency(snap.overduePayout)),
      _MetricCell('Satıcı', '${snap.rows.length}'),
      _MetricCell('Onay bekleyen', '${snap.awaitingApprovalCount}'),
    ]);
  }

  Widget _sanityCard(AdminFinanceSanityReport report) {
    final color = switch (report.status) {
      AdminFinanceSanityStatus.consistent => const Color(0xFF15803D),
      AdminFinanceSanityStatus.needsReview => const Color(0xFFF97316),
      AdminFinanceSanityStatus.incompleteData => const Color(0xFF6B7280),
    };
    return _section(
      title: 'Tutarlılık',
      subtitle: report.label,
      icon: Icons.fact_check_outlined,
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: report.notes
            .map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle, size: 6, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        note,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _summaryTable(List<AdminFinanceReportRow> rows) {
    if (rows.isEmpty) return _empty();
    return _modernTable(
      columns: const ['Metrik', 'Bu dönem', 'Önceki', 'Değişim', 'Durum'],
      rows: rows
          .map(
            (row) => _TableRowData(
              cells: [
                row.label,
                formatCurrency(row.current),
                formatCurrency(row.previous),
                formatPercent(row.changePercent),
                row.status,
              ],
              highlight: row.current > 0,
            ),
          )
          .toList(),
      alignRightFrom: 1,
      changeColumnIndex: 3,
    );
  }

  Widget _revenueSourceTable(List<AdminFinanceRevenueSourceRow> rows) {
    if (rows.every((r) => !r.hasData && r.amount <= 0)) return _empty();
    return _modernTable(
      columns: const ['Kaynak', 'Tutar', 'Pay', 'Durum'],
      rows: rows
          .map(
            (row) => _TableRowData(
              cells: [
                row.label,
                formatCurrency(row.amount),
                row.hasData ? '%${(row.share * 100).toStringAsFixed(1)}' : '—',
                row.hasData ? 'Kayıt var' : row.emptyNote,
              ],
              highlight: row.hasData,
            ),
          )
          .toList(),
      alignRightFrom: 1,
    );
  }

  Widget _adReportTable(List<AdminFinanceAdTypeRow> rows) {
    if (rows.isEmpty) return _empty();
    return _modernTable(
      columns: const ['Tür', 'Kamp.', 'Tahsilat', 'Harcanan', 'Gösterim', 'Tıklama', 'CTR'],
      rows: rows
          .map(
            (row) => _TableRowData(
              cells: [
                row.label,
                '${row.campaignCount}',
                formatCurrency(row.collectedAmount),
                formatCurrency(row.spentAmount),
                _compactInt(row.impressions),
                _compactInt(row.clicks),
                row.impressions == 0
                    ? '—'
                    : '%${(row.ctr * 100).toStringAsFixed(1)}',
              ],
              highlight: row.collectedAmount > 0,
            ),
          )
          .toList(),
      alignRightFrom: 2,
    );
  }

  Widget _cargoReport(AdminFinanceCargoReport report) {
    if (report.collection <= 0 &&
        report.cost <= 0 &&
        report.packageCount <= 0) {
      return _empty();
    }
    return _metricGrid([
      _MetricCell('Tahsilat', formatCurrency(report.collection)),
      _MetricCell('Maliyet', formatCurrency(report.cost)),
      _MetricCell('Net gelir', formatCurrency(report.netRevenue)),
      _MetricCell('Paket', '${report.packageCount}'),
      _MetricCell('Sübvansiyon', formatCurrency(report.freeShippingSubsidy)),
    ]);
  }

  Widget _expenseReportTable(List<AdminFinanceExpenseCategoryReportRow> rows) {
    if (rows.isEmpty) return _empty();
    return _modernTable(
      columns: const ['Kategori', 'Toplam', 'Adet', 'Bekleyen'],
      rows: rows
          .map(
            (row) => _TableRowData(
              cells: [
                row.categoryLabel,
                formatCurrency(row.total),
                '${row.count}',
                formatCurrency(row.pendingAmount),
              ],
              highlight: row.total > 0,
            ),
          )
          .toList(),
      alignRightFrom: 1,
    );
  }

  Widget _metricGrid(List<_MetricCell> cells) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 500 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cells.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.8,
          ),
          itemBuilder: (context, index) {
            final cell = cells[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    cell.label,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                  ),
                  Text(
                    cell.value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _empty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 28, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            'Bu dönem için veri yok',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _modernTable({
    required List<String> columns,
    required List<_TableRowData> rows,
    required int alignRightFrom,
    int? changeColumnIndex,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
            headingRowHeight: 38,
            dataRowMinHeight: 40,
            dataRowMaxHeight: 44,
            columnSpacing: 20,
            horizontalMargin: 14,
            columns: columns
                .map(
                  (c) => DataColumn(
                    label: Text(
                      c,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                )
                .toList(),
            rows: rows.map((rowData) {
              return DataRow(
                color: WidgetStateProperty.all(
                  rowData.highlight
                      ? Colors.white
                      : const Color(0xFFFAFAFA),
                ),
                cells: List.generate(rowData.cells.length, (index) {
                  final alignRight = index >= alignRightFrom;
                  Widget child;
                  if (changeColumnIndex != null && index == changeColumnIndex) {
                    child = _changeBadge(rowData.cells[index]);
                  } else {
                    child = Text(
                      rowData.cells[index],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: index == 0 ? FontWeight.w600 : FontWeight.w500,
                        color: const Color(0xFF111827),
                      ),
                    );
                  }
                  return DataCell(
                    Align(
                      alignment: alignRight
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: child,
                    ),
                  );
                }),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _changeBadge(String value) {
    if (value == '—' || value.isEmpty) {
      return Text(value, style: const TextStyle(fontSize: 11));
    }
    final numeric =
        double.tryParse(value.replaceAll('%', '').replaceAll('+', ''));
    final positive = numeric != null && numeric > 0;
    final negative = numeric != null && numeric < 0;
    final color = positive
        ? const Color(0xFF15803D)
        : negative
        ? const Color(0xFFDC2626)
        : const Color(0xFF6B7280);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  String _compactInt(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }
}

class _TableRowData {
  const _TableRowData({required this.cells, this.highlight = false});
  final List<String> cells;
  final bool highlight;
}

class _MetricCell {
  const _MetricCell(this.label, this.value);
  final String label;
  final String value;
}
