import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/finance_models.dart';
import '../../providers/finance_provider.dart';
import '../../widgets/finance_widgets.dart';

class ReconciliationTab extends StatefulWidget {
  const ReconciliationTab({super.key});

  @override
  State<ReconciliationTab> createState() => _ReconciliationTabState();
}

class _ReconciliationTabState extends State<ReconciliationTab> {
  List<ReconciliationNote> _notes = [];
  bool _loading = false;
  String? _error;
  String? _statusFilter; // null = all

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_notes.isEmpty && !_loading) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<FinanceProvider>().repo;
      _notes = await repo.getReconciliationNotes(status: _statusFilter);
      setState(() {});
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: _loading
              ? const FinLoadingOverlay()
              : _error != null
                  ? FinErrorCard(message: _error!, onRetry: _load)
                  : _notes.isEmpty
                      ? FinEmptyState(
                          message: 'Mutabakat kaydı bulunamadı',
                          icon: Icons.balance_outlined,
                          action: () => _showAddDialog(context),
                          actionLabel: 'Mutabakat Ekle',
                        )
                      : _buildList(),
        ),
        FinAddButton(
            label: 'Mutabakat Ekle',
            onTap: () => _showAddDialog(context)),
      ],
    );
  }

  Widget _buildFilterBar() {
    final filters = [
      ('Tümü', null),
      ('Bekliyor', 'pending'),
      ('İncelendi', 'reviewed'),
      ('Çözüldü', 'resolved'),
      ('Fark Var', 'discrepancy'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: filters
            .map((f) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _fc(f.$1, _statusFilter == f.$2, () {
                    setState(() => _statusFilter = f.$2);
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
          color: selected ? const Color(0xFF8B5CF6) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? const Color(0xFF8B5CF6) : kFinanceDivider),
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
        itemCount: _notes.length,
        itemBuilder: (_, i) => _noteCard(_notes[i]),
      ),
    );
  }

  Widget _noteCard(ReconciliationNote n) {
    final diff = (n.actualAmount ?? 0) - (n.expectedAmount ?? 0);
    final hasDiff = n.expectedAmount != null && n.actualAmount != null;
    final diffColor =
        diff >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
            color: n.status.color.withValues(alpha: 0.25)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showActionSheet(n),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      n.subject,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                  FinStatusBadge(
                      label: n.status.label, color: n.status.color),
                ],
              ),
              if (n.responsiblePerson != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Sorumlu: ${n.responsiblePerson}',
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF94A3B8)),
                ),
              ],
              const SizedBox(height: 8),
              if (hasDiff)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Beklenen',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFF94A3B8))),
                          Text(
                            fmtCurrency(n.expectedAmount!),
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Gerçekleşen',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFF94A3B8))),
                          Text(
                            fmtCurrency(n.actualAmount!),
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Fark',
                            style: TextStyle(
                                fontSize: 9,
                                color: Color(0xFF94A3B8))),
                        Text(
                          '${diff >= 0 ? '+' : ''}${fmtCurrency(diff)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: diffColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              if (n.description != null) ...[
                const SizedBox(height: 6),
                Text(
                  n.description!,
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF64748B)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    fmtDate(n.noteDate),
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF94A3B8)),
                  ),
                  if (n.dueDate != null)
                    Text(
                      'Son Tarih: ${fmtDate(n.dueDate!)}',
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF94A3B8)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActionSheet(ReconciliationNote n) {
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
            if (n.status != ReconciliationStatus.resolved)
              ListTile(
                leading: const Icon(Icons.check_circle_outline,
                    color: Color(0xFF10B981)),
                title: const Text('Çözüldü İşaretle'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final fp = context.read<FinanceProvider>();
                    await fp.repo.updateReconciliationNote(
                        n.id, {'status': ReconciliationStatus.resolved.value});
                    _load();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e')));
                    }
                  }
                },
              ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Sil'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  final fp = context.read<FinanceProvider>();
                  await fp.repo.deleteReconciliationNote(n.id);
                  _load();
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
    final subjectCtrl = TextEditingController();
    final expectedCtrl = TextEditingController();
    final actualCtrl = TextEditingController();
    final responsibleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var selectedStatus = ReconciliationStatus.pending;
    DateTime noteDate = DateTime.now();
    DateTime? dueDate;
    final dueDateCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Mutabakat Ekle',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FinTextField(
                    controller: subjectCtrl, label: 'Konu / Başlık'),
                const SizedBox(height: 10),
                FinTextField(
                  controller: expectedCtrl,
                  label: 'Beklenen Tutar (opsiyonel)',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  prefixText: '₺',
                ),
                const SizedBox(height: 10),
                FinTextField(
                  controller: actualCtrl,
                  label: 'Gerçekleşen Tutar (opsiyonel)',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  prefixText: '₺',
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<ReconciliationStatus>(
                  value: selectedStatus,
                  decoration: InputDecoration(
                    labelText: 'Durum',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  items: ReconciliationStatus.values
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.label,
                                style: const TextStyle(fontSize: 13)),
                          ))
                      .toList(),
                  onChanged: (v) => ss(() => selectedStatus = v!),
                ),
                const SizedBox(height: 10),
                FinTextField(
                    controller: responsibleCtrl,
                    label: 'Sorumlu Kişi (opsiyonel)'),
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
                        dueDate = picked;
                        dueDateCtrl.text = fmtDate(picked);
                      });
                    }
                  },
                  child: AbsorbPointer(
                    child: FinTextField(
                      controller: dueDateCtrl,
                      label: 'Son Tarih (opsiyonel)',
                      hint: 'Seçmek için dokunun',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FinTextField(
                    controller: descCtrl, label: 'Açıklama', maxLines: 3),
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
      final subject = subjectCtrl.text.trim();
      if (subject.isEmpty) return;
      try {
        final fp = context.read<FinanceProvider>();
        final note = ReconciliationNote(
          id: '',
          sellerId: fp.sellerId,
          subject: subject,
          noteDate: noteDate,
          expectedAmount: double.tryParse(
              expectedCtrl.text.replaceAll(',', '.')),
          actualAmount: double.tryParse(
              actualCtrl.text.replaceAll(',', '.')),
          status: selectedStatus,
          responsiblePerson: responsibleCtrl.text.trim().isNotEmpty
              ? responsibleCtrl.text.trim()
              : null,
          dueDate: dueDate,
          description: descCtrl.text.trim().isNotEmpty
              ? descCtrl.text.trim()
              : null,
          createdAt: DateTime.now(),
        );
        await fp.repo.createReconciliationNote(note);
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }
}
