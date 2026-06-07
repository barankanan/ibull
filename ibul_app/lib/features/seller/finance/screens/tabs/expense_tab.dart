import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../finance_quick_actions.dart';
import '../../models/finance_models.dart';
import '../../providers/finance_provider.dart';
import '../../widgets/finance_widgets.dart';

class ExpenseTab extends StatefulWidget {
  const ExpenseTab({super.key});

  @override
  State<ExpenseTab> createState() => _ExpenseTabState();
}

class _ExpenseTabState extends State<ExpenseTab> {
  List<Expense> _expenses = [];
  bool _loading = false;
  String? _error;
  bool? _paidFilter;
  String? _categoryFilter;
  int? _scheduledQuickActionId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_expenses.isEmpty && !_loading) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<FinanceProvider>().repo;
      _expenses = await repo.getExpenses(
        paid: _paidFilter,
        category: _categoryFilter,
      );
      setState(() {});
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  double get _totalAmount => _expenses.fold(0, (s, e) => s + e.amount);
  double get _paidAmount =>
      _expenses.where((e) => e.isPaid).fold(0, (s, e) => s + e.amount);
  double get _unpaidAmount =>
      _expenses.where((e) => !e.isPaid).fold(0, (s, e) => s + e.amount);
  int get _overdueCount => _expenses.where((e) => e.isOverdue).length;

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
                  : _expenses.isEmpty
                      ? FinEmptyState(
                          message: 'Gider kaydı bulunamadı',
                          icon: Icons.trending_down_outlined,
                          action: () => _showAddDialog(context),
                          actionLabel: 'Gider Ekle',
                        )
                      : _buildList(),
        ),
        FinAddButton(label: 'Gider Ekle', onTap: () => _showAddDialog(context)),
      ],
    );
  }

  void _handleQuickActions(FinanceProvider fp) {
    final event = fp.quickAction;
    if (event == null || _scheduledQuickActionId == event.id) return;
    if (!FinanceQuickActions.expenseTabActions.contains(event.action)) return;
    _scheduledQuickActionId = event.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final accepted = fp.consumeQuickAction(event.id);
      _scheduledQuickActionId = null;
      if (!accepted) return;
      if (event.action == FinanceQuickActions.expenseAdd) {
        _showAddDialog(context);
        return;
      }
      if (event.action == FinanceQuickActions.expenseAddPayment ||
          event.action == FinanceQuickActions.paymentExpense) {
        _showQuickPaymentDialog(context);
        return;
      }
      setState(() {
        _paidFilter = false;
        _categoryFilter = null;
      });
      _load();
    });
  }

  Widget _buildMiniToolbar() {
    return FinMiniToolbar(
      children: [
        FinToolbarAction(
          label: 'Gider Ekle',
          icon: Icons.add_rounded,
          onTap: () => _showAddDialog(context),
          primary: true,
        ),
        FinToolbarAction(
          label: 'Ödeme Ekle',
          icon: Icons.payments_rounded,
          onTap: () => _showQuickPaymentDialog(context),
        ),
        FinToolbarAction(
          label: 'Bekleyenler',
          icon: Icons.schedule_rounded,
          onTap: () {
            setState(() {
              _paidFilter = false;
              _categoryFilter = null;
            });
            _load();
          },
        ),
        FinToolbarAction(
          label: 'Gecikenler',
          icon: Icons.warning_amber_rounded,
          onTap: () {
            setState(() {
              _paidFilter = false;
              _categoryFilter = null;
            });
            _load();
          },
        ),
        FinToolbarAction(
          label: 'Tüm Giderler',
          icon: Icons.layers_clear_rounded,
          onTap: () {
            setState(() {
              _paidFilter = null;
              _categoryFilter = null;
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
      color: const Color(0xFFFFF7ED),
      child: Row(
        children: [
          Expanded(
              child: _chip('Toplam', fmtCurrency(_totalAmount),
                  const Color(0xFF92400E))),
          const SizedBox(width: 8),
          Expanded(
              child: _chip('Ödendi', fmtCurrency(_paidAmount),
                  const Color(0xFF10B981))),
          const SizedBox(width: 8),
          Expanded(
              child: _chip('Bekliyor', fmtCurrency(_unpaidAmount),
                  const Color(0xFFEF4444))),
          if (_overdueCount > 0) ...[
            const SizedBox(width: 8),
            Expanded(
                child: _chip(
                    'Gecikmiş', '$_overdueCount adet', const Color(0xFFDC2626))),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, String value, Color color) {
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
          _fc('Tümü', _paidFilter == null && _categoryFilter == null, () {
            setState(() {
              _paidFilter = null;
              _categoryFilter = null;
            });
            _load();
          }),
          const SizedBox(width: 6),
          _fc('Ödenmedi', _paidFilter == false, () {
            setState(() {
              _paidFilter = false;
              _categoryFilter = null;
            });
            _load();
          }),
          const SizedBox(width: 6),
          _fc('Gecikmiş', false, () {
            // filter: overdue (unpaid & due in past)
            setState(() {
              _paidFilter = false;
              _categoryFilter = null;
            });
            _load();
          }),
          const SizedBox(width: 6),
          for (final c in ExpenseCategory.values) ...[
            _fc(c.label, _categoryFilter == c.value, () {
              setState(() {
                _paidFilter = null;
                _categoryFilter = c.value;
              });
              _load();
            }),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _fc(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF97316) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? const Color(0xFFF97316) : kFinanceDivider),
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
        itemCount: _expenses.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, indent: 54, color: kFinanceDivider),
        itemBuilder: (_, i) => _expenseTile(_expenses[i]),
      ),
    );
  }

  Widget _expenseTile(Expense e) {
    final overdue = e.isOverdue;
    final color = e.isPaid
        ? const Color(0xFF10B981)
        : overdue
            ? const Color(0xFFEF4444)
            : const Color(0xFFF59E0B);

    return ListTile(
      dense: true,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.trending_down_rounded, color: color, size: 16),
      ),
      title: Row(
        children: [
          Text(e.category.label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          FinStatusBadge(
            label: e.isPaid ? 'Ödendi' : overdue ? 'Gecikmiş' : 'Bekliyor',
            color: color,
          ),
        ],
      ),
      subtitle: Text(
        [
          fmtDate(e.expenseDate),
          if (e.dueDate != null) 'Vade: ${fmtDate(e.dueDate!)}',
          if (e.supplierName != null) e.supplierName!,
          if (e.description != null) e.description!,
        ].join('  '),
        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        fmtCurrency(e.amount),
        style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w800, color: color),
      ),
      onTap: () => _showActionSheet(e),
    );
  }

  void _showActionSheet(Expense e) {
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
                  borderRadius: BorderRadius.circular(2)),
            ),
            if (!e.isPaid)
              ListTile(
                leading: const Icon(Icons.check_circle_outline,
                    color: Color(0xFF10B981)),
                title: const Text('Ödendi İşaretle'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final fp = context.read<FinanceProvider>();
                    await fp.repo.markExpensePaid(e.id, null);
                    _load();
                    fp.loadOverview();
                  } catch (err) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$err')));
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
                  await fp.repo.deleteExpense(e.id);
                  _load();
                  fp.loadOverview();
                } catch (err) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$err')));
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
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final dueDateCtrl = TextEditingController();
    var selectedCategory = ExpenseCategory.other;
    var isPaid = false;
    DateTime? selectedDueDate;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Gider Ekle',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<ExpenseCategory>(
                  initialValue: selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Kategori',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  items: ExpenseCategory.values
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.label,
                                style: const TextStyle(fontSize: 13)),
                          ))
                      .toList(),
                  onChanged: (v) => ss(() => selectedCategory = v!),
                ),
                const SizedBox(height: 10),
                FinTextField(
                  controller: amountCtrl,
                  label: 'Tutar',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  prefixText: '₺',
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      ss(() {
                        selectedDueDate = picked;
                        dueDateCtrl.text = fmtDate(picked);
                      });
                    }
                  },
                  child: AbsorbPointer(
                    child: FinTextField(
                      controller: dueDateCtrl,
                      label: 'Vade Tarihi (opsiyonel)',
                      hint: 'Seçmek için dokunun',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FinTextField(
                    controller: descCtrl, label: 'Açıklama', maxLines: 2),
                const SizedBox(height: 6),
                SwitchListTile(
                  value: isPaid,
                  onChanged: (v) => ss(() => isPaid = v),
                  title: const Text('Ödendi',
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
      final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
      if (amount == null || amount <= 0) return;
      try {
        if (!context.mounted) return;
        final fp = context.read<FinanceProvider>();
        final expense = Expense(
          id: '',
          sellerId: fp.sellerId,
          category: selectedCategory,
          amount: amount,
          isPaid: isPaid,
          dueDate: selectedDueDate,
          description: descCtrl.text.trim().isNotEmpty
              ? descCtrl.text.trim()
              : null,
          expenseDate: DateTime.now(),
          createdAt: DateTime.now(),
        );
        await fp.repo.createExpense(expense);
        _load();
        fp.loadOverview();
      } catch (e) {
        if (!context.mounted) return;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _showQuickPaymentDialog(BuildContext context) async {
    final unpaidExpenses = _expenses.where((expense) => !expense.isPaid).toList(growable: false);
    final cashAccounts = context.read<FinanceProvider>().cashAccounts;
    if (unpaidExpenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ödeme yapılacak bekleyen gider bulunamadı.')),
      );
      return;
    }

    Expense selectedExpense = unpaidExpenses.first;
  CashAccount? selectedAccount = cashAccounts.isNotEmpty ? cashAccounts.first : null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Gider Ödemesi',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Expense>(
                initialValue: selectedExpense,
                decoration: InputDecoration(
                  labelText: 'Gider Kaydı',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: unpaidExpenses
                    .map(
                      (expense) => DropdownMenuItem<Expense>(
                        value: expense,
                        child: Text(
                          '${expense.category.label} • ${fmtCurrency(expense.amount)}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) return;
                  setModalState(() {
                    selectedExpense = value;
                  });
                },
              ),
              if (cashAccounts.isNotEmpty) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<CashAccount>(
                  initialValue: selectedAccount,
                  decoration: InputDecoration(
                    labelText: 'Çıkış Hesabı',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: cashAccounts
                      .map((account) => DropdownMenuItem<CashAccount>(
                            value: account,
                            child: Text(
                              '${account.name} • ${fmtCurrency(account.currentBalance)}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ))
                      .toList(growable: false),
                  onChanged: (value) => setModalState(() => selectedAccount = value),
                ),
              ],
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Tam ödeme tutarı: ${fmtCurrency(selectedExpense.amount)}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: kFinancePrimary),
              child: const Text('Ödendi İşaretle'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      try {
        if (!context.mounted) return;
        final fp = context.read<FinanceProvider>();
        await fp.repo.payExpense(
          expenseId: selectedExpense.id,
          accountId: selectedAccount?.id,
          description: 'Gider ödemesi • ${selectedExpense.category.label}',
        );
        _load();
        fp.loadOverview();
        if (selectedAccount != null) {
          await fp.reloadCashAccounts();
        }
      } catch (e) {
        if (!context.mounted) return;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}
