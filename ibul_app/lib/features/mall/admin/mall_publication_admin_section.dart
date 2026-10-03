import 'package:flutter/material.dart';

import '../../../app/ibul_router.dart';
import '../../../app/marketplace_paths.dart';
import '../../../core/constants.dart';
import 'mall_admin_repository.dart';

/// "Yayın Talepleri": malls waiting for İBUL approval before they appear on
/// the customer map. Hidden when the queue is empty.
class MallPublicationAdminSection extends StatefulWidget {
  const MallPublicationAdminSection({super.key, required this.repository});

  final MallAdminRepository repository;

  @override
  State<MallPublicationAdminSection> createState() => _MallPublicationAdminSectionState();
}

class _MallPublicationAdminSectionState extends State<MallPublicationAdminSection> {
  List<Map<String, dynamic>> _items = const [];
  final _busy = <String>{};
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.repository.publicationQueue();
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) setState(() => _error = mallAdminErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && _error == null) return const SizedBox.shrink();
    return Container(
      key: const ValueKey('mall-publication-queue'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Yayın Talepleri (${_items.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.danger)),
          for (final item in _items) _row(item),
        ],
      ),
    );
  }

  Widget _row(Map<String, dynamic> item) {
    final mallId = item['mall_id'].toString();
    final busy = _busy.contains(mallId);
    final location = [item['district'], item['city']].whereType<String>().join(', ');
    final hasCoords = item['latitude'] != null && item['longitude'] != null;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item['mall_name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(
              [
                if (location.isNotEmpty) location,
                '${item['floor_count'] ?? 0} kat',
                '${item['store_count'] ?? 0} mağaza',
                if (!hasCoords) 'konum yok',
                if (item['requested_by_email'] != null) item['requested_by_email'].toString(),
              ].join(' • '),
              style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
            ),
          ]),
        ),
        TextButton(
          onPressed: () => IbulRouter.go(context, MarketplacePaths.mallProfile(mallId)),
          child: const Text('Önizle'),
        ),
        OutlinedButton(onPressed: busy ? null : () => _reject(mallId), child: const Text('Reddet')),
        const SizedBox(width: 8),
        FilledButton(
          key: ValueKey('mall-publication-approve-$mallId'),
          onPressed: busy ? null : () => _review(mallId, approve: true),
          child: const Text('Yayına Al'),
        ),
      ]),
    );
  }

  Future<void> _reject(String mallId) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yayın talebini reddet'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'AVM yönetimine iletilecek neden *'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Reddet')),
        ],
      ),
    );
    controller.dispose();
    if (note == null) return;
    if (note.isEmpty) {
      setState(() => _error = 'Red nedeni zorunlu.');
      return;
    }
    await _review(mallId, approve: false, note: note);
  }

  Future<void> _review(String mallId, {required bool approve, String? note}) async {
    setState(() {
      _busy.add(mallId);
      _error = null;
    });
    try {
      await widget.repository.reviewPublication(mallId: mallId, approve: approve, note: note);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(approve ? 'AVM yayına alındı; haritada görünecek.' : 'Yayın talebi reddedildi.'),
      ));
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = mallAdminErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy.remove(mallId));
    }
  }
}
