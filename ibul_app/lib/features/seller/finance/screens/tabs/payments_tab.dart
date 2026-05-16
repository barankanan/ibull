import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../finance_quick_actions.dart';
import '../../providers/finance_provider.dart';
import '../../widgets/finance_widgets.dart';

// A unified payment schedule item returned by the repository helper
class _ScheduleItem {
  final String id;
  final String type; // 'expense' | 'debt'
  final String title;
  final String? subtitle;
  final double amount;
  final DateTime dueDate;
  final bool isOverdue;
  final bool isPaid;

  const _ScheduleItem({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    required this.amount,
    required this.dueDate,
    required this.isOverdue,
    required this.isPaid,
  });
}

class PaymentsTab extends StatefulWidget {
  const PaymentsTab({super.key});

  @override
  State<PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<PaymentsTab> {
  List<Map<String, dynamic>> _raw = [];
  bool _loading = false;
  String? _error;
  int? _scheduledQuickActionId;

  DateTime _from = DateTime.now().subtract(const Duration(days: 7));
  DateTime _to = DateTime.now().add(const Duration(days: 30));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_raw.isEmpty && !_loading) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<FinanceProvider>().repo;
      _raw = await repo.getPaymentScheduleItems(from: _from, to: _to);
      setState(() {});
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  List<_ScheduleItem> get _items {
    final now = DateTime.now();
    return _raw.map((r) {
      final due = r['due_date'] is DateTime
          ? r['due_date'] as DateTime
          : DateTime.parse(r['due_date'] as String);
      final isPaid = r['is_paid'] == true;
      return _ScheduleItem(
        id: r['id'] as String,
        type: r['type'] as String,
        title: r['title'] as String? ?? r['type'],
        subtitle: r['subtitle'] as String?,
        amount: (r['amount'] as num).toDouble(),
        dueDate: due,
        isOverdue: !isPaid && due.isBefore(now),
        isPaid: isPaid,
      );
    }).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  Map<String, List<_ScheduleItem>> get _grouped {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endOfWeek = today.add(const Duration(days: 7));
    final endOf30 = today.add(const Duration(days: 30));
    final result = <String, List<_ScheduleItem>>{
      'Gecikmiş': [],
      'Bugün': [],
      'Bu Hafta': [],
      'Sonraki 30 Gün': [],
      'Ödendi': [],
    };
    for (final item in _items) {
      if (item.isPaid) {
        result['Ödendi']!.add(item);
      } else if (item.isOverdue) {
        result['Gecikmiş']!.add(item);
      } else {
        final d = DateTime(item.dueDate.year, item.dueDate.month, item.dueDate.day);
        if (d.isAtSameMomentAs(today)) {
          result['Bugün']!.add(item);
        } else if (d.isBefore(endOfWeek)) {
          result['Bu Hafta']!.add(item);
        } else if (d.isBefore(endOf30)) {
          result['Sonraki 30 Gün']!.add(item);
        }
      }
    }
    return result;
  }

  double get _totalUpcoming =>
      _items.where((i) => !i.isPaid && !i.isOverdue).fold(0, (s, i) => s + i.amount);
  double get _totalOverdue =>
      _items.where((i) => i.isOverdue).fold(0, (s, i) => s + i.amount);

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FinanceProvider>();
    _handleQuickActions(fp);

    return Column(
      children: [
        _buildSummaryBar(),
        _buildMiniToolbar(),
        _buildDateRangeBar(),
        Expanded(
          child: _loading
              ? const FinLoadingOverlay()
              : _error != null
                  ? FinErrorCard(message: _error!, onRetry: _load)
                  : _items.isEmpty
                      ? const FinEmptyState(
                          message: 'Seçili aralıkta ödeme bulunamadı',
                          icon: Icons.event_available_outlined,
                        )
                      : _buildGroupedList(),
        ),
      ],
    );
  }

  void _handleQuickActions(FinanceProvider fp) {
    final event = fp.quickAction;
    if (event == null || _scheduledQuickActionId == event.id) return;
    if (!FinanceQuickActions.paymentsTabActions.contains(event.action)) return;
    _scheduledQuickActionId = event.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final accepted = fp.consumeQuickAction(event.id);
      _scheduledQuickActionId = null;
      if (!accepted) return;
      final now = DateTime.now();
      setState(() {
        _from = event.action == FinanceQuickActions.paymentsOverdue
            ? now.subtract(const Duration(days: 30))
            : now;
        _to = event.action == FinanceQuickActions.paymentsOverdue
            ? now.add(const Duration(days: 7))
            : now.add(const Duration(days: 30));
      });
      _load();
    });
  }

  Widget _buildMiniToolbar() {
    return FinMiniToolbar(
      children: [
        FinToolbarAction(
          label: 'Gecikmişler',
          icon: Icons.warning_amber_rounded,
          onTap: () {
            final now = DateTime.now();
            setState(() {
              _from = now.subtract(const Duration(days: 30));
              _to = now.add(const Duration(days: 7));
            });
            _load();
          },
          primary: true,
        ),
        FinToolbarAction(
          label: '7 Gün',
          icon: Icons.date_range_rounded,
          onTap: () {
            final now = DateTime.now();
            setState(() {
              _from = now;
              _to = now.add(const Duration(days: 7));
            });
            _load();
          },
        ),
        FinToolbarAction(
          label: '30 Gün',
          icon: Icons.calendar_month_rounded,
          onTap: () {
            final now = DateTime.now();
            setState(() {
              _from = now;
              _to = now.add(const Duration(days: 30));
            });
            _load();
          },
        ),
        FinToolbarAction(
          label: 'Tümünü Yenile',
          icon: Icons.refresh_rounded,
          onTap: _load,
        ),
      ],
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: const Color(0xFFFFF7ED),
      child: Row(
        children: [
          Expanded(
            child: _chip('Gecikmiş', fmtCurrency(_totalOverdue),
                const Color(0xFFEF4444)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _chip('Yaklaşan', fmtCurrency(_totalUpcoming),
                const Color(0xFFF59E0B)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _chip('Toplam Kayıt', '${_items.length}',
                const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String val, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
          Text(val,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _buildDateRangeBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          const Icon(Icons.date_range_outlined, size: 14, color: Color(0xFF94A3B8)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () async {
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                initialDateRange: DateTimeRange(start: _from, end: _to),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: const ColorScheme.light(primary: kFinancePrimary),
                  ),
                  child: child!,
                ),
              );
              if (range != null) {
                setState(() {
                  _from = range.start;
                  _to = range.end;
                });
                _load();
              }
            },
            child: Text(
              '${fmtDate(_from)} – ${fmtDate(_to)}',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kFinancePrimary,
                  decoration: TextDecoration.underline),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, size: 16),
            color: const Color(0xFF94A3B8),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList() {
    final groups = _grouped;
    final groupOrder = ['Gecikmiş', 'Bugün', 'Bu Hafta', 'Sonraki 30 Gün', 'Ödendi'];
    final groupColors = {
      'Gecikmiş': const Color(0xFFEF4444),
      'Bugün': const Color(0xFF8B5CF6),
      'Bu Hafta': const Color(0xFFF59E0B),
      'Sonraki 30 Gün': const Color(0xFF3B82F6),
      'Ödendi': const Color(0xFF10B981),
    };

    return RefreshIndicator(
      color: kFinancePrimary,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: groupOrder.length,
        itemBuilder: (_, i) {
          final label = groupOrder[i];
          final items = groups[label] ?? [];
          if (items.isEmpty) return const SizedBox.shrink();
          final color = groupColors[label]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color),
                    ),
                    const Spacer(),
                    Text(
                      fmtCurrency(items.fold(0, (s, i) => s + i.amount)),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color),
                    ),
                  ],
                ),
              ),
              ...items.map((item) => _scheduleTile(item, color)),
            ],
          );
        },
      ),
    );
  }

  Widget _scheduleTile(_ScheduleItem item, Color groupColor) {
    final typeIcon =
        item.type == 'expense' ? Icons.receipt_outlined : Icons.credit_card_outlined;

    return ListTile(
      dense: true,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: groupColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(typeIcon, color: groupColor, size: 16),
      ),
      title: Text(item.title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      subtitle: Text(
        [
          fmtDate(item.dueDate),
          if (item.subtitle != null) item.subtitle!,
          item.type == 'expense' ? 'Gider' : 'Borç Ödemesi',
        ].join('  '),
        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            fmtCurrency(item.amount),
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: groupColor),
          ),
          if (item.isOverdue)
            const Text('Gecikmiş',
                style:
                    TextStyle(fontSize: 9, color: Color(0xFFEF4444))),
        ],
      ),
    );
  }
}
