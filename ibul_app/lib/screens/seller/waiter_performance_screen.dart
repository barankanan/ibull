import 'package:flutter/material.dart';

import '../../models/restaurant_ops_models.dart';
import '../../services/store_service.dart';

/// Waiter Performance Panel.
///
/// Shown in the Admin section (Garson Analitik).
/// Displays per-waiter KPIs, rankings, and an hourly heatmap bar chart.
class WaiterPerformanceScreen extends StatefulWidget {
  const WaiterPerformanceScreen({
    super.key,
    required this.sellerId,
  });

  final String sellerId;

  @override
  State<WaiterPerformanceScreen> createState() =>
      _WaiterPerformanceScreenState();
}

class _WaiterPerformanceScreenState extends State<WaiterPerformanceScreen> {
  final StoreService _storeService = StoreService();

  _PerfPeriod _period = _PerfPeriod.month;
  List<WaiterPerformanceRecord> _records = const [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTimeRange _periodRange() {
    final now = DateTime.now();
    switch (_period) {
      case _PerfPeriod.today:
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: now,
        );
      case _PerfPeriod.week:
        return DateTimeRange(
          start: now.subtract(const Duration(days: 6)),
          end: now,
        );
      case _PerfPeriod.month:
        return DateTimeRange(
          start: now.subtract(const Duration(days: 29)),
          end: now,
        );
    }
  }

  Future<void> _load() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final range = _periodRange();
      final rows = await _storeService.getWaiterPerformance(
        sellerId: widget.sellerId,
        fromDate: range.start,
        toDate: range.end,
      );
      setState(() {
        _records = rows
            .map(WaiterPerformanceRecord.fromMap)
            .toList(growable: false);
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatMoney(double v) =>
      '${v.toStringAsFixed(2).replaceAll('.', ',')} ₺';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Garson Performansı',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: _buildPeriodBar(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildPeriodBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Row(
        children: _PerfPeriod.values.map((p) {
          final selected = _period == p;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                if (_period == p) return;
                setState(() => _period = p);
                _load();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF7C3AED)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  p.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? Colors.white
                        : const Color(0xFF374151),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: Color(0xFFDC2626), size: 40),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _load,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }
    if (_records.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 48, color: Color(0xFFCBD5E1)),
            SizedBox(height: 10),
            Text(
              'Bu dönem için veri yok.\n(Historia tablosu boş olabilir.)',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _buildLeaderboard(),
        const SizedBox(height: 20),
        _buildRevenueChart(),
        const SizedBox(height: 20),
        _buildDetailCards(),
      ],
    );
  }

  // ── Leaderboard ─────────────────────────────────────────────────────────

  Widget _buildLeaderboard() {
    if (_records.isEmpty) return const SizedBox.shrink();
    final sorted = [..._records]
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
    final top3 = sorted.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sıralama',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (top3.length > 1)
              Expanded(
                  child: _PodiumItem(
                label: top3[1].waiterName,
                value: _formatMoney(top3[1].totalRevenue),
                rank: 2,
                height: 80,
              )),
            Expanded(
                child: _PodiumItem(
              label: top3[0].waiterName,
              value: _formatMoney(top3[0].totalRevenue),
              rank: 1,
              height: 100,
            )),
            if (top3.length > 2)
              Expanded(
                  child: _PodiumItem(
                label: top3[2].waiterName,
                value: _formatMoney(top3[2].totalRevenue),
                rank: 3,
                height: 65,
              )),
          ],
        ),
      ],
    );
  }

  // ── Bar chart ─────────────────────────────────────────────────────────────

  Widget _buildRevenueChart() {
    if (_records.isEmpty) return const SizedBox.shrink();
    final maxRevenue = _records
        .map((r) => r.totalRevenue)
        .reduce((a, b) => a > b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ciro Karşılaştırması',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              children: _records.map((record) {
                final ratio = maxRevenue > 0
                    ? record.totalRevenue / maxRevenue
                    : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          record.waiterName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Stack(
                            children: [
                              Container(
                                height: 20,
                                color: const Color(0xFFF1F5F9),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 600),
                                height: 20,
                                width: double.infinity,
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width *
                                          ratio,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF7C3AED),
                                      Color(0xFF4F46E5),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: Text(
                          _formatMoney(record.totalRevenue),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // ── Detail cards ──────────────────────────────────────────────────────────

  Widget _buildDetailCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Detaylı İstatistiler',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 10),
        ..._records.map((record) => _WaiterDetailCard(
              record: record,
              formatMoney: _formatMoney,
            )),
      ],
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _PodiumItem extends StatelessWidget {
  const _PodiumItem({
    required this.label,
    required this.value,
    required this.rank,
    required this.height,
  });

  final String label;
  final String value;
  final int rank;
  final double height;

  Color get _color {
    switch (rank) {
      case 1:
        return const Color(0xFFF59E0B);
      case 2:
        return const Color(0xFF94A3B8);
      case 3:
        return const Color(0xFFCD7C2F);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  String get _emoji {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(_emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: _color.withValues(alpha: 0.2),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: _color.withValues(alpha: 0.5)),
          ),
          child: Center(
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _color,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WaiterDetailCard extends StatelessWidget {
  const _WaiterDetailCard({
    required this.record,
    required this.formatMoney,
  });

  final WaiterPerformanceRecord record;
  final String Function(double) formatMoney;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      const Color(0xFF7C3AED).withValues(alpha: 0.1),
                  child: Text(
                    record.waiterName.isNotEmpty
                        ? record.waiterName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.waiterName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      Text(
                        '${record.orderCount} sipariş',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatMoney(record.totalRevenue),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _Kpi(
                  label: 'Ort. Hesap',
                  value: formatMoney(record.avgTicket),
                  icon: Icons.receipt_rounded,
                  color: const Color(0xFF2563EB),
                ),
                if (record.topProduct != null)
                  _Kpi(
                    label: 'En Çok',
                    value: record.topProduct!,
                    icon: Icons.star_rounded,
                    color: const Color(0xFFF59E0B),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              color: color,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

enum _PerfPeriod {
  today,
  week,
  month;

  String get label {
    switch (this) {
      case _PerfPeriod.today:
        return 'Bugün';
      case _PerfPeriod.week:
        return '7 Gün';
      case _PerfPeriod.month:
        return '30 Gün';
    }
  }
}
