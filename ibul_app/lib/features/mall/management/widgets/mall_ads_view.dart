import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/mall_ops.dart';
import '../services/mall_management_repository.dart';
import '../services/mall_operations_repository.dart';
import 'mall_campaign_dialog.dart';
import 'mall_panel_kit.dart';

/// Mall ads live in the shared `campaigns` table and go through the existing
/// admin review flow. No separate payment or budget engine.
class MallAdsView extends StatefulWidget {
  const MallAdsView({super.key, required this.mallId, required this.canManage, required this.operations});

  final String mallId;
  final bool canManage;
  final MallOperationsRepository operations;

  @override
  State<MallAdsView> createState() => _MallAdsViewState();
}

class _MallAdsViewState extends State<MallAdsView> {
  late Future<List<MallAd>> _ads = widget.operations.ads(widget.mallId);
  var _tab = 'active';
  String? _error;

  void _reload() => setState(() {
        _ads = widget.operations.ads(widget.mallId);
      });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MallAd>>(
      future: _ads,
      builder: (context, snapshot) {
        final ads = snapshot.data ?? const <MallAd>[];
        int count(String group) => ads.where((ad) => ad.group == group).length;
        final items = ads.where((ad) => ad.group == _tab).toList();
        return MallPage(children: [
          MallPageTitle(
            title: 'Reklam',
            subtitle: 'İBUL reklam altyapısıyla AVM\'nizi öne çıkarın. Reklamlar İBUL onayından sonra yayınlanır.',
            actions: [
              if (widget.canManage) MallPrimaryButton(label: 'Reklam Oluştur', icon: Icons.add, onPressed: _create),
            ],
          ),
          if (_error != null) MallInlineError(_error!, onClose: () => setState(() => _error = null)),
          MallSegmented(
            items: {
              'active': 'Aktif (${count('active')})',
              'draft': 'Taslak (${count('draft')})',
              'review': 'Onay bekleyen (${count('review')})',
              'done': 'Tamamlanan (${count('done')})',
            },
            selected: _tab,
            onChanged: (value) => setState(() => _tab = value),
          ),
          if (snapshot.connectionState != ConnectionState.done)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          else if (snapshot.hasError)
            MallLoadError('Reklamlar yüklenemedi.', onRetry: _reload)
          else if (items.isEmpty)
            MallEmptyState(
              icon: Icons.campaign_outlined,
              title: 'Bu sekmede reklam yok',
              message: 'Yerleşimler: ${MallAdPlacement.values.map(MallAdPlacement.label).join(', ')}.',
              actionLabel: widget.canManage && ads.isEmpty ? 'Reklam Oluştur' : null,
              onAction: widget.canManage ? _create : null,
            )
          else
            MallGrid(minTileWidth: 320, children: [for (final ad in items) _card(ad)]),
        ]);
      },
    );
  }

  Widget _card(MallAd ad) {
    final dates = ad.startsAt == null || ad.endsAt == null
        ? ''
        : '${mallDateLabel(ad.startsAt!)} – ${mallDateLabel(ad.endsAt!)}';
    return MallCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(ad.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            MallBadge(ad.statusLabel, tone: ad.group == 'active' ? MallTone.success : MallTone.neutral),
          ]),
          const SizedBox(height: 6),
          Text(MallAdPlacement.label(ad.placement), style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            [dates, if (ad.totalBudget > 0) 'Bütçe ₺${ad.totalBudget.toStringAsFixed(0)}'].where((p) => p.isNotEmpty).join(' • '),
            style: const TextStyle(color: MallTokens.muted, fontSize: 13),
          ),
          if (ad.reviewNotes != null) ...[
            const SizedBox(height: 8),
            Text('İnceleme notu: ${ad.reviewNotes}', style: const TextStyle(fontSize: 13)),
          ],
          if (widget.canManage && ad.status == 'draft')
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => _submit(ad), child: const Text('Onaya Gönder')),
            ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _AdDialog(mallId: widget.mallId, operations: widget.operations),
    );
    if (created == true) {
      _reload();
      if (mounted) showMallSnack(context, 'Reklam kaydedildi.');
    }
  }

  Future<void> _submit(MallAd ad) async {
    try {
      await widget.operations.submitAd(widget.mallId, ad.id);
      _reload();
      if (mounted) showMallSnack(context, 'Reklam onaya gönderildi.');
    } catch (error) {
      if (mounted) setState(() => _error = friendlyMallError(error));
    }
  }
}

class _AdDialog extends StatefulWidget {
  const _AdDialog({required this.mallId, required this.operations});

  final String mallId;
  final MallOperationsRepository operations;

  @override
  State<_AdDialog> createState() => _AdDialogState();
}

class _AdDialogState extends State<_AdDialog> {
  final _name = TextEditingController();
  final _budget = TextEditingController();
  var _placement = MallAdPlacement.values.first;
  late DateTime _start = DateUtils.dateOnly(DateTime.now());
  late DateTime _end = _start.add(const Duration(days: 7));
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MallFormDialog(
      title: 'Reklam Oluştur',
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Vazgeç')),
        OutlinedButton(onPressed: _busy ? null : () => _save(false), child: const Text('Taslak Kaydet')),
        MallPrimaryButton(label: 'Onaya Gönder', onPressed: _busy ? null : () => _save(true)),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[MallInlineError(_error!), const SizedBox(height: 16)],
          TextField(controller: _name, decoration: mallInput('Reklam adı *')),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _placement,
            decoration: mallInput('Yerleşim'),
            items: [
              for (final value in MallAdPlacement.values)
                DropdownMenuItem(value: value, child: Text(MallAdPlacement.label(value))),
            ],
            onChanged: (value) => setState(() => _placement = value ?? _placement),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _date('Başlangıç', _start, (value) => _start = value)),
            const SizedBox(width: 12),
            Expanded(child: _date('Bitiş', _end, (value) => _end = value)),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _budget,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: mallInput('Planlanan toplam bütçe (₺)', hint: 'İsteğe bağlı'),
          ),
          const SizedBox(height: 8),
          const Text('Ücretlendirme mevcut İBUL reklam onay sürecinde belirlenir.',
              style: TextStyle(color: MallTokens.muted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _date(String label, DateTime value, ValueChanged<DateTime> onPicked) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2024),
          lastDate: DateTime(2035),
        );
        if (picked != null) setState(() => onPicked(picked));
      },
      child: InputDecorator(decoration: mallInput(label), child: Text(mallDateLabel(value))),
    );
  }

  Future<void> _save(bool submit) async {
    final end = DateTime(_end.year, _end.month, _end.day, 23, 59, 59);
    if (_name.text.trim().isEmpty) return setState(() => _error = 'Reklam adı gerekli.');
    if (!end.isAfter(_start)) return setState(() => _error = 'Bitiş tarihi başlangıçtan sonra olmalı.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.operations.createAd(
        mallId: widget.mallId,
        name: _name.text,
        placement: _placement,
        startsAt: _start,
        endsAt: end,
        totalBudget: double.tryParse(_budget.text) ?? 0,
        submit: submit,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyMallError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
