import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/restaurant_ops_models.dart';
import '../../services/store_service.dart';
import '../../services/store/table_order_history_utils.dart';
import '../../widgets/garson/garson_closed_tables_strip.dart';
import '../../widgets/garson/garson_history_detail_sheet.dart';
import '../../widgets/garson/past_tables_history_layout.dart';

/// Garson "Geçmiş Masalar" listesi — tarih gruplu responsive grid.
///
/// Veri kaynağı: [StoreService.getTableOrderHistory] (değişmedi).
/// Detay / yazdır / tekrar aç: [showGarsonHistoryDetailSheet].
class TableHistoryScreen extends StatefulWidget {
  const TableHistoryScreen({
    super.key,
    required this.sellerId,
    this.onReprint,
    this.onPrintAdisyon,
    this.onRestoreTable,
    this.onDeleteHistory,
  });

  final String sellerId;
  final void Function(TableOrderHistoryRecord record)? onReprint;
  final void Function(TableOrderHistoryRecord record)? onPrintAdisyon;
  final Future<bool> Function(TableOrderHistoryRecord record)? onRestoreTable;
  final Future<bool> Function(TableOrderHistoryRecord record)? onDeleteHistory;

  @override
  State<TableHistoryScreen> createState() => _TableHistoryScreenState();
}

class _TableHistoryScreenState extends State<TableHistoryScreen> {
  final StoreService _storeService = StoreService();

  GarsonHistoryPeriod _period = GarsonHistoryPeriod.today;
  DateTimeRange? _customRange;

  List<TableOrderHistoryRecord> _records = const [];
  bool _isLoading = false;
  String? _error;

  static const _pageSize = 50;
  int _offset = 0;
  bool _hasMore = true;

  static final _dateFmt = DateFormat('d MMM HH:mm');

  @override
  void initState() {
    super.initState();
    _loadHistory();
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
          end: TableOrderHistoryUtils.endOfLocalDay(today),
        );
      case GarsonHistoryPeriod.month:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 29)),
          end: TableOrderHistoryUtils.endOfLocalDay(today),
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

  Future<void> _loadHistory({bool reset = true}) async {
    if (_isLoading) return;
    if (reset) {
      _offset = 0;
      _hasMore = true;
    }
    setState(() {
      _isLoading = true;
      _error = null;
      if (reset) _records = const [];
    });
    try {
      final range = _periodRange();
      final rawRows = await _storeService.getTableOrderHistory(
        sellerId: widget.sellerId,
        fromDate: range.start,
        toDate: range.end,
        limit: _pageSize,
        offset: _offset,
      );
      final parsed = rawRows
          .map(TableOrderHistoryRecord.fromMap)
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _records = reset ? parsed : [..._records, ...parsed];
        _hasMore = parsed.length >= _pageSize;
        _offset += parsed.length;
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
      onPrintAdisyon: widget.onPrintAdisyon != null
          ? () => widget.onPrintAdisyon!(record)
          : null,
      onPrintKitchen: widget.onReprint != null
          ? () => widget.onReprint!(record)
          : null,
      onRestoreTable: widget.onRestoreTable != null
          ? () => widget.onRestoreTable!(record)
          : null,
    );
  }

  Future<void> _confirmDelete(TableOrderHistoryRecord record) async {
    if (widget.onDeleteHistory == null || record.id.isEmpty) return;
    final label = TableOrderHistoryUtils.tableLabel(record.toMap());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Geçmiş kaydı silinsin mi?'),
        content: Text(
          '$label için bu kapanış kaydı kalıcı olarak silinecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final deleted = await widget.onDeleteHistory!(record);
    if (!mounted) return;
    if (deleted) {
      setState(() {
        _records = _records
            .where((entry) => entry.id != record.id)
            .toList(growable: false);
      });
      await _loadHistory();
    }
  }

  Widget _buildHistoryCard(TableOrderHistoryRecord record) {
    return GarsonClosedTableCard(
      layout: GarsonClosedTableCardLayout.grid,
      record: record,
      dateFmt: _dateFmt,
      formatMoney: _formatMoney,
      onTap: () => _openDetail(record),
      onPrintAdisyon: widget.onPrintAdisyon != null
          ? () => widget.onPrintAdisyon!(record)
          : null,
      onPrintKitchen: widget.onReprint != null
          ? () => widget.onReprint!(record)
          : null,
      onDelete: widget.onDeleteHistory == null
          ? null
          : () => unawaited(_confirmDelete(record)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Geçmiş Masalar',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _isLoading ? null : () => _loadHistory(),
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFilterBar(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final period in GarsonHistoryPeriod.values)
              if (period != GarsonHistoryPeriod.custom)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: PastTablesPeriodChip(
                    label: period.label,
                    selected: _period == period,
                    onTap: () {
                      if (_period == period) return;
                      setState(() => _period = period);
                      _loadHistory();
                    },
                  ),
                ),
            PastTablesPeriodChip(
              label: _period == GarsonHistoryPeriod.custom &&
                      _customRange != null
                  ? '${DateFormat('d MMM').format(_customRange!.start)} – ${DateFormat('d MMM').format(_customRange!.end)}'
                  : 'Tarih Seç',
              selected: _period == GarsonHistoryPeriod.custom,
              onTap: _pickCustomDateRange,
              icon: Icons.date_range_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading && _records.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null && _records.isEmpty) {
      final isTableMissing = _error!.contains('42P01') ||
          _error!.contains('does not exist') ||
          _error!.contains('Could not find table');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isTableMissing
                    ? Icons.receipt_long_outlined
                    : Icons.error_outline,
                size: 40,
                color: isTableMissing
                    ? const Color(0xFFCBD5E1)
                    : const Color(0xFFDC2626),
              ),
              const SizedBox(height: 10),
              Text(
                isTableMissing
                    ? 'Henüz geçmiş masa yok.'
                    : 'Geçmiş masalar yüklenemedi.',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _loadHistory(),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }
    if (_records.isEmpty) {
      return const Center(
        child: Text(
          'Seçilen dönemde kapatılmış masa yok.',
          style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        PastTablesGroupedSections(
          records: _records,
          cardBuilder: _buildHistoryCard,
        ),
        if (_hasMore) ...[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : () => _loadHistory(reset: false),
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_rounded, size: 18),
              label: Text(_isLoading ? 'Yükleniyor…' : 'Daha Fazla Yükle'),
            ),
          ),
        ],
      ],
    );
  }
}
