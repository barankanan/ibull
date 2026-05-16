import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/finance_models.dart';
import '../../providers/finance_provider.dart';
import '../../widgets/finance_widgets.dart';

class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  final _now = DateTime.now();
  late int _month;
  late int _year;

  Map<String, double> _categoryBreakdown = {};
  bool _loadingBreakdown = false;

  @override
  void initState() {
    super.initState();
    _month = _now.month;
    _year = _now.year;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_categoryBreakdown.isEmpty && !_loadingBreakdown) {
      _loadBreakdown();
    }
  }

  Future<void> _loadBreakdown() async {
    setState(() => _loadingBreakdown = true);
    try {
      final repo = context.read<FinanceProvider>().repo;
      _categoryBreakdown = await repo.getExpenseSummaryByCategory(
          year: _year, month: _month);
      setState(() {});
    } finally {
      setState(() => _loadingBreakdown = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FinanceProvider>();
    final overview = fp.overview;

    return RefreshIndicator(
      color: kFinancePrimary,
      onRefresh: () async {
        await fp.refresh();
        await _loadBreakdown();
      },
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildMonthSelector(),
          const SizedBox(height: 12),
          _buildMonthlySummary(overview),
          const SizedBox(height: 12),
          FinSectionHeader(title: 'Kategori Bazlı Giderler: ${fmtMonth(_month, _year)}'),
          const SizedBox(height: 8),
          _buildCategoryBreakdown(),
          const SizedBox(height: 12),
          if (fp.trend.isNotEmpty) _buildTrendSection(fp.trend),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            setState(() {
              if (_month == 1) {
                _month = 12;
                _year--;
              } else {
                _month--;
              }
            });
            _loadBreakdown();
          },
        ),
        GestureDetector(
          onTap: _loadBreakdown,
          child: Text(
            fmtMonth(_month, _year),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            setState(() {
              if (_month == 12) {
                _month = 1;
                _year++;
              } else {
                _month++;
              }
            });
            _loadBreakdown();
          },
        ),
      ],
    );
  }

  Widget _buildMonthlySummary(FinanceOverview? ov) {
    if (ov == null) return const SizedBox.shrink();
    return Card(
      elevation: 0,
      color: const Color(0xFFF0FDF4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FinSectionHeader(title: 'Dönem Özeti'),
            const SizedBox(height: 10),
            _summaryRow(
                'Toplam Gelir (Brüt)',
                fmtCurrency(ov.monthIncome),
                const Color(0xFF10B981)),
            _summaryRow(
                'Toplam Gider',
                fmtCurrency(ov.monthExpense),
                const Color(0xFFEF4444)),
            _summaryRow(
                'Net Gelir',
                fmtCurrency(ov.monthNetIncome),
                ov.monthIncome >= ov.monthExpense
                    ? const Color(0xFF065F46)
                    : const Color(0xFFDC2626)),
            const Divider(color: kFinanceDivider, height: 16),
            _summaryRow(
                'Aylık Maaş Yükü',
                fmtCurrency(ov.monthSalaryLoad),
                const Color(0xFF8B5CF6)),
            _summaryRow(
                'Toplam Borç',
                fmtCurrency(ov.totalDebt),
                const Color(0xFFF59E0B)),
            _summaryRow(
                'Nakit Likidite',
                fmtCurrency(ov.totalLiquidity),
                kFinancePrimary),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF64748B))),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    if (_loadingBreakdown) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_categoryBreakdown.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text('Bu ay için gider verisi bulunamadı.',
              style: TextStyle(color: Color(0xFF94A3B8))),
        ),
      );
    }

    final total = _categoryBreakdown.values.fold(0.0, (s, v) => s + v);
    final sorted = _categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final categoryColors = [
      const Color(0xFFEF4444),
      const Color(0xFFF97316),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF3B82F6),
      const Color(0xFF8B5CF6),
      const Color(0xFF14B8A6),
      const Color(0xFF6366F1),
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: kFinanceDivider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            for (int i = 0; i < sorted.length; i++) ...[
              _categoryBar(
                sorted[i].key,
                sorted[i].value,
                total,
                categoryColors[i % categoryColors.length],
              ),
              if (i < sorted.length - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _categoryBar(
      String category, double value, double total, Color color) {
    final pct = total > 0 ? value / total : 0.0;
    // Find matching enum label
    String label = category;
    try {
      label = ExpenseCategory.values
          .firstWhere((c) => c.value == category)
          .label;
    } catch (_) {}

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            Text(
              '${(pct * 100).toStringAsFixed(1)}%  ${fmtCurrency(value)}',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildTrendSection(List<MonthlyTrendPoint> trend) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          const FinSectionHeader(title: 'Aylık Trend'),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: kFinanceDivider),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    _legendDot(const Color(0xFF10B981), 'Gelir'),
                    const SizedBox(width: 12),
                    _legendDot(const Color(0xFFEF4444), 'Gider'),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 160,
                  child: FinTrendChart(
                      points: trend
                          .map((p) => (
                                label: p.label,
                                income: p.income,
                                expense: p.expense,
                              ))
                          .toList()),
                ),
              ],
            ),
          ),
        ),
      ],
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
}
