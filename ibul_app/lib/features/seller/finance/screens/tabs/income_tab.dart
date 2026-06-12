import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../finance_quick_actions.dart';
import '../../models/finance_models.dart';
import '../../providers/finance_provider.dart';
import '../../widgets/finance_widgets.dart';

enum _SalesRange { today, month, all }

class IncomeTab extends StatefulWidget {
  const IncomeTab({super.key});

  @override
  State<IncomeTab> createState() => _IncomeTabState();
}

class _IncomeTabState extends State<IncomeTab> {
  SalesBreakdown _sales = SalesBreakdown.empty;
  List<IncomeRecord> _records = [];
  List<DailySalesPoint> _series = const [];
  bool _loading = false;
  String? _error;
  _SalesRange _range = _SalesRange.month;
  _SalesChannelFilter _channelFilter = _SalesChannelFilter.all;
  int? _scheduledQuickActionId;
  bool _loadedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedOnce && !_loading) _load();
  }

  ({DateTime? from, DateTime? to}) get _rangeBounds {
    final now = DateTime.now();
    switch (_range) {
      case _SalesRange.today:
        return (from: DateTime(now.year, now.month, now.day), to: now);
      case _SalesRange.month:
        return (from: DateTime(now.year, now.month, 1), to: now);
      case _SalesRange.all:
        return (from: null, to: null);
    }
  }

  /// Grafik için günlük aralık. "Bugün" tek bar olmasın diye son 7 gün,
  /// "Tümü" için son 30 gün gösterilir.
  ({DateTime from, DateTime to}) get _chartBounds {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_range) {
      case _SalesRange.today:
        return (from: today.subtract(const Duration(days: 6)), to: today);
      case _SalesRange.month:
        return (from: DateTime(now.year, now.month, 1), to: today);
      case _SalesRange.all:
        return (from: today.subtract(const Duration(days: 29)), to: today);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<FinanceProvider>().repo;
      final bounds = _rangeBounds;
      final chartBounds = _chartBounds;
      final results = await Future.wait([
        repo.getSalesBreakdown(from: bounds.from, to: bounds.to),
        repo.getIncomeRecords(from: bounds.from, to: bounds.to),
        repo.getDailySalesSeries(
            from: chartBounds.from, to: chartBounds.to),
      ]);
      _sales = results[0] as SalesBreakdown;
      _records = results[1] as List<IncomeRecord>;
      _series = results[2] as List<DailySalesPoint>;
      _loadedOnce = true;
      setState(() {});
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _manualNet => _records.fold(0, (s, r) => s + r.netAmount);

  List<SoldProduct> get _visibleProducts {
    switch (_channelFilter) {
      case _SalesChannelFilter.all:
        return _sales.products;
      case _SalesChannelFilter.online:
        return _sales.products.where((p) => p.online).toList(growable: false);
      case _SalesChannelFilter.garson:
        return _sales.products.where((p) => p.garson).toList(growable: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FinanceProvider>();
    _handleQuickActions(fp);

    return Column(
      children: [
        _buildRangeSelector(),
        Expanded(
          child: _loading
              ? const FinLoadingOverlay()
              : _error != null
                  ? FinErrorCard(message: _error!, onRetry: _load)
                  : RefreshIndicator(
                      color: kFinancePrimary,
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 12),
                        children: [
                          _buildSummary(),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                            child: FinSalesChart(points: _series),
                          ),
                          _buildSoldProductsSection(),
                          const Divider(height: 1, color: kFinanceDivider),
                          _buildManualIncomeSection(),
                        ],
                      ),
                    ),
        ),
        FinAddButton(label: 'Gelir Ekle', onTap: _showAddDialog),
      ],
    );
  }

  void _handleQuickActions(FinanceProvider fp) {
    final event = fp.quickAction;
    if (event == null || _scheduledQuickActionId == event.id) return;
    if (!FinanceQuickActions.incomeTabActions.contains(event.action)) return;
    _scheduledQuickActionId = event.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final accepted = fp.consumeQuickAction(event.id);
      _scheduledQuickActionId = null;
      if (!accepted) return;
      if (event.action == FinanceQuickActions.incomeAdd) {
        _showAddDialog();
      }
    });
  }

  // ── RANGE SELECTOR ────────────────────────
  Widget _buildRangeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          Expanded(
            child: SegmentedButton<_SalesRange>(
              selected: {_range},
              onSelectionChanged: (val) {
                setState(() => _range = val.first);
                _load();
              },
              segments: const [
                ButtonSegment(value: _SalesRange.today, label: Text('Bugün')),
                ButtonSegment(value: _SalesRange.month, label: Text('Bu Ay')),
                ButtonSegment(value: _SalesRange.all, label: Text('Tümü')),
              ],
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: kFinancePrimary,
                selectedForegroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── SUMMARY ───────────────────────────────
  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFFF0FDF4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _summaryChip('Online Satış', fmtCurrency(_sales.onlineRevenue),
                '${_sales.onlineOrderCount} sipariş', const Color(0xFF3B82F6)),
            const SizedBox(width: 8),
            _summaryChip('Garson Satış', fmtCurrency(_sales.garsonRevenue),
                '${_sales.garsonOrderCount} adisyon', const Color(0xFFF59E0B)),
            const SizedBox(width: 8),
            _summaryChip('Toplam Ciro', fmtCurrency(_sales.totalRevenue),
                '${_sales.totalQuantity} ürün', const Color(0xFF10B981)),
            const SizedBox(width: 8),
            _summaryChip('Manuel Gelir', fmtCurrency(_manualNet),
                '${_records.length} kayıt', kFinancePrimary),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(String label, String value, String sub, Color color) {
    return Container(
      width: 132,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          Text(sub,
              style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  // ── SOLD PRODUCTS ─────────────────────────
  Widget _buildSoldProductsSection() {
    final products = _visibleProducts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
          child: Row(
            children: [
              const Icon(Icons.inventory_2_rounded,
                  size: 16, color: kFinancePrimary),
              const SizedBox(width: 6),
              const Text('Satılan Ürünler',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              const Spacer(),
              _channelChip('Tümü', _SalesChannelFilter.all),
              const SizedBox(width: 4),
              _channelChip('Online', _SalesChannelFilter.online),
              const SizedBox(width: 4),
              _channelChip('Garson', _SalesChannelFilter.garson),
            ],
          ),
        ),
        if (products.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: Text('Bu dönemde satış kaydı yok',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 560),
              child: DataTable(
                headingRowColor:
                    WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                headingRowHeight: 40,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 52,
                horizontalMargin: 14,
                columnSpacing: 20,
                headingTextStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF475569)),
                dataTextStyle:
                    const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                columns: const [
                  DataColumn(label: Text('Ürün')),
                  DataColumn(label: Text('Kanal')),
                  DataColumn(label: Text('Adet'), numeric: true),
                  DataColumn(label: Text('Ciro'), numeric: true),
                ],
                rows: products
                    .map((p) => DataRow(cells: [
                          DataCell(SizedBox(
                            width: 180,
                            child: Text(p.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          )),
                          DataCell(_channelBadge(p.channel)),
                          DataCell(Text('${p.quantity}')),
                          DataCell(Text(
                            fmtCurrency(p.revenue),
                            style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w700),
                          )),
                        ]))
                    .toList(growable: false),
              ),
            ),
          ),
      ],
    );
  }

  Widget _channelBadge(SalesChannel channel) {
    final color = switch (channel) {
      SalesChannel.online => const Color(0xFF3B82F6),
      SalesChannel.garson => const Color(0xFFF59E0B),
      SalesChannel.both => const Color(0xFF8B5CF6),
    };
    return FinStatusBadge(label: channel.label, color: color);
  }

  Widget _channelChip(String label, _SalesChannelFilter filter) {
    final selected = _channelFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _channelFilter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? kFinancePrimary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: selected ? kFinancePrimary : kFinanceDivider),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : const Color(0xFF64748B))),
      ),
    );
  }

  // ── MANUAL INCOME RECORDS ─────────────────
  Widget _buildManualIncomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 14, 14, 6),
          child: Row(
            children: [
              Icon(Icons.edit_note_rounded, size: 16, color: kFinancePrimary),
              SizedBox(width: 6),
              Text('Manuel Gelir Kayıtları',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        if (_records.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text('Elle eklenen gelir kaydı yok',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            ),
          )
        else
          ..._records.map(_incomeTile),
      ],
    );
  }

  Widget _incomeTile(IncomeRecord r) {
    final collected = r.isCollected;
    return ListTile(
      dense: true,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.trending_up_rounded,
            color: Color(0xFF10B981), size: 16),
      ),
      title: Row(
        children: [
          Text(r.incomeType.label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          FinStatusBadge(
            label: collected ? 'Tahsil Edildi' : 'Bekliyor',
            color: collected
                ? const Color(0xFF10B981)
                : const Color(0xFFF59E0B),
          ),
        ],
      ),
      subtitle: Text(
        '${fmtDate(r.incomeDate)}  ${r.source ?? ''}  ${r.description ?? ''}',
        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        fmtCurrency(r.netAmount),
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Color(0xFF10B981)),
      ),
      onTap: () => _showActionSheet(r),
    );
  }

  void _showActionSheet(IncomeRecord r) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (!r.isCollected)
              ListTile(
                leading: const Icon(Icons.check_circle_outline,
                    color: Color(0xFF10B981)),
                title: const Text('Tahsil Edildi İşaretle'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final fp = context.read<FinanceProvider>();
                    await fp.repo.markIncomeCollected(r.id, null);
                    _load();
                    fp.loadOverview();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Sil'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  final fp = context.read<FinanceProvider>();
                  await fp.repo.deleteIncomeRecord(r.id);
                  _load();
                  fp.loadOverview();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddDialog() async {
    final grossCtrl = TextEditingController();
    final netCtrl = TextEditingController();
    final taxCtrl = TextEditingController(text: '0');
    final sourceCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var selectedType = IncomeType.other;
    var isCollected = false;
    DateTime incomeDate = DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Gelir Kaydı Ekle',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<IncomeType>(
                  initialValue: selectedType,
                  decoration: InputDecoration(
                    labelText: 'Gelir Türü',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  items: IncomeType.values
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.label,
                                style: const TextStyle(fontSize: 13)),
                          ))
                      .toList(),
                  onChanged: (v) => ss(() => selectedType = v!),
                ),
                const SizedBox(height: 10),
                FinTextField(
                  controller: grossCtrl,
                  label: 'Brüt Tutar',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  prefixText: '₺',
                ),
                const SizedBox(height: 10),
                FinTextField(
                  controller: netCtrl,
                  label: 'Net Tutar (boşsa brüt alınır)',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  prefixText: '₺',
                ),
                const SizedBox(height: 10),
                FinTextField(
                  controller: taxCtrl,
                  label: 'KDV Tutarı',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  prefixText: '₺',
                ),
                const SizedBox(height: 10),
                FinTextField(
                    controller: sourceCtrl,
                    label: 'Kaynak',
                    hint: 'örn. Getir, Yemeksepeti, Kira'),
                const SizedBox(height: 10),
                FinTextField(
                    controller: descCtrl, label: 'Açıklama', maxLines: 2),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: incomeDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) ss(() => incomeDate = picked);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Gelir Tarihi',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(fmtDate(incomeDate),
                            style: const TextStyle(fontSize: 13)),
                        const Icon(Icons.calendar_today_rounded,
                            size: 16, color: kFinancePrimary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  value: isCollected,
                  onChanged: (v) => ss(() => isCollected = v),
                  title: const Text('Tahsil Edildi',
                      style: TextStyle(fontSize: 13)),
                  activeThumbColor: kFinancePrimary,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('İptal')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style:
                  FilledButton.styleFrom(backgroundColor: kFinancePrimary),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      final gross = double.tryParse(grossCtrl.text.replaceAll(',', '.')) ?? 0;
      final net = double.tryParse(netCtrl.text.replaceAll(',', '.')) ?? gross;
      final tax = double.tryParse(taxCtrl.text.replaceAll(',', '.')) ?? 0;
      if (gross <= 0) return;
      try {
        if (!mounted) return;
        final fp = context.read<FinanceProvider>();
        final record = IncomeRecord(
          id: '',
          sellerId: fp.sellerId,
          incomeType: selectedType,
          source: sourceCtrl.text.trim().isNotEmpty
              ? sourceCtrl.text.trim()
              : null,
          grossAmount: gross,
          netAmount: net,
          taxAmount: tax,
          isCollected: isCollected,
          description: descCtrl.text.trim().isNotEmpty
              ? descCtrl.text.trim()
              : null,
          incomeDate: incomeDate,
          createdAt: DateTime.now(),
        );
        await fp.repo.createIncomeRecord(record);
        _load();
        fp.loadOverview();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }
}

enum _SalesChannelFilter { all, online, garson }
