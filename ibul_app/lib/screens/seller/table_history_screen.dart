import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/restaurant_ops_models.dart';
import '../../services/store_service.dart';
import '../../widgets/garson/order_preview_sheet.dart';

/// Historical closed-table orders browser.
///
/// Features:
///   - Period filter: Today / Week / 30 Days / Tarih Seç (özel aralık)
///   - Waiter filter (chips from loaded records)
///   - Payment method filter (Nakit / Kart / Online / Diğer)
///   - Payment method revenue breakdown in the summary bar
///   - Tap-anywhere drill-down: items, totals, revision badge, last-edit note
///   - "Kim kapattı" row in expanded detail
///   - "(ESKİ MASA)" etiketiyle adisyon yeniden bas → [onPrintAdisyon]
///   - "(ESKİ MASA)" etiketiyle mutfak fişi yeniden bas → [onReprint]
///
/// Navigation: Admin panel → Geçmiş Masalar
class TableHistoryScreen extends StatefulWidget {
  const TableHistoryScreen({
    super.key,
    required this.sellerId,
    this.onReprint,
    this.onPrintAdisyon,
  });

  final String sellerId;

  /// Called when the user requests a kitchen reprint for a history record.
  /// The parent is responsible for dispatching the print job.
  final void Function(TableOrderHistoryRecord record)? onReprint;

  /// Called when the user requests an adisyon (receipt) reprint for a
  /// history record. The parent is responsible for dispatching the print job
  /// with the "(ESKİ MASA)" header.
  final void Function(TableOrderHistoryRecord record)? onPrintAdisyon;

  @override
  State<TableHistoryScreen> createState() => _TableHistoryScreenState();
}

class _TableHistoryScreenState extends State<TableHistoryScreen> {
  final StoreService _storeService = StoreService();

  // Filters
  _HistoryPeriod _period = _HistoryPeriod.today;
  DateTimeRange? _customRange;
  int? _filterTable;
  String? _filterWaiter;
  String? _filterPayment; // raw value e.g. 'cash', 'card', 'online', 'other'

  List<TableOrderHistoryRecord> _records = const [];
  bool _isLoading = false;
  String? _error;

  // Pagination
  static const _pageSize = 50;
  int _offset = 0;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  DateTimeRange _periodRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_period) {
      case _HistoryPeriod.today:
        return DateTimeRange(
            start: today, end: today.add(const Duration(days: 1)));
      case _HistoryPeriod.week:
        return DateTimeRange(
            start: today.subtract(const Duration(days: 6)),
            end: today.add(const Duration(days: 1)));
      case _HistoryPeriod.month:
        return DateTimeRange(
            start: today.subtract(const Duration(days: 29)),
            end: today.add(const Duration(days: 1)));
      case _HistoryPeriod.custom:
        return _customRange ??
            DateTimeRange(
                start: today, end: today.add(const Duration(days: 1)));
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
    if (picked != null && mounted) {
      // Make end date inclusive (end of day)
      final inclusiveEnd = DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
        23,
        59,
        59,
      );
      setState(() {
        _customRange = DateTimeRange(start: picked.start, end: inclusiveEnd);
        _period = _HistoryPeriod.custom;
      });
      _loadHistory();
    }
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
        tableNumber: _filterTable,
        fromDate: range.start,
        toDate: range.end,
        limit: _pageSize,
        offset: _offset,
      );
      final parsed = rawRows
          .map(TableOrderHistoryRecord.fromMap)
          .toList(growable: false);
      setState(() {
        _records = reset ? parsed : [..._records, ...parsed];
        _hasMore = parsed.length >= _pageSize;
        _offset += parsed.length;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Client-side secondary filters ─────────────────────────────────────────
  List<String> get _allWaiters {
    final names = _records
        .map((r) => r.waiterName)
        .whereType<String>()
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList(growable: false)..sort();
    return names;
  }

  List<String> get _allPayments {
    final methods = _records
        .map((r) => r.paymentMethod?.toLowerCase())
        .whereType<String>()
        .where((m) => m.isNotEmpty)
        .toSet()
        .toList(growable: false)..sort();
    return methods;
  }

  List<TableOrderHistoryRecord> get _filteredRecords {
    return _records.where((r) {
      if (_filterWaiter != null && r.waiterName != _filterWaiter) return false;
      if (_filterPayment != null &&
          (r.paymentMethod?.toLowerCase() ?? '') != _filterPayment) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  /// Revenue totals grouped by payment method (from `_filteredRecords`).
  Map<String, double> get _revenueByMethod {
    final result = <String, double>{};
    for (final r in _filteredRecords) {
      final key = r.paymentMethod?.toLowerCase() ?? 'other';
      result[key] = (result[key] ?? 0.0) + r.grandTotal;
    }
    return result;
  }

  String _formatMoney(double v) =>
      '${v.toStringAsFixed(2).replaceAll('.', ',')} ₺';

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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: _buildFilterBar(),
        ),
      ),
      body: Column(
        children: [
          if (_records.isNotEmpty) _buildSummaryBar(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1 — period chips + active table badge
          Row(
            children: [
              // Standard period chips (exclude 'custom' — it has its own button)
              ..._HistoryPeriod.values
                  .where((p) => p != _HistoryPeriod.custom)
                  .map((p) {
                final selected = _period == p;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () {
                      if (_period == p) return;
                      setState(() => _period = p);
                      _loadHistory();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF2563EB)
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
              }),
              // Custom date range picker button
              GestureDetector(
                onTap: _pickCustomDateRange,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _period == _HistoryPeriod.custom
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.date_range_rounded,
                        size: 12,
                        color: _period == _HistoryPeriod.custom
                            ? Colors.white
                            : const Color(0xFF374151),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _period == _HistoryPeriod.custom && _customRange != null
                            ? '${DateFormat('d MMM').format(_customRange!.start)} – ${DateFormat('d MMM').format(_customRange!.end)}'
                            : 'Tarih Seç',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _period == _HistoryPeriod.custom
                              ? Colors.white
                              : const Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (_filterTable != null)
                GestureDetector(
                  onTap: () {
                    setState(() => _filterTable = null);
                    _loadHistory();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Masa $_filterTable',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.close_rounded,
                            size: 14, color: Color(0xFFDC2626)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          // Row 2 — waiter + payment method secondary filters
          if (_allWaiters.isNotEmpty || _allPayments.isNotEmpty) ...[
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Waiter chips
                  ..._allWaiters.map((w) {
                    final selected = _filterWaiter == w;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () {
                          setState(
                            () => _filterWaiter =
                                selected ? null : w,
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF7C3AED)
                                : const Color(0xFFF5F3FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_outline_rounded,
                                  size: 12,
                                  color: selected
                                      ? Colors.white
                                      : const Color(0xFF7C3AED)),
                              const SizedBox(width: 4),
                              Text(
                                w,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? Colors.white
                                      : const Color(0xFF7C3AED),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  if (_allWaiters.isNotEmpty && _allPayments.isNotEmpty)
                    Container(
                      width: 1,
                      height: 20,
                      margin:
                          const EdgeInsets.symmetric(horizontal: 6),
                      color: const Color(0xFFE2E8F0),
                    ),
                  // Payment method chips
                  ..._allPayments.map((pm) {
                    final selected = _filterPayment == pm;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () {
                          setState(
                            () => _filterPayment =
                                selected ? null : pm,
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _paymentLabel(pm),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF16A34A),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _paymentLabel(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'cash':
        return 'Nakit';
      case 'card':
        return 'Kart';
      case 'online':
        return 'Online';
      case 'mixed':
        return 'Karma';
      case 'complimentary':
        return 'İkram';
      default:
        return 'Diğer';
    }
  }

  /// Top-5 products by total quantity across filtered records.
  List<MapEntry<String, int>> get _topFiveProducts {
    final counts = <String, int>{};
    for (final r in _filteredRecords) {
      for (final item in r.items) {
        final name = (item['name'] as String?) ?? 'Bilinmeyen';
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        counts[name] = (counts[name] ?? 0) + qty;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).toList(growable: false);
  }

  /// Revenue totals grouped by waiter (from `_filteredRecords`).
  Map<String, double> get _revenueByWaiter {
    final result = <String, double>{};
    for (final r in _filteredRecords) {
      final key = r.waiterName?.isNotEmpty == true ? r.waiterName! : 'Bilinmeyen';
      result[key] = (result[key] ?? 0.0) + r.grandTotal;
    }
    return result;
  }

  /// Total quantity of all items across filtered records.
  int get _totalItemCount {
    return _filteredRecords.fold(0, (sum, r) {
      return sum +
          r.items.fold<int>(
            0,
            (s, item) => s + ((item['quantity'] as num?)?.toInt() ?? 1),
          );
    });
  }

  /// Average closed-table grand total across filtered records.
  double get _avgTableTotal {
    final filtered = _filteredRecords;
    if (filtered.isEmpty) return 0.0;
    return filtered.fold(0.0, (s, r) => s + r.grandTotal) / filtered.length;
  }

  Widget _buildSummaryBar() {
    final filtered = _filteredRecords;
    final tableCount = filtered.map((r) => r.tableNumber).toSet().length;
    final total = filtered.fold(0.0, (s, r) => s + r.grandTotal);
    final byMethod = _revenueByMethod;
    final top5 = _topFiveProducts;
    final byWaiter = _revenueByWaiter;
    final avgTotal = _avgTableTotal;
    final itemCount = _totalItemCount;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── KPI row (scrollable → no overflow on narrow screens) ──────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StatChip(
                  label: 'Kayıt',
                  value: '${filtered.length}',
                  color: const Color(0xFF2563EB),
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label: 'Masa',
                  value: '$tableCount',
                  color: const Color(0xFF7C3AED),
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label: 'Ciro',
                  value: _formatMoney(total),
                  color: const Color(0xFF16A34A),
                ),
                // Average only meaningful for 2+ records
                if (filtered.length > 1) ...[
                  const SizedBox(width: 8),
                  _StatChip(
                    label: 'Ort. Adisyon',
                    value: _formatMoney(avgTotal),
                    color: const Color(0xFFEA580C),
                  ),
                ],
                // Total items sold
                if (itemCount > 0) ...[
                  const SizedBox(width: 8),
                  _StatChip(
                    label: 'Ürün',
                    value: '$itemCount adet',
                    color: const Color(0xFF0891B2),
                  ),
                ],
              ],
            ),
          ),
          // ── Payment method breakdown ──────────────────────────────────
          if (byMethod.isNotEmpty) ...[
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: byMethod.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _methodColor(e.key),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_paymentLabel(e.key)}: ${_formatMoney(e.value)}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(growable: false),
              ),
            ),
          ],
          // ── Top-5 most-sold products ──────────────────────────────────
          if (top5.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'En Çok Satılan Ürünler',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: top5.asMap().entries.map((entry) {
                  final rank = entry.key + 1;
                  final name = entry.value.key;
                  final qty = entry.value.value;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFED7AA)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$rank.',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFEA580C),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF92400E),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEA580C),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'x$qty',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(growable: false),
              ),
            ),
          ],
          // ── Waiter revenue breakdown ──────────────────────────────────
          if (byWaiter.isNotEmpty && byWaiter.length > 1) ...[
            const SizedBox(height: 8),
            const Text(
              'Garson Dökümü',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: byWaiter.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFDDD6FE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_outline_rounded,
                              size: 11, color: Color(0xFF7C3AED)),
                          const SizedBox(width: 3),
                          Text(
                            e.key,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF5B21B6),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatMoney(e.value),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF4C1D95),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(growable: false),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Color _methodColor(String method) {
    switch (method) {
      case 'cash':
        return const Color(0xFF16A34A);
      case 'card':
        return const Color(0xFF2563EB);
      case 'online':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  Widget _buildContent() {
    if (_isLoading && _records.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _records.isEmpty) {
      // If the error is about the table not existing, show a friendly empty state.
      final isTableMissing = _error!.contains('42P01') ||
          _error!.contains('does not exist') ||
          _error!.contains('Could not find table');
      if (isTableMissing) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.receipt_long_outlined,
                  size: 48, color: Color(0xFFCBD5E1)),
              const SizedBox(height: 10),
              const Text(
                'Henüz geçmiş masa yok.',
                style: TextStyle(
                    color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                'Masaları kapatınca geçmiş burada görünecek.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _loadHistory(),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        );
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: Color(0xFFDC2626), size: 36),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _loadHistory(),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }
    if (_records.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_outlined,
                size: 48, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 10),
            const Text(
              'Henüz geçmiş masa yok.',
              style: TextStyle(
                  color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Seçilen dönemde masa kapatma kaydı bulunmuyor.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final shown = _filteredRecords;
    if (shown.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_alt_off_outlined,
                size: 36, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 8),
            const Text(
              'Filtrelerle eşleşen kayıt yok.',
              style: TextStyle(
                  color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => setState(() {
                _filterWaiter = null;
                _filterPayment = null;
              }),
              child: const Text('Filtreleri Temizle'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: shown.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= shown.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: OutlinedButton(
                onPressed: () => _loadHistory(reset: false),
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Daha Fazla Yükle'),
              ),
            ),
          );
        }
        final record = shown[index];
        return _HistoryRecordCard(
          record: record,
          formatMoney: _formatMoney,
          onFilterByTable: () {
            setState(() => _filterTable = record.tableNumber);
            _loadHistory();
          },
          onPreview: () => _openHistoryPreview(record),
          onPrintAdisyon: widget.onPrintAdisyon != null
              ? () => widget.onPrintAdisyon!(record)
              : null,
          onReprint: widget.onReprint != null
              ? () => widget.onReprint!(record)
              : null,
        );
      },
    );
  }

  void _openHistoryPreview(TableOrderHistoryRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OrderPreviewSheet(
        record: OrderPreviewRecord.fromHistory(record),
        initialTab: 2, // open on Sipariş Detayı for history
        onPrintAdisyon: widget.onPrintAdisyon != null
            ? () => widget.onPrintAdisyon!(record)
            : null,
        onPrintKitchenTicket: widget.onReprint != null
            ? () => widget.onReprint!(record)
            : null,
        onResendToKitchen: widget.onReprint != null
            ? () => widget.onReprint!(record)
            : null,
      ),
    );
  }
}

class _HistoryRecordCard extends StatelessWidget {
  const _HistoryRecordCard({
    required this.record,
    required this.formatMoney,
    required this.onFilterByTable,
    this.onPreview,
    this.onPrintAdisyon,
    this.onReprint,
  });

  final TableOrderHistoryRecord record;
  final String Function(double) formatMoney;
  final VoidCallback onFilterByTable;
  /// Open the OrderPreviewSheet on the Sipariş Detayı tab.
  final VoidCallback? onPreview;
  /// Reprint the receipt (adisyon) with "(ESKİ MASA)" header.
  final VoidCallback? onPrintAdisyon;
  /// Reprint the kitchen ticket with "(ESKİ MASA)" header.
  final VoidCallback? onReprint;

  static final _dateFmt = DateFormat('d MMM yyyy');
  static final _timeFmt = DateFormat('HH:mm');

  String get _paymentBadge {
    return _TableHistoryScreenState._paymentLabel(record.paymentMethod);
  }

  /// e.g. "1 sa 23 dk"  /  "47 dk"
  String get _durationLabel {
    final d = record.sessionDuration;
    if (d.isNegative || d.inMinutes < 1) return '< 1 dk';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) return '$m dk';
    if (m == 0) return '$h sa';
    return '$h sa $m dk';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPreview,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Üst satır: Masa rozeti + ödeme + rev. + sağ üst tarih/saat
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: onFilterByTable,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'MASA',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          Text(
                            '${record.tableNumber}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              formatMoney(record.grandTotal),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _paymentBadge,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ),
                            ),
                            if (record.revision > 1) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7ED),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: const Color(0xFFFED7AA)),
                                ),
                                child: Text(
                                  'Rev.${record.revision}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFEA580C),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          record.waiterName?.isNotEmpty == true
                              ? '${record.items.length} kalem • ${record.waiterName}'
                              : '${record.items.length} kalem',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Sağ üst: kapatılma tarihi + saati (kullanıcı isteği)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _dateFmt.format(record.closedAt),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.schedule_rounded,
                              size: 11, color: Color(0xFF64748B)),
                          const SizedBox(width: 3),
                          Text(
                            _timeFmt.format(record.closedAt),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
          // ── Session duration ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(Icons.timer_outlined,
                    size: 13, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(
                  'Süre: $_durationLabel',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // ── Items list ────────────────────────────────────────────────
          ...record.items.map((item) {
            final name = item['name']?.toString() ?? '-';
            final qty = (item['quantity'] as num?)?.toInt() ?? 1;
            final price = (item['price'] as num?)?.toDouble() ?? 0.0;
            final total = price * qty;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Text(
                    '$qty×',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    formatMoney(total),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (record.items.isEmpty)
            Text(
              'Ürün detayı bulunamadı.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          // ── Grand total row ───────────────────────────────────────────
          if (record.items.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Divider(height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOPLAM',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                Text(
                  formatMoney(record.grandTotal),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ],
          // ── Last edit note ────────────────────────────────────────────
          if (record.lastEditNote != null &&
              record.lastEditNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.edit_note_rounded,
                      size: 14, color: Color(0xFFD97706)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      record.lastEditNote!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // ── Kim kapattı ───────────────────────────────────────────────
          if (record.waiterName != null &&
              record.waiterName!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline_rounded,
                    size: 13, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(
                  'Kim kapattı: ',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  record.waiterName!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ],
          // ── Quick actions ─────────────────────────────────────────────
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            children: [
              // "Adisyon Yazdır" — opens the receipt (Adisyon) tab
              if (onPrintAdisyon != null)
                GestureDetector(
                  onTap: onPrintAdisyon,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.receipt_long_rounded,
                            size: 13, color: Color(0xFF16A34A)),
                        SizedBox(width: 4),
                        Text(
                          'Adisyon Yazdır',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // "Önizle" — opens the 3-tab OrderPreviewSheet (Detay tab)
              if (onPreview != null)
                GestureDetector(
                  onTap: onPreview,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDDD6FE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.visibility_outlined,
                            size: 13, color: Color(0xFF7C3AED)),
                        SizedBox(width: 4),
                        Text(
                          'Önizle',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              GestureDetector(
                onTap: onFilterByTable,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.filter_list_rounded,
                          size: 13, color: Color(0xFF2563EB)),
                      SizedBox(width: 4),
                      Text(
                        'Bu Masayı Filtrele',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (onReprint != null)
                GestureDetector(
                  onTap: onReprint,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFFFED7AA)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.print_outlined,
                            size: 13, color: Color(0xFFEA580C)),
                        SizedBox(width: 4),
                        Text(
                          'Mutfak Fişi Yazdır',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFEA580C),
                          ),
                        ),
                      ],
                    ),
                  ),
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

// ─── Enums & helpers ─────────────────────────────────────────────────────────

enum _HistoryPeriod {
  today,
  week,
  month,
  custom;

  String get label {
    switch (this) {
      case _HistoryPeriod.today:
        return 'Bugün';
      case _HistoryPeriod.week:
        return 'Hafta';
      case _HistoryPeriod.month:
        return '30 Gün';
      case _HistoryPeriod.custom:
        return 'Özel';
    }
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
