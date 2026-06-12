import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../finance_quick_actions.dart';
import '../../models/finance_models.dart';
import '../../providers/finance_provider.dart';
import '../../widgets/finance_widgets.dart';

class DebtTab extends StatefulWidget {
  const DebtTab({super.key});

  @override
  State<DebtTab> createState() => _DebtTabState();
}

class _DebtTabState extends State<DebtTab> {
  List<Debt> _debts = [];
  bool _loading = false;
  String? _error;
  String? _statusFilter; // null = active+partially_paid+overdue
  int? _scheduledQuickActionId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_debts.isEmpty && !_loading) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<FinanceProvider>().repo;
      _debts = await repo.getDebts(status: _statusFilter);
      if (_statusFilter == null) {
        // default: exclude paid and cancelled
        _debts = _debts
            .where((d) => d.status != DebtStatus.paid && d.status != DebtStatus.cancelled)
            .toList();
      }
      setState(() {});
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  double get _totalRemaining =>
      _debts.fold(0, (s, d) => s + d.remainingAmount);
  int get _overdueCount =>
      _debts.where((d) => d.status == DebtStatus.overdue).length;

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FinanceProvider>();
    _handleQuickActions(fp);

    return Column(
      children: [
        _buildHeader(),
        _buildMiniToolbar(),
        _buildFilterBar(),
        Expanded(
          child: _loading
              ? const FinLoadingOverlay()
              : _error != null
                  ? FinErrorCard(message: _error!, onRetry: _load)
                  : _debts.isEmpty
                      ? FinEmptyState(
                          message: 'Borç kaydı bulunamadı',
                          icon: Icons.credit_card_outlined,
                          action: () => _showAddDebtDialog(context),
                          actionLabel: 'Borç Ekle',
                        )
                      : _buildList(),
        ),
        FinAddButton(
            label: 'Borç Ekle', onTap: () => _showAddDebtDialog(context)),
      ],
    );
  }

  void _handleQuickActions(FinanceProvider fp) {
    final event = fp.quickAction;
    if (event == null || _scheduledQuickActionId == event.id) return;
    if (!FinanceQuickActions.debtTabActions.contains(event.action)) return;
    _scheduledQuickActionId = event.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final accepted = fp.consumeQuickAction(event.id);
      _scheduledQuickActionId = null;
      if (!accepted) return;
      if (event.action == FinanceQuickActions.debtAdd) {
        _showAddDebtDialog(context);
        return;
      }
      if (event.action == FinanceQuickActions.debtAddPayment ||
          event.action == FinanceQuickActions.paymentSupplier ||
          event.action == FinanceQuickActions.paymentDebt ||
          event.action == FinanceQuickActions.cashDebtPaymentLink) {
        _showQuickPaymentDialog(context, debtType: event.payload['debtType'] as String?);
        return;
      }
      setState(() => _statusFilter = 'overdue');
      _load();
    });
  }

  Widget _buildMiniToolbar() {
    return FinMiniToolbar(
      children: [
        FinToolbarAction(
          label: 'Borç Ekle',
          icon: Icons.add_rounded,
          onTap: () => _showAddDebtDialog(context),
          primary: true,
        ),
        FinToolbarAction(
          label: 'Ödeme Ekle',
          icon: Icons.payments_rounded,
          onTap: () => _showQuickPaymentDialog(context),
        ),
        FinToolbarAction(
          label: 'Gecikenler',
          icon: Icons.warning_amber_rounded,
          onTap: () {
            setState(() => _statusFilter = 'overdue');
            _load();
          },
        ),
        FinToolbarAction(
          label: 'Aktifler',
          icon: Icons.playlist_add_check_circle_rounded,
          onTap: () {
            setState(() => _statusFilter = null);
            _load();
          },
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFFFEF2F2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Toplam Kalan Borç',
                    style:
                        TextStyle(fontSize: 11, color: Color(0xFF991B1B))),
                Text(
                  fmtCurrency(_totalRemaining),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFEF4444),
                  ),
                ),
                Text(
                  '${_debts.length} borç  •  $_overdueCount gecikmiş',
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFFFCA5A5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = [
      ('Aktif', null),
      ('Gecikmiş', 'overdue'),
      ('Kısmen Ödendi', 'partially_paid'),
      ('Tümü', '__all__'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: filters
            .map((f) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _fc(f.$1, _statusFilter == f.$2, () {
                    setState(() =>
                        _statusFilter = f.$2 == '__all__' ? null : f.$2);
                    _load();
                  }),
                ))
            .toList(),
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
          color: selected ? const Color(0xFFEF4444) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? const Color(0xFFEF4444) : kFinanceDivider),
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
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: _debts.length,
        itemBuilder: (_, i) => _debtCard(_debts[i]),
      ),
    );
  }

  Widget _debtCard(Debt d) {
    final status = d.status;
    final percent = d.paidPercent;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
            color: status.color.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showDebtDetail(context, d),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      d.creditorName,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                  FinStatusBadge(label: status.label, color: status.color),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                d.debtType.label,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kalan',
                            style: const TextStyle(
                                fontSize: 10, color: Color(0xFF94A3B8))),
                        Text(
                          fmtCurrency(d.remainingAmount),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: status.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ödenen',
                            style: const TextStyle(
                                fontSize: 10, color: Color(0xFF94A3B8))),
                        Text(
                          fmtCurrency(d.paidAmount),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Toplam',
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFF94A3B8))),
                      Text(
                        fmtCurrency(d.originalAmount),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percent / 100,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(status.color),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Başlangıç: ${fmtDate(d.startDate)}',
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF94A3B8)),
                  ),
                  if (d.dueDate != null)
                    Text(
                      'Vade: ${fmtDate(d.dueDate!)}',
                      style: TextStyle(
                          fontSize: 10,
                          color: d.status == DebtStatus.overdue
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF94A3B8)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // Debt Detail Sheet (with payment history)
  // ─────────────────────────────────────────
  void _showDebtDetail(BuildContext context, Debt d) {
    // Modal sheets attach to the root navigator/overlay, which is ABOVE the
    // ChangeNotifierProvider<FinanceProvider> created inside FinanceShell. We
    // capture the provider here (this State IS under it) and re-expose it to the
    // sheet subtree so its context.read<FinanceProvider>() calls resolve.
    final fp = context.read<FinanceProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => ChangeNotifierProvider<FinanceProvider>.value(
        value: fp,
        child: _DebtDetailSheet(debt: d, onUpdated: _load),
      ),
    );
  }

  // ─────────────────────────────────────────
  // Add Debt Dialog
  // ─────────────────────────────────────────
  Future<void> _showAddDebtDialog(BuildContext context) async {
    final creditorCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final dueDateCtrl = TextEditingController();
    var selectedType = DebtType.supplier;
    DateTime? selectedDueDate;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Borç Ekle',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<DebtType>(
                  initialValue: selectedType,
                  decoration: InputDecoration(
                    labelText: 'Borç Türü',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  items: DebtType.values
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
                    controller: creditorCtrl,
                    label: 'Alacaklı / Borçlu Olunan',
                    hint: 'örn. ABC Tedarik Ltd.'),
                const SizedBox(height: 10),
                FinTextField(
                  controller: amountCtrl,
                  label: 'Ana Tutar',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  prefixText: '₺',
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
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
                      label: 'Vade Tarihi',
                      hint: 'Seçmek için dokunun',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FinTextField(
                    controller: descCtrl, label: 'Açıklama', maxLines: 2),
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
      final creditor = creditorCtrl.text.trim();
      if (creditor.isEmpty) return;
      try {
        if (!context.mounted) return;
        final fp = context.read<FinanceProvider>();
        final debt = Debt(
          id: '',
          sellerId: fp.sellerId,
          debtType: selectedType,
          creditorName: creditor,
          originalAmount: amount,
          startDate: DateTime.now(),
          dueDate: selectedDueDate,
          status: DebtStatus.active,
          description: descCtrl.text.trim().isNotEmpty
              ? descCtrl.text.trim()
              : null,
          createdAt: DateTime.now(),
        );
        await fp.repo.createDebt(debt);
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

  Future<void> _showQuickPaymentDialog(BuildContext context, {String? debtType}) async {
    final cashAccounts = context.read<FinanceProvider>().cashAccounts;
    final payableDebts = _debts
        .where((debt) => debt.remainingAmount > 0)
        .where((debt) => debtType == null || debt.debtType.value == debtType)
        .toList(growable: false);
    if (payableDebts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ödeme eklemek için açık borç bulunamadı.')),
      );
      return;
    }

    Debt selectedDebt = payableDebts.first;
    CashAccount? selectedAccount = cashAccounts.isNotEmpty ? cashAccounts.first : null;
    final amountCtrl = TextEditingController(
      text: selectedDebt.remainingAmount.toStringAsFixed(2),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Borç Ödemesi Ekle',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Debt>(
                initialValue: selectedDebt,
                decoration: InputDecoration(
                  labelText: 'Borç Kaydı',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: payableDebts
                    .map((debt) => DropdownMenuItem<Debt>(
                          value: debt,
                          child: Text(
                            '${debt.creditorName} • ${fmtCurrency(debt.remainingAmount)}',
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) return;
                  setModalState(() {
                    selectedDebt = value;
                    amountCtrl.text = value.remainingAmount.toStringAsFixed(2);
                  });
                },
              ),
              const SizedBox(height: 10),
              FinTextField(
                controller: amountCtrl,
                label: 'Ödeme Tutarı',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                prefixText: '₺',
              ),
              if (cashAccounts.isNotEmpty) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<CashAccount>(
                  initialValue: selectedAccount,
                  decoration: InputDecoration(
                    labelText: 'Çıkış Hesabı',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: kFinancePrimary),
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
        final payment = DebtPayment(
          id: '',
          sellerId: fp.sellerId,
          debtId: selectedDebt.id,
          amount: amount,
          paymentDate: DateTime.now(),
          accountId: selectedAccount?.id,
          description: 'Borç ödemesi • ${selectedDebt.creditorName}',
          createdAt: DateTime.now(),
        );
        await fp.repo.recordDebtPayment(payment: payment);
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

// ─────────────────────────────────────────
// Debt Detail Sheet Widget
// ─────────────────────────────────────────
class _DebtDetailSheet extends StatefulWidget {
  const _DebtDetailSheet({required this.debt, required this.onUpdated});

  final Debt debt;
  final VoidCallback onUpdated;

  @override
  State<_DebtDetailSheet> createState() => _DebtDetailSheetState();
}

class _DebtDetailSheetState extends State<_DebtDetailSheet> {
  List<DebtPayment> _payments = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() => _loading = true);
    try {
      final fp = context.read<FinanceProvider>();
      _payments = await fp.repo.getDebtPayments(widget.debt.id);
      setState(() {});
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.debt;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 12),
            decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    d.creditorName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                FinStatusBadge(label: d.status.label, color: d.status.color),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _amountChip('Ana Tutar', fmtCurrency(d.originalAmount),
                    const Color(0xFF64748B)),
                const SizedBox(width: 8),
                _amountChip('Ödenen', fmtCurrency(d.paidAmount),
                    const Color(0xFF10B981)),
                const SizedBox(width: 8),
                _amountChip('Kalan', fmtCurrency(d.remainingAmount),
                    d.status.color),
              ],
            ),
          ),
          const Divider(color: kFinanceDivider),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Ödeme Geçmişi',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                TextButton.icon(
                  onPressed: () => _showAddPaymentDialog(context),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Ödeme Ekle',
                      style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                      foregroundColor: kFinancePrimary),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const FinLoadingOverlay()
                : _payments.isEmpty
                    ? const FinEmptyState(
                        message: 'Henüz ödeme yapılmadı',
                        icon: Icons.receipt_long_outlined,
                      )
                    : ListView.separated(
                        controller: ctrl,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: _payments.length,
                        separatorBuilder: (_, _) => const Divider(
                            height: 1, color: kFinanceDivider),
                        itemBuilder: (_, i) => _paymentTile(_payments[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _amountChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 9, color: Color(0xFF94A3B8))),
            Text(value,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
      ),
    );
  }

  Widget _paymentTile(DebtPayment p) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.check_circle_rounded,
          color: Color(0xFF10B981), size: 20),
      title: Text(fmtCurrency(p.amount),
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF10B981))),
      subtitle: Text(
        '${fmtDate(p.paymentDate)}  ${p.description ?? ''}',
        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
        onPressed: () async {
          final fp = context.read<FinanceProvider>();
          await fp.repo.deleteDebtPayment(p.id);
          _loadPayments();
          widget.onUpdated();
          fp.loadOverview();
        },
      ),
    );
  }

  Future<void> _showAddPaymentDialog(BuildContext context) async {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ödeme Ekle',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Kalan: ${fmtCurrency(widget.debt.remainingAmount)}',
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 10),
            FinTextField(
              controller: amountCtrl,
              label: 'Ödeme Tutarı',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              prefixText: '₺',
            ),
            const SizedBox(height: 10),
            FinTextField(
                controller: descCtrl, label: 'Açıklama', maxLines: 2),
          ],
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
    );

    if (ok == true) {
      final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
      if (amount == null || amount <= 0) return;
      try {
        if (!context.mounted) return;
        final fp = context.read<FinanceProvider>();
        final payment = DebtPayment(
          id: '',
          sellerId: fp.sellerId,
          debtId: widget.debt.id,
          amount: amount,
          paymentDate: DateTime.now(),
          description: descCtrl.text.trim().isNotEmpty
              ? descCtrl.text.trim()
              : null,
          createdAt: DateTime.now(),
        );
        await fp.repo.createDebtPayment(payment);
        _loadPayments();
        widget.onUpdated();
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
}
