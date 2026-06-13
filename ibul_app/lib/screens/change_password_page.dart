import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/constants.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _isSaving = false;
  bool _hasEmailPassword = true;

  @override
  void initState() {
    super.initState();
    _currentPasswordController.addListener(_onFormChanged);
    _newPasswordController.addListener(_onFormChanged);
    _confirmPasswordController.addListener(_onFormChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAuthCapabilities());
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  void _loadAuthCapabilities() {
    final appState = Provider.of<AppState>(context, listen: false);
    setState(() => _hasEmailPassword = appState.hasEmailPasswordProvider);
  }

  bool get _canSubmit {
    if (_isSaving || !_hasEmailPassword) return false;

    final current = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    return current.isNotEmpty &&
        newPassword.length >= 6 &&
        confirm.isNotEmpty &&
        newPassword == confirm &&
        current != newPassword;
  }

  String? get _validationHint {
    if (!_hasEmailPassword) return null;

    final current = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if (current.isEmpty) return 'Mevcut şifrenizi girin';
    if (newPassword.isEmpty) return 'Yeni şifrenizi girin';
    if (newPassword.length < 6) return 'Yeni şifre en az 6 karakter olmalıdır';
    if (current == newPassword) {
      return 'Yeni şifre mevcut şifreden farklı olmalıdır';
    }
    if (confirm.isEmpty) return 'Yeni şifrenizi tekrar girin';
    if (newPassword != confirm) return 'Yeni şifreler eşleşmiyor';
    return null;
  }

  @override
  void dispose() {
    _currentPasswordController
      ..removeListener(_onFormChanged)
      ..dispose();
    _newPasswordController
      ..removeListener(_onFormChanged)
      ..dispose();
    _confirmPasswordController
      ..removeListener(_onFormChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    setState(() => _isSaving = true);
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      await appState.changeUserPasswordWithVerification(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      if (!mounted) return;
      _showMessage('Şifreniz güncellendi');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showMessage(_friendlyError(e), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceAll('Exception:', '').trim();
    if (message.contains('AuthApiException')) {
      return 'Şifre güncellenemedi. Oturumunuz yenilenmiş olabilir; tekrar deneyin.';
    }
    return message.isEmpty ? 'Şifre güncellenemedi' : message;
  }

  Future<void> _showForgotPasswordDialog() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final emailController = TextEditingController(
      text: appState.currentUser?['email']?.toString().trim() ?? '',
    );
    var isSending = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> sendResetEmail() async {
              final email = emailController.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                _showMessage('Geçerli bir e-posta adresi girin', isError: true);
                return;
              }

              setDialogState(() => isSending = true);
              try {
                await appState.sendPasswordResetEmail(email: email);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                _showMessage(
                  'Şifre sıfırlama bağlantısı $email adresine gönderildi',
                );
              } catch (e) {
                if (!dialogContext.mounted) return;
                _showMessage(_friendlyError(e), isError: true);
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() => isSending = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('Şifremi Unuttum'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'E-posta adresinize şifre sıfırlama bağlantısı gönderilir. '
                    'Bağlantıya tıklayarak yeni şifrenizi belirleyebilirsiniz.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(
                      labelText: 'E-posta',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSending ? null : () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: isSending ? null : sendResetEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Bağlantı Gönder'),
                ),
              ],
            );
          },
        );
      },
    );

    emailController.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final validationHint = _validationHint;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text(
          'Şifre Değiştir',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_hasEmailPassword) _buildGoogleAccountBanner(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock_outline, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Güvenli şifre güncelleme',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _hasEmailPassword
                        ? 'Mevcut şifrenizi doğruladıktan sonra yeni şifrenizi belirleyin.'
                        : 'Bu hesap Google ile açıldı. Şifre belirlemek için aşağıdaki e-posta sıfırlama akışını kullanın.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 20),
                  _buildPasswordField(
                    label: 'Mevcut Şifre',
                    controller: _currentPasswordController,
                    visible: _showCurrentPassword,
                    enabled: _hasEmailPassword,
                    onToggle: () => setState(
                      () => _showCurrentPassword = !_showCurrentPassword,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildPasswordField(
                    label: 'Yeni Şifre',
                    controller: _newPasswordController,
                    visible: _showNewPassword,
                    enabled: _hasEmailPassword,
                    onToggle: () =>
                        setState(() => _showNewPassword = !_showNewPassword),
                  ),
                  const SizedBox(height: 16),
                  _buildPasswordField(
                    label: 'Yeni Şifre Tekrarı',
                    controller: _confirmPasswordController,
                    visible: _showConfirmPassword,
                    enabled: _hasEmailPassword,
                    onToggle: () => setState(
                      () => _showConfirmPassword = !_showConfirmPassword,
                    ),
                  ),
                  if (validationHint != null && _hasEmailPassword) ...[
                    const SizedBox(height: 12),
                    Text(
                      validationHint,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canSubmit ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
                  disabledForegroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
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
                        'Şifreyi Güncelle',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: _isSaving ? null : _showForgotPasswordDialog,
                child: const Text(
                  'Şifremi Unuttum',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleAccountBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Hesabınız Google ile giriş yapıyor. Mevcut şifre doğrulaması bu hesap türünde kullanılamaz. '
              'Şifre oluşturmak için "Şifremi Unuttum" ile e-posta sıfırlama bağlantısı isteyin.',
              style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool visible,
    required VoidCallback onToggle,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          obscureText: !visible,
          autofillHints: const [AutofillHints.password],
          enableSuggestions: false,
          autocorrect: false,
          decoration: InputDecoration(
            hintText: '••••••••',
            filled: true,
            fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
            suffixIcon: IconButton(
              icon: Icon(
                visible ? Icons.visibility : Icons.visibility_off,
                size: 20,
              ),
              onPressed: enabled ? onToggle : null,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}
