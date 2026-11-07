import 'package:flutter/material.dart';

import '../../services/store/split_bill_plan.dart';
import '../../services/store/table_payment_guard.dart';

const List<(String, String)> splitPaymentMethods = <(String, String)>[
  ('cash', 'Nakit'),
  ('card', 'Kart'),
  ('online', 'Online'),
];

class SplitBillSheet extends StatefulWidget {
  const SplitBillSheet({
    super.key,
    required this.tableLabel,
    required this.billKurus,
    required this.paidKurus,
    required this.idempotencyPrefix,
    required this.onCollect,
  });

  final String tableLabel;
  final int billKurus;
  final int paidKurus;
  final String idempotencyPrefix;
  final Future<void> Function(SplitShare share, String method) onCollect;

  static Future<void> show(
    BuildContext context, {
    required String tableLabel,
    required int billKurus,
    required int paidKurus,
    required String idempotencyPrefix,
    required Future<void> Function(SplitShare share, String method) onCollect,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SplitBillSheet(
        tableLabel: tableLabel,
        billKurus: billKurus,
        paidKurus: paidKurus,
        idempotencyPrefix: idempotencyPrefix,
        onCollect: onCollect,
      ),
    );
  }

  @override
  State<SplitBillSheet> createState() => _SplitBillSheetState();
}

class _SplitBillSheetState extends State<SplitBillSheet> {
  int _personCount = minEqualSplitPeople;
  final Map<int, String> _methods = <int, String>{};
  final Set<int> _paid = <int>{};
  int? _savingIndex;
  String? _error;

  int get _remainingKurus {
    final remaining = widget.billKurus - widget.paidKurus;
    return remaining < 0 ? 0 : remaining;
  }

  bool get _locked => _paid.isNotEmpty || _savingIndex != null;

  EqualSplitPlan get _plan => planEqualSplit(
    remainingKurus: _remainingKurus,
    personCount: _personCount,
    idempotencyPrefix: widget.idempotencyPrefix,
  );

  Future<void> _collect(SplitShare share) async {
    if (_savingIndex != null || _paid.contains(share.index)) return;
    setState(() {
      _savingIndex = share.index;
      _error = null;
    });
    try {
      await widget.onCollect(share, _methods[share.index] ?? 'cash');
      if (!mounted) return;
      setState(() {
        _paid.add(share.index);
        _savingIndex = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _savingIndex = null;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final wide = MediaQuery.sizeOf(context).width >= 720;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: wide ? 720 : double.infinity,
            maxHeight: MediaQuery.sizeOf(context).height * 0.86,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.tableLabel} — Hesabı Böl',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Her pay ayrı tahsil edilir. Masa kapanmaz ve fiş basılmaz.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 14),
                _Summary(
                  billKurus: widget.billKurus,
                  paidKurus: widget.paidKurus,
                ),
                const SizedBox(height: 12),
                _PeopleStepper(
                  count: _personCount,
                  locked: _locked,
                  onChanged: (count) => setState(() {
                    _personCount = count;
                    _error = null;
                  }),
                ),
                const SizedBox(height: 12),
                if (!plan.isReady)
                  Text(
                    plan.message ?? 'Hesap bölünemedi.',
                    style: const TextStyle(
                      color: Color(0xFFB45309),
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  for (final share in plan.shares) ...[
                    _ShareRow(
                      share: share,
                      method: _methods[share.index] ?? 'cash',
                      paid: _paid.contains(share.index),
                      saving: _savingIndex == share.index,
                      enabled: _savingIndex == null,
                      onMethod: (method) =>
                          setState(() => _methods[share.index] = method),
                      onCollect: () => _collect(share),
                    ),
                    const SizedBox(height: 8),
                  ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    key: const ValueKey<String>('split-error'),
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _savingIndex == null
                        ? () => Navigator.of(context).pop()
                        : null,
                    child: const Text('Kapat'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.billKurus, required this.paidKurus});

  final int billKurus;
  final int paidKurus;

  @override
  Widget build(BuildContext context) {
    final remaining = billKurus - paidKurus;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hesap ${formatTablePaymentKurus(billKurus)}'),
          Text(
            'Alınan ${formatTablePaymentKurus(paidKurus < 0 ? 0 : paidKurus)}',
          ),
          const SizedBox(height: 4),
          Text(
            'Kalan ${formatTablePaymentKurus(remaining < 0 ? 0 : remaining)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _PeopleStepper extends StatelessWidget {
  const _PeopleStepper({
    required this.count,
    required this.locked,
    required this.onChanged,
  });

  final int count;
  final bool locked;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Kişi sayısı',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          key: const ValueKey<String>('split-people-dec'),
          onPressed: locked || count <= minEqualSplitPeople
              ? null
              : () => onChanged(count - 1),
          icon: const Icon(Icons.remove),
        ),
        Text(
          '$count',
          key: const ValueKey<String>('split-people-count'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        IconButton(
          key: const ValueKey<String>('split-people-inc'),
          onPressed: locked || count >= maxEqualSplitPeople
              ? null
              : () => onChanged(count + 1),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({
    required this.share,
    required this.method,
    required this.paid,
    required this.saving,
    required this.enabled,
    required this.onMethod,
    required this.onCollect,
  });

  final SplitShare share;
  final String method;
  final bool paid;
  final bool saving;
  final bool enabled;
  final ValueChanged<String> onMethod;
  final VoidCallback onCollect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Kişi ${share.index}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                formatTablePaymentKurus(share.amountKurus),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final entry in splitPaymentMethods)
                ChoiceChip(
                  label: Text(entry.$2),
                  selected: method == entry.$1,
                  onSelected: paid || !enabled
                      ? null
                      : (selected) {
                          if (selected) onMethod(entry.$1);
                        },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              key: ValueKey<String>('split-collect-${share.index}'),
              onPressed: paid || !enabled ? null : onCollect,
              child: Text(
                paid
                    ? 'Alındı'
                    : saving
                    ? 'Kaydediliyor'
                    : 'Tahsil et',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
