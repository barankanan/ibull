import 'package:flutter/material.dart';

import '../../features/seller/achievements/models/seller_brand_verification_models.dart';
import '../../features/seller/achievements/services/seller_brand_verification_service.dart';

class BrandVerificationAdminPage extends StatefulWidget {
  const BrandVerificationAdminPage({super.key});

  @override
  State<BrandVerificationAdminPage> createState() =>
      _BrandVerificationAdminPageState();
}

class _BrandVerificationAdminPageState extends State<BrandVerificationAdminPage> {
  final _service = SellerBrandVerificationService();
  List<SellerBrandVerificationApplication> _applications = const [];
  bool _loading = true;
  String? _error;
  SellerBrandVerificationApplication? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _service.fetchAllForAdmin();
      if (!mounted) return;
      setState(() {
        _applications = rows;
        _loading = false;
        if (_selected != null) {
          final match = rows.where((row) => row.id == _selected!.id);
          _selected = match.isEmpty ? null : match.first;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Marka Onay Başvuruları',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Satıcı marka doğrulama başvurularını inceleyin ve onaylayın.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(child: Center(child: Text(_error!)))
          else
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: _buildList(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 6,
                    child: _selected == null
                        ? _emptyDetail()
                        : _buildDetail(_selected!),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_applications.isEmpty) {
      return const Center(child: Text('Başvuru bulunamadı'));
    }
    return Card(
      child: ListView.separated(
        itemCount: _applications.length,
        separatorBuilder: (_, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = _applications[index];
          final selected = _selected?.id == item.id;
          return ListTile(
            selected: selected,
            title: Text(item.brandName.isEmpty ? '—' : item.brandName),
            subtitle: Text(
              '${item.storeName ?? item.fullName}\n'
              '${item.statusLabel} • ${item.createdAt?.toLocal().toString().split('.').first ?? ''}',
            ),
            isThreeLine: true,
            onTap: () => setState(() => _selected = item),
          );
        },
      ),
    );
  }

  Widget _emptyDetail() {
    return Card(
      child: Center(
        child: Text(
          'Detay için bir başvuru seçin',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ),
    );
  }

  Widget _buildDetail(SellerBrandVerificationApplication item) {
    return Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.brandName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text('Durum: ${item.statusLabel}'),
            const Divider(height: 24),
            _detailRow('Başvuru sahibi', item.fullName),
            _detailRow('Firma ünvanı', item.companyTitle),
            _detailRow('MERSİS', item.mersisNo),
            _detailRow('Vergi No', item.taxNo),
            _detailRow('E-posta', item.email),
            _detailRow('Telefon', item.phone),
            _detailRow('Web', item.website ?? '—'),
            _detailRow('Ticaret Sicil', item.tradeRegistryNo ?? '—'),
            _detailRow('Not', item.storeNote ?? '—'),
            const SizedBox(height: 12),
            if (item.rejectionReason?.isNotEmpty == true)
              _detailRow('Red gerekçesi', item.rejectionReason!),
            if (item.adminNote?.isNotEmpty == true)
              _detailRow('Admin notu', item.adminNote!),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (item.taxPlatePath != null)
                  _docChip('Vergi levhası', item.taxPlatePath!),
                if (item.tradeRegistryPath != null)
                  _docChip('Ticaret sicil', item.tradeRegistryPath!),
                if (item.brandRegistrationPath != null)
                  _docChip('Marka tescil', item.brandRegistrationPath!),
                if (item.identityDocumentPath != null)
                  _docChip('Kimlik belgesi', item.identityDocumentPath!),
              ],
            ),
            if (item.status == SellerBrandVerificationStatus.submitted ||
                item.status == SellerBrandVerificationStatus.needsInfo) ...[
              const SizedBox(height: 20),
              _AdminActionPanel(
                onApprove: () => _approve(item),
                onReject: (reason) => _reject(item, reason),
                onRequestInfo: (note) => _requestInfo(item, note),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _docChip(String label, String path) {
    return ActionChip(
      label: Text(label),
      onPressed: () async {
        try {
          final url = await _service.signedDocumentUrl(path);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Belge hazır: $url')),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Belge açılamadı: $e')),
          );
        }
      },
    );
  }

  Future<void> _approve(SellerBrandVerificationApplication item) async {
    await _service.approveApplication(applicationId: item.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Başvuru onaylandı, rozet verildi')),
    );
    await _load();
  }

  Future<void> _reject(
    SellerBrandVerificationApplication item,
    String reason,
  ) async {
    await _service.rejectApplication(
      applicationId: item.id,
      reason: reason,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Başvuru reddedildi')),
    );
    await _load();
  }

  Future<void> _requestInfo(
    SellerBrandVerificationApplication item,
    String note,
  ) async {
    await _service.requestMoreInfo(
      applicationId: item.id,
      adminNote: note,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ek bilgi talebi gönderildi')),
    );
    await _load();
  }
}

class _AdminActionPanel extends StatefulWidget {
  const _AdminActionPanel({
    required this.onApprove,
    required this.onReject,
    required this.onRequestInfo,
  });

  final Future<void> Function() onApprove;
  final Future<void> Function(String reason) onReject;
  final Future<void> Function(String note) onRequestInfo;

  @override
  State<_AdminActionPanel> createState() => _AdminActionPanelState();
}

class _AdminActionPanelState extends State<_AdminActionPanel> {
  final _noteController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _noteController,
          decoration: const InputDecoration(
            labelText: 'Admin notu / red gerekçesi / ek bilgi',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      await widget.onApprove();
                      if (mounted) setState(() => _busy = false);
                    },
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Onayla'),
            ),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () async {
                      final reason = _noteController.text.trim();
                      if (reason.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Red için gerekçe zorunlu'),
                          ),
                        );
                        return;
                      }
                      setState(() => _busy = true);
                      await widget.onReject(reason);
                      if (mounted) setState(() => _busy = false);
                    },
              child: const Text('Reddet'),
            ),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () async {
                      final note = _noteController.text.trim();
                      if (note.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Ek bilgi notu zorunlu'),
                          ),
                        );
                        return;
                      }
                      setState(() => _busy = true);
                      await widget.onRequestInfo(note);
                      if (mounted) setState(() => _busy = false);
                    },
              child: const Text('Ek bilgi iste'),
            ),
          ],
        ),
      ],
    );
  }
}
