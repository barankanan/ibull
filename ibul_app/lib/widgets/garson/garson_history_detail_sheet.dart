import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../models/restaurant_ops_models.dart';
import '../../services/store/table_order_history_utils.dart';
import 'order_preview_sheet.dart';

Future<void> showGarsonHistoryDetailSheet({
  required BuildContext context,
  required TableOrderHistoryRecord record,
  VoidCallback? onPrintAdisyon,
  VoidCallback? onPrintKitchen,
  Future<bool> Function()? onRestoreTable,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return GarsonHistoryDetailSheet(
        record: record,
        onPrintAdisyon: onPrintAdisyon,
        onPrintKitchen: onPrintKitchen,
        onRestoreTable: onRestoreTable,
      );
    },
  );
}

class GarsonHistoryDetailSheet extends StatefulWidget {
  const GarsonHistoryDetailSheet({
    super.key,
    required this.record,
    this.onPrintAdisyon,
    this.onPrintKitchen,
    this.onRestoreTable,
  });

  final TableOrderHistoryRecord record;
  final VoidCallback? onPrintAdisyon;
  final VoidCallback? onPrintKitchen;
  final Future<bool> Function()? onRestoreTable;

  @override
  State<GarsonHistoryDetailSheet> createState() =>
      _GarsonHistoryDetailSheetState();
}

class _GarsonHistoryDetailSheetState extends State<GarsonHistoryDetailSheet> {
  bool _restoreInProgress = false;

  static final _dtFmt = DateFormat('d MMM yyyy HH:mm');

  String _money(double value) =>
      '${value.toStringAsFixed(2).replaceAll('.', ',')} ₺';

  Future<void> _handleRestore() async {
    if (_restoreInProgress || widget.onRestoreTable == null) return;
    setState(() => _restoreInProgress = true);
    try {
      final ok = await widget.onRestoreTable!();
      if (!mounted) return;
      if (ok) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _restoreInProgress = false);
    }
  }

  Future<void> _promptRestoreForEdit() async {
    if (widget.onRestoreTable == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Masayı düzenlemek için aç'),
          content: const Text(
            'Kapalı masada miktar değişikliği yapılamaz. '
            'Siparişleri düzenlemek için masayı tekrar açmak ister misiniz?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Masayı Tekrar Aç'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await _handleRestore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final map = record.toMap();
    final tableTitle = record.displayTableLabel?.isNotEmpty == true
        ? record.displayTableLabel!
        : 'Masa ${record.tableNumber}';
    final area = record.tableAreaName ?? TableOrderHistoryUtils.areaName(map);
    final statusLabel = TableOrderHistoryUtils.closeStatusLabel(map);
    final openedAt = record.openedAt ?? record.createdAt;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.45,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tableTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111827),
                            ),
                          ),
                          if (area.isNotEmpty)
                            Text(
                              area,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Açılış: ${_dtFmt.format(openedAt)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ),
                    Text(
                      'Kapanış: ${_dtFmt.format(record.closedAt)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          for (final item in record.items)
                            _HistoryItemRow(
                              item: item,
                              money: _money,
                              onAdjustQuantity: _promptRestoreForEdit,
                            ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Toplam',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                _money(record.grandTotal),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => OrderPreviewSheet(
                            record: OrderPreviewRecord.fromHistory(record),
                            initialTab: 0,
                            onPrintAdisyon: widget.onPrintAdisyon,
                            onPrintKitchenTicket: widget.onPrintKitchen,
                            onResendToKitchen: widget.onPrintKitchen,
                          ),
                        );
                      },
                      icon: const Icon(Icons.preview_outlined, size: 16),
                      label: const Text('Adisyon / Mutfak Önizleme'),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    children: [
                      if (widget.onRestoreTable != null)
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _restoreInProgress ? null : _handleRestore,
                            icon: _restoreInProgress
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.replay_rounded, size: 18),
                            label: const Text('Masayı Tekrar Aç'),
                          ),
                        ),
                      if (widget.onRestoreTable != null) const SizedBox(width: 8),
                      if (widget.onPrintAdisyon != null)
                        _ActionIconButton(
                          tooltip: 'Adisyon Yazdır',
                          icon: Icons.receipt_long_outlined,
                          onTap: widget.onPrintAdisyon!,
                        ),
                      if (widget.onPrintKitchen != null)
                        _ActionIconButton(
                          tooltip: 'Mutfağa Yazdır',
                          icon: Icons.print_outlined,
                          onTap: widget.onPrintKitchen!,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HistoryItemRow extends StatelessWidget {
  const _HistoryItemRow({
    required this.item,
    required this.money,
    required this.onAdjustQuantity,
  });

  final Map<String, dynamic> item;
  final String Function(double) money;
  final VoidCallback onAdjustQuantity;

  @override
  Widget build(BuildContext context) {
    final qty = (item['quantity'] as num?)?.toInt() ?? 1;
    final unit = (item['price'] as num?)?.toDouble() ?? 0.0;
    final lineTotal = unit * qty;
    final name = item['name']?.toString().trim().isNotEmpty == true
        ? item['name'].toString().trim()
        : '-';
    final note = item['notes']?.toString().trim() ??
        item['note']?.toString().trim() ??
        '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if (note.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          note,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    Text(
                      '${money(unit)} × $qty',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              Text(
                money(lineTotal),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _QtyButton(icon: Icons.remove, onTap: onAdjustQuantity),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '$qty',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _QtyButton(icon: Icons.add, onTap: onAdjustQuantity),
              const SizedBox(width: 8),
              Text(
                'Düzenlemek için masayı aç',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: AppColors.primary),
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, size: 18),
    );
  }
}
