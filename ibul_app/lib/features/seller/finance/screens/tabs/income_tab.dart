import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../finance_quick_actions.dart';
import '../../models/finance_models.dart';
import '../../providers/finance_provider.dart';
import '../../widgets/finance_widgets.dart';

class IncomeTab extends StatefulWidget {
  const IncomeTab({super.key});

  @override
  State<IncomeTab> createState() => _IncomeTabState();
}

class _IncomeTabState extends State<IncomeTab> {
  List<IncomeRecord> _records = [];
  bool _loading = false;
  String? _error;
  bool? _collectedFilter; // null = all, true = collected, false = pending
  String? _typeFilter;
  int? _scheduledQuickActionId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_records.isEmpty && !_loading) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<FinanceProvider>().repo;
      _records = await repo.getIncomeRecords(collected: _collectedFilter);
      if (_typeFilter != null) {
        _records = _records.where((r) => r.incomeType.value == _typeFilter).toList();
      }
      setState(() {});
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  double get _totalGross =>
      _records.fold(0, (s, r) => s + r.grossAmount);
  double get _totalNet =>
      _records.fold(0, (s, r) => s + r.netAmount);
  int get _uncollected =>
      _records.where((r) => !r.isCollected).length;

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FinanceProvider>();
    _handleQuickActions(fp);

    return Column(
      children: [
        _buildSummaryBar(),
        _buildMiniToolbar(),
        _buildFilterBar(),
        Expanded(
          child: _loading
              ? const FinLoadingOverlay()
              : _error != null
                  ? FinErrorCard(message: _error!, onRetry: _load)
                  : _records.isEmpty
                      ? FinEmptyState(
                          message: 'Gelir kaydı bulunamadı',
                          icon: Icons.trending_up_outlined,
                          action: () => _showAddDialog(context),
                          actionLabel: 'Gelir Ekle',
                        )
                      : _buildList(),
        ),
        FinAddButton(label: 'Gelir Ekle', onTap: () => _showAddDialog(context)),
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
        _showAddDialog(context);
        return;
      }
      setState(() {
        if (event.action == FinanceQuickActions.incomePending) {
            _collectedFilter = false;
            _typeFilter = null;
        } else {
          _collectedFilter = null;
          _typeFilter = null;
        }
      });
      _load();
    });
  }

  Widget _buildMiniToolbar() {
    return FinMiniToolbar(
      children: [
        FinToolbarAction(
          label: 'Gelir Ekle',
          icon: Icons.add_rounded,
          onTap: () => _showAddDialog(context),
          primary: true,
        ),
        FinToolbarAction(
          label: 'Bekleyenler',
          icon: Icons.schedule_rounded,
          onTap: () {
            setState(() {
              _collectedFilter = false;
              _typeFilter = null;
            });
            _load();
          },
        ),
        FinToolbarAction(
          label: 'Tahsil Edildi',
          icon: Icons.check_circle_outline_rounded,
          onTap: () {
            setState(() {
              _collectedFilter = true;
              _typeFilter = null;
            });
            _load();
          },
        ),
        FinToolbarAction(
          label: 'Filtre Temizle',
          icon: Icons.filter_alt_off_rounded,
          onTap: () {
            setState(() {
              _collectedFilter = null;
              _typeFilter = null;
            });
            _load();
          },
        ),
      ],
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFFF0FDF4),
      child: Row(
        children: [
          Expanded(
            child: _summaryChip(
                'Brüt Gelir', fmtCurrency(_totalGross), const Color(0xFF065F46)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _summaryChip(
                'Net Gelir', fmtCurrency(_totalNet), const Color(0xFF10B981)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _summaryChip(
                'Bekleyen', '$_uncollected kayıt', const Color(0xFFF59E0B)),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, String value, Color color) {
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
          Text(value,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          _filterChip('Tümü', null == _collectedFilter && _typeFilter == null,
              () {
            _collectedFilter = null;
            _typeFilter = null;
            _load();
          }),
          const SizedBox(width: 6),
          _filterChip('Tahsil Edilmedi', _collectedFilter == false, () {
            setState(() => _collectedFilter = false);
            _load();
          }),
          const SizedBox(width: 6),
          _filterChip('Tahsil Edildi', _collectedFilter == true, () {
            setState(() => _collectedFilter = true);
            _load();
          }),
          const SizedBox(width: 6),
          for (final t in IncomeType.values) ...[
            _filterChip(t.label, _typeFilter == t.value, () {
              setState(() {
                _collectedFilter = null;
                _typeFilter = t.value;
              });
              _load();
            }),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? kFinancePrimary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? kFinancePrimary : kFinanceDivider),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      color: kFinancePrimary,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: _records.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 54, color: kFinanceDivider),
        itemBuilder: (_, i) => _incomeTile(_records[i]),
      ),
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
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            fmtCurrency(r.netAmount),
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF10B981)),
          ),
          if (r.taxAmount > 0)
            Text(
              'KDV: ${fmtCurrency(r.taxAmount)}',
              style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
            ),
        ],
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
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$e')));
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
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$e')));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
    final grossCtrl = TextEditingController();
    final netCtrl = TextEditingController();
    final taxCtrl = TextEditingController(text: '0');
    final sourceCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var selectedType = IncomeType.sales;
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
                  value: selectedType,
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
                  label: 'Net Tutar',
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
                    hint: 'örn. Getir, Yemeksepeti'),
                const SizedBox(height: 10),
                FinTextField(
                    controller: descCtrl, label: 'Açıklama', maxLines: 2),
                const SizedBox(height: 10),
                SwitchListTile(
                  value: isCollected,
                  onChanged: (v) => ss(() => isCollected = v),
                  title: const Text('Tahsil Edildi',
                      style: TextStyle(fontSize: 13)),
                  activeColor: kFinancePrimary,
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
