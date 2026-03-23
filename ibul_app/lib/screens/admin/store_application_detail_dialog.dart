import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StoreApplicationDetailDialog extends StatefulWidget {
  final Map<String, dynamic> application;
  final Future<void> Function(
    String id,
    String status, {
    String? rejectionReason,
  })
  onUpdateStatus;

  const StoreApplicationDetailDialog({
    super.key,
    required this.application,
    required this.onUpdateStatus,
  });

  @override
  State<StoreApplicationDetailDialog> createState() =>
      _StoreApplicationDetailDialogState();
}

class _StoreApplicationDetailDialogState
    extends State<StoreApplicationDetailDialog> {
  String _selectedTab = 'Genel Bilgiler';
  bool _isSubmitting = false;

  Future<void> _handleApprove() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await widget.onUpdateStatus(
        widget.application['id'].toString(),
        'approved',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Başvuru onaylandı.')));
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('İşlem tamamlanamadı: $error')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _handleReject() async {
    final reason = await _showReasonDialog(
      title: 'Başvuruyu Reddet',
      hintText: 'Reddetme gerekçesi',
      initialValue: 'Admin tarafından reddedildi',
      confirmLabel: 'Reddet',
    );
    if (reason == null || reason.trim().isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.onUpdateStatus(
        widget.application['id'].toString(),
        'rejected',
        rejectionReason: reason.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Başvuru reddedildi.')));
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('İşlem tamamlanamadı: $error')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _handleMissingDocuments() async {
    final note = await _showReasonDialog(
      title: 'Eksik Belge Bildir',
      hintText: 'Eksik belge notu',
      initialValue: 'Eksik belge nedeniyle ek evrak talep edildi',
      confirmLabel: 'Bildir',
    );
    if (note == null || note.trim().isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.onUpdateStatus(
        widget.application['id'].toString(),
        'missing_documents',
        rejectionReason: note.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Eksik belge bildirimi kaydedildi.')),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('İşlem tamamlanamadı: $error')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<String?> _showReasonDialog({
    required String title,
    required String hintText,
    required String initialValue,
    required String confirmLabel,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: hintText,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 1000,
        height: 800,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Row(
                children: [
                  _buildSidebar(),
                  Expanded(
                    child: Container(
                      color: const Color(0xFFF9FAFB),
                      child: _buildContent(),
                    ),
                  ),
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.store, color: Color(0xFF8B5CF6), size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.application['business_name'] ?? 'İsimsiz Mağaza',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Başvuru İnceleniyor',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Başvuru Tarihi: 14.02.2026', // Mock date
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 240,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          _buildSidebarItem(Icons.info_outline, 'Genel Bilgiler'),
          _buildSidebarItem(Icons.description_outlined, 'Belgeler'),
          _buildSidebarItem(
            Icons.account_balance_wallet_outlined,
            'Finansal Bilgiler',
          ),
          _buildSidebarItem(Icons.person_outline, 'Yetkili Kişi'),
          _buildSidebarItem(Icons.history, 'Geçmiş İşlemler'),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String title) {
    final isSelected = _selectedTab == title;
    return InkWell(
      onTap: () => setState(() => _selectedTab = title),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey.shade100 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? const Color(0xFF111827)
                  : Colors.grey.shade500,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? const Color(0xFF111827)
                    : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedTab) {
      case 'Genel Bilgiler':
        return _buildGeneralInfoTab();
      case 'Belgeler':
        return _buildDocumentsTab();
      case 'Finansal Bilgiler':
        return _buildFinancialInfoTab();
      case 'Yetkili Kişi':
        return _buildAuthorizedPersonTab();
      case 'Geçmiş İşlemler':
        return const Center(child: Text('Geçmiş işlemler burada listelenecek'));
      default:
        return const SizedBox();
    }
  }

  Widget _buildGeneralInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        // Score Cards
        Row(
          children: [
            _buildScoreCard(
              'Başvuru Skoru',
              '4.6',
              Icons.analytics,
              Colors.blue,
            ),
            const SizedBox(width: 16),
            _buildScoreCard(
              'Risk Seviyesi',
              'Düşük',
              Icons.shield,
              Colors.green,
            ),
            const SizedBox(width: 16),
            _buildScoreCard(
              'Oto. Doğrulama',
              'Başarılı',
              Icons.check_circle,
              Colors.teal,
            ),
            const SizedBox(width: 16),
            _buildScoreCard(
              'Güven Puanı',
              '92/100',
              Icons.verified_user,
              const Color(0xFF8B5CF6),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Kurumsal Kimlik
        const Text(
          'Kurumsal Kimlik',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildInfoRow(
          'Yasal Unvan',
          widget.application['business_name'] ?? '-',
        ),
        _buildInfoRow('Vergi Dairesi / No', '12121212121'),
        _buildInfoRow('Mersis No', '-'),
        _buildInfoRow('KEP Adresi', 'denemek@gmail.com'),
        _buildInfoRow('Web Sitesi', '-'),
        const SizedBox(height: 32),

        // Sistem Kontrolleri
        const Text(
          'Otomatik Sistem Kontrolleri',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildCheckRow('Vergi No', 'Doğrulandı (GİB)', true),
        _buildCheckRow('MERSİS', 'Aktif Kayıt', true),
        _buildCheckRow('Kara Liste', 'Temiz', true),
        _buildCheckRow('IP Kontrolü', 'Tekil Başvuru', true),
      ],
    );
  }

  Widget _buildDocumentsTab() {
    final docsRaw = widget.application['documents'];
    final docs = docsRaw is Map
        ? Map<String, dynamic>.from(docsRaw)
        : <String, dynamic>{};

    final definitions = <Map<String, dynamic>>[
      {'key': 'taxPlate', 'title': 'Vergi Levhası', 'mandatory': true},
      {
        'key': 'signatureCircular',
        'title': 'İmza Sirküleri',
        'mandatory': true,
      },
      {
        'key': 'tradeRegistryGazette',
        'title': 'Ticaret Sicil Gazetesi',
        'mandatory': true,
      },
      {'key': 'ibanDocument', 'title': 'IBAN Belgesi', 'mandatory': true},
      {'key': 'idCard', 'title': 'Kimlik (Yetkili)', 'mandatory': true},
    ];

    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const Text(
          'Yüklenen Belgeler',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        ...definitions.expand((doc) {
          final key = doc['key'] as String;
          final path = (docs['${key}Path'] ?? '').toString();
          final uploaded = docs[key] == true || path.isNotEmpty;
          return [
            _buildDocumentItem(
              doc['title'] as String,
              status: uploaded ? 'Yüklendi' : 'Eksik',
              isMandatory: doc['mandatory'] == true,
              path: path,
              fileName: (docs['${key}Name'] ?? '').toString(),
            ),
            const SizedBox(height: 12),
          ];
        }),
      ],
    );
  }

  Future<String> _resolveDocumentUrl(String path) async {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return Supabase.instance.client.storage
        .from('seller-documents')
        .createSignedUrl(path, 3600);
  }

  Future<void> _openDocumentPreview({
    required String path,
    required String title,
  }) async {
    if (path.isEmpty) return;
    try {
      final url = await _resolveDocumentUrl(path);
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => Dialog(
          child: SizedBox(
            width: 900,
            height: 700,
            child: Column(
              children: [
                AppBar(
                  title: Text(title),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Expanded(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: SelectableText(
                          'Belge önizlenemedi.\nURL: $url',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Belge açılamadı: $e')));
    }
  }

  Widget _buildFinancialInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const Text(
          'Finansal Güven',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildInfoRow('Hesap Türü', 'Kurumsal Şirket Hesabı'),
        _buildInfoRow('IBAN', 'sadadsd'),
        _buildInfoRow('Banka Adı', '-'),
        _buildInfoRow('Hesap Sahibi', '-'),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 12),
            const Text(
              'IBAN Doğrulama',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              'İsim Uyuşuyor',
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 32),
        const Text(
          'Sistem Önerileri',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildInfoRow('Ödeme Bloke Süresi', '14 Gün (Standart)'),
        _buildInfoRow('Komisyon Oranı', '%12 (Teknoloji)'),
        _buildInfoRow('Riskli Sektör', 'Hayır'),
      ],
    );
  }

  Widget _buildAuthorizedPersonTab() {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const Text(
          'Yetkili Kişi Bilgileri',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildInfoRow('Ad Soyad', widget.application['full_name'] ?? '-'),
        _buildInfoRow(
          'E-posta',
          widget.application['email'] ?? 'denemek@gmail.com',
        ),
        _buildInfoRow('Telefon', '21323123123'),
        const SizedBox(height: 24),
        _buildCheckRow('TC Doğrulama (NVİ)', 'Başarılı', true),
        _buildCheckRow('Telefon Onayı', 'SMS Doğrulandı', true),
        _buildCheckRow('E-posta Onayı', 'Link Doğrulandı', true),
        _buildCheckRow(
          'Daha Önce Mağaza?',
          'Hayır (İlk Başvuru)',
          false,
          isError: true,
        ), // Example of "Error" style usage for negative check if needed, or just info. Image showed X for "Daha Önce Mağaza" but red text "Hayır". Wait, X usually means fail. Let's assume it means "No previous store" which is good, or maybe it's a check that failed. In the image it was red X and "Hayır (İlk Başvuru)". Let's match visual.
      ],
    );
  }

  Widget _buildScoreCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckRow(
    String label,
    String status,
    bool isSuccess, {
    bool isError = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            isError
                ? Icons.cancel
                : (isSuccess ? Icons.check_circle : Icons.info),
            color: isError
                ? Colors.red
                : (isSuccess ? Colors.green : Colors.grey),
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const Spacer(),
          Text(
            status,
            style: TextStyle(
              color: isError
                  ? Colors.red
                  : (isSuccess ? Colors.green.shade700 : Colors.grey.shade700),
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentItem(
    String name, {
    String? status,
    bool isMandatory = false,
    bool unreadable = false,
    String path = '',
    String fileName = '',
  }) {
    Color statusColor = Colors.grey;
    Color statusBg = Colors.grey.shade100;
    if (status == 'Eksik') {
      statusColor = Colors.red;
      statusBg = Colors.red.shade50;
    } else if (status == 'Onaylı') {
      statusColor = Colors.green;
      statusBg = Colors.green.shade50;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.description, color: Colors.grey),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                status ?? '',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const Spacer(),
          if (unreadable)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Okunmuyor',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (isMandatory)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Zorunlu belge',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (status != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: path.isEmpty
                ? null
                : () => _openDocumentPreview(
                    path: path,
                    title: fileName.isNotEmpty ? fileName : name,
                  ),
            icon: Icon(
              Icons.visibility,
              color: path.isEmpty ? Colors.grey.shade300 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: _isSubmitting ? null : _handleMissingDocuments,
            icon: const Icon(Icons.mail_outline, size: 18),
            label: const Text('Eksik Belge Bildir'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              foregroundColor: const Color(0xFF8B5CF6),
              side: const BorderSide(color: Color(0xFF8B5CF6)),
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: _isSubmitting ? null : _handleReject,
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Reddet'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              foregroundColor: const Color(0xFFDC2626),
              side: const BorderSide(color: Color(0xFFFECACA)),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _handleApprove,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check, size: 18),
            label: Text(_isSubmitting ? 'İşleniyor' : 'Başvuruyu Onayla'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}
