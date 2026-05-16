import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/finance_provider.dart';
import '../../widgets/finance_widgets.dart';
import '../../models/finance_models.dart';

class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FinanceProvider>();
    if (fp.loadingOverview && fp.overview == FinanceOverview.empty) {
      return const FinLoadingOverlay(message: 'Finansal özet yükleniyor...');
    }
    final ov = fp.overview;
    return RefreshIndicator(
      color: kFinancePrimary,
      onRefresh: fp.loadOverview,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (fp.overviewError != null) ...[
            _buildFallbackNotice(fp.overviewError!),
            const SizedBox(height: 12),
          ],
          if (!embedded) ...[
            _buildHealthSection(ov),
            const SizedBox(height: 12),
            _buildKpiGrid(ov),
            const SizedBox(height: 12),
            if (fp.trend.isNotEmpty) _buildTrendSection(fp.trend),
            if (fp.trend.isNotEmpty) const SizedBox(height: 12),
          ],
          _buildAlertSection(ov),
          const SizedBox(height: 12),
          _buildBalanceSection(ov),
        ],
      ),
    );
  }

  Widget _buildFallbackNotice(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFFD97706), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Bazı özet veriler fallback hesaplamayla gösteriliyor. $message',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF92400E),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthSection(FinanceOverview ov) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kFinanceDivider),
      ),
      child: Row(
        children: [
          FinHealthGauge(
            score: ov.healthScore,
            color: ov.healthColor,
            label: ov.healthLabel,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Finans Sağlığı',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                _healthDetail('Aylık Gelir', fmtCurrency(ov.monthIncome), const Color(0xFF10B981)),
                _healthDetail('Aylık Gider', fmtCurrency(ov.monthExpense), const Color(0xFFEF4444)),
                _healthDetail(
                    'Net',
                    fmtCurrency(ov.monthNetIncome),
                    ov.monthNetIncome >= 0
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444)),
                if (ov.overduePayments > 0)
                  _healthDetail(
                      'Gecikmiş Ödeme',
                      '${ov.overduePayments} adet',
                      const Color(0xFFEF4444)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _healthDetail(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          Text(value,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(FinanceOverview ov) {
    final cards = [
      (
        label: 'Nakit Kasa',
        value: fmtCurrency(ov.totalCashBalance),
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFF10B981),
        subtitle: 'Toplam nakit bakiye',
      ),
      (
        label: 'Banka / POS',
        value: fmtCurrency(ov.totalBankBalance),
        icon: Icons.account_balance_rounded,
        color: const Color(0xFF3B82F6),
        subtitle: 'Banka + POS hesapları',
      ),
      (
        label: 'Bekleyen Tahsilat',
        value: fmtCurrency(ov.pendingCollections),
        icon: Icons.pending_actions_rounded,
        color: const Color(0xFFF59E0B),
        subtitle: 'Henüz tahsil edilmedi',
      ),
      (
        label: 'Bekleyen Ödeme',
        value: fmtCurrency(ov.pendingPayments),
        icon: Icons.schedule_rounded,
        color: const Color(0xFFEF4444),
        subtitle: 'Ödenmesi gereken',
      ),
      (
        label: 'Toplam Borç',
        value: fmtCurrency(ov.totalDebt),
        icon: Icons.credit_card_rounded,
        color: const Color(0xFF8B5CF6),
        subtitle: 'Aktif borç toplamı',
      ),
      (
        label: 'Bu Ay Maaş',
        value: fmtCurrency(ov.monthSalaryLoad),
        icon: Icons.people_rounded,
        color: const Color(0xFF06B6D4),
        subtitle: 'Maaş yükü',
      ),
      (
        label: 'Yaklaşan Ödeme',
        value: '${ov.upcomingPayments} adet',
        icon: Icons.event_rounded,
        color: const Color(0xFFF97316),
        subtitle: '7 gün içinde',
      ),
      (
        label: 'Toplam Likidite',
        value: fmtCurrency(ov.totalLiquidity),
        icon: Icons.waves_rounded,
        color: const Color(0xFF065F46),
        subtitle: 'Nakit + Banka',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 1.5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: cards.length,
      itemBuilder: (_, i) {
        final c = cards[i];
        return FinKpiCard(
          label: c.label,
          value: c.value,
          icon: c.icon,
          color: c.color,
          subtitle: c.subtitle,
        );
      },
    );
  }

  Widget _buildTrendSection(List<MonthlyTrendPoint> trend) {
    final chartPoints = trend
        .map((p) => (label: p.label, income: p.income, expense: p.expense))
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kFinanceDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aylık Gelir / Gider Trendi',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _legendDot(const Color(0xFF10B981), 'Gelir'),
              const SizedBox(width: 12),
              _legendDot(const Color(0xFFEF4444), 'Gider'),
            ],
          ),
          const SizedBox(height: 12),
          FinTrendChart(points: chartPoints, height: 130),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
      ],
    );
  }

  Widget _buildAlertSection(FinanceOverview ov) {
    final alerts = <({String text, Color color, IconData icon})>[];

    if (ov.overduePayments > 0) {
      alerts.add((
        text: '${ov.overduePayments} gecikmiş ödeme var',
        color: const Color(0xFFEF4444),
        icon: Icons.warning_rounded,
      ));
    }
    if (ov.overdueDebts > 0) {
      alerts.add((
        text: '${ov.overdueDebts} vadesi geçmiş borç',
        color: const Color(0xFFEF4444),
        icon: Icons.credit_card_off_rounded,
      ));
    }
    if (ov.upcomingPayments > 0) {
      alerts.add((
        text: '${ov.upcomingPayments} ödeme bu hafta vadesi geliyor',
        color: const Color(0xFFF59E0B),
        icon: Icons.event_rounded,
      ));
    }
    if (ov.monthNetIncome < 0) {
      alerts.add((
        text: 'Bu ay giderler geliri aşıyor: ${fmtCurrency(ov.monthNetIncome.abs())} fazla',
        color: const Color(0xFFEF4444),
        icon: Icons.trending_down_rounded,
      ));
    }

    if (alerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
            SizedBox(width: 8),
            Text(
              'Herhangi bir uyarı yok — her şey yolunda',
              style: TextStyle(fontSize: 12, color: Color(0xFF065F46)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: alerts
          .map(
            (a) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: a.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: a.color.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(a.icon, color: a.color, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      a.text,
                      style: TextStyle(fontSize: 12, color: a.color),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildBalanceSection(FinanceOverview ov) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kFinanceDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Finansal Durum Özeti',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          _summaryRow('Toplam Likidite', fmtCurrency(ov.totalLiquidity), const Color(0xFF10B981)),
          _summaryRow('Toplam Borç', fmtCurrency(ov.totalDebt), const Color(0xFFEF4444)),
          _summaryRow(
              'Net Pozisyon',
              fmtCurrency(ov.totalLiquidity - ov.totalDebt),
              (ov.totalLiquidity - ov.totalDebt) >= 0
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444)),
          const Divider(height: 16, color: kFinanceDivider),
          _summaryRow('Bu Ay Net Kazanç', fmtCurrency(ov.monthNetIncome),
              ov.monthNetIncome >= 0
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444)),
          _summaryRow('Bu Ay Maaş Yükü', fmtCurrency(ov.monthSalaryLoad),
              const Color(0xFF64748B)),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: valueColor)),
        ],
      ),
    );
  }
}
