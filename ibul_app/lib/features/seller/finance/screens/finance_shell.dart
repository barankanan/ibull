import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../finance_quick_actions.dart';
import '../models/finance_models.dart';
import '../providers/finance_provider.dart';
import '../widgets/finance_widgets.dart';
import 'tabs/cash_tab.dart';
import 'tabs/debt_tab.dart';
import 'tabs/expense_tab.dart';
import 'tabs/income_tab.dart';
import 'tabs/overview_tab.dart';
import 'tabs/payments_tab.dart';
import 'tabs/reconciliation_tab.dart';
import 'tabs/reports_tab.dart';
import 'tabs/salary_tab.dart';
import 'tabs/settings_tab.dart';

class FinanceShell extends StatelessWidget {
  const FinanceShell({
    super.key,
    required this.sellerId,
    this.optimisticClosedHistory = const <Map<String, dynamic>>[],
  });

  final String sellerId;
  final List<Map<String, dynamic>> optimisticClosedHistory;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FinanceProvider(
        sellerId: sellerId,
        optimisticClosedHistory: optimisticClosedHistory,
      ),
      child: const _FinanceShellContent(),
    );
  }
}

class _FinanceShellContent extends StatefulWidget {
  const _FinanceShellContent();

  @override
  State<_FinanceShellContent> createState() => _FinanceShellContentState();
}

class _FinanceShellContentState extends State<_FinanceShellContent> {
  static const _tabs = [
    (label: 'Genel Bakış', icon: Icons.dashboard_rounded),
    (label: 'Kasa', icon: Icons.account_balance_wallet_rounded),
    (label: 'Gelirler', icon: Icons.trending_up_rounded),
    (label: 'Giderler', icon: Icons.trending_down_rounded),
    (label: 'Borçlar', icon: Icons.credit_card_rounded),
    (label: 'Maaşlar', icon: Icons.people_rounded),
    (label: 'Ödemeler', icon: Icons.payment_rounded),
    (label: 'Mutabakat', icon: Icons.checklist_rounded),
    (label: 'Raporlar', icon: Icons.bar_chart_rounded),
    (label: 'Ayarlar', icon: Icons.settings_rounded),
  ];

  int _selectedIndex = 0;
  bool _loadingExtras = false;
  String? _extrasWarning;
  List<Map<String, dynamic>> _recentActivities = const [];
  List<Map<String, dynamic>> _paymentSchedule = const [];
  Map<String, double> _expenseSummary = const {};
  CompanySettings? _companySettings;
  double _todayIncome = 0;
  double _upcomingPaymentAmount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<FinanceProvider>();
      await provider.init();
      if (!mounted) return;
      await _loadDashboardExtras();
    });
  }

  Future<void> _refreshAll() async {
    await context.read<FinanceProvider>().refresh();
    if (!mounted) return;
    await _loadDashboardExtras();
  }

  Future<void> _loadDashboardExtras() async {
    setState(() {
      _loadingExtras = true;
      _extrasWarning = null;
    });
    try {
      final repo = context.read<FinanceProvider>().repo;
      final now = DateTime.now();
      final results = await Future.wait([
        repo.getCashMovements(limit: 4),
        repo.getIncomeRecords(limit: 4),
        repo.getExpenses(limit: 4),
        repo.getIncomeRecords(
          from: DateTime(now.year, now.month, now.day),
          to: now,
          limit: 100,
        ),
        repo.getPaymentScheduleItems(
          from: now.subtract(const Duration(days: 14)),
          to: now.add(const Duration(days: 21)),
        ),
        repo.getExpenseSummaryByCategory(year: now.year, month: now.month),
        repo.getCompanySettings(),
      ]);

      final movements = results[0] as List<CashMovement>;
      final incomes = results[1] as List<IncomeRecord>;
      final expenses = results[2] as List<Expense>;
      final todayIncomes = results[3] as List<IncomeRecord>;
      final schedule = results[4] as List<Map<String, dynamic>>;

      final items =
          <Map<String, dynamic>>[
            ...movements.map(
              (m) => {
                'title': m.accountName ?? m.movementType.label,
                'subtitle': m.description ?? m.movementType.label,
                'amount': m.isIn ? m.amount : -m.amount,
                'date': m.movementDate,
                'color': m.isIn
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
                'icon': m.isIn
                    ? Icons.south_west_rounded
                    : Icons.north_east_rounded,
                'tag': m.isIn ? 'Kasa Girişi' : 'Kasa Çıkışı',
              },
            ),
            ...incomes.map(
              (i) => {
                'title': i.source ?? i.incomeType.label,
                'subtitle': i.description ?? i.incomeType.label,
                'amount': i.netAmount,
                'date': i.incomeDate,
                'color': const Color(0xFF10B981),
                'icon': Icons.trending_up_rounded,
                'tag': i.isCollected ? 'Gelir' : 'Bekleyen Gelir',
              },
            ),
            ...expenses.map(
              (e) => {
                'title': e.supplierName ?? e.category.label,
                'subtitle': e.description ?? e.category.label,
                'amount': -e.amount,
                'date': e.expenseDate,
                'color': e.isPaid
                    ? const Color(0xFFEF4444)
                    : const Color(0xFFF59E0B),
                'icon': e.isPaid
                    ? Icons.receipt_long_rounded
                    : Icons.schedule_rounded,
                'tag': e.isPaid ? 'Gider' : 'Bekleyen Gider',
              },
            ),
          ]..sort(
            (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
          );

      setState(() {
        _recentActivities = items.take(8).toList(growable: false);
        _paymentSchedule = schedule.take(6).toList(growable: false);
        _expenseSummary = results[5] as Map<String, double>;
        _companySettings = results[6] as CompanySettings?;
        _todayIncome = todayIncomes.fold<double>(
          0,
          (sum, item) => sum + item.netAmount,
        );
        _upcomingPaymentAmount = schedule.fold<double>(0, (sum, item) {
          final dueDate = item['due_date'] as DateTime;
          final amount = (item['amount'] as num?)?.toDouble() ?? 0;
          return dueDate.isAfter(now.subtract(const Duration(days: 1)))
              ? sum + amount
              : sum;
        });
      });
    } catch (error) {
      setState(() {
        _extrasWarning = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loadingExtras = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1180;
    final provider = context.watch<FinanceProvider>();
    final overview = provider.overview;

    return Container(
      color: const Color(0xFFF8FAFC),
      child: RefreshIndicator(
        color: kFinancePrimary,
        onRefresh: _refreshAll,
        child: ListView(
          padding: EdgeInsets.all(isDesktop ? 16 : 12),
          children: [
            _buildHeader(isDesktop),
            const SizedBox(height: 12),
            if (_extrasWarning != null) ...[
              _buildTopWarning(_extrasWarning!),
              const SizedBox(height: 12),
            ],
            _buildKpiGrid(overview),
            const SizedBox(height: 12),
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 8,
                    child: Column(
                      children: [
                        _buildPerformanceCard(provider),
                        const SizedBox(height: 12),
                        _buildRecentActivityCard(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        _buildPaymentSummaryPanel(overview),
                        const SizedBox(height: 12),
                        _buildSchedulePanel(),
                        const SizedBox(height: 12),
                        _buildCompanyPanel(),
                        const SizedBox(height: 12),
                        _buildHealthPanel(overview),
                      ],
                    ),
                  ),
                ],
              )
            else ...[
              _buildPerformanceCard(provider),
              const SizedBox(height: 12),
              _buildPaymentSummaryPanel(overview),
              const SizedBox(height: 12),
              _buildSchedulePanel(),
              const SizedBox(height: 12),
              _buildHealthPanel(overview),
              const SizedBox(height: 12),
              _buildCompanyPanel(),
              const SizedBox(height: 12),
              _buildRecentActivityCard(),
            ],
            const SizedBox(height: 14),
            _buildSectionSwitcher(),
            const SizedBox(height: 12),
            _buildSectionContent(isDesktop),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return FinSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Finans Merkezi',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Dashboard-first görünüm korunuyor. Muhasebe modülleri aşağıdaki secondary navigation ile erişilebilir.',
                  style: TextStyle(
                    fontSize: isDesktop ? 13 : 12,
                    color: const Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _refreshAll,
            style: FilledButton.styleFrom(
              backgroundColor: kFinancePrimary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Yenile'),
          ),
        ],
      ),
    );
  }

  Widget _buildTopWarning(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFD97706),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Bazı finance servisleri fallback modunda çalışıyor. Sayfa kapanmadan devam eder. $message',
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(FinanceOverview overview) {
    final cards = [
      (
        title: 'Bugünkü Gelir',
        value: fmtCurrency(_todayIncome),
        subtitle: 'Günün tahakkuk eden geliri',
        icon: Icons.today_rounded,
        accent: const Color(0xFF0EA5E9),
      ),
      (
        title: 'Bu Ay Gelir',
        value: fmtCurrency(overview.monthIncome),
        subtitle: 'Ay içindeki toplam gelir',
        icon: Icons.trending_up_rounded,
        accent: const Color(0xFF10B981),
      ),
      (
        title: 'Bu Ay Gider',
        value: fmtCurrency(overview.monthExpense),
        subtitle: 'Ay içindeki toplam gider',
        icon: Icons.trending_down_rounded,
        accent: const Color(0xFFEF4444),
      ),
      (
        title: 'Net Durum',
        value: fmtCurrency(overview.monthNetPosition),
        subtitle: 'Gelir - gider - maaş yükü',
        icon: overview.monthNetPosition >= 0
            ? Icons.show_chart_rounded
            : Icons.trending_down_rounded,
        accent: overview.monthNetPosition >= 0
            ? const Color(0xFF16A34A)
            : const Color(0xFFDC2626),
      ),
      (
        title: 'Bekleyen Tahsilat',
        value: fmtCurrency(overview.pendingCollections),
        subtitle: 'Henüz toplanmamış gelir',
        icon: Icons.schedule_send_rounded,
        accent: const Color(0xFFF59E0B),
      ),
      (
        title: 'Toplam Borç',
        value: fmtCurrency(overview.totalDebt),
        subtitle: 'Kalan aktif borç bakiyesi',
        icon: Icons.credit_card_rounded,
        accent: const Color(0xFFF97316),
      ),
      (
        title: 'Nakit Kasa',
        value: fmtCurrency(overview.totalCashBalance),
        subtitle: 'Kasa hesapları',
        icon: Icons.account_balance_wallet_rounded,
        accent: const Color(0xFF3B82F6),
      ),
      (
        title: 'Banka / POS',
        value: fmtCurrency(overview.totalBankBalance),
        subtitle: 'Banka ve POS hesapları',
        icon: Icons.account_balance_rounded,
        accent: const Color(0xFF7C3AED),
      ),
      (
        title: 'Maaş Yükü',
        value: fmtCurrency(overview.monthSalaryLoad),
        subtitle: 'Aylık maaş yükümlülüğü',
        icon: Icons.badge_rounded,
        accent: const Color(0xFF8B5CF6),
      ),
      (
        title: 'Yaklaşan Ödemeler',
        value: fmtCurrency(_upcomingPaymentAmount),
        subtitle: '${overview.upcomingPayments} kayıt yakın vadede',
        icon: Icons.event_note_rounded,
        accent: const Color(0xFF6366F1),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        childAspectRatio: 1.95,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemBuilder: (_, index) {
        final item = cards[index];
        return FinKpiCard(
          label: item.title,
          value: item.value,
          subtitle: item.subtitle,
          icon: item.icon,
          color: item.accent,
        );
      },
    );
  }

  Widget _buildPerformanceCard(FinanceProvider provider) {
    final trendPoints = provider.trend
        .map(
          (point) => (
            label: point.label,
            income: point.income,
            expense: point.expense,
          ),
        )
        .toList(growable: false);
    final overview = provider.overview;

    return FinSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Finansal Performans',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ana grafik görünümü korunur; gelir ve gider trendi burada izlenir.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          if (trendPoints.isEmpty)
            Container(
              height: 260,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Trend verisi hazır değil. Fallback hesaplama veya yeni hareketler geldikçe grafik dolacak.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            )
          else
            FinTrendChart(points: trendPoints, height: 260),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _miniStat(
                'Bu Ay Gelir',
                fmtCurrency(overview.monthIncome),
                const Color(0xFF10B981),
              ),
              _miniStat(
                'Bu Ay Gider',
                fmtCurrency(overview.monthExpense),
                const Color(0xFFEF4444),
              ),
              _miniStat(
                'Maaş Yükü',
                fmtCurrency(overview.monthSalaryLoad),
                const Color(0xFF8B5CF6),
              ),
              _miniStat(
                'Toplam Likidite',
                fmtCurrency(overview.totalLiquidity),
                kFinancePrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Container(
      width: 170,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummaryPanel(FinanceOverview overview) {
    return FinSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ödeme Özeti',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          FinMetricRow(
            label: 'Bekleyen ödeme toplamı',
            value: fmtCurrency(overview.pendingPayments),
            valueColor: const Color(0xFFEF4444),
          ),
          FinMetricRow(
            label: 'Toplam kalan borç',
            value: fmtCurrency(overview.totalDebt),
            valueColor: const Color(0xFFF59E0B),
          ),
          FinMetricRow(
            label: 'Bu hafta yaklaşan',
            value: '${overview.upcomingPayments} kayıt',
            valueColor: const Color(0xFF3B82F6),
          ),
          FinMetricRow(
            label: 'Gecikmiş kalemler',
            value: '${overview.overduePayments + overview.overdueDebts} kayıt',
            valueColor: const Color(0xFFDC2626),
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulePanel() {
    return FinSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ödeme Takvimi',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (_loadingExtras && _paymentSchedule.isEmpty)
            const SizedBox(
              height: 110,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_paymentSchedule.isEmpty)
            const Text(
              'Yakın vade bulunmuyor.',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            )
          else
            ..._paymentSchedule.map(_scheduleRow),
        ],
      ),
    );
  }

  Widget _scheduleRow(Map<String, dynamic> item) {
    final dueDate = item['due_date'] as DateTime;
    final amount = (item['amount'] as num?)?.toDouble() ?? 0;
    final isOverdue = item['is_overdue'] == true;
    final color = isOverdue ? const Color(0xFFEF4444) : const Color(0xFF3B82F6);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item['type'] == 'debt'
                  ? Icons.credit_card_rounded
                  : Icons.receipt_long_rounded,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title']?.toString() ?? '-',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item['description'] ?? ''} • ${fmtDate(dueDate)}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            fmtCurrency(amount),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyPanel() {
    final settings = _companySettings;
    return FinSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Banka / Kurumsal Bilgi',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          FinMetricRow(label: 'Şirket', value: settings?.companyName ?? '-'),
          FinMetricRow(label: 'Vergi No', value: settings?.taxNumber ?? '-'),
          FinMetricRow(
            label: 'Vergi Dairesi',
            value: settings?.taxOffice ?? '-',
          ),
          FinMetricRow(
            label: 'Para Birimi',
            value: settings?.defaultCurrency ?? 'TRY',
          ),
          FinMetricRow(
            label: 'Komisyon Oranı',
            value:
                '%${(((settings?.platformCommissionRate ?? 0) * 100)).toStringAsFixed(1)}',
            valueColor: const Color(0xFF7C3AED),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthPanel(FinanceOverview overview) {
    return FinSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Finans Sağlığı',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Center(
            child: FinHealthGauge(
              score: overview.healthScore,
              color: overview.healthColor,
              label: overview.healthLabel,
            ),
          ),
          const SizedBox(height: 12),
          FinMetricRow(
            label: 'Net pozisyon',
            value: fmtCurrency(overview.monthNetIncome),
            valueColor: overview.monthNetIncome >= 0
                ? const Color(0xFF10B981)
                : const Color(0xFFEF4444),
          ),
          FinMetricRow(
            label: 'Likidite',
            value: fmtCurrency(overview.totalLiquidity),
            valueColor: kFinancePrimary,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    return FinSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'İşlem Geçmişi / Rapor Alanı',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (_loadingExtras && _recentActivities.isEmpty)
            const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_recentActivities.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Henüz işlem kaydı bulunmuyor.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ),
            )
          else ...[
            ..._recentActivities.map(_activityRow),
            if (_expenseSummary.isNotEmpty) ...[
              const Divider(height: 20, color: kFinanceDivider),
              const Text(
                'Bu Ay Gider Dağılımı',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              ..._buildExpenseBreakdownRows(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _activityRow(Map<String, dynamic> item) {
    final amount = (item['amount'] as num?)?.toDouble() ?? 0;
    final date = item['date'] as DateTime;
    final color = item['color'] as Color;
    final icon = item['icon'] as IconData;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title']?.toString() ?? '-',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item['tag'] ?? ''} • ${item['subtitle'] ?? ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${amount >= 0 ? '+' : '-'}${fmtCurrency(amount.abs())}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: amount >= 0 ? const Color(0xFF10B981) : color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                fmtDate(date),
                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildExpenseBreakdownRows() {
    final total = _expenseSummary.values.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    final rows = _expenseSummary.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return rows
        .take(4)
        .map((entry) {
          final ratio = total == 0 ? 0.0 : entry.value / total;
          final label = ExpenseCategory.fromValue(entry.key).label;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                    Text(
                      '${(ratio * 100).toStringAsFixed(1)}% • ${fmtCurrency(entry.value)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: kFinancePrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      kFinancePrimary,
                    ),
                  ),
                ),
              ],
            ),
          );
        })
        .toList(growable: false);
  }

  Widget _buildSectionSwitcher() {
    return FinSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Muhasebe Modülleri',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Text(
                'Hızlı İşlemler',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildGlobalQuickActions(),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_tabs.length, (index) {
              final tab = _tabs[index];
              return FinSectionSwitchChip(
                label: tab.label,
                icon: tab.icon,
                selected: _selectedIndex == index,
                onTap: () => setState(() => _selectedIndex = index),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalQuickActions() {
    return FinMiniToolbar(
      embedded: true,
      children: [
        FinToolbarAction(
          label: '+ Gelir',
          icon: Icons.add_chart_rounded,
          onTap: () => _dispatchQuickAction(FinanceQuickActions.incomeAdd),
          primary: true,
        ),
        FinToolbarAction(
          label: '+ Gider',
          icon: Icons.add_card_rounded,
          onTap: () => _dispatchQuickAction(FinanceQuickActions.expenseAdd),
        ),
        FinToolbarAction(
          label: '+ Borç',
          icon: Icons.credit_card_rounded,
          onTap: () => _dispatchQuickAction(FinanceQuickActions.debtAdd),
        ),
        FinToolbarAction(
          label: '+ Maaş',
          icon: Icons.payments_rounded,
          onTap: () =>
              _dispatchQuickAction(FinanceQuickActions.salaryAddRecord),
        ),
        FinToolbarAction(
          label: '+ Ödeme',
          icon: Icons.payment_rounded,
          onTap: _showPaymentQuickSheet,
        ),
        FinToolbarAction(
          label: '+ Kasa Hareketi',
          icon: Icons.swap_horiz_rounded,
          onTap: _showCashQuickSheet,
        ),
      ],
    );
  }

  void _dispatchQuickAction(
    String action, {
    Map<String, dynamic> payload = const {},
  }) {
    final tabIndex = FinanceQuickActions.tabIndexFor(action);
    if (tabIndex != null && _selectedIndex != tabIndex) {
      setState(() => _selectedIndex = tabIndex);
    }
    context.read<FinanceProvider>().triggerQuickAction(
      action,
      payload: payload,
    );
  }

  void _showPaymentQuickSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.credit_card_rounded,
                color: Color(0xFFEF4444),
              ),
              title: const Text('Borç Ödemesi Başlat'),
              subtitle: const Text('Açık borç kaydını seçip ödeme oluştur'),
              onTap: () {
                Navigator.pop(sheetContext);
                _dispatchQuickAction(FinanceQuickActions.paymentDebt);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.local_shipping_rounded,
                color: Color(0xFFF97316),
              ),
              title: const Text('Tedarikçi Ödemesi'),
              subtitle: const Text('Tedarikçi tipindeki borçları filtrele'),
              onTap: () {
                Navigator.pop(sheetContext);
                _dispatchQuickAction(
                  FinanceQuickActions.paymentSupplier,
                  payload: const {'debtType': 'supplier'},
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.people_alt_rounded,
                color: Color(0xFF8B5CF6),
              ),
              title: const Text('Maaş Ödemesi Başlat'),
              subtitle: const Text('Açık maaş kayıtlarına toplu ödeme aç'),
              onTap: () {
                Navigator.pop(sheetContext);
                _dispatchQuickAction(FinanceQuickActions.paymentSalary);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.receipt_long_rounded,
                color: Color(0xFF0EA5E9),
              ),
              title: const Text('Gider Ödemesi'),
              subtitle: const Text('Bekleyen gideri seçip ödenmiş işaretle'),
              onTap: () {
                Navigator.pop(sheetContext);
                _dispatchQuickAction(FinanceQuickActions.paymentExpense);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.arrow_circle_up_rounded,
                color: Color(0xFFEF4444),
              ),
              title: const Text('Kasa Çıkışı'),
              subtitle: const Text('Serbest ödeme veya kasadan çıkış kaydı'),
              onTap: () {
                Navigator.pop(sheetContext);
                _dispatchQuickAction(FinanceQuickActions.paymentCashOutflow);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.compare_arrows_rounded,
                color: Color(0xFF3B82F6),
              ),
              title: const Text('Banka Transferi'),
              subtitle: const Text('Transfer tipi kasa hareketi başlat'),
              onTap: () {
                Navigator.pop(sheetContext);
                _dispatchQuickAction(FinanceQuickActions.paymentBankTransfer);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCashQuickSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.arrow_circle_down_rounded,
                color: Color(0xFF10B981),
              ),
              title: const Text('Kasa Girişi'),
              onTap: () {
                Navigator.pop(sheetContext);
                _dispatchQuickAction(FinanceQuickActions.cashInflow);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.arrow_circle_up_rounded,
                color: Color(0xFFEF4444),
              ),
              title: const Text('Kasa Çıkışı'),
              onTap: () {
                Navigator.pop(sheetContext);
                _dispatchQuickAction(FinanceQuickActions.cashOutflow);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.compare_arrows_rounded,
                color: Color(0xFF3B82F6),
              ),
              title: const Text('Transfer'),
              onTap: () {
                Navigator.pop(sheetContext);
                _dispatchQuickAction(FinanceQuickActions.cashTransfer);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.rule_folder_rounded,
                color: Color(0xFFF59E0B),
              ),
              title: const Text('Düzeltme'),
              onTap: () {
                Navigator.pop(sheetContext);
                _dispatchQuickAction(FinanceQuickActions.cashCorrection);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.badge_rounded,
                color: Color(0xFF8B5CF6),
              ),
              title: const Text('Avans'),
              onTap: () {
                Navigator.pop(sheetContext);
                _dispatchQuickAction(FinanceQuickActions.cashAdvance);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_rounded, color: Color(0xFFF97316)),
              title: const Text('Borç Ödeme Bağlantısı'),
              onTap: () {
                Navigator.pop(sheetContext);
                _dispatchQuickAction(FinanceQuickActions.cashDebtPaymentLink);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionContent(bool isDesktop) {
    return FinSurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
            child: Row(
              children: [
                Icon(
                  _tabs[_selectedIndex].icon,
                  size: 18,
                  color: kFinancePrimary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _tabs[_selectedIndex].label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: kFinanceDivider),
          SizedBox(
            height: isDesktop ? 680 : 620,
            child: IndexedStack(
              index: _selectedIndex,
              children: const [
                OverviewTab(embedded: true),
                CashTab(),
                IncomeTab(),
                ExpenseTab(),
                DebtTab(),
                SalaryTab(),
                PaymentsTab(),
                ReconciliationTab(),
                ReportsTab(),
                SettingsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
