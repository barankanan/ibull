import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants.dart';
import '../models/mall_store_link.dart';
import '../services/mall_management_repository.dart';
import '../services/mall_operations_repository.dart';
import 'mall_panel_kit.dart';

typedef MallDocumentOpener = Future<void> Function(Uri url);

/// Store → AVM application review. The AVM gives the final answer; documents
/// open through a 5-minute signed URL, never a public link.
/// Returns the success message, or null when closed without a decision.
Future<String?> showMallStoreApplicationDialog(
  BuildContext context, {
  required MallStoreLink link,
  required MallOperationsRepository operations,
  MallDocumentOpener? openDocument,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ReviewDialog(
      link: link,
      operations: operations,
      openDocument: openDocument ?? (url) => launchUrl(url, mode: LaunchMode.externalApplication),
    ),
  );
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.link, required this.operations, required this.openDocument});

  final MallStoreLink link;
  final MallOperationsRepository operations;
  final MallDocumentOpener openDocument;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _message = TextEditingController();
  var _busy = false;
  String? _error;

  MallStoreLink get _link => widget.link;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MallFormDialog(
      title: 'Mağaza Başvurusu',
      width: 640,
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Kapat')),
        OutlinedButton(
          key: const ValueKey('mall-review-reject'),
          onPressed: _busy ? null : () => _decide(approve: false),
          child: const Text('Reddet'),
        ),
        OutlinedButton(
          key: const ValueKey('mall-review-info'),
          onPressed: _busy ? null : _askInfo,
          child: const Text('Bilgi İste'),
        ),
        MallPrimaryButton(
          key: const ValueKey('mall-review-approve'),
          label: _busy ? 'Kaydediliyor…' : 'Onayla',
          icon: Icons.check,
          onPressed: _busy ? null : () => _decide(approve: true),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[MallInlineError(_error!), const SizedBox(height: 12)],
          Row(children: [
            mallLogo(_link.logoUrl, size: 64),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_link.storeName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                if (_link.category != null) Text(_link.category!, style: const TextStyle(color: MallTokens.muted)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          _field('Şube', [?_link.branchName, if (_link.locationLabel.isNotEmpty) _link.locationLabel].join(' • ')),
          _field('Kat', _link.floorName),
          _field('Mağaza No', _link.unitCode),
          _field('Alan', _link.areaM2 == null ? '—' : '${_link.areaM2!.toStringAsFixed(0)} m²'),
          if (_link.note != null) _field('Not', _link.note!),
          if (_link.reviewNote != null) _field('Son mesajınız', _link.reviewNote!),
          const SizedBox(height: 12),
          const Text('Belgeler', style: TextStyle(fontWeight: FontWeight.w800)),
          for (final doc in _link.documents)
            ListTile(
              key: ValueKey('mall-review-doc-${doc.type}'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(doc.mime == 'application/pdf' ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
                  color: AppColors.primary),
              title: Text(doc.label),
              subtitle: Text(doc.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: TextButton(onPressed: _busy ? null : () => _open(doc), child: const Text('Görüntüle')),
            ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('mall-review-message'),
            controller: _message,
            maxLines: 2,
            maxLength: 500,
            decoration: mallInput('Mağazaya not', hint: 'Bilgi İste için zorunlu; onay/red için isteğe bağlı'),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: MallTokens.muted))),
          Expanded(child: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );

  Future<void> _open(MallLinkDocument doc) async {
    try {
      final url = await widget.operations.documentUrl(doc.path);
      await widget.openDocument(Uri.parse(url));
    } catch (error) {
      if (mounted) setState(() => _error = friendlyMallError(error));
    }
  }

  Future<void> _askInfo() async {
    if (_message.text.trim().length < 3) {
      setState(() => _error = 'Mağazaya iletilecek mesajı yazın.');
      return;
    }
    await _run(() => widget.operations.requestInfo(_link.id, _message.text), 'Bilgi isteği mağazaya gönderildi.');
  }

  Future<void> _decide({required bool approve}) => _run(
        () => widget.operations.respondToApplication(_link.id, approve: approve, note: _message.text),
        approve ? '${_link.storeName} ${_link.placeLabel} konumunda aktif.' : 'Başvuru reddedildi.',
      );

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.pop(context, success);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyMallError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
