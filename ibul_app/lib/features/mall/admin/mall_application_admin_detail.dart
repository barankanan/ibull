import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants.dart';
import '../models/mall_application.dart';
import 'mall_admin_repository.dart';

class MallApplicationAdminDetail extends StatefulWidget {
  const MallApplicationAdminDetail({
    super.key,
    required this.application,
    required this.repository,
    required this.onChanged,
  });

  final MallApplication application;
  final MallAdminRepository repository;
  final VoidCallback onChanged;

  @override
  State<MallApplicationAdminDetail> createState() =>
      _MallApplicationAdminDetailState();
}

class _MallApplicationAdminDetailState extends State<MallApplicationAdminDetail> {
  MallApplicantSummary? _applicant;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _loadApplicant();
  }

  @override
  void didUpdateWidget(covariant MallApplicationAdminDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.application.applicantUserId !=
        widget.application.applicantUserId) {
      _loadApplicant();
    }
  }

  Future<void> _loadApplicant() async {
    try {
      final summary = await widget.repository.applicantSummary(
        widget.application.applicantUserId,
      );
      if (!mounted) return;
      setState(() => _applicant = summary);
    } catch (error) {
      debugPrint('[mall-admin] applicant $error');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      await action();
      if (!mounted) return;
      widget.onChanged();
    } catch (error) {
      if (!mounted) return;
      final message = mallAdminErrorMessage(error);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      if (message.contains('değiştirilmiş')) widget.onChanged();
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final application = widget.application;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: wide ? 48 : 12,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
        child: Column(
          children: [
            AppBar(
              title: Text(application.mallName),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _chip(application.status),
                  const SizedBox(height: 16),
                  _section('AVM bilgileri', [
                    _line('Ad', application.mallName),
                    _line('Unvan', application.legalName),
                    _line('Telefon', application.phone),
                    _line('Web', application.website),
                  ]),
                  _section('Konum', [
                    _line('Şehir', application.city),
                    _line('İlçe', application.district),
                    _line('Adres', application.addressText),
                    _line(
                      'Koordinat',
                      '${application.latitude}, ${application.longitude}',
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => _openMap(application),
                        child: const Text('Haritada Aç'),
                      ),
                    ),
                  ]),
                  _section('Yetkili', [
                    _line('Ad', application.authorizedPersonName),
                    _line('Görev', application.authorizedPersonTitle),
                    _line(
                      'Kat sayısı',
                      application.declaredFloorCount?.toString(),
                    ),
                  ]),
                  _section('Başvuran', [
                    _line('Ad', _applicant?.displayName),
                    _line('E-posta', _applicant?.email),
                  ]),
                  _section('Başvuru', [
                    _line('Oluşturulma', _date(application.createdAt)),
                    _line('Gönderilme', _date(application.submittedAt)),
                    _line('Durum', mallAdminStatusLabel(application.status)),
                    _line('Admin notu', application.adminNote),
                    _line('Red nedeni', application.rejectionReason),
                    _line('İnceleme', _date(application.reviewedAt)),
                  ]),
                  if (application.status == MallApplicationStatus.approved)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'AVM organizasyonu oluşturuldu. Durum: kurulum aşamasında, henüz yayınlanmadı.',
                      ),
                    ),
                  _section(
                    'Belgeler',
                    application.documentPaths
                        .map((path) => _documentTile(path))
                        .toList(),
                  ),
                ],
              ),
            ),
            if (_hasActions(application.status))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (mallAdminCanApprove(application.status))
                      FilledButton(
                        onPressed: _acting || application.documentPaths.length < 6
                            ? null
                            : _approve,
                        child: const Text('Onayla'),
                      ),
                    if (mallAdminCanRequestInfo(application.status))
                      OutlinedButton(
                        onPressed: _acting ? null : _requestInfo,
                        child: const Text('Bilgi İste'),
                      ),
                    if (mallAdminCanReject(application.status))
                      TextButton(
                        onPressed: _acting ? null : _reject,
                        child: const Text('Reddet'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _hasActions(MallApplicationStatus status) =>
      mallAdminCanApprove(status) ||
      mallAdminCanRequestInfo(status) ||
      mallAdminCanReject(status);

  Future<void> _approve() async {
    final note = await _ask(
      title: 'AVM başvurusunu onayla',
      body:
          'Onay sonrası AVM organizasyonu oluşturulur, başvuran mall yöneticisi olur ve AVM henüz müşterilere yayınlanmaz.',
      noteLabel: 'Admin notu (opsiyonel)',
      required: false,
    );
    if (note == null) return;
    await _run(() async {
      await widget.repository.approveApplication(widget.application.id, note);
    });
  }

  Future<void> _requestInfo() async {
    final note = await _ask(
      title: 'Ek bilgi iste',
      body: 'Başvuran bu notu hesap ekranında görür.',
      noteLabel: 'İstenen bilgi',
      required: true,
    );
    if (note == null || note.trim().isEmpty) return;
    await _run(() async {
      await widget.repository.requestMoreInfo(
        applicationId: widget.application.id,
        adminNote: note,
      );
    });
  }

  Future<void> _reject() async {
    final reason = await _ask(
      title: 'Başvuruyu reddet',
      body: 'Red nedeni başvurana iletilir.',
      noteLabel: 'Red nedeni',
      required: true,
    );
    if (reason == null || reason.trim().isEmpty) return;
    await _run(() async {
      await widget.repository.rejectApplication(
        applicationId: widget.application.id,
        rejectionReason: reason,
      );
    });
  }

  Future<String?> _ask({
    required String title,
    required String body,
    required String noteLabel,
    required bool required,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(body),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(labelText: noteLabel),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              if (required && controller.text.trim().isEmpty) return;
              Navigator.pop(context, controller.text);
            },
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _openDocument(String path) async {
    try {
      final url = await widget.repository.signedDocumentUrl(path);
      final lower = path.toLowerCase();
      if (lower.endsWith('.pdf')) {
        final launched = await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Belge açılamadı.')),
          );
        }
        return;
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          child: SizedBox(
            width: 640,
            height: 480,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Center(
                child: Text('Görsel önizlenemedi.'),
              ),
            ),
          ),
        ),
      );
    } catch (error) {
      debugPrint('[mall-admin] document $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belge açılamadı.')),
      );
    }
  }

  Future<void> _openMap(MallApplication application) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${application.latitude},${application.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _documentTile(String path) {
    final name = path.split('/').last;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: TextButton(
        onPressed: () => _openDocument(path),
        child: const Text('Görüntüle'),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _line(String label, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text('$label: $value'),
    );
  }

  Widget _chip(MallApplicationStatus status) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(
        label: Text(mallAdminStatusLabel(status)),
        backgroundColor: AppColors.surfaceMuted,
        labelStyle: TextStyle(color: _color(status)),
      ),
    );
  }

  Color _color(MallApplicationStatus status) {
    return switch (status) {
      MallApplicationStatus.pendingReview => AppColors.warning,
      MallApplicationStatus.needsInfo => AppColors.primary,
      MallApplicationStatus.approved => AppColors.success,
      MallApplicationStatus.rejected ||
      MallApplicationStatus.cancelled =>
        AppColors.danger,
      _ => AppColors.textGrey,
    };
  }

  String? _date(DateTime? value) {
    if (value == null) return null;
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day.$month.${local.year}';
  }
}
