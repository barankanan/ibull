import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../management/models/mall_store_link.dart';
import '../management/models/mall_unit.dart';
import '../management/services/mall_management_repository.dart';
import '../management/widgets/mall_panel_kit.dart';
import '../services/mall_picked_file.dart';
import 'seller_mall_link_repository.dart';
import 'seller_mall_models.dart';

typedef SellerMallFilePicker = Future<SellerMallFile?> Function(String type);

/// AVM Bul → Mağaza Konumu → Belgeler. Sends a store → AVM application; the
/// AVM management gives the final approval. Returns the AVM name when sent.
Future<String?> showSellerMallApplyDialog(
  BuildContext context, {
  SellerMallLinkRepository? repository,
  SellerMallFilePicker? pickFile,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ApplyDialog(
      repository: repository ?? SellerMallLinkRepository(),
      pickFile: pickFile ?? pickSellerMallFile,
    ),
  );
}

Future<SellerMallFile?> pickSellerMallFile(String type) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    withData: mallPickerWithData,
    withReadStream: mallPickerWithReadStream,
  );
  final file = result?.files.firstOrNull;
  if (file == null) return null;
  final mime = SellerMallFile.mimeFor(file.name);
  if (mime == null) throw MallManagementException('PDF, JPG, PNG veya WEBP yükleyin.');
  final bytes = await readMallPickedFile(file);
  if (bytes == null || bytes.isEmpty) throw MallManagementException('Dosya okunamadı.');
  if (bytes.length > SellerMallFile.maxBytes) throw MallManagementException('Dosya en fazla 10 MB olabilir.');
  return SellerMallFile(type: type, name: file.name, bytes: bytes, mime: mime);
}

class _ApplyDialog extends StatefulWidget {
  const _ApplyDialog({required this.repository, required this.pickFile});

  final SellerMallLinkRepository repository;
  final SellerMallFilePicker pickFile;

  @override
  State<_ApplyDialog> createState() => _ApplyDialogState();
}

class _ApplyDialogState extends State<_ApplyDialog> {
  static const _steps = ['AVM Bul', 'Mağaza Konumu', 'Belgeler'];

  final _query = TextEditingController();
  final _unitCode = TextEditingController();
  final _area = TextEditingController();
  final _note = TextEditingController();
  final _files = <String, SellerMallFile>{};
  late final _requestId = SellerMallApplicationDraft.newRequestId();
  var _step = 0;
  var _busy = false;
  var _searched = false;
  String? _error;
  List<SellerMallOption> _results = const [];
  List<SellerBranchOption> _branches = const [];
  SellerMallOption? _mall;
  String? _branchId;
  String? _floorId;

  @override
  void initState() {
    super.initState();
    widget.repository.myBranches().then((branches) {
      if (!mounted) return;
      setState(() {
        _branches = branches;
        _branchId = branches.firstOrNull?.id;
      });
    }).catchError((Object error) {
      if (mounted) setState(() => _error = friendlyMallError(error));
    });
  }

  @override
  void dispose() {
    _query.dispose();
    _unitCode.dispose();
    _area.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MallFormDialog(
      title: 'AVM\'ye Başvur',
      width: 760,
      actions: _actions(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stepper(),
          const SizedBox(height: 20),
          if (_error != null) ...[MallInlineError(_error!), const SizedBox(height: 16)],
          ...switch (_step) {
            0 => _findStep(),
            1 => _placeStep(),
            _ => _documentsStep(),
          },
        ],
      ),
    );
  }

  List<Widget> _actions() => [
        TextButton(
          onPressed: _busy
              ? null
              : () => _step == 0
                  ? Navigator.pop(context)
                  : setState(() {
                      _step -= 1;
                      _error = null;
                    }),
          child: Text(_step == 0 ? 'Vazgeç' : 'Geri'),
        ),
        if (_step == 1)
          MallPrimaryButton(
            key: const ValueKey('seller-apply-next'),
            label: 'Devam',
            icon: Icons.arrow_forward,
            onPressed: () {
              final error = _placeError();
              setState(() {
                _error = error;
                if (error == null) _step = 2;
              });
            },
          ),
        if (_step == 2)
          MallPrimaryButton(
            key: const ValueKey('seller-apply-send'),
            label: _busy ? 'Gönderiliyor…' : 'AVM\'ye Başvur',
            icon: Icons.send_outlined,
            onPressed: _busy ? null : _send,
          ),
      ];

  Widget _stepper() => Row(children: [
        for (var i = 0; i < _steps.length; i++) ...[
          if (i > 0) const Expanded(child: Divider(indent: 8, endIndent: 8)),
          CircleAvatar(
            radius: 14,
            backgroundColor: i <= _step ? AppColors.primary : MallTokens.soft,
            child: i < _step
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text('${i + 1}',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800, color: i <= _step ? Colors.white : MallTokens.muted)),
          ),
          const SizedBox(width: 8),
          Text(_steps[i],
              style: TextStyle(
                  fontWeight: i == _step ? FontWeight.w800 : FontWeight.w500, color: i == _step ? null : MallTokens.muted)),
        ],
      ]);

  List<Widget> _findStep() => [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: TextField(
              key: const ValueKey('seller-apply-query'),
              controller: _query,
              autofocus: true,
              onSubmitted: (_) => _search(),
              decoration: mallInput('AVM adı', hint: 'Örn. Primall'),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 52,
            child: MallPrimaryButton(
                key: const ValueKey('seller-apply-search'), label: 'Ara', onPressed: _busy ? null : _search),
          ),
        ]),
        const SizedBox(height: 16),
        if (_busy)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
        else if (_searched && _results.isEmpty)
          const Text('Eşleşen AVM bulunamadı.', textAlign: TextAlign.center, style: TextStyle(color: MallTokens.muted))
        else
          for (final mall in _results) _mallCard(mall),
      ];

  Widget _mallCard(SellerMallOption mall) => Container(
        key: ValueKey('seller-apply-mall-${mall.name}'),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(border: Border.all(color: MallTokens.border), borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          mallLogo(mall.logoUrl, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(mall.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              if (mall.locationLabel.isNotEmpty) Text(mall.locationLabel, style: const TextStyle(color: MallTokens.muted)),
              const SizedBox(height: 4),
              Wrap(spacing: 6, children: [
                if (mall.isVerified) const MallBadge('Doğrulandı', tone: MallTone.success, dense: true),
                if (mall.status != 'active') const MallBadge('Kurulumda', dense: true),
              ]),
            ]),
          ),
          MallPrimaryButton(
            label: 'Seç',
            onPressed: mall.floors.isEmpty
                ? null
                : () => setState(() {
                      _mall = mall;
                      _floorId = mall.floors.length == 1 ? mall.floors.first.id : null;
                      _error = null;
                      _step = 1;
                    }),
          ),
        ]),
      );

  List<Widget> _placeStep() {
    final mall = _mall!;
    return [
      Text(mall.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 14),
      if (_branches.length > 1) ...[
        DropdownButtonFormField<String>(
          key: const ValueKey('seller-apply-branch'),
          initialValue: _branchId,
          decoration: mallInput('Şube *'),
          items: [for (final branch in _branches) DropdownMenuItem(value: branch.id, child: Text(branch.label))],
          onChanged: (value) => setState(() => _branchId = value),
        ),
        const SizedBox(height: 12),
      ],
      DropdownButtonFormField<String>(
        key: const ValueKey('seller-apply-floor'),
        initialValue: _floorId,
        decoration: mallInput('Kat *'),
        items: [for (final floor in mall.floors) DropdownMenuItem(value: floor.id, child: Text(floor.name))],
        onChanged: (value) => setState(() => _floorId = value),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: TextField(
            key: const ValueKey('seller-apply-unit'),
            controller: _unitCode,
            decoration: mallInput('Mağaza No / Alan Kodu *', hint: '101, Z-12, K-03'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            key: const ValueKey('seller-apply-area'),
            controller: _area,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: mallInput('Alan (m²)', hint: 'İsteğe bağlı'),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      TextField(
        key: const ValueKey('seller-apply-note'),
        controller: _note,
        maxLines: 2,
        maxLength: 500,
        decoration: mallInput('Not', hint: 'AVM yönetimine iletmek istedikleriniz'),
      ),
    ];
  }

  String? _placeError() {
    if (_branchId == null) return 'Başvuru için aktif bir mağaza şubesi gerekli.';
    if (_floorId == null) return 'Kat seçin.';
    return MallUnitValidation.codeError(_unitCode.text) ?? MallUnitValidation.areaError(_area.text);
  }

  List<Widget> _documentsStep() => [
        const Text(
          'Mağazanız İBUL\'da doğrulandığı için vergi/ticaret evrakı tekrar istenmez. '
          'Belgeler gizli saklanır; yalnız AVM yönetimi ve siz görebilirsiniz.',
          style: TextStyle(color: MallTokens.muted),
        ),
        const SizedBox(height: 14),
        const Text('Zorunlu: biri yeterli', style: TextStyle(fontWeight: FontWeight.w800)),
        for (final type in MallLinkDocument.required) _fileRow(type),
        const SizedBox(height: 12),
        const Text('İsteğe bağlı', style: TextStyle(fontWeight: FontWeight.w800)),
        for (final type in const ['mall_approval', 'storefront_photo', 'other']) _fileRow(type),
      ];

  Widget _fileRow(String type) {
    final file = _files[type];
    return Padding(
      key: ValueKey('seller-apply-doc-$type'),
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        Icon(file == null ? Icons.upload_file_outlined : Icons.check_circle,
            color: file == null ? MallTokens.muted : AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(MallLinkDocument.labelFor(type), style: const TextStyle(fontWeight: FontWeight.w600)),
            if (file != null)
              Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: MallTokens.muted)),
          ]),
        ),
        if (file != null)
          IconButton(
            tooltip: 'Kaldır',
            onPressed: _busy ? null : () => setState(() => _files.remove(type)),
            icon: const Icon(Icons.close),
          ),
        OutlinedButton(
          key: ValueKey('seller-apply-pick-$type'),
          onPressed: _busy ? null : () => _pick(type),
          child: Text(file == null ? 'Yükle' : 'Değiştir'),
        ),
      ]),
    );
  }

  Future<void> _pick(String type) async {
    try {
      final file = await widget.pickFile(type);
      if (file != null && mounted) setState(() => _files[type] = file);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyMallError(error));
    }
  }

  Future<void> _search() async {
    if (_query.text.trim().length < 2) {
      setState(() => _error = 'En az 2 karakter yazın.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final results = await widget.repository.findMalls(_query.text);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searched = true;
      });
    } catch (error) {
      if (mounted) setState(() => _error = friendlyMallError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final draft = SellerMallApplicationDraft(
      requestId: _requestId,
      mallId: _mall!.id,
      branchId: _branchId!,
      floorId: _floorId!,
      unitCode: _unitCode.text,
      areaM2: double.tryParse(_area.text.trim().replaceAll(',', '.')),
      note: _note.text,
      files: _files.values.toList(),
    );
    if (!draft.hasRequiredDocument) {
      setState(() => _error = 'AVM kira sözleşmesi veya yer tahsis belgesinden birini yükleyin.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final mallName = await widget.repository.apply(draft);
      if (mounted) Navigator.pop(context, mallName.isEmpty ? _mall!.name : mallName);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyMallError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
