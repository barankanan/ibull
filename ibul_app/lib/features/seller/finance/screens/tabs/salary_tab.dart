import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../finance_quick_actions.dart';
import '../../models/finance_models.dart';
import '../../providers/finance_provider.dart';
import '../../widgets/finance_widgets.dart';

/// Çalışanlar + maaş kayıtları tek bir Excel benzeri tabloda birleşik.
/// Her satır = bir çalışan, seçili ayın maaş kartı bilgileriyle.
class SalaryTab extends StatefulWidget {
  const SalaryTab({super.key});

  @override
  State<SalaryTab> createState() => _SalaryTabState();
}

class _SalaryTabState extends State<SalaryTab> {
  List<FinanceEmployee> _employees = [];
  Map<String, SalaryRecord> _recordByEmployee = {};
  bool _loading = false;
  String? _error;
  int? _scheduledQuickActionId;
  bool _loadedOnce = false;

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
    if (!_loadedOnce && !_loading) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<FinanceProvider>().repo;
      final results = await Future.wait([
        repo.getEmployees(),
        repo.getSalaryRecords(year: _selectedYear, month: _selectedMonth),
      ]);
      _employees = results[0] as List<FinanceEmployee>;
      final records = results[1] as List<SalaryRecord>;
      _recordByEmployee = {for (final r in records) r.employeeId: r};
      _loadedOnce = true;
      setState(() {});
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  SalaryRecord? _recordFor(FinanceEmployee e) => _recordByEmployee[e.id];

  double _net(FinanceEmployee e) => _recordFor(e)?.netSalary ?? e.baseSalary;
  double _advance(FinanceEmployee e) => _recordFor(e)?.advanceDeduction ?? 0;
  double _bonus(FinanceEmployee e) => _recordFor(e)?.bonus ?? 0;
  double _paid(FinanceEmployee e) => _recordFor(e)?.paidAmount ?? 0;
  double _remaining(FinanceEmployee e) =>
      (_net(e) - _paid(e)).clamp(0, double.infinity);

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FinanceProvider>();
    _handleQuickActions(fp);

    return Column(
      children: [
        _buildMonthSelector(),
        if (_employees.isNotEmpty) _buildSummaryBar(),
        _buildToolbar(),
        Expanded(
          child: _loading
              ? const FinLoadingOverlay()
              : _error != null
                  ? FinErrorCard(message: _error!, onRetry: _load)
                  : _employees.isEmpty
                      ? FinEmptyState(
                          message: 'Çalışan bulunamadı',
                          icon: Icons.person_add_outlined,
                          action: () => _showEmployeeDialog(),
                          actionLabel: 'Çalışan Ekle',
                        )
                      : _buildTable(),
        ),
        FinAddButton(
            label: 'Çalışan Ekle', onTap: () => _showEmployeeDialog()),
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
        _showEmployeeDialog();
        return;
      }
      if (event.action == FinanceQuickActions.salaryAddRecord) {
        _pickEmployeeThenEditSalary();
        return;
      }
      _showBulkPaymentDialog();
    });
  }

  // ── MONTH SELECTOR ────────────────────────
  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              _load();
            },
          ),
          GestureDetector(
            onTap: _load,
            child: Text(
              fmtMonth(_selectedMonth, _selectedYear),
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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
              _load();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar() {
    final active = _employees.where((e) => e.isActive).length;
    final totalNet = _employees.fold<double>(0, (s, e) => s + _net(e));
    final totalAdvance = _employees.fold<double>(0, (s, e) => s + _advance(e));
    final totalPaid = _employees.fold<double>(0, (s, e) => s + _paid(e));
    final totalRemaining =
        (totalNet - totalPaid).clamp(0, double.infinity).toDouble();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: const Color(0xFFF0F9FF),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _chip('Aktif', '$active çalışan', const Color(0xFF0369A1)),
            const SizedBox(width: 8),
            _chip('Net Maaş', fmtCurrency(totalNet), kFinancePrimary),
            const SizedBox(width: 8),
            _chip('Avans', fmtCurrency(totalAdvance), const Color(0xFFF59E0B)),
            const SizedBox(width: 8),
            _chip('Ödenen', fmtCurrency(totalPaid), const Color(0xFF10B981)),
            const SizedBox(width: 8),
            _chip('Kalan', fmtCurrency(totalRemaining),
                const Color(0xFFEF4444)),
          ],
        ),
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

  Widget _buildToolbar() {
    return FinMiniToolbar(
      children: [
        FinToolbarAction(
          label: 'Çalışan Ekle',
          icon: Icons.person_add_alt_1_rounded,
          onTap: () => _showEmployeeDialog(),
          primary: true,
        ),
        FinToolbarAction(
          label: 'Toplu Ödeme',
          icon: Icons.payments_rounded,
          onTap: () => _showBulkPaymentDialog(),
        ),
      ],
    );
  }

  // ── EXCEL TABLE ───────────────────────────
  Widget _buildTable() {
    return RefreshIndicator(
      color: kFinancePrimary,
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 860),
            child: DataTable(
              headingRowColor:
                  WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              headingRowHeight: 42,
              dataRowMinHeight: 46,
              dataRowMaxHeight: 58,
              horizontalMargin: 12,
              columnSpacing: 16,
              headingTextStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF475569)),
              dataTextStyle:
                  const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
              columns: const [
                DataColumn(label: Text('Çalışan')),
                DataColumn(label: Text('Pozisyon')),
                DataColumn(label: Text('Net Maaş'), numeric: true),
                DataColumn(label: Text('Prim'), numeric: true),
                DataColumn(label: Text('Avans'), numeric: true),
                DataColumn(label: Text('Ödenen'), numeric: true),
                DataColumn(label: Text('Kalan'), numeric: true),
                DataColumn(label: Text('Durum')),
                DataColumn(label: Text('İşlem')),
              ],
              rows: _employees.map(_buildRow).toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _buildRow(FinanceEmployee e) {
    final record = _recordFor(e);
    final remaining = _remaining(e);
    return DataRow(
      cells: [
        DataCell(
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: kFinancePrimary.withValues(alpha: 0.1),
                child: Text(
                  e.fullName.isNotEmpty ? e.fullName[0].toUpperCase() : '?',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: kFinancePrimary),
                ),
              ),
              const SizedBox(width: 8),
              Text(e.fullName,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: e.isActive
                          ? const Color(0xFF0F172A)
                          : const Color(0xFF94A3B8))),
            ],
          ),
          onTap: () => _openDetail(e),
        ),
        DataCell(Text(e.position ?? '-')),
        DataCell(Text(fmtCurrency(_net(e)),
            style: const TextStyle(fontWeight: FontWeight.w700))),
        DataCell(Text(fmtCurrency(_bonus(e)),
            style: const TextStyle(color: Color(0xFF3B82F6)))),
        DataCell(Text(fmtCurrency(_advance(e)),
            style: const TextStyle(color: Color(0xFFF59E0B)))),
        DataCell(Text(fmtCurrency(_paid(e)),
            style: const TextStyle(
                color: Color(0xFF10B981), fontWeight: FontWeight.w700))),
        DataCell(Text(
          fmtCurrency(remaining),
          style: TextStyle(
              color: remaining > 0
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF94A3B8),
              fontWeight: FontWeight.w700),
        )),
        DataCell(record != null
            ? FinStatusBadge(label: record.status.label, color: record.status.color)
            : (e.isActive
                ? FinStatusBadge(
                    label: 'Kayıt Yok', color: const Color(0xFF94A3B8))
                : FinStatusBadge(
                    label: 'Pasif', color: const Color(0xFF94A3B8)))),
        DataCell(_rowMenu(e)),
      ],
    );
  }

  Widget _rowMenu(FinanceEmployee e) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, size: 18),
      tooltip: 'İşlemler',
      onSelected: (value) {
        switch (value) {
          case 'edit_salary':
            _showEditSalaryDialog(e);
            break;
          case 'pay':
            _payEmployee(e);
            break;
          case 'edit_employee':
            _showEmployeeDialog(existing: e);
            break;
          case 'history':
            _openDetail(e);
            break;
          case 'toggle':
            _toggleActive(e);
            break;
          case 'delete':
            _deleteEmployee(e);
            break;
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
            value: 'edit_salary',
            child: Row(children: [
              Icon(Icons.tune_rounded, size: 16, color: kFinancePrimary),
              SizedBox(width: 8),
              Text('Maaş / Prim / Avans Düzenle'),
            ])),
        const PopupMenuItem(
            value: 'pay',
            child: Row(children: [
              Icon(Icons.payments_rounded, size: 16, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text('Ödeme Yap'),
            ])),
        const PopupMenuItem(
            value: 'history',
            child: Row(children: [
              Icon(Icons.history_rounded, size: 16, color: Color(0xFF64748B)),
              SizedBox(width: 8),
              Text('Ödeme Geçmişi'),
            ])),
        const PopupMenuItem(
            value: 'edit_employee',
            child: Row(children: [
              Icon(Icons.badge_outlined, size: 16, color: Color(0xFF64748B)),
              SizedBox(width: 8),
              Text('Çalışan Bilgileri'),
            ])),
        PopupMenuItem(
            value: 'toggle',
            child: Row(children: [
              Icon(e.isActive
                  ? Icons.person_off_outlined
                  : Icons.person_add_outlined,
                  size: 16,
                  color: const Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              Text(e.isActive ? 'Pasife Al' : 'Aktive Et'),
            ])),
        const PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              Icon(Icons.delete_outline, size: 16, color: Colors.red),
              SizedBox(width: 8),
              Text('Sil'),
            ])),
      ],
    );
  }

  // ── ENSURE / EDIT SALARY RECORD ───────────
  /// Çalışan için seçili ayın maaş kaydını döndürür; yoksa oluşturur.
  Future<SalaryRecord?> _ensureRecord(FinanceEmployee e) async {
    final existing = _recordFor(e);
    if (existing != null) return existing;
    final fp = context.read<FinanceProvider>();
    final created = await fp.repo.createSalaryRecord(SalaryRecord(
      id: '',
      sellerId: fp.sellerId,
      employeeId: e.id,
      employeeName: e.fullName,
      periodYear: _selectedYear,
      periodMonth: _selectedMonth,
      baseSalary: e.baseSalary,
      netSalary: e.baseSalary,
      status: SalaryStatus.pending,
      createdAt: DateTime.now(),
    ));
    _recordByEmployee[e.id] = created;
    return created;
  }

  Future<void> _pickEmployeeThenEditSalary() async {
    final active = _employees.where((e) => e.isActive).toList(growable: false);
    if (active.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Önce aktif bir çalışan ekleyin.')));
      }
      return;
    }
    FinanceEmployee selected = active.first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Maaş Kaydı — Çalışan Seç',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          content: DropdownButtonFormField<FinanceEmployee>(
            initialValue: selected,
            decoration: InputDecoration(
              labelText: 'Çalışan',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: active
                .map((e) => DropdownMenuItem(value: e, child: Text(e.fullName)))
                .toList(growable: false),
            onChanged: (v) => ss(() => selected = v ?? selected),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('İptal')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: kFinancePrimary),
              child: const Text('Devam'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && mounted) _showEditSalaryDialog(selected);
  }

  Future<void> _showEditSalaryDialog(FinanceEmployee e) async {
    final record = _recordFor(e);
    final bonusCtrl =
        TextEditingController(text: (record?.bonus ?? 0).toStringAsFixed(2));
    final overtimeCtrl = TextEditingController(
        text: (record?.overtime ?? 0).toStringAsFixed(2));
    final deductionCtrl = TextEditingController(
        text: (record?.deduction ?? 0).toStringAsFixed(2));
    final advanceCtrl = TextEditingController(
        text: (record?.advanceDeduction ?? 0).toStringAsFixed(2));

    double computeNet() {
      final b = double.tryParse(bonusCtrl.text.replaceAll(',', '.')) ?? 0;
      final o = double.tryParse(overtimeCtrl.text.replaceAll(',', '.')) ?? 0;
      final d = double.tryParse(deductionCtrl.text.replaceAll(',', '.')) ?? 0;
      final a = double.tryParse(advanceCtrl.text.replaceAll(',', '.')) ?? 0;
      final net = e.baseSalary + b + o - d - a;
      return net < 0 ? 0 : net;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: Text('${e.fullName} — ${fmtMonth(_selectedMonth, _selectedYear)}',
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kFinancePrimary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Brüt Maaş',
                          style: TextStyle(fontSize: 12)),
                      Text(fmtCurrency(e.baseSalary),
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                FinTextField(
                  controller: bonusCtrl,
                  label: 'Prim',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  prefixText: '₺',
                ),
                const SizedBox(height: 10),
                FinTextField(
                  controller: overtimeCtrl,
                  label: 'Mesai',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  prefixText: '₺',
                ),
                const SizedBox(height: 10),
                FinTextField(
                  controller: deductionCtrl,
                  label: 'Kesinti',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  prefixText: '₺',
                ),
                const SizedBox(height: 10),
                FinTextField(
                  controller: advanceCtrl,
                  label: 'Nakit Avans',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  prefixText: '₺',
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Net Maaş',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                      Text(fmtCurrency(computeNet()),
                          key: ValueKey(
                              '${bonusCtrl.text}-${overtimeCtrl.text}-${deductionCtrl.text}-${advanceCtrl.text}'),
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF10B981))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('İptal')),
            FilledButton(
              onPressed: () {
                ss(() {}); // net önizlemeyi tazele
                Navigator.pop(ctx, true);
              },
              style: FilledButton.styleFrom(backgroundColor: kFinancePrimary),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    final bonus = double.tryParse(bonusCtrl.text.replaceAll(',', '.')) ?? 0;
    final overtime =
        double.tryParse(overtimeCtrl.text.replaceAll(',', '.')) ?? 0;
    final deduction =
        double.tryParse(deductionCtrl.text.replaceAll(',', '.')) ?? 0;
    final advance = double.tryParse(advanceCtrl.text.replaceAll(',', '.')) ?? 0;

    try {
      if (!mounted) return;
      final fp = context.read<FinanceProvider>();
      if (record != null) {
        // Net maaş DB trigger'ı ile yeniden hesaplanır.
        await fp.repo.updateSalaryRecord(record.id, {
          'bonus': bonus,
          'overtime': overtime,
          'deduction': deduction,
          'advance_deduction': advance,
        });
      } else {
        final net = (e.baseSalary + bonus + overtime - deduction - advance)
            .clamp(0, double.infinity)
            .toDouble();
        await fp.repo.createSalaryRecord(SalaryRecord(
          id: '',
          sellerId: fp.sellerId,
          employeeId: e.id,
          employeeName: e.fullName,
          periodYear: _selectedYear,
          periodMonth: _selectedMonth,
          baseSalary: e.baseSalary,
          bonus: bonus,
          overtime: overtime,
          deduction: deduction,
          advanceDeduction: advance,
          netSalary: net,
          status: SalaryStatus.pending,
          createdAt: DateTime.now(),
        ));
      }
      await _load();
      fp.loadOverview();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hata: $err'), backgroundColor: Colors.red));
      }
    }
  }

  // ── PAYMENT ───────────────────────────────
  Future<void> _payEmployee(FinanceEmployee e) async {
    SalaryRecord? record;
    try {
      record = await _ensureRecord(e);
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hata: $err'), backgroundColor: Colors.red));
      }
      return;
    }
    if (record == null || !mounted) return;
    await _showPaymentDialog(record);
  }

  Future<void> _showPaymentDialog(SalaryRecord r) async {
    final remaining = (r.netSalary - r.paidAmount).clamp(0, double.infinity);
    final amountCtrl =
        TextEditingController(text: remaining.toStringAsFixed(2));
    DateTime paymentDate = DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: Text('${r.employeeName ?? 'Çalışan'} — Maaş Ödemesi',
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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
              const SizedBox(height: 10),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: paymentDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) ss(() => paymentDate = picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Ödeme Tarihi',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(fmtDate(paymentDate),
                          style: const TextStyle(fontSize: 13)),
                      const Icon(Icons.calendar_today_rounded,
                          size: 16, color: kFinancePrimary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('İptal')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: kFinancePrimary),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) return;
    try {
      if (!mounted) return;
      final fp = context.read<FinanceProvider>();
      await fp.repo.createSalaryPayment(SalaryPayment(
        id: '',
        sellerId: fp.sellerId,
        salaryRecordId: r.id,
        amount: amount,
        paymentDate: paymentDate,
        createdAt: DateTime.now(),
      ));
      await _load();
      fp.loadOverview();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _showBulkPaymentDialog() async {
    final payable = _employees
        .where((e) => _recordFor(e) != null && _remaining(e) > 0)
        .toList(growable: false);
    if (payable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Toplu ödeme için açık maaş kaydı bulunamadı.')));
      return;
    }
    final totalRemaining =
        payable.fold<double>(0, (s, e) => s + _remaining(e));

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Toplu Maaş Ödemesi',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: Text(
          '${payable.length} çalışan için toplam ${fmtCurrency(totalRemaining)} ödeme oluşturulacak.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: kFinancePrimary),
            child: const Text('Ödemeleri Oluştur'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    try {
      if (!mounted) return;
      final fp = context.read<FinanceProvider>();
      for (final e in payable) {
        final record = _recordFor(e)!;
        await fp.repo.createSalaryPayment(SalaryPayment(
          id: '',
          sellerId: fp.sellerId,
          salaryRecordId: record.id,
          amount: _remaining(e),
          paymentDate: DateTime.now(),
          createdAt: DateTime.now(),
        ));
      }
      await _load();
      fp.loadOverview();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // ── EMPLOYEE CRUD ─────────────────────────
  Future<void> _toggleActive(FinanceEmployee e) async {
    try {
      final fp = context.read<FinanceProvider>();
      await fp.repo.updateEmployee(e.id, {'is_active': !e.isActive});
      await _load();
      fp.loadOverview();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$err')));
      }
    }
  }

  Future<void> _deleteEmployee(FinanceEmployee e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çalışanı Sil'),
        content: Text('${e.fullName} pasife alınacak. Devam edilsin mi?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      if (!mounted) return;
      final fp = context.read<FinanceProvider>();
      await fp.repo.updateEmployee(e.id, {'is_active': false});
      await _load();
      fp.loadOverview();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$err')));
      }
    }
  }

  Future<void> _showEmployeeDialog({FinanceEmployee? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.fullName ?? '');
    final positionCtrl =
        TextEditingController(text: existing?.position ?? '');
    final baseSalaryCtrl = TextEditingController(
        text: existing != null ? existing.baseSalary.toStringAsFixed(2) : '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final ibanCtrl = TextEditingController(text: existing?.iban ?? '');
    int paymentDay = existing?.paymentDay ?? 1;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: Text(existing == null ? 'Çalışan Ekle' : 'Çalışan Düzenle',
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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
                DropdownButtonFormField<int>(
                  initialValue: paymentDay,
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
              style: FilledButton.styleFrom(backgroundColor: kFinancePrimary),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    final name = nameCtrl.text.trim();
    final base = double.tryParse(baseSalaryCtrl.text.replaceAll(',', '.'));
    if (name.isEmpty || base == null || base < 0) return;
    try {
      if (!mounted) return;
      final fp = context.read<FinanceProvider>();
      if (existing != null) {
        await fp.repo.updateEmployee(existing.id, {
          'full_name': name,
          'position': positionCtrl.text.trim().isNotEmpty
              ? positionCtrl.text.trim()
              : null,
          'base_salary': base,
          'payment_day': paymentDay,
          'phone':
              phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
          'iban':
              ibanCtrl.text.trim().isNotEmpty ? ibanCtrl.text.trim() : null,
        });
      } else {
        await fp.repo.createEmployee(FinanceEmployee(
          id: '',
          sellerId: fp.sellerId,
          fullName: name,
          position: positionCtrl.text.trim().isNotEmpty
              ? positionCtrl.text.trim()
              : null,
          baseSalary: base,
          paymentDay: paymentDay,
          phone:
              phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
          iban: ibanCtrl.text.trim().isNotEmpty ? ibanCtrl.text.trim() : null,
          isActive: true,
          createdAt: DateTime.now(),
        ));
      }
      await _load();
      fp.loadOverview();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // ── PAYMENT HISTORY DETAIL ────────────────
  void _openDetail(FinanceEmployee e) {
    final record = _recordFor(e);
    if (record == null) {
      _showEditSalaryDialog(e);
      return;
    }
    // Modal sheets attach to the root navigator (above the FinanceProvider
    // created in FinanceShell), so capture it here and re-expose it to the sheet.
    final fp = context.read<FinanceProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => ChangeNotifierProvider<FinanceProvider>.value(
        value: fp,
        child: _SalaryRecordDetailSheet(
          record: record,
          onAddPayment: () {
            Navigator.pop(context);
            _showPaymentDialog(record);
          },
          onUpdated: _load,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Salary Record Detail Sheet (ödeme geçmişi)
// ─────────────────────────────────────────
class _SalaryRecordDetailSheet extends StatefulWidget {
  const _SalaryRecordDetailSheet({
    required this.record,
    required this.onAddPayment,
    required this.onUpdated,
  });

  final SalaryRecord record;
  final VoidCallback onAddPayment;
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
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
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
                  child: Text(r.employeeName ?? 'Çalışan',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                ),
                FinStatusBadge(label: r.status.label, color: r.status.color),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _chip('Net Maaş', fmtCurrency(r.netSalary), kFinancePrimary),
                const SizedBox(width: 8),
                _chip('Ödenen', fmtCurrency(r.paidAmount),
                    const Color(0xFF10B981)),
                const SizedBox(width: 8),
                _chip('Kalan', fmtCurrency(r.netSalary - r.paidAmount),
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
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                TextButton.icon(
                  onPressed: widget.onAddPayment,
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Ödeme Ekle',
                      style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: kFinancePrimary),
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
                style:
                    const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
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
      subtitle: Text(fmtDate(p.paymentDate),
          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
    );
  }
}
