import 'package:flutter/material.dart';

import '../models/mall_ops.dart';
import '../models/mall_store_link.dart';
import '../services/mall_management_repository.dart';
import 'mall_media_picker.dart';
import 'mall_panel_kit.dart';

String mallDateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

Future<MallCampaignDraft?> showMallCampaignDialog(
  BuildContext context, {
  required String mallId,
  required List<MallStoreLink> stores,
  required MallManagementRepository repository,
  MallCampaign? existing,
}) {
  return showDialog<MallCampaignDraft>(
    context: context,
    builder: (_) => _CampaignDialog(mallId: mallId, stores: stores, repository: repository, existing: existing),
  );
}

class _CampaignDialog extends StatefulWidget {
  const _CampaignDialog({required this.mallId, required this.stores, required this.repository, this.existing});

  final String mallId;
  final List<MallStoreLink> stores;
  final MallManagementRepository repository;
  final MallCampaign? existing;

  @override
  State<_CampaignDialog> createState() => _CampaignDialogState();
}

class _CampaignDialogState extends State<_CampaignDialog> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _description = TextEditingController(text: widget.existing?.description ?? '');
  late final _category = TextEditingController(text: widget.existing?.targetCategory ?? '');
  late String? _imageUrl = widget.existing?.imageUrl;
  late DateTime _start = widget.existing?.startsAt ?? _today();
  late DateTime _end = widget.existing?.endsAt ?? _today().add(const Duration(days: 14));
  late String _target = widget.existing?.targetType ?? 'mall';
  late final Set<String> _branches = {...?widget.existing?.targetBranchIds};
  var _uploading = false;
  String? _error;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _category.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MallFormDialog(
      title: widget.existing == null ? 'Kampanya Oluştur' : 'Kampanyayı Düzenle',
      width: 640,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        OutlinedButton(onPressed: _uploading ? null : () => _submit(false), child: const Text('Taslak Kaydet')),
        MallPrimaryButton(label: 'Yayınla', onPressed: _uploading ? null : () => _submit(true)),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[MallInlineError(_error!), const SizedBox(height: 16)],
          TextField(
            key: const ValueKey('mall-campaign-title'),
            controller: _title,
            decoration: mallInput('Başlık *', hint: 'Örn. Hafta sonu indirimi'),
          ),
          const SizedBox(height: 16),
          TextField(controller: _description, maxLines: 3, decoration: mallInput('Açıklama')),
          const SizedBox(height: 16),
          _imageRow(),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _dateField('Başlangıç', _start, (value) => _start = value)),
            const SizedBox(width: 12),
            Expanded(child: _dateField('Bitiş', _end, (value) => _end = value)),
          ]),
          const SizedBox(height: 20),
          const Text('Hedef', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          MallSegmented(
            items: const {'mall': 'Tüm AVM', 'stores': 'Seçili mağazalar', 'category': 'Kategori'},
            selected: _target,
            onChanged: (value) => setState(() => _target = value),
          ),
          const SizedBox(height: 12),
          if (_target == 'category')
            TextField(controller: _category, decoration: mallInput('Kategori *', hint: 'Örn. Giyim')),
          if (_target == 'stores')
            widget.stores.isEmpty
                ? const Text('AVM\'ye bağlı aktif mağaza yok.', style: TextStyle(color: MallTokens.muted))
                : Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final store in widget.stores)
                      if (store.branchId != null)
                        FilterChip(
                          label: Text(store.storeName),
                          selected: _branches.contains(store.branchId),
                          selectedColor: MallTokens.soft,
                          onSelected: (on) => setState(
                            () => on ? _branches.add(store.branchId!) : _branches.remove(store.branchId),
                          ),
                        ),
                  ]),
        ],
      ),
    );
  }

  Widget _imageRow() {
    return Row(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 120,
          height: 68,
          color: MallTokens.soft,
          child: _imageUrl == null
              ? const Icon(Icons.image_outlined)
              : Image.network(_imageUrl!, fit: BoxFit.cover),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Wrap(spacing: 8, children: [
          OutlinedButton.icon(
            onPressed: _uploading ? null : _upload,
            icon: const Icon(Icons.upload_outlined, size: 18),
            label: Text(_uploading ? 'Yükleniyor…' : 'Görsel Yükle'),
          ),
          if (_imageUrl != null)
            TextButton(onPressed: () => setState(() => _imageUrl = null), child: const Text('Kaldır')),
        ]),
      ),
    ]);
  }

  Widget _dateField(String label, DateTime value, ValueChanged<DateTime> onPicked) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2024),
          lastDate: DateTime(2035),
        );
        if (picked != null) setState(() => onPicked(picked));
      },
      child: InputDecorator(
        decoration: mallInput(label),
        child: Row(children: [
          Expanded(child: Text(mallDateLabel(value))),
          const Icon(Icons.calendar_today_outlined, size: 18),
        ]),
      ),
    );
  }

  Future<void> _upload() async {
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final file = await pickMallImage(tag: 'CAMPAIGN');
      if (file == null) return;
      final url = await widget.repository.uploadMedia(
        mallId: widget.mallId,
        kind: 'campaigns',
        fileName: file.name,
        bytes: file.bytes,
      );
      if (mounted) setState(() => _imageUrl = url);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyMallError(error));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _submit(bool publish) {
    final title = _title.text.trim();
    final endOfDay = DateTime(_end.year, _end.month, _end.day, 23, 59, 59);
    final error = title.length < 3 || title.length > 120
        ? 'Başlık 3-120 karakter olmalı.'
        : endOfDay.isBefore(_start)
            ? 'Bitiş tarihi başlangıçtan önce olamaz.'
            : _target == 'stores' && _branches.isEmpty
                ? 'En az bir mağaza seçin.'
                : _target == 'category' && _category.text.trim().isEmpty
                    ? 'Kategori girin.'
                    : null;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(
      context,
      MallCampaignDraft(
        id: widget.existing?.id,
        title: title,
        description: _description.text.trim().isEmpty ? null : _description.text.trim(),
        imageUrl: _imageUrl,
        startsAt: DateTime(_start.year, _start.month, _start.day),
        endsAt: endOfDay,
        targetType: _target,
        targetCategory: _target == 'category' ? _category.text.trim() : null,
        targetBranchIds: _target == 'stores' ? _branches.toList() : const [],
        publish: publish,
      ),
    );
  }
}
