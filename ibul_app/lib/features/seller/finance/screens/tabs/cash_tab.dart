import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../finance_quick_actions.dart';
import '../../models/finance_models.dart';
import '../../providers/finance_provider.dart';
import '../../repositories/finance_repository.dart';
import '../../widgets/finance_widgets.dart';

class CashTab extends StatefulWidget {
  const CashTab({super.key});

  @override
  State<CashTab> createState() => _CashTabState();
}

class _CashTabState extends State<CashTab> {
  String? _selectedAccountId;
  List<CashMovement> _movements = [];
  bool _loadingMovements = false;
  String? _movementsError;
  int? _scheduledQuickActionId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final accounts = context.read<FinanceProvider>().cashAccounts;
    if (_selectedAccountId == null && accounts.isNotEmpty) {
      _selectedAccountId = accounts.first.id;
      _loadMovements();
    }
  }

  FinanceRepository get _repo => context.read<FinanceProvider>().repo;

  Future<void> _loadMovements() async {
    if (_selectedAccountId == null) return;
    setState(() {
      _loadingMovements = true;
      _movementsError = null;
    });
    try {
      final data = await _repo.getCashMovements(
          accountId: _selectedAccountId, limit: 60);
      setState(() => _movements = data);
    } catch (e) {
      setState(() => _movementsError = e.toString());
    } finally {
      setState(() => _loadingMovements = false);
    }
  }

  void _selectAccount(String id) {
    setState(() {
      _selectedAccountId = id;
      _movements = [];
    });
    _loadMovements();
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FinanceProvider>();
    _handleQuickActions(fp);
    final accounts = fp.cashAccounts;

    return Column(
      children: [
        _buildHeader(fp, accounts),
        _buildMiniToolbar(fp),
        Expanded(
          child: accounts.isEmpty
              ? FinEmptyState(
                  message: 'Henüz kasa/hesap eklenmemiş',
                  icon: Icons.account_balance_wallet_outlined,
                  action: () => _showAddAccountDialog(context, fp),
                  actionLabel: 'Hesap Ekle',
                )
              : Column(
                  children: [
                    _buildAccountSelector(accounts),
                    Expanded(child: _buildMovementList()),
                  ],
                ),
        ),
      ],
    );
  }

  void _handleQuickActions(FinanceProvider fp) {
    final event = fp.quickAction;
    if (event == null || _scheduledQuickActionId == event.id) return;
    if (!FinanceQuickActions.cashTabActions.contains(event.action)) return;
    _scheduledQuickActionId = event.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final accepted = fp.consumeQuickAction(event.id);
      _scheduledQuickActionId = null;
      if (!accepted) return;
      if (event.action == FinanceQuickActions.cashAddAccount) {
        _showAddAccountDialog(context, fp);
        return;
      }
      _showAddMovementDialog(
        context,
        presetAction: event.action,
        presetDescription: event.payload['description'] as String?,
      );
    });
  }

  Widget _buildMiniToolbar(FinanceProvider fp) {
    return FinMiniToolbar(
      children: [
        FinToolbarAction(
          label: 'Hesap Ekle',
          icon: Icons.account_balance_wallet_outlined,
          onTap: () => _showAddAccountDialog(context, fp),
          primary: true,
        ),
        FinToolbarAction(
          label: 'Hareket Ekle',
          icon: Icons.swap_vert_circle_rounded,
          onTap: () => _showMovementTypeSheet(context),
        ),
        FinToolbarAction(
          label: 'Transfer',
          icon: Icons.compare_arrows_rounded,
          onTap: () => _showAddMovementDialog(
            context,
            presetAction: FinanceQuickActions.cashTransfer,
          ),
        ),
        FinToolbarAction(
          label: 'Yenile',
          icon: Icons.refresh_rounded,
          onTap: () async {
            await fp.reloadCashAccounts();
            _loadMovements();
          },
        ),
      ],
    );
  }

  Widget _buildHeader(FinanceProvider fp, List<CashAccount> accounts) {
    double total = 0;
    for (final a in accounts) {
      total += a.currentBalance;
    }
    return Container(
      padding: const EdgeInsets.all(14),
      color: const Color(0xFFF0FDF4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Toplam Kasa Bakiyesi',
                    style: TextStyle(fontSize: 11, color: Color(0xFF065F46))),
                Text(
                  fmtCurrency(total),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF065F46),
                  ),
                ),
                Text(
                  '${accounts.length} hesap',
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF6EE7B7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMovementTypeSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.arrow_circle_down_rounded, color: Color(0xFF10B981)),
              title: const Text('Kasa Giriş'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showAddMovementDialog(context, presetAction: FinanceQuickActions.cashInflow);
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_circle_up_rounded, color: Color(0xFFEF4444)),
              title: const Text('Kasa Çıkış'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showAddMovementDialog(context, presetAction: FinanceQuickActions.cashOutflow);
              },
            ),
            ListTile(
              leading: const Icon(Icons.compare_arrows_rounded, color: Color(0xFF3B82F6)),
              title: const Text('Transfer'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showAddMovementDialog(context, presetAction: FinanceQuickActions.cashTransfer);
              },
            ),
            ListTile(
              leading: const Icon(Icons.rule_folder_rounded, color: Color(0xFFF59E0B)),
              title: const Text('Düzeltme'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showAddMovementDialog(context, presetAction: FinanceQuickActions.cashCorrection);
              },
            ),
            ListTile(
              leading: const Icon(Icons.badge_rounded, color: Color(0xFF8B5CF6)),
              title: const Text('Avans'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showAddMovementDialog(context, presetAction: FinanceQuickActions.cashAdvance);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_rounded, color: Color(0xFFF97316)),
              title: const Text('Borç Ödeme Bağlantısı'),
              onTap: () {
                Navigator.pop(sheetContext);
                context.read<FinanceProvider>().triggerQuickAction(FinanceQuickActions.cashDebtPaymentLink);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSelector(List<CashAccount> accounts) {
    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        itemCount: accounts.length,
        itemBuilder: (_, i) {
          final a = accounts[i];
          final selected = _selectedAccountId == a.id;
          final t = a.accountType;
          return GestureDetector(
            onTap: () => _selectAccount(a.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? t.color.withValues(alpha: 0.15)
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? t.color : kFinanceDivider,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(t.icon, size: 12, color: t.color),
                      const SizedBox(width: 4),
                      Text(
                        a.name,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: selected ? t.color : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fmtCurrency(a.currentBalance),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: t.color,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMovementList() {
    if (_loadingMovements) {
      return const FinLoadingOverlay(message: 'Hareketler yükleniyor...');
    }
    if (_movementsError != null) {
      return FinErrorCard(message: _movementsError!, onRetry: _loadMovements);
    }
    if (_movements.isEmpty) {
      return FinEmptyState(
        message: 'Bu hesapta henüz hareket yok',
        icon: Icons.receipt_long_outlined,
        action: () => _showAddMovementDialog(context),
        actionLabel: 'Hareket Ekle',
      );
    }
    return RefreshIndicator(
      color: kFinancePrimary,
      onRefresh: _loadMovements,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: _movements.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, indent: 54, color: kFinanceDivider),
        itemBuilder: (_, i) => _movementTile(_movements[i]),
      ),
    );
  }

  Widget _movementTile(CashMovement m) {
    final isIn = m.isIn;
    final color = isIn ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    return ListTile(
      dense: true,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isIn ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
          color: color,
          size: 16,
        ),
      ),
      title: Text(
        m.movementType.label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${fmtDate(m.movementDate)}  ${m.description ?? ''}',
        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '${isIn ? '+' : '-'}${fmtCurrency(m.amount)}',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // Dialogs
  // ─────────────────────────────────────────

  Future<void> _showAddAccountDialog(
      BuildContext context, FinanceProvider fp) async {
    final nameCtrl = TextEditingController();
    final bankCtrl = TextEditingController();
    final ibanCtrl = TextEditingController();
    var selectedType = CashAccountType.cash;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Yeni Hesap / Kasa Ekle',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<CashAccountType>(
                  initialValue: selectedType,
                  decoration: InputDecoration(
                    labelText: 'Hesap Türü',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  items: CashAccountType.values
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Row(children: [
                              Icon(t.icon, size: 14, color: t.color),
                              const SizedBox(width: 6),
                              Text(t.label,
                                  style: const TextStyle(fontSize: 13)),
                            ]),
                          ))
                      .toList(),
                  onChanged: (v) => ss(() => selectedType = v!),
                ),
                const SizedBox(height: 10),
                FinTextField(
                    controller: nameCtrl,
                    label: 'Hesap Adı',
                    hint: 'örn. Ana Kasa'),
                if (selectedType == CashAccountType.bank) ...[
                  const SizedBox(height: 10),
                  FinTextField(
                      controller: bankCtrl,
                      label: 'Banka Adı',
                      hint: 'örn. Garanti Bankası'),
                  const SizedBox(height: 10),
                  FinTextField(
                      controller: ibanCtrl,
                      label: 'IBAN',
                      hint: 'TR...'),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('İptal')),
            FilledButton(
              onPressed: nameCtrl.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(ctx, true),
              style:
                  FilledButton.styleFrom(backgroundColor: kFinancePrimary),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      try {
        final account = CashAccount(
          id: '',
          sellerId: fp.sellerId,
          name: nameCtrl.text.trim(),
          accountType: selectedType,
          bankName: bankCtrl.text.trim().isNotEmpty
              ? bankCtrl.text.trim()
              : null,
          iban: ibanCtrl.text.trim().isNotEmpty ? ibanCtrl.text.trim() : null,
          createdAt: DateTime.now(),
        );
        await fp.repo.createCashAccount(account);
        await fp.reloadCashAccounts();
        final newAccounts = fp.cashAccounts;
        if (newAccounts.isNotEmpty && mounted) {
          setState(() => _selectedAccountId = newAccounts.last.id);
          _loadMovements();
        }
      } catch (e) {
        if (!context.mounted) return;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _showAddMovementDialog(
    BuildContext context, {
    String? presetAction,
    String? presetDescription,
  }) async {
    if (_selectedAccountId == null) return;
    final fp = context.read<FinanceProvider>();
    final accounts = fp.cashAccounts;
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController(text: presetDescription ?? '');
    var selectedType = CashMovementType.income;
    var direction = 'in';
    String? targetAccountId;

    switch (presetAction) {
      case FinanceQuickActions.cashOutflow:
      case FinanceQuickActions.paymentCashOutflow:
        selectedType = CashMovementType.expense;
        direction = 'out';
        descCtrl.text = presetDescription ?? 'Ödeme / kasa çıkışı';
        break;
      case FinanceQuickActions.cashTransfer:
      case FinanceQuickActions.paymentBankTransfer:
        selectedType = CashMovementType.transfer;
        direction = 'out';
        descCtrl.text = presetDescription ?? 'Hesaplar arası transfer';
        break;
      case FinanceQuickActions.cashCorrection:
        selectedType = CashMovementType.correction;
        direction = 'out';
        descCtrl.text = presetDescription ?? 'Bakiye düzeltmesi';
        break;
      case FinanceQuickActions.cashAdvance:
        selectedType = CashMovementType.salaryPayment;
        direction = 'out';
        descCtrl.text = presetDescription ?? 'Personel avansı';
        break;
      case FinanceQuickActions.cashInflow:
      default:
        selectedType = CashMovementType.income;
        direction = 'in';
        break;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Kasa Hareketi Ekle',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<CashMovementType>(
                  initialValue: selectedType,
                  decoration: InputDecoration(
                    labelText: 'Hareket Türü',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  items: CashMovementType.values
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.label,
                                style: const TextStyle(fontSize: 13)),
                          ))
                      .toList(),
                  onChanged: (v) => ss(() => selectedType = v!),
                ),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'in',
                        label: Text('Giriş'),
                        icon: Icon(Icons.arrow_downward_rounded)),
                    ButtonSegment(
                        value: 'out',
                        label: Text('Çıkış'),
                        icon: Icon(Icons.arrow_upward_rounded)),
                  ],
                  selected: {direction},
                  onSelectionChanged: (s) => ss(() => direction = s.first),
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return direction == 'in'
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444);
                      }
                      return null;
                    }),
                  ),
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
                FinTextField(
                  controller: descCtrl,
                  label: 'Açıklama (opsiyonel)',
                  maxLines: 2,
                ),
                if (selectedType == CashMovementType.transfer) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: targetAccountId,
                    decoration: InputDecoration(
                      labelText: 'Hedef Hesap',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    items: accounts
                        .where((account) => account.id != _selectedAccountId)
                        .map(
                          (account) => DropdownMenuItem<String>(
                            value: account.id,
                            child: Text(
                              '${account.name} • ${fmtCurrency(account.currentBalance)}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) => ss(() => targetAccountId = value),
                  ),
                ],
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
        if (selectedType == CashMovementType.transfer) {
          if (targetAccountId == null || targetAccountId == _selectedAccountId) return;
          await fp.repo.transferBetweenAccounts(
            fromAccountId: _selectedAccountId!,
            toAccountId: targetAccountId!,
            amount: amount,
            description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : 'Hesaplar arası transfer',
            movementDate: DateTime.now(),
          );
        } else {
        final movement = CashMovement(
          id: '',
          sellerId: fp.sellerId,
          accountId: _selectedAccountId!,
          movementType: selectedType,
          amount: amount,
          direction: direction,
          description: descCtrl.text.trim().isNotEmpty
              ? descCtrl.text.trim()
              : null,
          movementDate: DateTime.now(),
          createdAt: DateTime.now(),
        );
        await fp.repo.createCashMovement(movement);
        }
        await fp.reloadCashAccounts();
        _loadMovements();
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
