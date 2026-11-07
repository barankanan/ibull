import 'package:flutter/material.dart';

import 'transfer_table_modal.dart';

class MergeTableResult {
  const MergeTableResult({required this.targetTable, required this.targetLabel});

  final int targetTable;
  final String targetLabel;
}

class MergeTableSheet extends StatefulWidget {
  const MergeTableSheet({
    super.key,
    required this.sourceTable,
    required this.sourceLabel,
    required this.targets,
    required this.sourceItemCount,
    required this.sourcePaidLabel,
    required this.remainingLabel,
  });

  final int sourceTable;
  final String sourceLabel;
  final List<TransferTargetTable> targets;
  final int sourceItemCount;
  final String sourcePaidLabel;
  final String remainingLabel;

  static Future<MergeTableResult?> show(
    BuildContext context, {
    required int sourceTable,
    required String sourceLabel,
    required List<TransferTargetTable> targets,
    required int sourceItemCount,
    required String sourcePaidLabel,
    required String remainingLabel,
  }) {
    return showModalBottomSheet<MergeTableResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => MergeTableSheet(
        sourceTable: sourceTable,
        sourceLabel: sourceLabel,
        targets: targets,
        sourceItemCount: sourceItemCount,
        sourcePaidLabel: sourcePaidLabel,
        remainingLabel: remainingLabel,
      ),
    );
  }

  @override
  State<MergeTableSheet> createState() => _MergeTableSheetState();
}

class _MergeTableSheetState extends State<MergeTableSheet> {
  int? _target;

  @override
  Widget build(BuildContext context) {
    final choices = widget.targets
        .where((table) => table.tableNumber != widget.sourceTable)
        .toList(growable: false);
    final wide = MediaQuery.sizeOf(context).width >= 720;
    TransferTargetTable? selected;
    for (final table in choices) {
      if (table.tableNumber == _target) selected = table;
    }
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: wide ? 720 : double.infinity),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Masaları birleştir',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.sourceLabel} açık adisyonu seçilen masaya taşınır. '
              'Ürün, adet, not ve fiyat aynı kalır. Alınmış ara ödemeler '
              'hedef hesaba geçer. Mutfak fişi yeniden basılmaz.',
            ),
            const SizedBox(height: 12),
            Text(
              '${widget.sourceItemCount} açık satır · '
              'alınan ${widget.sourcePaidLabel} · '
              'birleşik kalan ${widget.remainingLabel}',
            ),
            const SizedBox(height: 12),
            if (choices.isEmpty)
              const Text('Birleştirilecek başka masa yok.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final table in choices)
                    ChoiceChip(
                      label: Text(
                        table.isOccupied ? '${table.label} · dolu' : table.label,
                      ),
                      selected: _target == table.tableNumber,
                      onSelected: (_) {
                        setState(() => _target = table.tableNumber);
                      },
                    ),
                ],
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: selected == null
                  ? null
                  : () {
                      final target = selected!;
                      Navigator.pop(
                        context,
                        MergeTableResult(
                          targetTable: target.tableNumber,
                          targetLabel: target.label,
                        ),
                      );
                    },
              child: const Text('Hesapları birleştir'),
            ),
          ],
        ),
      ),
    );
  }
}
