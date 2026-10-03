import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../models/mall_profile.dart';
import '../services/mall_management_repository.dart';
import 'mall_media_picker.dart';
import 'mall_panel_kit.dart';

class MallProfileView extends StatefulWidget {
  const MallProfileView({
    super.key,
    required this.mall,
    required this.canEdit,
    required this.repository,
    required this.onSaved,
  });

  final MallProfile mall;
  final bool canEdit;
  final MallManagementRepository repository;
  final Future<void> Function() onSaved;

  @override
  State<MallProfileView> createState() => _MallProfileViewState();
}

class _MallProfileViewState extends State<MallProfileView> {
  late final Map<String, TextEditingController> _fields = {
    'name': TextEditingController(text: widget.mall.name),
    'legal': TextEditingController(text: widget.mall.legalName ?? ''),
    'city': TextEditingController(text: widget.mall.city),
    'district': TextEditingController(text: widget.mall.district),
    'address': TextEditingController(text: widget.mall.addressText),
    'phone': TextEditingController(text: widget.mall.phone ?? ''),
    'website': TextEditingController(text: widget.mall.website ?? ''),
    'hours': TextEditingController(text: widget.mall.openingHours ?? ''),
  };
  var _editing = false;
  var _busy = false;
  String? _error;
  String? _nameError;

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mall = widget.mall;
    return MallPage(children: [
      MallPageTitle(
        title: 'AVM Bilgileri',
        subtitle: 'Müşterilerin göreceği AVM profili.',
        actions: [
          if (widget.canEdit && !_editing)
            MallPrimaryButton(label: 'Düzenle', icon: Icons.edit_outlined, onPressed: () => setState(() => _editing = true)),
        ],
      ),
      if (_error != null) MallInlineError(_error!, onClose: () => setState(() => _error = null)),
      _mediaCard(mall),
      MallCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MallCardTitle(
              'Profil',
              trailing: Wrap(spacing: 8, children: [
                MallBadge(mall.isVerified ? 'Doğrulandı' : 'Doğrulama bekleniyor',
                    tone: mall.isVerified ? MallTone.success : MallTone.warning),
                MallBadge(mall.publishLabel, tone: mall.status == 'active' ? MallTone.success : MallTone.neutral),
              ]),
            ),
            if (_editing) _form() else _readOnly(mall),
            if (!widget.canEdit)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Bu alanları AVM yöneticisi veya içerik editörü düzenleyebilir.',
                    style: TextStyle(color: MallTokens.muted)),
              ),
          ],
        ),
      ),
    ]);
  }

  Widget _mediaCard(MallProfile mall) {
    return MallCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(MallTokens.radius)),
            child: AspectRatio(
              aspectRatio: 1200 / 300,
              child: mall.coverUrl == null
                  ? Container(
                      color: MallTokens.soft,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_outlined, color: AppColors.primary, size: 40),
                    )
                  : Image.network(mall.coverUrl!, fit: BoxFit.cover),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                mallLogo(mall.logoUrl, size: 72),
                if (widget.canEdit) ...[
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _upload('logo'),
                    icon: const Icon(Icons.upload_outlined, size: 18),
                    label: Text(mall.logoUrl == null ? 'Logo Yükle' : 'Logoyu Değiştir'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _upload('cover'),
                    icon: const Icon(Icons.wallpaper_outlined, size: 18),
                    label: Text(mall.coverUrl == null ? 'Kapak Yükle' : 'Kapağı Değiştir'),
                  ),
                ],
                const Text('JPG, PNG veya WEBP • en fazla 10 MB', style: TextStyle(color: MallTokens.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _readOnly(MallProfile mall) {
    final rows = <(String, String?)>[
      ('AVM adı', mall.name),
      ('Resmi unvan', mall.legalName),
      ('Şehir / İlçe', mall.locationLabel),
      ('Adres', mall.addressText),
      ('Telefon', mall.phone),
      ('Web sitesi', mall.website),
      ('Çalışma saatleri', mall.openingHours),
    ];
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 160, child: Text(row.$1, style: const TextStyle(color: MallTokens.muted))),
                Expanded(
                  child: Text(
                    (row.$2?.trim().isEmpty ?? true) ? '—' : row.$2!,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _form() {
    Widget field(String key, String label, {int lines = 1, String? hint, String? error}) {
      return TextField(
        controller: _fields[key],
        maxLines: lines,
        decoration: mallInput(label, hint: hint, error: error),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MallGrid(minTileWidth: 300, children: [
          field('name', 'AVM adı *', error: _nameError),
          field('legal', 'Resmi unvan'),
          field('city', 'Şehir'),
          field('district', 'İlçe'),
          field('phone', 'Telefon'),
          field('website', 'Web sitesi', hint: 'primall.com'),
        ]),
        const SizedBox(height: 16),
        field('address', 'Adres', lines: 2),
        const SizedBox(height: 16),
        field('hours', 'Çalışma saatleri', lines: 2, hint: 'Her gün 10:00 - 22:00'),
        const SizedBox(height: 20),
        Wrap(alignment: WrapAlignment.end, spacing: 8, children: [
          TextButton(onPressed: _busy ? null : () => setState(() => _editing = false), child: const Text('Vazgeç')),
          MallPrimaryButton(label: _busy ? 'Kaydediliyor…' : 'Kaydet', onPressed: _busy ? null : _save),
        ]),
      ],
    );
  }

  String _text(String key) => _fields[key]!.text.trim();

  String? _optional(String key) => _text(key).isEmpty ? null : _text(key);

  Future<void> _save() async {
    setState(() => _nameError = _text('name').isEmpty ? 'AVM adı gerekli.' : null);
    if (_nameError != null) return;
    final mall = widget.mall;
    await _run(() async {
      await widget.repository.updateProfile(MallProfile(
        id: mall.id,
        name: _text('name'),
        legalName: _optional('legal'),
        city: _text('city'),
        district: _text('district'),
        addressText: _text('address'),
        phone: _optional('phone'),
        website: _optional('website'),
        openingHours: _optional('hours'),
        logoUrl: mall.logoUrl,
        coverUrl: mall.coverUrl,
        status: mall.status,
        isVerified: mall.isVerified,
      ));
      if (mounted) setState(() => _editing = false);
      await widget.onSaved();
      if (mounted) showMallSnack(context, 'AVM bilgileri kaydedildi.');
    });
  }

  Future<void> _upload(String kind) async {
    await _run(() async {
      final file = await pickMallImage(tag: 'MEDIA');
      if (file == null) return;
      final url = await widget.repository.uploadMedia(
        mallId: widget.mall.id,
        kind: kind,
        fileName: file.name,
        bytes: file.bytes,
      );
      await widget.repository.setMallMedia(mallId: widget.mall.id, kind: kind, url: url);
      await widget.onSaved();
      if (mounted) showMallSnack(context, kind == 'logo' ? 'Logo güncellendi.' : 'Kapak güncellendi.');
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = friendlyMallError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
