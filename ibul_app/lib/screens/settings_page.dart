import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_state.dart';
import '../core/constants.dart';
import '../utils/dynamic_value_helpers.dart';
import '../utils/pick_image_file.dart';
import 'addresses_page.dart';
import 'change_password_page.dart';
import '../widgets/web_header.dart';
import '../widgets/web_sticky_footer_scroll_view.dart';
import '../widgets/account_sidebar.dart';

class _ProfileAvatarPreset {
  const _ProfileAvatarPreset(this.id, this.color);
  final String id;
  final Color color;
}

const _avatarPresets = <_ProfileAvatarPreset>[
  _ProfileAvatarPreset('violet', Color(0xFF7C3AED)),
  _ProfileAvatarPreset('blue', Color(0xFF2563EB)),
  _ProfileAvatarPreset('emerald', Color(0xFF059669)),
  _ProfileAvatarPreset('rose', Color(0xFFE11D48)),
  _ProfileAvatarPreset('amber', Color(0xFFD97706)),
  _ProfileAvatarPreset('slate', Color(0xFF475569)),
];

const _styleOptions = ['Klasik', 'Sportif', 'Bohem', 'Minimal', 'Trend'];
const _genderOptions = ['Kadın', 'Erkek', 'Belirtmek istemiyorum'];

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _nameController;
  late TextEditingController _surnameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _genderController;
  late TextEditingController _birthDateController;
  late TextEditingController _styleController;

  bool _smsNotifications = false;
  bool _emailNotifications = true;
  bool _initialized = false;
  bool _isSaving = false;

  String? _profilePhotoUrl;
  String? _pendingPhotoUrl;
  Uint8List? _localPhotoBytes;
  String? _originalPhone;
  String? _originalEmail;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _surnameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _addressController = TextEditingController();
    _heightController = TextEditingController();
    _weightController = TextEditingController();
    _genderController = TextEditingController();
    _birthDateController = TextEditingController();
    _styleController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _hydrateFromAppState();
      _initialized = true;
    }
  }

  void _hydrateFromAppState() {
    final appState = Provider.of<AppState>(context, listen: false);
    final user = appState.currentUser;

    final fullName = readString(
      user?['displayName'] ?? user?['display_name'] ?? user?['name'],
    );
    var name = '';
    var surname = '';
    if (fullName.isNotEmpty) {
      final parts = fullName.split(' ');
      if (parts.length > 1) {
        surname = parts.last;
        name = parts.sublist(0, parts.length - 1).join(' ');
      } else {
        name = fullName;
      }
    }

    _nameController.text = name;
    _surnameController.text = surname;
    _phoneController.text = readString(user?['phone']);
    _emailController.text = readString(user?['email']);
    _addressController.text = _resolveAddressDisplay(appState);

    final weight = user?['weight'];
    if (weight != null) {
      _weightController.text = readString(weight);
    }
    final height = user?['height'];
    if (height != null) {
      _heightController.text = readString(height);
    }
    _genderController.text = readString(
      user?['gender'],
    );
    _birthDateController.text = readString(
      user?['birthDate'] ?? user?['birth_date'],
    );
    _styleController.text = readString(user?['style']);

    _profilePhotoUrl = readNullableString(
      user?['photo_url'] ?? user?['photoURL'],
    );
    _pendingPhotoUrl = _profilePhotoUrl;
    _originalPhone = _phoneController.text.trim();
    _originalEmail = _emailController.text.trim();
  }

  String _resolveAddressDisplay(AppState appState) {
    final current = appState.currentDeliveryAddress?.trim();
    if (current != null && current.isNotEmpty) return current;

    if (appState.deliveryAddresses.isNotEmpty) {
      final addr = appState.deliveryAddresses.first;
      return _formatAddressEntry(addr);
    }

    final user = appState.currentUser;
    return user?['address']?.toString().trim() ?? '';
  }

  String _formatAddressEntry(Map<String, String> addr) {
    final title = addr['title']?.trim();
    final detail = addr['detail']?.trim() ?? '';
    if (title != null && title.isNotEmpty && detail.isNotEmpty) {
      return '$title — $detail';
    }
    return detail;
  }

  Color _presetColor(String presetId) {
    for (final preset in _avatarPresets) {
      if (preset.id == presetId) return preset.color;
    }
    return AppColors.primary;
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  DateTime? _parseBirthDate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final parts = trimmed.split('/');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }
    return DateTime.tryParse(trimmed);
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hesabı Sil'),
        content: const Text(
          'Hesabınızı kalıcı olarak silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      final appState = Provider.of<AppState>(context, listen: false);
      await appState.deleteAccount();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hesabınız silindi.'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _genderController.dispose();
    _birthDateController.dispose();
    _styleController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_isSaving) return;

    final appState = Provider.of<AppState>(context, listen: false);
    final fullName =
        '${_nameController.text.trim()} ${_surnameController.text.trim()}'
            .trim();
    final newPhone = _phoneController.text.trim();
    final newEmail = _emailController.text.trim();
    final phoneChanged =
        newPhone.isNotEmpty && newPhone != (_originalPhone ?? '');
    final emailChanged =
        newEmail.isNotEmpty && newEmail != (_originalEmail ?? '');

    if (phoneChanged) {
      final confirmed = await _showPhoneUpdateDialog(newPhone);
      if (confirmed != true) return;
    }

    if (emailChanged) {
      final confirmed = await _showEmailUpdateDialog(newEmail);
      if (confirmed != true) return;
    }

    setState(() => _isSaving = true);
    String? photoUploadError;
    try {
      String? photoUrlToSave;
      if (_localPhotoBytes != null) {
        try {
          photoUrlToSave = await appState.uploadProfilePhotoBytes(
            _localPhotoBytes!,
            fileName: 'profile.jpg',
          );
          _localPhotoBytes = null;
        } catch (e) {
          photoUploadError = _describePhotoUploadFailure(e);
        }
      } else if (_pendingPhotoUrl != null &&
          _pendingPhotoUrl != _profilePhotoUrl) {
        photoUrlToSave = _pendingPhotoUrl;
      }

      await appState.updateUserProfile(
        displayName: fullName.isNotEmpty ? fullName : null,
        weight: double.tryParse(_weightController.text.replaceAll(',', '.')),
        height: double.tryParse(_heightController.text.replaceAll(',', '.')),
        gender: _genderController.text.isNotEmpty
            ? _genderController.text
            : null,
        birthDate: _birthDateController.text.isNotEmpty
            ? _birthDateController.text
            : null,
        style: _styleController.text.isNotEmpty ? _styleController.text : null,
        phone: newPhone.isNotEmpty ? newPhone : null,
        photoUrl: photoUrlToSave,
      );

      if (emailChanged) {
        await appState.updateUserEmail(newEmail);
        if (mounted) {
          await _showEmailConfirmationInfoDialog(newEmail);
        }
      }

      if (mounted) {
        _hydrateFromAppState();
      }

      if (photoUrlToSave != null) {
        _profilePhotoUrl = appState.currentUser?['photo_url']?.toString() ??
            appState.currentUser?['photoURL']?.toString() ??
            photoUrlToSave;
        _pendingPhotoUrl = _profilePhotoUrl;
      }
      _originalPhone = newPhone;
      _originalEmail = newEmail;

      if (mounted) {
        if (photoUploadError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Profil bilgileriniz kaydedildi; ancak fotoğraf yüklenemedi. '
                '$photoUploadError',
              ),
              backgroundColor: Colors.orange.shade800,
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bilgileriniz başarıyla güncellendi'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profil güncellenemedi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _describePhotoUploadFailure(Object error) {
    if (error is StorageException) {
      final status = error.statusCode?.toString() ?? '';
      if (status == '403') {
        return 'Depolama izni reddedildi (403). Oturumunuzu yenileyip tekrar deneyin.';
      }
      final message = error.message.trim();
      if (message.isNotEmpty) {
        return message;
      }
    }

    final text = error.toString();
    if (text.contains('403') ||
        text.toLowerCase().contains('row-level security')) {
      return 'Depolama izni reddedildi. Oturumunuzu yenileyip tekrar deneyin.';
    }

    final cleaned = text.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
    return cleaned.isEmpty ? 'Bilinmeyen yükleme hatası' : cleaned;
  }

  Future<bool?> _showPhoneUpdateDialog(String newPhone) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Telefon Güncelleme'),
        content: Text(
          'Telefon numaranız +90 $newPhone olarak kaydedilecek.\n\n'
          'SMS doğrulama henüz aktif değil; numara yalnızca profilinize kaydedilir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Devam Et'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showEmailUpdateDialog(String newEmail) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('E-posta Güncelleme'),
        content: Text(
          'E-posta adresiniz $newEmail olarak güncellenecek.\n\n'
          'Supabase, yeni adrese bir doğrulama bağlantısı gönderecektir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Devam Et'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEmailConfirmationInfoDialog(String newEmail) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Doğrulama Gerekli'),
        content: Text(
          '$newEmail adresine bir doğrulama e-postası gönderildi. '
          'Değişikliğin tamamlanması için gelen kutunuzu kontrol edin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddresses() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddressesPage()),
    );
    if (!mounted) return;
    final appState = Provider.of<AppState>(context, listen: false);
    setState(() {
      _addressController.text = _resolveAddressDisplay(appState);
    });
  }

  Future<void> _openChangePassword() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
    );
  }

  Future<void> _pickBirthDate() async {
    final initial = _parseBirthDate(_birthDateController.text) ??
        DateTime(DateTime.now().year - 25);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      locale: const Locale('tr', 'TR'),
    );
    if (picked != null) {
      setState(() => _birthDateController.text = _formatDate(picked));
    }
  }

  Future<void> _pickOption({
    required String title,
    required List<String> options,
    required TextEditingController controller,
  }) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...options.map(
              (option) => ListTile(
                title: Text(option),
                trailing: controller.text == option
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, option),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null) {
      setState(() => controller.text = selected);
    }
  }

  Future<void> _showProfilePhotoOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Profil Fotoğrafı',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Galeriden seç'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickProfileFromGallery();
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Hazır avatarlar',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _avatarPresets.map((preset) {
                  return InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _pendingPhotoUrl = 'preset:${preset.id}';
                        _localPhotoBytes = null;
                      });
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: preset.color,
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickProfileFromGallery() async {
    try {
      final picked = await pickImageFile();
      if (picked == null || picked.bytes.isEmpty) return;
      setState(() {
        _localPhotoBytes = picked.bytes;
        _pendingPhotoUrl = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fotoğraf seçilemedi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildProfileAvatar({required double radius}) {
    final url = _pendingPhotoUrl ?? _profilePhotoUrl;

    if (_localPhotoBytes != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: MemoryImage(_localPhotoBytes!),
      );
    }

    if (url != null && url.startsWith('preset:')) {
      final presetId = url.substring('preset:'.length);
      return CircleAvatar(
        radius: radius,
        backgroundColor: _presetColor(presetId),
        child: Icon(Icons.person, size: radius, color: Colors.white),
      );
    }

    if (url != null && url.startsWith('http')) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, _) {},
        child: url.isEmpty
            ? Icon(Icons.person, size: radius, color: Colors.grey)
            : null,
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade200,
      child: Icon(Icons.person, size: radius * 0.9, color: Colors.grey.shade500),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= 800;
    return isWeb ? _buildWebView() : _buildMobileView();
  }

  Widget _buildWebView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          WebHeader(onSearch: (q) {}),
          Expanded(
            child: WebStickyFooterScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 40,
                      horizontal: 24,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          width: 280,
                          child: AccountSidebar(activePage: 'Ayarlar'),
                        ),
                        const SizedBox(width: 32),
                        Expanded(child: _buildFormCard(isWeb: true)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.black,
        title: const Text(
          'Kullanıcı Bilgilerim',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: _buildFormCard(isWeb: false),
            ),
          ),
          _buildMobileSaveBar(),
        ],
      ),
    );
  }

  Widget _buildMobileSaveBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Bilgileri Güncelle',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isSaving ? null : _deleteAccount,
            child: const Text(
              'Hesabı Sil',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard({required bool isWeb}) {
    return Container(
      padding: EdgeInsets.all(isWeb ? 32 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isWeb ? 16 : 16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isWeb ? 0.02 : 0.03),
            blurRadius: isWeb ? 10 : 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isWeb)
            const Text(
              'Kullanıcı Bilgilerim',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
          if (isWeb) const SizedBox(height: 24),
          _buildSectionHeader('Profil', isWeb: isWeb),
          const SizedBox(height: 16),
          _buildProfileRow(isWeb: isWeb),
          const SizedBox(height: 32),
          _buildSectionHeader('Kişisel Bilgiler', isWeb: isWeb),
          const SizedBox(height: 16),
          _buildPersonalFields(isWeb: isWeb),
          const SizedBox(height: 32),
          _buildSectionHeader('İletişim Bilgileri', isWeb: isWeb),
          const SizedBox(height: 16),
          _buildContactFields(isWeb: isWeb),
          const SizedBox(height: 32),
          _buildSectionHeader('Güvenlik', isWeb: isWeb),
          const SizedBox(height: 12),
          _buildChangePasswordCard(isWeb: isWeb),
          const SizedBox(height: 32),
          _buildSectionHeader('Bildirimler', isWeb: isWeb),
          const SizedBox(height: 16),
          _buildNotificationFields(isWeb: isWeb),
          if (isWeb) ...[
            const SizedBox(height: 32),
            _buildActionButtons(isWeb: isWeb),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {required bool isWeb}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: isWeb ? 18 : 15,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF111827),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 32,
          height: 3,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileRow({required bool isWeb}) {
    final radius = isWeb ? 40.0 : 36.0;
    return Container(
      padding: EdgeInsets.all(isWeb ? 20 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.primary.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _showProfilePhotoOptions,
            child: Stack(
              children: [
                _buildProfileAvatar(radius: radius),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: isWeb ? 28 : 26,
                    height: isWeb ? 28 : 26,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.white,
                      size: isWeb ? 15 : 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: isWeb ? 24 : 14),
          Expanded(
          child: isWeb
              ? Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        'Ad',
                        'Adınız',
                        controller: _nameController,
                        isWeb: isWeb,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        'Soyad',
                        'Soyadınız',
                        controller: _surnameController,
                        isWeb: isWeb,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton(
                      onPressed: _showProfilePhotoOptions,
                      child: const Text(
                        'Resmi düzenle',
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            'Ad',
                            'Adınız',
                            controller: _nameController,
                            isWeb: isWeb,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            'Soyad',
                            'Soyadınız',
                            controller: _surnameController,
                            isWeb: isWeb,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    ),
    );
  }

  Widget _buildPersonalFields({required bool isWeb}) {
    if (isWeb) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  'Boy',
                  'Boyunuzu giriniz',
                  controller: _heightController,
                  isWeb: isWeb,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  'Kilo',
                  'Kilonuzu giriniz',
                  controller: _weightController,
                  isWeb: isWeb,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildPickerField(
                  label: 'Doğum Tarihi',
                  hint: 'GG/AA/YYYY',
                  controller: _birthDateController,
                  isWeb: isWeb,
                  onTap: _pickBirthDate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildPickerField(
                  label: 'Tarz',
                  hint: 'Seçiniz',
                  controller: _styleController,
                  isWeb: isWeb,
                  onTap: () => _pickOption(
                    title: 'Tarz Seçin',
                    options: _styleOptions,
                    controller: _styleController,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildPickerField(
                  label: 'Cinsiyet',
                  hint: 'Seçiniz',
                  controller: _genderController,
                  isWeb: isWeb,
                  onTap: () => _pickOption(
                    title: 'Cinsiyet Seçin',
                    options: _genderOptions,
                    controller: _genderController,
                  ),
                ),
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                'Boy',
                'Boyunuzu giriniz',
                controller: _heightController,
                isWeb: isWeb,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                'Kilo',
                'Kilonuzu giriniz',
                controller: _weightController,
                isWeb: isWeb,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildPickerField(
                label: 'Doğum Tarihi',
                hint: 'GG/AA/YYYY',
                controller: _birthDateController,
                isWeb: isWeb,
                onTap: _pickBirthDate,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPickerField(
                label: 'Tarz',
                hint: 'Seçiniz',
                controller: _styleController,
                isWeb: isWeb,
                onTap: () => _pickOption(
                  title: 'Tarz Seçin',
                  options: _styleOptions,
                  controller: _styleController,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildPickerField(
          label: 'Cinsiyet',
          hint: 'Seçiniz',
          controller: _genderController,
          isWeb: isWeb,
          onTap: () => _pickOption(
            title: 'Cinsiyet Seçin',
            options: _genderOptions,
            controller: _genderController,
          ),
        ),
      ],
    );
  }

  Widget _buildContactFields({required bool isWeb}) {
    return Column(
      children: [
        isWeb
            ? Row(
                children: [
                  Expanded(child: _buildPhoneField(isWeb: isWeb)),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildTextField(
                      'E-mail',
                      'E-mail giriniz',
                      controller: _emailController,
                      isWeb: isWeb,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPhoneField(isWeb: isWeb),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'E-mail',
                    'E-mail giriniz',
                    controller: _emailController,
                    isWeb: isWeb,
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),
        const SizedBox(height: 16),
        _buildPickerField(
          label: 'Adresim',
          hint: 'Adres seçin veya düzenleyin',
          controller: _addressController,
          isWeb: isWeb,
          onTap: _openAddresses,
          suffixIcon: Icons.chevron_right,
        ),
      ],
    );
  }

  Widget _buildPhoneField({required bool isWeb}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Telefon Numarası',
          style: TextStyle(
            fontSize: isWeb ? 13 : 11,
            color: isWeb ? const Color(0xFF374151) : Colors.grey,
            fontWeight: isWeb ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isWeb ? 12 : 8,
                vertical: isWeb ? 12 : 10,
              ),
              decoration: BoxDecoration(
                color: isWeb
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : AppColors.primary,
                borderRadius: BorderRadius.circular(isWeb ? 8 : 6),
                border: isWeb
                    ? Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      )
                    : null,
              ),
              child: Text(
                '+90',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isWeb ? AppColors.primary : Colors.white,
                  fontSize: isWeb ? 14 : 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'Numara giriniz',
                  filled: isWeb,
                  fillColor: isWeb ? Colors.grey.shade50 : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(isWeb ? 8 : 6),
                    borderSide: isWeb
                        ? BorderSide.none
                        : BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(isWeb ? 8 : 6),
                    borderSide: isWeb
                        ? BorderSide.none
                        : BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: isWeb ? 12 : 10,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChangePasswordCard({required bool isWeb}) {
    return Material(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: _openChangePassword,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.lock_outline, color: Colors.grey.shade700, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Şifre Değiştir',
                      style: TextStyle(
                        fontSize: isWeb ? 14 : 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Şifrenizi güvenli bir ekranda güncelleyin',
                      style: TextStyle(
                        fontSize: isWeb ? 12 : 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationFields({required bool isWeb}) {
    if (isWeb) {
      return Row(
        children: [
          Expanded(
            child: _buildNotificationOption(
              'SMS Bildirimleri',
              'Kampanya ve sipariş durumları hakkında SMS alın',
              _smsNotifications,
              (val) => setState(() => _smsNotifications = val),
              isWeb: isWeb,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: _buildNotificationOption(
              'E-posta Bildirimleri',
              'Kampanya ve bültenler hakkında e-posta alın',
              _emailNotifications,
              (val) => setState(() => _emailNotifications = val),
              isWeb: isWeb,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildNotificationOption(
          'Sms',
          'Sms ile İBUL tarafından telefonunuza gelecek bildirimler',
          _smsNotifications,
          (val) => setState(() => _smsNotifications = val),
          isWeb: isWeb,
        ),
        const SizedBox(height: 12),
        _buildNotificationOption(
          'E-mail',
          'E-posta ile İBUL tarafından gelecek bildirimler',
          _emailNotifications,
          (val) => setState(() => _emailNotifications = val),
          isWeb: isWeb,
        ),
      ],
    );
  }

  Widget _buildActionButtons({required bool isWeb}) {
    final saveButton = ElevatedButton(
      onPressed: _isSaving ? null : _saveChanges,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: isWeb ? 32 : 0,
          vertical: isWeb ? 16 : 14,
        ),
        minimumSize: Size(isWeb ? 0 : double.infinity, isWeb ? 48 : 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: _isSaving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text(
              'Bilgileri Güncelle',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
    );

    final deleteButton = OutlinedButton(
      onPressed: _deleteAccount,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red,
        side: const BorderSide(color: Colors.red),
        padding: EdgeInsets.symmetric(
          horizontal: isWeb ? 24 : 0,
          vertical: isWeb ? 16 : 12,
        ),
        minimumSize: Size(isWeb ? 0 : double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text('Hesabı Sil'),
    );

    if (isWeb) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          deleteButton,
          const SizedBox(width: 16),
          saveButton,
        ],
      );
    }

    return Column(
      children: [
        saveButton,
        const SizedBox(height: 12),
        deleteButton,
      ],
    );
  }

  Widget _buildTextField(
    String label,
    String hint, {
    required bool isWeb,
    TextEditingController? controller,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isWeb ? 13 : 11,
            color: isWeb ? const Color(0xFF374151) : Colors.grey,
            fontWeight: isWeb ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: isWeb ? 14 : 13),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: isWeb ? 12 : 10,
            ),
            filled: isWeb,
            fillColor: isWeb ? Colors.grey.shade50 : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isWeb ? 8 : 6),
              borderSide: isWeb
                  ? BorderSide.none
                  : BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isWeb ? 8 : 6),
              borderSide: isWeb
                  ? BorderSide.none
                  : BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPickerField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool isWeb,
    required VoidCallback onTap,
    IconData? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isWeb ? 13 : 11,
            color: isWeb ? const Color(0xFF374151) : Colors.grey,
            fontWeight: isWeb ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: true,
          onTap: onTap,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: isWeb ? 14 : 13),
            suffixIcon: Icon(
              suffixIcon ?? Icons.calendar_today_outlined,
              size: 18,
              color: Colors.grey.shade500,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: isWeb ? 12 : 10,
            ),
            filled: isWeb,
            fillColor: isWeb ? Colors.grey.shade50 : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isWeb ? 8 : 6),
              borderSide: isWeb
                  ? BorderSide.none
                  : BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isWeb ? 8 : 6),
              borderSide: isWeb
                  ? BorderSide.none
                  : BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationOption(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged, {
    required bool isWeb,
  }) {
    return Container(
      padding: isWeb ? const EdgeInsets.all(16) : EdgeInsets.zero,
      decoration: isWeb
          ? BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            )
          : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isWeb ? 14 : 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                if (isWeb) const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: isWeb ? 12 : 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
