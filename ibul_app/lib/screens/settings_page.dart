import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/app_state.dart';
import '../widgets/web_header.dart';
import '../widgets/web_footer.dart';
import '../widgets/account_sidebar.dart';

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
  
  // New controllers for other fields
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _genderController;
  late TextEditingController _birthDateController;
  late TextEditingController _styleController;
  
  bool _smsNotifications = false;
  bool _emailNotifications = true;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  bool _initialized = false;
  
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
      final appState = Provider.of<AppState>(context, listen: false);
      final user = appState.currentUser;
      
      String fullName = user?['displayName'] ?? user?['name'] ?? '';
      String name = '';
      String surname = '';
      
      if (fullName.isNotEmpty) {
        List<String> parts = fullName.split(' ');
        if (parts.length > 1) {
          surname = parts.last;
          name = parts.sublist(0, parts.length - 1).join(' ');
        } else {
          name = fullName;
        }
      }

      _nameController.text = name;
      _surnameController.text = surname;
      _phoneController.text = user?['phone'] ?? '';
      _emailController.text = user?['email'] ?? '';
      _addressController.text = user?['address'] ?? '';
      
      // Initialize other fields if they exist, otherwise they stay empty
      if (user?['weight'] != null) _weightController.text = user!['weight'].toString();
      if (user?['height'] != null) _heightController.text = user!['height'].toString();
      if (user?['gender'] != null) _genderController.text = user!['gender'];
      if (user?['birthDate'] != null) _birthDateController.text = user!['birthDate'];
      if (user?['style'] != null) _styleController.text = user!['style'];
      
      _initialized = true;
    }
  }

  Future<void> _deleteAccount() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hesabı Sil'),
        content: const Text('Hesabınızı kalıcı olarak silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
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
      // Perform delete operation
      if (!mounted) return;
      final appState = Provider.of<AppState>(context, listen: false);
      await appState.deleteAccount();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hesabınız silindi.'), backgroundColor: Colors.red),
        );
        Navigator.popUntil(context, (route) => route.isFirst); // Go to login/home
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
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final fullName = '${_nameController.text.trim()} ${_surnameController.text.trim()}'.trim();
    
    try {
      await appState.updateUserProfile(
        displayName: fullName.isNotEmpty ? fullName : null,
        weight: double.tryParse(_weightController.text),
        height: double.tryParse(_heightController.text),
        gender: _genderController.text.isNotEmpty ? _genderController.text : null,
        birthDate: _birthDateController.text.isNotEmpty ? _birthDateController.text : null,
        style: _styleController.text.isNotEmpty ? _styleController.text : null,
        phone: _phoneController.text.isNotEmpty ? _phoneController.text : null,
        address: _addressController.text.isNotEmpty ? _addressController.text : null,
      );
      
      // Update other fields in Firestore directly since updateProfile only handles basic info
      // Ideally we should add these to updateProfile or have a separate method
      // For now let's assume updateProfile handles what it can
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Değişiklikler başarıyla kaydedildi'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata oluştu: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= 800;

    if (isWeb) {
      return _buildWebView();
    }

    return _buildMobileView();
  }

  Widget _buildWebView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          WebHeader(onSearch: (q) {}),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Sidebar
                            const SizedBox(
                              width: 280,
                              child: AccountSidebar(activePage: 'Ayarlar'),
                            ),
                            const SizedBox(width: 32),
                            // Right Content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Kullanıcı Bilgilerim',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  
                                  // Settings Form Container
                                  Container(
                                    padding: const EdgeInsets.all(32),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.grey.shade200),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.02),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Profile Section Header
                                        const Text(
                                          'Profil Bilgileri',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1F2937),
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        
                                        // Profile Image and Basic Info Row
                                        Row(
                                          children: [
                                            Stack(
                                              children: [
                                                CircleAvatar(
                                                  radius: 40,
                                                  backgroundColor: Colors.grey.shade100,
                                                  child: const Icon(Icons.person, size: 48, color: Colors.grey),
                                                ),
                                                Positioned(
                                                  bottom: 0,
                                                  right: 0,
                                                  child: Container(
                                                    width: 28,
                                                    height: 28,
                                                    decoration: const BoxDecoration(
                                                      color: AppColors.primary,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(Icons.edit, color: Colors.white, size: 16),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 24),
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Expanded(child: _buildTextField('Ad', 'Baran', controller: _nameController, isWeb: true)),
                                                  const SizedBox(width: 16),
                                                  Expanded(child: _buildTextField('Soyad', 'Kananoğulları', controller: _surnameController, isWeb: true)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 24),
                                        
                                        // Personal Details Grid
                                        Row(
                                          children: [
                                            Expanded(child: _buildTextField('Boy', '1.75 (Örn)', controller: _heightController, isWeb: true)),
                                            const SizedBox(width: 16),
                                            Expanded(child: _buildTextField('Kilo', '70 (Örn)', controller: _weightController, isWeb: true)),
                                            const SizedBox(width: 16),
                                            Expanded(child: _buildTextField('Doğum Tarihi', 'GG/AA/YYYY', controller: _birthDateController, isWeb: true)),
                                          ],
                                        ),
                                        const SizedBox(height: 24),
                                        Row(
                                          children: [
                                            Expanded(child: _buildTextField('Tarz', 'Seçiniz', controller: _styleController, isWeb: true)),
                                            const SizedBox(width: 16),
                                            Expanded(child: _buildTextField('Cinsiyet', 'Erkek/Kadın', controller: _genderController, isWeb: true)),
                                            const SizedBox(width: 16),
                                            const Expanded(child: SizedBox()), // Spacer for grid alignment
                                          ],
                                        ),
                                        
                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 32),
                                          child: Divider(),
                                        ),

                                        // Contact Info Header
                                        const Text(
                                          'İletişim Bilgileri',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1F2937),
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        
                                        // Contact Info Fields
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text('Telefon Numarası', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
                                                  const SizedBox(height: 8),
                                                  Row(
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                                        decoration: BoxDecoration(
                                                          color: AppColors.primary.withValues(alpha: 0.1),
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                                                        ),
                                                        child: const Text('+90', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: TextField(
                                                          controller: _phoneController,
                                                          decoration: InputDecoration(
                                                            hintText: 'Numara giriniz',
                                                            filled: true,
                                                            fillColor: Colors.grey.shade50,
                                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 24),
                                            Expanded(child: _buildTextField('E-mail', 'E-mail giriniz', controller: _emailController, isWeb: true)),
                                          ],
                                        ),
                                        const SizedBox(height: 24),
                                        _buildTextField('Adresim', 'Adres giriniz', controller: _addressController, isWeb: true),
                                        
                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 32),
                                          child: Divider(),
                                        ),

                                        // Security Header
                                        const Text(
                                          'Güvenlik',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1F2937),
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        
                                        // Password Fields
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: _buildPasswordField('Mevcut Şifre', _showCurrentPassword, (val) => setState(() => _showCurrentPassword = val), isWeb: true),
                                            ),
                                            const SizedBox(width: 24),
                                            Expanded(
                                              child: _buildPasswordField('Yeni Şifre', _showNewPassword, (val) => setState(() => _showNewPassword = val), isWeb: true),
                                            ),
                                            const SizedBox(width: 24),
                                            Expanded(
                                              child: _buildPasswordField('Yeni Şifre Tekrarı', _showConfirmPassword, (val) => setState(() => _showConfirmPassword = val), isWeb: true),
                                            ),
                                          ],
                                        ),

                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 32),
                                          child: Divider(),
                                        ),

                                        // Notifications Header
                                        const Text(
                                          'Bildirim Ayarları',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1F2937),
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        
                                        // Notification Switches
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildNotificationOption(
                                                'SMS Bildirimleri',
                                                'Kampanya ve sipariş durumları hakkında SMS alın',
                                                _smsNotifications,
                                                (val) => setState(() => _smsNotifications = val),
                                                isWeb: true,
                                              ),
                                            ),
                                            const SizedBox(width: 24),
                                            Expanded(
                                              child: _buildNotificationOption(
                                                'E-posta Bildirimleri',
                                                'Kampanya ve bültenler hakkında E-posta alın',
                                                _emailNotifications,
                                                (val) => setState(() => _emailNotifications = val),
                                                isWeb: true,
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 48),

                                        // Actions
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            OutlinedButton(
                                              onPressed: _deleteAccount,
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.red,
                                                side: const BorderSide(color: Colors.red),
                                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              child: const Text('Hesabı Sil'),
                                            ),
                                            const SizedBox(width: 16),
                                            ElevatedButton(
                                              onPressed: _saveChanges,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.primary,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              child: const Text('Değişiklikleri Kaydet'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const WebFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileView() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Kullanıcı Bilgilerim',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profilim Section
            Container(
              width: double.infinity,
              color: Colors.grey.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: const Text(
                'Profilim',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.grey.shade300,
                        child: const Icon(Icons.person, size: 36, color: Colors.white),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      'Resmi düzenle',
                      style: TextStyle(fontSize: 12, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            
            // Form Fields
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildTextField('Ad', 'Adınız', controller: _nameController)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTextField('Boy', '1.75 (Örn)', controller: _heightController)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildTextField('Soyad', 'Soyadınız', controller: _surnameController)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTextField('Kilo', '70 (Örn)', controller: _weightController)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildTextField('Doğum Tarihi', 'GG/AA/YYYY', controller: _birthDateController)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTextField('Tarz', 'Seçiniz', controller: _styleController)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField('Cinsiyet', 'Erkek/Kadın', controller: _genderController),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // İletişim Bilgileri
            Container(
              width: double.infinity,
              color: Colors.grey.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: const Text(
                'İletişim Bilgileri',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Telefon Numarası',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '+90',
                          style: TextStyle(fontSize: 13, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          decoration: InputDecoration(
                            hintText: 'Numara giriniz',
                            hintStyle: const TextStyle(fontSize: 13),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'E-mail',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      hintText: 'E-mail giriniz',
                      hintStyle: const TextStyle(fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Adresim',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      hintText: 'Adres giriniz',
                      hintStyle: const TextStyle(fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      suffixIcon: const Icon(Icons.chevron_right, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Güvenlik
            Container(
              width: double.infinity,
              color: Colors.grey.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Text(
                    'Güvenlik',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mevcut şifre',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    obscureText: !_showCurrentPassword,
                    decoration: InputDecoration(
                      hintText: '****************',
                      hintStyle: const TextStyle(fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showCurrentPassword ? Icons.visibility : Icons.visibility_off,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _showCurrentPassword = !_showCurrentPassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Yeni şifre',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    obscureText: !_showNewPassword,
                    decoration: InputDecoration(
                      hintText: 'yeni şifre',
                      hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showNewPassword ? Icons.visibility : Icons.visibility_off,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _showNewPassword = !_showNewPassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Yeni Şifre Tekrarı',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    obscureText: !_showConfirmPassword,
                    decoration: InputDecoration(
                      hintText: 'yeni şifre',
                      hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showConfirmPassword ? Icons.visibility : Icons.visibility_off,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _showConfirmPassword = !_showConfirmPassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Bildiri Seçenekleri
            Container(
              width: double.infinity,
              color: Colors.grey.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Text(
                    'Bildiri Seçenekleri',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sms',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Sms ile İBUL tarafından telefonunuza gelecek bildirimler',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _smsNotifications,
                        onChanged: (value) {
                          setState(() {
                            _smsNotifications = value;
                          });
                        },
                        activeThumbColor: AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'E-mail',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'E-Mail ile İBUL tarafından telefonunuza gelecek bildirimler',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _emailNotifications,
                        onChanged: (value) {
                          setState(() {
                            _emailNotifications = value;
                          });
                        },
                        activeThumbColor: AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Hesabı Sil Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton(
                onPressed: _deleteAccount,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Hesabı Sil',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.delete_outline, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String hint, {bool isWeb = false, TextEditingController? controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: isWeb ? 13 : 11, color: isWeb ? const Color(0xFF374151) : Colors.grey, fontWeight: isWeb ? FontWeight.w500 : FontWeight.normal),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: isWeb ? 14 : 13),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isWeb ? 12 : 10),
            filled: isWeb,
            fillColor: isWeb ? Colors.grey.shade50 : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isWeb ? 8 : 6),
              borderSide: isWeb ? BorderSide.none : BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isWeb ? 8 : 6),
              borderSide: isWeb ? BorderSide.none : BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField(String label, bool isVisible, Function(bool) onVisibilityChanged, {bool isWeb = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: isWeb ? 13 : 11, color: isWeb ? const Color(0xFF374151) : Colors.grey, fontWeight: isWeb ? FontWeight.w500 : FontWeight.normal),
        ),
        const SizedBox(height: 8),
        TextField(
          obscureText: !isVisible,
          decoration: InputDecoration(
            hintText: '****************',
            hintStyle: TextStyle(fontSize: isWeb ? 14 : 13, color: Colors.grey),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isWeb ? 12 : 10),
            filled: isWeb,
            fillColor: isWeb ? Colors.grey.shade50 : null,
            suffixIcon: IconButton(
              icon: Icon(
                isVisible ? Icons.visibility : Icons.visibility_off,
                size: 20,
                color: Colors.grey,
              ),
              onPressed: () => onVisibilityChanged(!isVisible),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isWeb ? 8 : 6),
              borderSide: isWeb ? BorderSide.none : BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isWeb ? 8 : 6),
              borderSide: isWeb ? BorderSide.none : BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationOption(String title, String subtitle, bool value, Function(bool) onChanged, {bool isWeb = false}) {
    return Container(
      padding: isWeb ? const EdgeInsets.all(16) : EdgeInsets.zero,
      decoration: isWeb ? BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ) : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: isWeb ? 14 : 13, fontWeight: FontWeight.w500, color: const Color(0xFF1F2937)),
                ),
                if (isWeb) const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: isWeb ? 12 : 10, color: Colors.grey.shade600),
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
