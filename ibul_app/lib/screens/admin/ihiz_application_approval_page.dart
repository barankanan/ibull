import 'package:flutter/material.dart';

import '../../services/admin_service.dart';

class IhizApplicationApprovalPage extends StatefulWidget {
  const IhizApplicationApprovalPage({super.key});

  @override
  State<IhizApplicationApprovalPage> createState() =>
      _IhizApplicationApprovalPageState();
}

class _IhizApplicationApprovalPageState
    extends State<IhizApplicationApprovalPage> {
  final AdminService _adminService = AdminService();
  String _statusFilter = 'pending';
  final Set<String> _updatingIds = <String>{};
  static const List<(String label, String value)> _topFilters = [
    ('Başvurular', 'pending'),
    ('Kullanıcılar', 'approved'),
    ('Red Edilenler', 'rejected'),
  ];

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Onaylı';
      case 'rejected':
        return 'Reddedildi';
      default:
        return 'Beklemede';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF065F46);
      case 'rejected':
        return const Color(0xFF991B1B);
      default:
        return const Color(0xFF92400E);
    }
  }

  String _formatDate(dynamic raw) {
    final value = raw?.toString();
    if (value == null || value.isEmpty) return '-';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final local = parsed.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  Future<String?> _askRejectReason() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Red Nedeni'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Kısa bir red nedeni girin',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Reddet'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<bool> _updateStatus(
    Map<String, dynamic> row,
    String status, {
    String? rejectionReason,
  }) async {
    final id = row['id']?.toString();
    if (id == null || id.isEmpty) return false;
    if (_updatingIds.contains(id)) return false;

    setState(() {
      _updatingIds.add(id);
    });
    try {
      await _adminService.updateIhizCourierApplicationStatus(
        id,
        status,
        rejectionReason: rejectionReason,
      );
      if (!mounted) return false;
      final message = status == 'approved'
          ? 'Başvuru onaylandı.'
          : (status == 'rejected'
                ? 'Başvuru reddedildi.'
                : 'Başvuru durumu güncellendi.');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Güncelleme başarısız: ${error.toString().replaceAll('Exception:', '').trim()}',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _updatingIds.remove(id);
        });
      }
    }
  }

  Future<void> _openDetailDialog(Map<String, dynamic> row) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return _IhizApplicationDetailDialog(
          row: Map<String, dynamic>.from(row),
          formatDate: _formatDate,
          statusLabel: _statusLabel,
          statusColor: _statusColor,
          askRejectReason: _askRejectReason,
          onApprove: (targetRow) => _updateStatus(targetRow, 'approved'),
          onReject: (targetRow, reason) =>
              _updateStatus(targetRow, 'rejected', rejectionReason: reason),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusQuery = _statusFilter == 'all' ? null : _statusFilter;
    String? emptyLabel;
    for (final item in _topFilters) {
      if (item.$2 == _statusFilter) {
        emptyLabel = item.$1;
        break;
      }
    }
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _topFilters.map((item) {
                final isActive = _statusFilter == item.$2;
                return InkWell(
                  onTap: () {
                    if (_statusFilter == item.$2) return;
                    setState(() {
                      _statusFilter = item.$2;
                    });
                  },
                  borderRadius: BorderRadius.circular(999),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF6D28D9)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isActive
                            ? const Color(0xFF6D28D9)
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Text(
                      item.$1,
                      style: TextStyle(
                        color: isActive
                            ? Colors.white
                            : const Color(0xFF374151),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _adminService.getIhizCourierApplicationsStream(
              status: statusQuery,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Başvurular yüklenemedi: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              final rows = snapshot.data ?? const <Map<String, dynamic>>[];
              if (rows.isEmpty) {
                return Center(
                  child: Text(
                    '${emptyLabel ?? 'Bu filtrede'} kaydı bulunamadı.',
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final id = row['id']?.toString() ?? '';
                  final status = (row['status'] ?? 'pending').toString();
                  final isUpdating = _updatingIds.contains(id);
                  final fullName = (row['full_name'] ?? '-').toString();
                  final email = (row['email'] ?? '-').toString();
                  final phone = (row['phone'] ?? '-').toString();
                  final city = (row['city'] ?? '-').toString();
                  final district = (row['district'] ?? '-').toString();
                  final availability = (row['availability'] ?? '-').toString();
                  final rejectionReason = (row['rejection_reason'] ?? '')
                      .toString()
                      .trim();

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  fullName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _statusColor(
                                    status,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  _statusLabel(status),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _statusColor(status),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            children: [
                              Text('E-posta: $email'),
                              Text('Telefon: $phone'),
                              Text('Bölge: $district / $city'),
                              Text('Müsaitlik: $availability'),
                              Text(
                                'Başvuru: ${_formatDate(row['created_at'])}',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Ehliyet: ${(row['license_type'] ?? '-')} | Motor: ${(row['motor_type'] ?? '-')} | Sicil: ${(row['criminal_record'] ?? '-')}',
                            style: const TextStyle(color: Color(0xFF4B5563)),
                          ),
                          if (rejectionReason.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Red nedeni: $rejectionReason',
                              style: const TextStyle(color: Color(0xFFB91C1C)),
                            ),
                          ],
                          const SizedBox(height: 14),
                          if (status == 'pending')
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _openDetailDialog(row),
                                  icon: const Icon(Icons.visibility_outlined),
                                  label: const Text('Detaylar'),
                                ),
                                OutlinedButton(
                                  onPressed: isUpdating
                                      ? null
                                      : () async {
                                          final reason =
                                              await _askRejectReason();
                                          if (reason == null) return;
                                          await _updateStatus(
                                            row,
                                            'rejected',
                                            rejectionReason: reason,
                                          );
                                        },
                                  child: const Text('Reddet'),
                                ),
                                const SizedBox(width: 10),
                                FilledButton(
                                  onPressed: isUpdating
                                      ? null
                                      : () => _updateStatus(row, 'approved'),
                                  child: isUpdating
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Onayla'),
                                ),
                              ],
                            )
                          else
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _openDetailDialog(row),
                                  icon: const Icon(Icons.visibility_outlined),
                                  label: const Text('Detaylar'),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  status == 'approved'
                                      ? 'Onay tarihi: ${_formatDate(row['approved_at'])}'
                                      : 'Durum güncellendi',
                                  style: const TextStyle(
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _IhizApplicationDetailDialog extends StatefulWidget {
  const _IhizApplicationDetailDialog({
    required this.row,
    required this.formatDate,
    required this.statusLabel,
    required this.statusColor,
    required this.askRejectReason,
    required this.onApprove,
    required this.onReject,
  });

  final Map<String, dynamic> row;
  final String Function(dynamic raw) formatDate;
  final String Function(String status) statusLabel;
  final Color Function(String status) statusColor;
  final Future<String?> Function() askRejectReason;
  final Future<bool> Function(Map<String, dynamic> row) onApprove;
  final Future<bool> Function(Map<String, dynamic> row, String reason) onReject;

  @override
  State<_IhizApplicationDetailDialog> createState() =>
      _IhizApplicationDetailDialogState();
}

class _IhizApplicationDetailDialogState
    extends State<_IhizApplicationDetailDialog> {
  int _activeSectionIndex = 0;
  bool _isActionLoading = false;

  static const List<String> _sections = [
    'Genel Bilgiler',
    'Belgeler',
    'Finansal Bilgiler',
    'Yetkili Kişi',
    'Geçmiş İşlemler',
  ];

  String _text(dynamic value, {String fallback = '-'}) {
    final resolved = value?.toString().trim() ?? '';
    return resolved.isEmpty ? fallback : resolved;
  }

  bool _hasValue(dynamic value) {
    final resolved = value?.toString().trim() ?? '';
    return resolved.isNotEmpty;
  }

  bool _docExists(String key) => _hasValue(widget.row[key]);

  String _formatBytes(dynamic value) {
    int bytes = 0;
    if (value is int) {
      bytes = value;
    } else if (value is num) {
      bytes = value.toInt();
    } else {
      bytes = int.tryParse('${value ?? ''}') ?? 0;
    }
    if (bytes <= 0) return '-';
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  String _fileExtension(String value) {
    final source = value.trim();
    if (source.isEmpty) return '';
    final path = Uri.tryParse(source)?.path ?? source;
    final normalized = path.toLowerCase();
    final dotIndex = normalized.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex >= normalized.length - 1) {
      return '';
    }
    return normalized.substring(dotIndex + 1);
  }

  bool _isImageDocument({required String fileName, String? publicUrl}) {
    final extension = _fileExtension(publicUrl ?? fileName);
    return extension == 'jpg' ||
        extension == 'jpeg' ||
        extension == 'png' ||
        extension == 'webp';
  }

  Future<void> _openImagePreview({
    required String title,
    required String imageUrl,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 40,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 5,
                    child: Center(
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) {
                          return const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'Görsel yüklenemedi. URL erişimini kontrol edin.',
                              style: TextStyle(color: Color(0xFFB91C1C)),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDocumentCard({
    required String title,
    required String fileName,
    required String fileSize,
    String? publicUrl,
  }) {
    final exists = fileName != '-';
    final normalizedUrl = (publicUrl ?? '').trim();
    final hasUrl = normalizedUrl.isNotEmpty;
    final canPreviewImage =
        exists &&
        hasUrl &&
        _isImageDocument(fileName: fileName, publicUrl: normalizedUrl);
    return Container(
      width: 360,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: exists ? const Color(0xFFBFDBFE) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: exists
                      ? const Color(0xFFEFF6FF)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.description_outlined,
                  color: exists
                      ? const Color(0xFF1D4ED8)
                      : const Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF374151),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fileName,
                      style: TextStyle(
                        color: exists
                            ? const Color(0xFF111827)
                            : const Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Boyut: $fileSize',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (canPreviewImage) ...[
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () =>
                  _openImagePreview(title: title, imageUrl: normalizedUrl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    normalizedUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) {
                      return Container(
                        color: const Color(0xFFF3F4F6),
                        alignment: Alignment.center,
                        child: const Text(
                          'Önizleme yüklenemedi',
                          style: TextStyle(color: Color(0xFFB91C1C)),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () =>
                  _openImagePreview(title: title, imageUrl: normalizedUrl),
              icon: const Icon(Icons.open_in_new_outlined),
              label: const Text('Görseli Aç'),
            ),
          ] else if (exists && !hasUrl) ...[
            const SizedBox(height: 8),
            const Text(
              'Bu başvuru için belge görsel URL kaydı yok.',
              style: TextStyle(color: Color(0xFF92400E), fontSize: 12),
            ),
          ] else if (exists && hasUrl) ...[
            const SizedBox(height: 8),
            Text(
              'Belge türü görsel önizleme desteklemiyor: $normalizedUrl',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ] else ...[
            const SizedBox(height: 8),
            const Text(
              'Belge yüklenmemiş',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  double _applicationScore5() {
    final checks = <bool>[
      _hasValue(widget.row['full_name']),
      _hasValue(widget.row['email']),
      _hasValue(widget.row['phone']),
      _text(widget.row['tc_number'], fallback: '').length == 11,
      _hasValue(widget.row['license_type']),
      _hasValue(widget.row['motor_type']),
      _hasValue(widget.row['city']),
      _hasValue(widget.row['district']),
      _docExists('driver_license_front_file_name'),
      _docExists('driver_license_back_file_name'),
      _docExists('vehicle_registration_file_name'),
    ];
    final okCount = checks.where((item) => item).length;
    return (okCount / checks.length) * 5;
  }

  int _trustScore100() {
    final base = (_applicationScore5() / 5 * 100).round();
    final criminalRecord = _text(widget.row['criminal_record']).toLowerCase();
    if (criminalRecord == 'var') {
      return (base - 18).clamp(30, 100);
    }
    return base.clamp(30, 100);
  }

  String _riskLabel() {
    final criminalRecord = _text(widget.row['criminal_record']).toLowerCase();
    final hasAllDocs =
        _docExists('driver_license_front_file_name') &&
        _docExists('driver_license_back_file_name') &&
        _docExists('vehicle_registration_file_name');
    if (criminalRecord == 'var') return 'Yüksek';
    if (!hasAllDocs) return 'Orta';
    return 'Düşük';
  }

  Color _riskColor() {
    switch (_riskLabel()) {
      case 'Yüksek':
        return const Color(0xFFB91C1C);
      case 'Orta':
        return const Color(0xFF92400E);
      default:
        return const Color(0xFF166534);
    }
  }

  bool _autoVerified() {
    return _text(widget.row['tc_number'], fallback: '').length == 11 &&
        _text(widget.row['phone'], fallback: '').length >= 10 &&
        _docExists('driver_license_front_file_name') &&
        _docExists('driver_license_back_file_name') &&
        _docExists('vehicle_registration_file_name');
  }

  Future<void> _approveFromDialog() async {
    if (_isActionLoading) return;
    setState(() {
      _isActionLoading = true;
    });
    final approved = await widget.onApprove(widget.row);
    if (mounted) {
      setState(() {
        _isActionLoading = false;
      });
    }
    if (approved && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _rejectFromDialog() async {
    if (_isActionLoading) return;
    final reason = await widget.askRejectReason();
    if (reason == null || reason.trim().isEmpty) return;
    setState(() {
      _isActionLoading = true;
    });
    final rejected = await widget.onReject(widget.row, reason);
    if (mounted) {
      setState(() {
        _isActionLoading = false;
      });
    }
    if (rejected && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<String?> _askMissingDocumentNote() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eksik Belge Bildir'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText:
                  'Hangi belge eksik? Kurye için kısa bir açıklama yazın.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Gönder'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<void> _sendMissingDocumentNotice() async {
    final note = await _askMissingDocumentNote();
    if (note == null || note.trim().isEmpty || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Eksik belge bildirimi oluşturuldu.')),
    );
  }

  Widget _buildMetaItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContent() {
    switch (_activeSectionIndex) {
      case 1:
        final frontName = _text(widget.row['driver_license_front_file_name']);
        final frontSize = _formatBytes(
          widget.row['driver_license_front_file_size'],
        );
        final frontUrl = _text(
          widget.row['driver_license_front_url'],
          fallback: '',
        );
        final backName = _text(widget.row['driver_license_back_file_name']);
        final backSize = _formatBytes(
          widget.row['driver_license_back_file_size'],
        );
        final backUrl = _text(
          widget.row['driver_license_back_url'],
          fallback: '',
        );
        final vehicleName = _text(widget.row['vehicle_registration_file_name']);
        final vehicleSize = _formatBytes(
          widget.row['vehicle_registration_file_size'],
        );
        final vehicleUrl = _text(
          widget.row['vehicle_registration_url'],
          fallback: '',
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Yüklenen Belgeler',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildDocumentCard(
                  title: 'Ehliyet Ön Yüz',
                  fileName: frontName,
                  fileSize: frontSize,
                  publicUrl: frontUrl,
                ),
                _buildDocumentCard(
                  title: 'Ehliyet Arka Yüz',
                  fileName: backName,
                  fileSize: backSize,
                  publicUrl: backUrl,
                ),
                _buildDocumentCard(
                  title: 'Araç Ruhsatı',
                  fileName: vehicleName,
                  fileSize: vehicleSize,
                  publicUrl: vehicleUrl,
                ),
              ],
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Finansal Bilgiler',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            _buildMetaItem('Şirket Türü', _text(widget.row['company_type'])),
            _buildMetaItem('Vergi Numarası', _text(widget.row['tax_number'])),
            _buildMetaItem(
              'Hesap Sahibi',
              _text(widget.row['payment_account_holder']),
            ),
            _buildMetaItem('Banka Adı', _text(widget.row['payment_bank_name'])),
            _buildMetaItem('IBAN', _text(widget.row['payment_iban'])),
            _buildMetaItem(
              'Sistem Yorumu',
              _riskLabel() == 'Yüksek'
                  ? 'İnceleme önerilir'
                  : 'Temel finans verisi uygun',
            ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Yetkili Kişi',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            _buildMetaItem('Ad Soyad', _text(widget.row['full_name'])),
            _buildMetaItem('E-posta', _text(widget.row['email'])),
            _buildMetaItem('Telefon', _text(widget.row['phone'])),
            _buildMetaItem('TC Kimlik No', _text(widget.row['tc_number'])),
            _buildMetaItem('Doğum Tarihi', _text(widget.row['birth_date'])),
          ],
        );
      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Geçmiş İşlemler',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            _buildMetaItem(
              'Başvuru Tarihi',
              widget.formatDate(widget.row['created_at']),
            ),
            _buildMetaItem(
              'Durum',
              widget.statusLabel(
                _text(widget.row['status'], fallback: 'pending'),
              ),
            ),
            _buildMetaItem(
              'Onay Tarihi',
              widget.formatDate(widget.row['approved_at']),
            ),
            _buildMetaItem('Red Nedeni', _text(widget.row['rejection_reason'])),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Genel Bilgiler',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            _buildMetaItem('Ad Soyad', _text(widget.row['full_name'])),
            _buildMetaItem(
              'Bölge',
              '${_text(widget.row['district'])} / ${_text(widget.row['city'])}',
            ),
            _buildMetaItem('Müsaitlik', _text(widget.row['availability'])),
            _buildMetaItem('Ehliyet', _text(widget.row['license_type'])),
            _buildMetaItem('Motor', _text(widget.row['motor_type'])),
            _buildMetaItem('Adli Sicil', _text(widget.row['criminal_record'])),
            _buildMetaItem('Not', _text(widget.row['note'])),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _text(widget.row['status'], fallback: 'pending');
    final score = _applicationScore5().toStringAsFixed(1);
    final trust = _trustScore100();
    final autoVerified = _autoVerified();
    final statusColor = widget.statusColor(status);
    final isPending = status == 'pending';

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200, maxHeight: 760),
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.badge_outlined),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _text(widget.row['full_name']),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  widget.statusLabel(status),
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                'Başvuru Tarihi: ${widget.formatDate(widget.row['created_at'])}',
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 240,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          right: BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                      ),
                      child: ListView.builder(
                        itemCount: _sections.length,
                        itemBuilder: (context, index) {
                          final isActive = _activeSectionIndex == index;
                          return ListTile(
                            selected: isActive,
                            leading: Icon(
                              [
                                Icons.info_outline,
                                Icons.description_outlined,
                                Icons.account_balance_wallet_outlined,
                                Icons.person_outline,
                                Icons.history,
                              ][index],
                            ),
                            title: Text(_sections[index]),
                            onTap: () {
                              setState(() {
                                _activeSectionIndex = index;
                              });
                            },
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_activeSectionIndex == 0) ...[
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _ScoreMetricCard(
                                    title: 'Başvuru Skoru',
                                    value: score,
                                    subtitle: '5.0 üzerinden',
                                    valueColor: const Color(0xFF2563EB),
                                    icon: Icons.query_stats_outlined,
                                  ),
                                  _ScoreMetricCard(
                                    title: 'Risk Seviyesi',
                                    value: _riskLabel(),
                                    subtitle: 'Otomatik değerlendirme',
                                    valueColor: _riskColor(),
                                    icon: Icons.shield_outlined,
                                  ),
                                  _ScoreMetricCard(
                                    title: 'Oto. Doğrulama',
                                    value: autoVerified
                                        ? 'Başarılı'
                                        : 'İncelenmeli',
                                    subtitle: 'TC + belge + iletişim',
                                    valueColor: autoVerified
                                        ? const Color(0xFF0F766E)
                                        : const Color(0xFF92400E),
                                    icon: Icons.verified_outlined,
                                  ),
                                  _ScoreMetricCard(
                                    title: 'Güven Puanı',
                                    value: '$trust/100',
                                    subtitle: 'Profil güven metriği',
                                    valueColor: const Color(0xFF7C3AED),
                                    icon: Icons.safety_check_outlined,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 22),
                            ],
                            _buildSectionContent(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isPending)
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isActionLoading
                            ? null
                            : _sendMissingDocumentNotice,
                        icon: const Icon(Icons.mark_email_unread_outlined),
                        label: const Text('Eksik Belge Bildir'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _isActionLoading ? null : _rejectFromDialog,
                        icon: const Icon(Icons.close),
                        label: const Text('Reddet'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: _isActionLoading ? null : _approveFromDialog,
                        icon: _isActionLoading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: const Text('Başvuruyu Onayla'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreMetricCard extends StatelessWidget {
  const _ScoreMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.valueColor,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color valueColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF6B7280)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              color: valueColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
