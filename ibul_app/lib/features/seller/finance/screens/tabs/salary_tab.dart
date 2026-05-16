import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../finance_quick_actions.dart';
import '../../models/finance_models.dart';
import '../../providers/finance_provider.dart';
import '../../widgets/finance_widgets.dart';

class SalaryTab extends StatefulWidget {
  const SalaryTab({super.key});

  @override
  State<SalaryTab> createState() => _SalaryTabState();
}

class _SalaryTabState extends State<SalaryTab> {
  int _selectedSegment = 0; // 0 = employees, 1 = salary records
  List<FinanceEmployee> _employees = [];
  List<SalaryRecord> _records = [];
  bool _loading = false;
  String? _error;
  int? _scheduledQuickActionId;

  // Month/year for salary records view
  final _now = DateTime.now();
  late int _selectedMonth;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedMonth = _now.month;
    _selectedYear = _now.year;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_employees.isEmpty && !_loading) _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<FinanceProvider>().repo;
      _employees = await repo.getEmployees();
      setState(() {});
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadSalaryRecords() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<FinanceProvider>().repo;
      _records = await repo.getSalaryRecords(
          year: _selectedYear, month: _selectedMonth);
      setState(() {});
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  double get _totalNetSalary =>
      _employees.fold(0, (s, e) => s + e.baseSalary);

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FinanceProvider>();
    _handleQuickActions(fp);

    return Column(
      children: [
        _buildSegmentControl(),
        _buildMiniToolbar(),
        if (_selectedSegment == 0) _buildEmployeeContent(),
        if (_selectedSegment == 1) _buildSalaryContent(),
      ],
    );
  }

  void _handleQuickActions(FinanceProvider fp) {
    final event = fp.quickAction;
    if (event == null || _scheduledQuickActionId == event.id) return;
    if (!FinanceQuickActions.salaryTabActions.contains(event.action)) return;
    _scheduledQuickActionId = event.id;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final accepted = fp.consumeQuickAction(event.id);
      _scheduledQuickActionId = null;
      if (!accepted) return;
      if (event.action == FinanceQuickActions.salaryAddEmployee) {
          _showAddEmployeeDialog(context);
          return;
      }
      setState(() => _selectedSegment = 1);
      await _loadSalaryRecords();
      if (!mounted) return;
      if (event.action == FinanceQuickActions.salaryAddRecord) {
          _showAddSalaryRecordDialog(context);
          return;
      }
      _showBulkPaymentDialog(context);
    });
  }

  Widget _buildMiniToolbar() {
    return FinMiniToolbar(
      children: [
        FinToolbarAction(
          label: 'Personel Ekle',
          icon: Icons.person_add_alt_1_rounded,
          onTap: () => _showAddEmployeeDialog(context),
          primary: _selectedSegment == 0,
        ),
        FinToolbarAction(
          label: 'Maaş Kaydı Ekle',
          icon: Icons.note_add_rounded,
          onTap: () {
            setState(() => _selectedSegment = 1);
            _loadSalaryRecords().then((_) {
              if (mounted) _showAddSalaryRecordDialog(context);
            });
          },
          primary: _selectedSegment == 1,
        ),
        FinToolbarAction(
          label: 'Toplu Ödeme',
          icon: Icons.payments_rounded,
          onTap: () {
            setState(() => _selectedSegment = 1);
            _loadSalaryRecords().then((_) {
              if (mounted) _showBulkPaymentDialog(context);
            });
          },
        ),
      ],
    );
  }

  Widget _buildSegmentControl() {
    return Container(
      padding: const EdgeInsets.all(10),
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          Expanded(
            child: SegmentedButton<int>(
              selected: {_selectedSegment},
              onSelectionChanged: (val) {
                setState(() => _selectedSegment = val.first);
                if (val.first == 0) {
                  _loadEmployees();
                } else {
                  _loadSalaryRecords();
                }
              },
              segments: const [
                ButtonSegment(
                    value: 0,
                    label: Text('Çalışanlar'),
                    icon: Icon(Icons.people_outline)),
                ButtonSegment(
                    value: 1,
                    label: Text('Maaş Kayıtları'),
                    icon: Icon(Icons.receipt_long_outlined)),
              ],
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: kFinancePrimary,
                selectedForegroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── EMPLOYEES ──────────────────────────────
  Widget _buildEmployeeContent() {
    return Expanded(
      child: Column(
        children: [
          if (_employees.isNotEmpty) _buildEmployeeSummaryBar(),
          Expanded(
            child: _loading
                ? const FinLoadingOverlay()
                : _error != null
                    ? FinErrorCard(message: _error!, onRetry: _loadEmployees)
                    : _employees.isEmpty
                        ? FinEmptyState(
                            message: 'Çalışan bulunamadı',
                            icon: Icons.person_add_outlined,
                            action: () => _showAddEmployeeDialog(context),
                            actionLabel: 'Çalışan Ekle',
                          )
                        : _buildEmployeeList(),
          ),
          FinAddButton(
              label: 'Çalışan Ekle',
              onTap: () => _showAddEmployeeDialog(context)),
        ],
      ),
    );
  }

  Widget _buildEmployeeSummaryBar() {
    final active = _employees.where((e) => e.isActive).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: const Color(0xFFF0F9FF),
      child: Row(
        children: [
          _chip('Aktif', '$active çalışan', const Color(0xFF0369A1)),
          const SizedBox(width: 8),
          _chip('Aylık Yük', fmtCurrency(_totalNetSalary),
              kFinancePrimary),
        ],
      ),
    );
  }

  Widget _chip(String label, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

  Widget _buildEmployeeList() {
    return RefreshIndicator(
      color: kFinancePrimary,
      onRefresh: _loadEmployees,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: _employees.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 54, color: kFinanceDivider),
        itemBuilder: (_, i) => _employeeTile(_employees[i]),
      ),
    );
  }

  Widget _employeeTile(FinanceEmployee e) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: kFinancePrimary.withValues(alpha: 0.1),
        child: Text(
          e.fullName.isNotEmpty ? e.fullName[0].toUpperCase() : '?',
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kFinancePrimary),
        ),
      ),
      title: Row(
        children: [
          Text(e.fullName,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          if (!e.isActive)
            FinStatusBadge(
                label: 'Pasif', color: const Color(0xFF94A3B8)),
        ],
      ),
      subtitle: Text(
        [
          if (e.position != null) e.position!,
          'Ödeme Günü: ${e.paymentDay}',
        ].join('  •  '),
        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            fmtCurrency(e.baseSalary),
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: kFinancePrimary),
          ),
          Text(
            'brüt maaş',
            style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
      onTap: () => _showEmployeeOptions(e),
    );
  }

  void _showEmployeeOptions(FinanceEmployee e) {
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
            ListTile(
              leading: Icon(
                  e.isActive ? Icons.person_off_outlined : Icons.person_add_outlined,
                  color: e.isActive ? Colors.orange : kFinancePrimary),
              title: Text(e.isActive ? 'Pasife Al' : 'Aktive Et'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  final fp = context.read<FinanceProvider>();
                  await fp.repo.updateEmployee(e.id, {'is_active': !e.isActive});
                  _loadEmployees();
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
                  await fp.repo.updateEmployee(e.id, {'is_active': false});
                  _loadEmployees();
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

  Future<void> _showAddEmployeeDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final positionCtrl = TextEditingController();
    final baseSalaryCtrl = TextEditingController();
    final netSalaryCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final ibanCtrl = TextEditingController();
    int paymentDay = 1;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Çalışan Ekle',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FinTextField(controller: nameCtrl, label: 'Ad Soyad'),
                const SizedBox(height: 10),
                FinTextField(
                    controller: positionCtrl, label: 'Pozisyon/Görev'),
                const SizedBox(height: 10),
                FinTextField(
                  controller: baseSalaryCtrl,
                  label: 'Brüt Maaş',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  prefixText: '₺',
                ),
                const SizedBox(height: 10),
                FinTextField(
                  controller: netSalaryCtrl,
                  label: 'Net Maaş',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  prefixText: '₺',
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: paymentDay,
                  decoration: InputDecoration(
                    labelText: 'Maaş Ödeme Günü',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  items: List.generate(
                    28,
                    (i) => DropdownMenuItem(
                        value: i + 1, child: Text('${i + 1}. Gün')),
                  ),
                  onChanged: (v) => ss(() => paymentDay = v!),
                ),
                const SizedBox(height: 10),
                FinTextField(
                    controller: phoneCtrl,
                    label: 'Telefon (opsiyonel)',
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 10),
                FinTextField(
                    controller: ibanCtrl,
                    label: 'IBAN (opsiyonel)',
                    hint: 'TR00 0000 0000 0000 0000'),
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
      final name = nameCtrl.text.trim();
      final base = double.tryParse(baseSalaryCtrl.text.replaceAll(',', '.'));
      if (name.isEmpty || base == null || base <= 0) return;
      try {
        final fp = context.read<FinanceProvider>();
        final emp = FinanceEmployee(
          id: '',
          sellerId: fp.sellerId,
          fullName: name,
          position: positionCtrl.text.trim().isNotEmpty
              ? positionCtrl.text.trim()
              : null,
          baseSalary: base,
          paymentDay: paymentDay,
          phone: phoneCtrl.text.trim().isNotEmpty
              ? phoneCtrl.text.trim()
              : null,
          iban: ibanCtrl.text.trim().isNotEmpty
              ? ibanCtrl.text.trim()
              : null,
          isActive: true,
          createdAt: DateTime.now(),
        );
        await fp.repo.createEmployee(emp);
        _loadEmployees();
        fp.loadOverview();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _showAddSalaryRecordDialog(BuildContext context) async {
    if (_employees.isEmpty) {
      await _loadEmployees();
    }
    final activeEmployees = _employees.where((e) => e.isActive).toList(growable: false);
    if (activeEmployees.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Önce aktif bir çalışan ekleyin.')),
        );
      }
      return;
    }

    FinanceEmployee selectedEmployee = activeEmployees.first;
    final bonusCtrl = TextEditingController(text: '0');
    final overtimeCtrl = TextEditingController(text: '0');
    final deductionCtrl = TextEditingController(text: '0');
    final advanceCtrl = TextEditingController(text: '0');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Maaş Kaydı Ekle',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<FinanceEmployee>(
                  value: selectedEmployee,
                  decoration: InputDecoration(
                    labelText: 'Çalışan',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: activeEmployees
                      .map((employee) => DropdownMenuItem(
                            value: employee,
                            child: Text(employee.fullName,
                                style: const TextStyle(fontSize: 13)),
                          ))
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      setModalState(() => selectedEmployee = value);
                    }
                  },
                ),
                const SizedBox(height: 10),
                FinTextField(
                  controller: bonusCtrl,
                  label: 'Prim',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  prefixText: '₺',
                ),
                const SizedBox(height: 10),
                FinTextField(
                  controller: overtimeCtrl,
                  label: 'Mesai',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  prefixText: '₺',
                ),
                const SizedBox(height: 10),
                FinTextField(
                  controller: deductionCtrl,
                  label: 'Kesinti',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  prefixText: '₺',
                ),
                const SizedBox(height: 10),
                FinTextField(
                  controller: advanceCtrl,
                  label: 'Avans',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  prefixText: '₺',
                ),
              ],
            ),
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
      final bonus = double.tryParse(bonusCtrl.text.replaceAll(',', '.')) ?? 0;
      final overtime = double.tryParse(overtimeCtrl.text.replaceAll(',', '.')) ?? 0;
      final deduction = double.tryParse(deductionCtrl.text.replaceAll(',', '.')) ?? 0;
      final advance = double.tryParse(advanceCtrl.text.replaceAll(',', '.')) ?? 0;
      final netSalary = selectedEmployee.baseSalary + bonus + overtime - deduction - advance;
      try {
        final fp = context.read<FinanceProvider>();
        final record = SalaryRecord(
          id: '',
          sellerId: fp.sellerId,
          employeeId: selectedEmployee.id,
          employeeName: selectedEmployee.fullName,
          periodYear: _selectedYear,
          periodMonth: _selectedMonth,
          baseSalary: selectedEmployee.baseSalary,
          bonus: bonus,
          overtime: overtime,
          deduction: deduction,
          advanceDeduction: advance,
          netSalary: netSalary,
          paidAmount: 0,
          status: SalaryStatus.pending,
          createdAt: DateTime.now(),
        );
        await fp.repo.createSalaryRecord(record);
        _loadSalaryRecords();
        fp.loadOverview();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _showBulkPaymentDialog(BuildContext context) async {
    final payableRecords = _records
        .where((record) => record.netSalary - record.paidAmount > 0)
        .toList(growable: false);
    if (payableRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Toplu ödeme için açık maaş kaydı bulunamadı.')),
      );
      return;
    }

    final totalRemaining = payableRecords.fold<double>(
      0,
      (sum, record) => sum + (record.netSalary - record.paidAmount),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Toplu Maaş Ödemesi',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: Text(
          '${payableRecords.length} kayıt için toplam ${fmtCurrency(totalRemaining)} ödeme oluşturulacak.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: kFinancePrimary),
            child: const Text('Ödemeleri Oluştur'),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        final fp = context.read<FinanceProvider>();
        for (final record in payableRecords) {
          final remaining = record.netSalary - record.paidAmount;
          final payment = SalaryPayment(
            id: '',
            sellerId: fp.sellerId,
            salaryRecordId: record.id,
            amount: remaining,
            paymentDate: DateTime.now(),
            createdAt: DateTime.now(),
          );
          await fp.repo.createSalaryPayment(payment);
        }
        _loadSalaryRecords();
        fp.loadOverview();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // ── SALARY RECORDS ─────────────────────────
  Widget _buildSalaryContent() {
    return Expanded(
      child: Column(
        children: [
          _buildMonthSelector(),
          Expanded(
            child: _loading
                ? const FinLoadingOverlay()
                : _error != null
                    ? FinErrorCard(
                        message: _error!, onRetry: _loadSalaryRecords)
                    : _records.isEmpty
                        ? FinEmptyState(
                            message:
                                '${fmtMonth(_selectedMonth, _selectedYear)} için maaş kaydı yok',
                            icon: Icons.receipt_long_outlined,
                          )
                        : _buildRecordList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFFF8FAFC),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                if (_selectedMonth == 1) {
                  _selectedMonth = 12;
                  _selectedYear--;
                } else {
                  _selectedMonth--;
                }
              });
              _loadSalaryRecords();
            },
          ),
          GestureDetector(
            onTap: _loadSalaryRecords,
            child: Text(
              fmtMonth(_selectedMonth, _selectedYear),
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                if (_selectedMonth == 12) {
                  _selectedMonth = 1;
                  _selectedYear++;
                } else {
                  _selectedMonth++;
                }
              });
              _loadSalaryRecords();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecordList() {
    return RefreshIndicator(
      color: kFinancePrimary,
      onRefresh: _loadSalaryRecords,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: _records.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 54, color: kFinanceDivider),
        itemBuilder: (_, i) => _salaryRecordTile(_records[i]),
      ),
    );
  }

  Widget _salaryRecordTile(SalaryRecord r) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: r.status.color.withValues(alpha: 0.1),
        child: Icon(Icons.person_rounded, color: r.status.color, size: 16),
      ),
      title: Row(
        children: [
          Text(r.employeeName ?? 'Çalışan',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          FinStatusBadge(label: r.status.label, color: r.status.color),
        ],
      ),
      subtitle: Text(
        'Net: ${fmtCurrency(r.netSalary)}',
        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
      ),
      trailing: Text(
        fmtCurrency(r.paidAmount),
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF10B981)),
      ),
      onTap: () => _showSalaryRecordDetail(r),
    );
  }

  void _showSalaryRecordDetail(SalaryRecord r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) =>
          _SalaryRecordDetailSheet(record: r, onUpdated: _loadSalaryRecords),
    );
  }
}

// ─────────────────────────────────────────
// Salary Record Detail Sheet
// ─────────────────────────────────────────
class _SalaryRecordDetailSheet extends StatefulWidget {
  const _SalaryRecordDetailSheet(
      {required this.record, required this.onUpdated});

  final SalaryRecord record;
  final VoidCallback onUpdated;

  @override
  State<_SalaryRecordDetailSheet> createState() =>
      _SalaryRecordDetailSheetState();
}

class _SalaryRecordDetailSheetState extends State<_SalaryRecordDetailSheet> {
  List<SalaryPayment> _payments = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final fp = context.read<FinanceProvider>();
      _payments = await fp.repo.getSalaryPayments(widget.record.id);
      setState(() {});
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
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
                    r.employeeName ?? 'Çalışan',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                FinStatusBadge(label: r.status.label, color: r.status.color),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _chip('Net Maaş', fmtCurrency(r.netSalary),
                    kFinancePrimary),
                const SizedBox(width: 8),
                _chip('Ödenen', fmtCurrency(r.paidAmount),
                    const Color(0xFF10B981)),
                const SizedBox(width: 8),
                _chip(
                    'Kalan',
                    fmtCurrency(r.netSalary - r.paidAmount),
                    r.status.color),
              ],
            ),
          ),
          const Divider(color: kFinanceDivider),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Ödemeler',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                TextButton.icon(
                  onPressed: () => _showAddPaymentDialog(context),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Ödeme Ekle',
                      style: TextStyle(fontSize: 12)),
                  style:
                      TextButton.styleFrom(foregroundColor: kFinancePrimary),
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
                        icon: Icons.money_off_outlined)
                    : ListView.builder(
                        controller: ctrl,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: _payments.length,
                        itemBuilder: (_, i) => _paymentTile(_payments[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String val, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 9, color: Color(0xFF94A3B8))),
            Text(val,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
      ),
    );
  }

  Widget _paymentTile(SalaryPayment p) {
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
        fmtDate(p.paymentDate),
        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
      ),
    );
  }

  Future<void> _showAddPaymentDialog(BuildContext context) async {
    final amountCtrl = TextEditingController(
        text: (widget.record.netSalary - widget.record.paidAmount)
            .toStringAsFixed(2));

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Maaş Ödemesi Ekle',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FinTextField(
              controller: amountCtrl,
              label: 'Ödeme Tutarı',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              prefixText: '₺',
            ),
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
      final amount =
          double.tryParse(amountCtrl.text.replaceAll(',', '.'));
      if (amount == null || amount <= 0) return;
      try {
        final fp = context.read<FinanceProvider>();
        final payment = SalaryPayment(
          id: '',
          sellerId: fp.sellerId,
          salaryRecordId: widget.record.id,
          amount: amount,
          paymentDate: DateTime.now(),
          createdAt: DateTime.now(),
        );
        await fp.repo.createSalaryPayment(payment);
        _load();
        widget.onUpdated();
        fp.loadOverview();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: Colors.red));
        }
      }
    }
  }
}
