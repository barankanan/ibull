import 'package:flutter/material.dart';

import '../helpers/admin_finance_analytics_helper.dart';
import '../helpers/admin_finance_manual_revenue_helper.dart';
import '../helpers/admin_finance_payout_helper.dart';
import '../helpers/admin_finance_revenue_helper.dart';
import '../helpers/admin_panel_density.dart';
import 'admin_finance_charts_panel.dart';
import 'admin_finance_manual_revenue_panel.dart';
import 'admin_finance_payout_panel.dart';
import 'admin_finance_segment_header.dart';
import '../../../../services/admin_service.dart';

class AdminFinanceRevenuePanel extends StatelessWidget {
  const AdminFinanceRevenuePanel({
    super.key,
    required this.density,
    required this.periodLabel,
    required this.snapshot,
    required this.cargo,
    required this.payoutSnapshot,
    required this.revenueSeries,
    required this.isAutoLoading,
    required this.isPayoutLoading,
    required this.payoutError,
    required this.manualSummary,
    required this.manualRevenues,
    required this.isManualLoading,
    required this.manualError,
    required this.manualCategoryFilter,
    required this.manualStatusFilter,
    required this.manualTypeFilter,
    required this.onManualCategoryFilterChanged,
    required this.onManualStatusFilterChanged,
    required this.onManualTypeFilterChanged,
    required this.onSaveRevenue,
    required this.onCancelRevenue,
    required this.onManualRetry,
    required this.payoutStatusFilter,
    required this.searchQuery,
    required this.onPayoutStatusFilterChanged,
    required this.onSearchChanged,
    required this.onApprove,
    required this.onMarkPaid,
    required this.onDispute,
    required this.onCancel,
    required this.onPayoutRetry,
    required this.formatCurrency,
    required this.formatCompactCurrency,
    required this.formatPercent,
  });

  final AdminPanelDensity density;
  final String periodLabel;
  final AdminFinancePeriodSnapshot snapshot;
  final AdminFinanceCargoBreakdown cargo;
  final AdminFinancePayoutPeriodSnapshot payoutSnapshot;
  final List<AdminFinanceChartPoint> revenueSeries;
  final bool isAutoLoading;
  final bool isPayoutLoading;
  final String? payoutError;
  final AdminFinanceManualRevenueSummary manualSummary;
  final List<AdminRevenue> manualRevenues;
  final bool isManualLoading;
  final String? manualError;
  final String? manualCategoryFilter;
  final String? manualStatusFilter;
  final String? manualTypeFilter;
  final ValueChanged<String?> onManualCategoryFilterChanged;
  final ValueChanged<String?> onManualStatusFilterChanged;
  final ValueChanged<String?> onManualTypeFilterChanged;
  final AdminRevenueSaveCallback onSaveRevenue;
  final AdminRevenueCancelCallback onCancelRevenue;
  final VoidCallback onManualRetry;
  final String? payoutStatusFilter;
  final String searchQuery;
  final ValueChanged<String?> onPayoutStatusFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final PayoutRowAction onApprove;
  final PayoutMarkPaidAction onMarkPaid;
  final PayoutRowAction onDispute;
  final PayoutRowAction onCancel;
  final VoidCallback onPayoutRetry;
  final String Function(double) formatCurrency;
  final String Function(double) formatCompactCurrency;
  final String Function(double?) formatPercent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminFinanceSegmentHeader(
          density: density,
          title: 'Gelir Merkezi',
          subtitle: 'Otomatik gelirler sistemden hesaplanır; manuel gelirler aşağıda yönetilir.',
          periodLabel: periodLabel,
          icon: Icons.trending_up_rounded,
          accent: const Color(0xFF0F766E),
        ),
        SizedBox(height: density.sectionGap),
        if (isAutoLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          _section(
            title: 'Otomatik Gelir Kaynakları',
            subtitle: 'Sipariş komisyonu, reklam ve kargo — sistemden hesaplanır',
            child: _revenueBlocks(),
          ),
          SizedBox(height: density.sectionGap),
          _payoutKpis(),
          SizedBox(height: density.sectionGap),
          _section(
            title: 'Gelir Kaynakları Trendi',
            child: AdminFinanceChartsPanel(
              density: density,
              periodLabel: periodLabel,
              cashFlowSeries: const [],
              revenueSeries: revenueSeries,
              expenseSeries: const [],
              formatCurrency: formatCurrency,
              revenueOnly: true,
            ),
          ),
          SizedBox(height: density.gridSpacing),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 960;
              final ad = _section(
                title: 'Reklam Geliri Kırılımı',
                subtitle: 'Otomatik hesaplanır',
                child: _adTable(snapshot.adBreakdown.rows),
              );
              final cargoSection = _section(
                title: 'Kargo Geliri',
                subtitle: snapshot.manualCargoAdjustment > 0
                    ? 'Otomatik + manuel düzeltme dahil'
                    : 'Otomatik hesaplanır',
                child: _cargoMetrics(),
              );
              if (!wide) {
                return Column(
                  children: [ad, SizedBox(height: density.gridSpacing), cargoSection],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: ad),
                  SizedBox(width: density.gridSpacing),
                  Expanded(child: cargoSection),
                ],
              );
            },
          ),
          SizedBox(height: density.sectionGap),
          _section(
            title: 'Satıcı Hakedişleri',
            subtitle: 'Onay, ödeme ve bekleyen hakediş takibi',
            child: AdminFinancePayoutPanel(
              density: density,
              snapshot: payoutSnapshot,
              isLoading: isPayoutLoading,
              error: payoutError,
              periodLabel: periodLabel,
              statusFilter: payoutStatusFilter,
              searchQuery: searchQuery,
              onStatusFilterChanged: onPayoutStatusFilterChanged,
              onSearchChanged: onSearchChanged,
              onApprove: onApprove,
              onMarkPaid: onMarkPaid,
              onDispute: onDispute,
              onCancel: onCancel,
              formatCurrency: formatCurrency,
              formatCompactCurrency: formatCompactCurrency,
              onRetry: onPayoutRetry,
              compactHeader: true,
            ),
          ),
        ],
        SizedBox(height: density.sectionGap),
        _section(
          title: 'Manuel Gelir Kayıtları',
          subtitle: 'Emlak/kira, sponsorluk, manuel tahsilat ve diğer gelirler',
          child: AdminFinanceManualRevenuePanel(
            density: density,
            summary: manualSummary,
            revenues: manualRevenues,
            isLoading: isManualLoading,
            error: manualError,
            periodLabel: periodLabel,
            categoryFilter: manualCategoryFilter,
            statusFilter: manualStatusFilter,
            typeFilter: manualTypeFilter,
            onCategoryFilterChanged: onManualCategoryFilterChanged,
            onStatusFilterChanged: onManualStatusFilterChanged,
            onTypeFilterChanged: onManualTypeFilterChanged,
            onSaveRevenue: onSaveRevenue,
            onCancelRevenue: onCancelRevenue,
            formatCurrency: formatCurrency,
            formatCompactCurrency: formatCompactCurrency,
            onRetry: onManualRetry,
          ),
        ),
      ],
    );
  }

  Widget _revenueBlocks() {
    final core = snapshot.orderCore;
    final blocks = [
      _RevenueBlock(
        label: 'Sipariş Geliri',
        subtitle: 'Otomatik · Komisyon',
        amount: core.commission,
        icon: Icons.shopping_bag_outlined,
        color: const Color(0xFF2563EB),
      ),
      _RevenueBlock(
        label: 'Reklam Geliri',
        subtitle: snapshot.adBreakdown.usesPlannedBudgetLabel
            ? 'Otomatik · Planlanan / tahsilat'
            : 'Otomatik · Tahsil edilen',
        amount: snapshot.adBreakdown.totalCollected,
        icon: Icons.campaign_outlined,
        color: const Color(0xFFDB2777),
      ),
      _RevenueBlock(
        label: 'Kargo Geliri',
        subtitle: snapshot.manualCargoAdjustment > 0
            ? 'Otomatik + düzeltme'
            : 'Otomatik · Net kargo',
        amount: core.cargoNetRevenue + snapshot.manualCargoAdjustment,
        icon: Icons.local_shipping_outlined,
        color: const Color(0xFF0284C7),
      ),
      _RevenueBlock(
        label: 'Emlak / Kira',
        subtitle: snapshot.propertyRentRevenue > 0 ? 'Manuel kayıt' : 'Manuel giriş',
        amount: snapshot.propertyRentRevenue,
        icon: Icons.apartment_outlined,
        color: const Color(0xFF6B7280),
        isComingSoon: snapshot.propertyRentRevenue <= 0,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 1000 ? 4 : constraints.maxWidth >= 560 ? 2 : 1;
        final w = cols == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - density.gridSpacing * (cols - 1)) / cols;
        return Wrap(
          spacing: density.gridSpacing,
          runSpacing: density.gridSpacing,
          children: blocks
              .map((b) => SizedBox(width: w, child: _blockCard(b)))
              .toList(),
        );
      },
    );
  }

  Widget _blockCard(_RevenueBlock block) {
    return Container(
      padding: EdgeInsets.all(density.financeKpiCardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(block.icon, size: 16, color: block.color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  block.label,
                  style: TextStyle(
                    fontSize: density.financeKpiSubtitleFontSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            block.isComingSoon ? 'Yakında' : formatCurrency(block.amount),
            style: TextStyle(
              fontSize: density.financeKpiValueFontSize - 2,
              fontWeight: FontWeight.w800,
              color: block.isComingSoon ? const Color(0xFF9CA3AF) : const Color(0xFF111827),
            ),
          ),
          Text(
            block.subtitle,
            style: TextStyle(fontSize: density.financeKpiSubtitleFontSize, color: const Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _payoutKpis() {
    final cards = [
      ('Satıcı Hakedişi', payoutSnapshot.totalNetPayout, const Color(0xFF7C3AED)),
      ('Bekleyen Hakediş', payoutSnapshot.pendingPayout, const Color(0xFFF97316)),
      ('Ödenen Hakediş', payoutSnapshot.paidPayout, const Color(0xFF16A34A)),
      ('Geciken Hakediş', payoutSnapshot.overduePayout, const Color(0xFFDC2626)),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 900 ? 4 : constraints.maxWidth >= 520 ? 2 : 1;
        final w = cols == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - density.gridSpacing * (cols - 1)) / cols;
        return Wrap(
          spacing: density.gridSpacing,
          runSpacing: density.gridSpacing,
          children: cards
              .map(
                (c) => SizedBox(
                  width: w,
                  child: Container(
                    padding: EdgeInsets.all(density.financeKpiCardPadding),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.$1, style: TextStyle(fontSize: 10, color: const Color(0xFF6B7280), fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                          formatCompactCurrency(c.$2),
                          style: TextStyle(fontSize: density.financeKpiValueFontSize - 3, fontWeight: FontWeight.w800, color: c.$3),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _section({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
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
          Text(title, style: TextStyle(fontSize: density.financeSectionTitleFontSize, fontWeight: FontWeight.w800)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: density.financeSectionSubtitleFontSize, color: const Color(0xFF6B7280))),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _adTable(List<AdminFinanceAdTypeRow> rows) {
    if (rows.isEmpty) {
      return const Text('Bu dönem reklam geliri bulunamadı.', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)));
    }
    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Expanded(child: Text(row.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
              Text(formatCurrency(row.collectedAmount), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Text('${row.campaignCount} kamp.', style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _cargoMetrics() {
    final netWithManual = cargo.netRevenue;
    if (cargo.collection <= 0 && cargo.packageCount <= 0 && netWithManual <= 0) {
      return const Text('Bu dönem kargo geliri bulunamadı.', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)));
    }
    return Column(
      children: [
        _metricRow('Tahsilat', formatCurrency(cargo.collection)),
        _metricRow('Maliyet', formatCurrency(cargo.cost)),
        _metricRow('Net gelir', formatCurrency(netWithManual)),
        if (snapshot.manualCargoAdjustment > 0)
          _metricRow('Manuel düzeltme', formatCurrency(snapshot.manualCargoAdjustment)),
        _metricRow('Paket', '${cargo.packageCount}'),
      ],
    );
  }

  Widget _metricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)))),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _RevenueBlock {
  const _RevenueBlock({
    required this.label,
    required this.subtitle,
    required this.amount,
    required this.icon,
    required this.color,
    this.isComingSoon = false,
  });

  final String label;
  final String subtitle;
  final double amount;
  final IconData icon;
  final Color color;
  final bool isComingSoon;
}
