import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/restaurant_ops_models.dart';
import '../../services/store/table_order_history_utils.dart';
import '../../services/store_service.dart';
import 'garson_history_detail_sheet.dart';

enum GarsonHistoryPeriod { today, week, month, custom }

extension GarsonHistoryPeriodLabel on GarsonHistoryPeriod {
  String get label {
    switch (this) {
      case GarsonHistoryPeriod.today:
        return 'Bugün';
      case GarsonHistoryPeriod.week:
        return 'Hafta';
      case GarsonHistoryPeriod.month:
        return '30 Gün';
      case GarsonHistoryPeriod.custom:
        return 'Tarih Seç';
    }
  }
}

/// Compact closed-table history strip for the garson board top area.
class GarsonClosedTablesStrip extends StatefulWidget {
  const GarsonClosedTablesStrip({
    super.key,
    required this.sellerId,
    this.onPrintAdisyon,
    this.onPrintKitchen,
    this.onRestoreTable,
    this.onSeeAll,
    this.refreshToken = 0,
  });

  final String sellerId;
  final void Function(TableOrderHistoryRecord record)? onPrintAdisyon;
  final void Function(TableOrderHistoryRecord record)? onPrintKitchen;
  final Future<bool> Function(TableOrderHistoryRecord record)? onRestoreTable;
  final VoidCallback? onSeeAll;
  final int refreshToken;

  @override
  State<GarsonClosedTablesStrip> createState() =>
      _GarsonClosedTablesStripState();
}

class _GarsonClosedTablesStripState extends State<GarsonClosedTablesStrip> {
  final StoreService _storeService = StoreService();
  GarsonHistoryPeriod _period = GarsonHistoryPeriod.today;
  DateTimeRange? _customRange;
  List<TableOrderHistoryRecord> _records = const [];
  bool _isLoading = false;
  String? _error;

  static final _dateFmt = DateFormat('d MMM HH:mm');
  static const _cardWidth = 220.0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void didUpdateWidget(covariant GarsonClosedTablesStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sellerId != widget.sellerId ||
        oldWidget.refreshToken != widget.refreshToken) {
      _loadHistory();
    }
  }

  DateTimeRange _periodRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_period) {
      case GarsonHistoryPeriod.today:
        return DateTimeRange(
          start: today,
          end: TableOrderHistoryUtils.endOfLocalDay(today),
        );
      case GarsonHistoryPeriod.week:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: today.add(const Duration(days: 1)),
        );
      case GarsonHistoryPeriod.month:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 29)),
          end: today.add(const Duration(days: 1)),
        );
      case GarsonHistoryPeriod.custom:
        return _customRange ??
            DateTimeRange(
              start: today,
              end: today.add(const Duration(days: 1)),
            );
    }
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _customRange,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      locale: const Locale('tr'),
      helpText: 'Tarih Aralığı Seç',
      cancelText: 'Vazgeç',
      confirmText: 'Uygula',
      saveText: 'Uygula',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _customRange = DateTimeRange(
        start: picked.start,
        end: DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        ),
      );
      _period = GarsonHistoryPeriod.custom;
    });
    await _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (widget.sellerId.isEmpty || _isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final range = _periodRange();
      final rows = await _storeService.getTableOrderHistory(
        sellerId: widget.sellerId,
        fromDate: range.start,
        toDate: range.end,
        limit: 24,
      );
      if (!mounted) return;
      setState(() {
        _records = rows
            .map(TableOrderHistoryRecord.fromMap)
            .toList(growable: false);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatMoney(double value) =>
      '${value.toStringAsFixed(2).replaceAll('.', ',')} ₺';

  void _openDetail(TableOrderHistoryRecord record) {
    showGarsonHistoryDetailSheet(
      context: context,
      record: record,
      onPrintAdisyon: widget.onPrintAdisyon == null
          ? null
          : () => widget.onPrintAdisyon!(record),
      onPrintKitchen: widget.onPrintKitchen == null
          ? null
          : () => widget.onPrintKitchen!(record),
      onRestoreTable: widget.onRestoreTable == null
          ? null
          : () => widget.onRestoreTable!(record),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, size: 18, color: Color(0xFF334155)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Geçmiş Masalar',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (widget.onSeeAll != null)
                TextButton(
                  onPressed: widget.onSeeAll,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 30),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Tümü', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final period in GarsonHistoryPeriod.values)
                  if (period != GarsonHistoryPeriod.custom)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _PeriodChip(
                        label: period.label,
                        selected: _period == period,
                        onTap: () {
                          if (_period == period) return;
                          setState(() => _period = period);
                          _loadHistory();
                        },
                      ),
                    ),
                _PeriodChip(
                  label: _period == GarsonHistoryPeriod.custom &&
                          _customRange != null
                      ? '${DateFormat('d MMM').format(_customRange!.start)} – ${DateFormat('d MMM').format(_customRange!.end)}'
                      : 'Tarih Seç',
                  selected: _period == GarsonHistoryPeriod.custom,
                  onTap: _pickCustomDateRange,
                  icon: Icons.date_range_rounded,
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Yenile',
                  onPressed: _isLoading ? null : _loadHistory,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _buildBody(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null && _records.isEmpty) {
      return _EmptyHint(
        message: 'Geçmiş masalar yüklenemedi.',
        actionLabel: 'Tekrar dene',
        onAction: _loadHistory,
      );
    }
    if (_isLoading && _records.isEmpty) {
      return const SizedBox(
        height: 108,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_records.isEmpty) {
      return const _EmptyHint(
        message: 'Seçilen dönemde kapatılmış masa yok.',
      );
    }

    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _records.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final record = _records[index];
          return GarsonClosedTableCard(
            width: _cardWidth,
            record: record,
            dateFmt: _dateFmt,
            formatMoney: _formatMoney,
            onTap: () => _openDetail(record),
            onPrintAdisyon: widget.onPrintAdisyon == null
                ? null
                : () => widget.onPrintAdisyon!(record),
            onPrintKitchen: widget.onPrintKitchen == null
                ? null
                : () => widget.onPrintKitchen!(record),
          );
        },
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: selected ? Colors.white : const Color(0xFF374151)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact closed-table card shared by the garson history strip and list screen.
class GarsonClosedTableCard extends StatelessWidget {
  const GarsonClosedTableCard({
    super.key,
    this.width,
    this.compact = false,
    required this.record,
    required this.dateFmt,
    required this.formatMoney,
    required this.onTap,
    this.onPrintAdisyon,
    this.onPrintKitchen,
    this.onDelete,
  });

  /// Fixed width for horizontal strip mode. Ignored when [compact] is true.
  final double? width;

  /// Horizontal low-height layout for the history list screen.
  final bool compact;
  final TableOrderHistoryRecord record;
  final DateFormat dateFmt;
  final String Function(double) formatMoney;
  final VoidCallback onTap;
  final VoidCallback? onPrintAdisyon;
  final VoidCallback? onPrintKitchen;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final map = record.toMap();
    final tableTitle = TableOrderHistoryUtils.tableLabel(map);
    final area = record.tableAreaName ?? TableOrderHistoryUtils.areaName(map);
    final summary = TableOrderHistoryUtils.productSummary(map);
    final statusLabel = TableOrderHistoryUtils.closeStatusLabel(map);
    final openedAt = record.openedAt ?? record.createdAt;
    final closedAt = record.closedAt;

    if (compact) {
      return _buildCompactHorizontalCard(
        tableTitle: tableTitle,
        area: area,
        summary: summary,
        statusLabel: statusLabel,
        openedAt: openedAt,
        closedAt: closedAt,
      );
    }

    final card = Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
                Row(
                  children: [
                    if (onDelete != null)
                      _MiniAction(
                        icon: Icons.delete_outline_rounded,
                        tooltip: 'Sil',
                        onTap: onDelete!,
                        dense: true,
                        color: const Color(0xFFDC2626),
                      ),
                    if (onDelete != null) const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        tableTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    _StatusBadge(label: statusLabel),
                  ],
                ),
                if (area.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      area,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${dateFmt.format(openedAt)} → ${dateFmt.format(closedAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatMoney(record.grandTotal),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    if (onPrintAdisyon != null)
                      _MiniAction(
                        icon: Icons.receipt_long_outlined,
                        tooltip: 'Adisyon',
                        onTap: onPrintAdisyon!,
                      ),
                    if (onPrintKitchen != null)
                      _MiniAction(
                        icon: Icons.print_outlined,
                        tooltip: 'Mutfak',
                        onTap: onPrintKitchen!,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    if (width != null) {
      return SizedBox(width: width, child: card);
    }
    return card;
  }

  Widget _buildCompactHorizontalCard({
    required String tableTitle,
    required String area,
    required String summary,
    required String statusLabel,
    required DateTime openedAt,
    required DateTime closedAt,
  }) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tableTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        _StatusBadge(label: statusLabel, dense: true),
                      ],
                    ),
                    if (area.isNotEmpty)
                      Text(
                        area,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    Text(
                      '${dateFmt.format(openedAt)} → ${dateFmt.format(closedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatMoney(record.grandTotal),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                  if (onPrintAdisyon != null || onPrintKitchen != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onPrintAdisyon != null)
                          _MiniAction(
                            icon: Icons.receipt_long_outlined,
                            tooltip: 'Adisyon',
                            onTap: onPrintAdisyon!,
                            dense: true,
                          ),
                        if (onPrintKitchen != null)
                          _MiniAction(
                            icon: Icons.print_outlined,
                            tooltip: 'Mutfak',
                            onTap: onPrintKitchen!,
                            dense: true,
                          ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, this.dense = false});

  final String label;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 5 : 6,
        vertical: dense ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: dense ? 8 : 9,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF2563EB),
        ),
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.dense = false,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool dense;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(
        minWidth: dense ? 24 : 28,
        minHeight: dense ? 24 : 28,
      ),
      icon: Icon(
        icon,
        size: dense ? 14 : 16,
        color: color ?? const Color(0xFF64748B),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 4),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
