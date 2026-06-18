import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../models/seller_brand_verification_models.dart';
import '../services/seller_brand_verification_service.dart';

class SellerBrandVerificationCard extends StatelessWidget {
  const SellerBrandVerificationCard({
    super.key,
    required this.sellerId,
    required this.isBrandVerified,
    required this.application,
    required this.onChanged,
  });

  final String sellerId;
  final bool isBrandVerified;
  final SellerBrandVerificationApplication? application;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final status = isBrandVerified
        ? SellerBrandVerificationStatus.approved
        : (application?.status ?? SellerBrandVerificationStatus.none);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFEFF6FF),
            AppColors.primary.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1D4ED8), Color(0xFF38BDF8)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1D4ED8).withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Onaylanmış Mağaza',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isBrandVerified
                          ? 'Marka doğrulamanız tamamlandı.'
                          : 'Marka ve işletme bilgilerinizi doğrulatarak güven rozeti kazanın.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StatusChip(label: _statusLabel(status)),
          if (!isBrandVerified &&
              application?.rejectionReason?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              'Red gerekçesi: ${application!.rejectionReason}',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFB91C1C),
                height: 1.35,
              ),
            ),
          ],
          if (!isBrandVerified &&
              application?.adminNote?.trim().isNotEmpty == true &&
              status == SellerBrandVerificationStatus.needsInfo) ...[
            const SizedBox(height: 8),
            Text(
              'Admin notu: ${application!.adminNote}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade700,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (!isBrandVerified)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: sellerId.trim().isEmpty
                    ? null
                    : () => _openForm(context),
                icon: const Icon(Icons.verified_user_outlined, size: 18),
                label: Text(_ctaLabel(status)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _statusLabel(SellerBrandVerificationStatus status) {
    if (isBrandVerified) return 'Onaylandı';
    return application?.statusLabel ?? 'Başvuru yok';
  }

  String _ctaLabel(SellerBrandVerificationStatus status) {
    switch (status) {
      case SellerBrandVerificationStatus.none:
        return 'Marka Onay Başvurusu';
      case SellerBrandVerificationStatus.draft:
        return 'Başvuruyu Tamamla';
      case SellerBrandVerificationStatus.submitted:
        return 'Başvuru Durumunu Gör';
      case SellerBrandVerificationStatus.needsInfo:
        return 'Eksik Bilgileri Tamamla';
      case SellerBrandVerificationStatus.rejected:
        return 'Yeniden Başvur';
      case SellerBrandVerificationStatus.approved:
        return 'Onaylandı';
    }
  }

  Future<void> _openForm(BuildContext context) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SellerBrandVerificationFormSheet(
        sellerId: sellerId,
        initialApplication: application,
        readOnly: application?.status == SellerBrandVerificationStatus.submitted,
      ),
    );
    if (changed == true) onChanged();
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF93C5FD)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1D4ED8),
        ),
      ),
    );
  }
}

class SellerBrandVerificationFormSheet extends StatefulWidget {
  const SellerBrandVerificationFormSheet({
    super.key,
    required this.sellerId,
    this.initialApplication,
    this.readOnly = false,
  });

  final String sellerId;
  final SellerBrandVerificationApplication? initialApplication;
  final bool readOnly;

  @override
  State<SellerBrandVerificationFormSheet> createState() =>
      _SellerBrandVerificationFormSheetState();
}

class _SellerBrandVerificationFormSheetState
    extends State<SellerBrandVerificationFormSheet> {
  final _service = SellerBrandVerificationService();
  final _formKey = GlobalKey<FormState>();
  late SellerBrandVerificationFormData _form;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _form = widget.initialApplication == null
        ? const SellerBrandVerificationFormData()
        : SellerBrandVerificationFormData.fromApplication(
            widget.initialApplication!,
          );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      margin: EdgeInsets.only(top: MediaQuery.sizeOf(context).height * 0.06),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Marka Onay Başvurusu',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
              ],
              if (widget.readOnly)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Başvurunuz incelemede. Sonuçlandığında burada görünecek.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
              _field('Ad Soyad', _form.fullName, (v) => _form = _form.copyWith(fullName: v)),
              _field('Marka Adı', _form.brandName, (v) => _form = _form.copyWith(brandName: v)),
              _field('Şirket / Firma Ünvanı', _form.companyTitle, (v) => _form = _form.copyWith(companyTitle: v)),
              _field('MERSİS No', _form.mersisNo, (v) => _form = _form.copyWith(mersisNo: v)),
              _field('Vergi No', _form.taxNo, (v) => _form = _form.copyWith(taxNo: v)),
              _field('Ticaret Sicil No', _form.tradeRegistryNo, (v) => _form = _form.copyWith(tradeRegistryNo: v)),
              _field('Web Sitesi', _form.website, (v) => _form = _form.copyWith(website: v), required: false),
              _field('E-posta', _form.email, (v) => _form = _form.copyWith(email: v)),
              _field('Telefon', _form.phone, (v) => _form = _form.copyWith(phone: v)),
              _field('Mağaza notu', _form.storeNote, (v) => _form = _form.copyWith(storeNote: v), maxLines: 3, required: false),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Şirket Kuruluş Tarihi'),
                subtitle: Text(
                  _form.companyFoundedAt == null
                      ? 'Seçilmedi'
                      : '${_form.companyFoundedAt!.day}.${_form.companyFoundedAt!.month}.${_form.companyFoundedAt!.year}',
                ),
                trailing: widget.readOnly
                    ? null
                    : TextButton(
                        onPressed: _pickFoundedDate,
                        child: const Text('Seç'),
                      ),
              ),
              _uploadTile('Vergi levhası', _form.taxPlatePath, 'tax_plate'),
              _uploadTile('Ticaret sicil / faaliyet belgesi', _form.tradeRegistryPath, 'trade_registry'),
              _uploadTile('Marka tescil belgesi (opsiyonel)', _form.brandRegistrationPath, 'brand_registration', optional: true),
              _uploadTile('Kimlik / yetkili belge', _form.identityDocumentPath, 'identity', optional: true),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _form.acceptedAccuracy,
                onChanged: widget.readOnly
                    ? null
                    : (v) => setState(() => _form = _form.copyWith(acceptedAccuracy: v ?? false)),
                title: const Text('Bilgilerin doğruluğunu kabul ediyorum'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _form.acceptedReview,
                onChanged: widget.readOnly
                    ? null
                    : (v) => setState(() => _form = _form.copyWith(acceptedReview: v ?? false)),
                title: const Text('İBUL doğrulama incelemesini kabul ediyorum'),
              ),
              if (!widget.readOnly) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: _saving ? null : _saveDraft,
                      child: const Text('Taslak Kaydet'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1D4ED8),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Başvuruyu Gönder'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    String value,
    ValueChanged<String> onChanged, {
    int maxLines = 1,
    bool required = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        initialValue: value,
        maxLines: maxLines,
        readOnly: widget.readOnly,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? '$label zorunlu' : null
            : null,
        onChanged: onChanged,
      ),
    );
  }

  Widget _uploadTile(
    String label,
    String? path,
    String key, {
    bool optional = false,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(path == null ? 'Yüklenmedi' : 'Yüklendi'),
      trailing: widget.readOnly
          ? null
          : TextButton(
              onPressed: () => _pickDocument(key),
              child: const Text('Yükle'),
            ),
    );
  }

  Future<void> _pickFoundedDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _form.companyFoundedAt ?? DateTime(now.year - 1),
      firstDate: DateTime(1950),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _form = _form.copyWith(companyFoundedAt: picked));
    }
  }

  Future<void> _pickDocument(String key) async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      setState(() => _error = 'Dosya okunamadı');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final path = await _service.uploadDocument(
        sellerId: widget.sellerId,
        fileName: file.name,
        bytes: bytes,
        contentType: _guessContentType(file.name),
      );
      setState(() {
        switch (key) {
          case 'tax_plate':
            _form = _form.copyWith(taxPlatePath: path);
          case 'trade_registry':
            _form = _form.copyWith(tradeRegistryPath: path);
          case 'brand_registration':
            _form = _form.copyWith(brandRegistrationPath: path);
          case 'identity':
            _form = _form.copyWith(identityDocumentPath: path);
        }
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _guessContentType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    return 'application/octet-stream';
  }

  Future<void> _saveDraft() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.saveDraft(
        sellerId: widget.sellerId,
        form: _form,
        existingId: widget.initialApplication?.id,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final validation = _form.validateForSubmit();
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.submitApplication(
        sellerId: widget.sellerId,
        form: _form,
        existingId: widget.initialApplication?.id,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marka onay başvurunuz gönderildi')),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
