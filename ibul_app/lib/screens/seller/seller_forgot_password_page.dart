import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/ibul_router.dart';
import '../../core/constants.dart';
import '../../services/seller_recovery_service.dart';
import 'seller_forgot_password_widgets.dart';

class SellerForgotPasswordPage extends StatefulWidget {
  const SellerForgotPasswordPage({super.key, this.initialEmail = ''});

  final String initialEmail;

  static Future<void> open(BuildContext context, {String initialEmail = ''}) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SellerForgotPasswordPage(initialEmail: initialEmail),
      ),
    );
  }

  @override
  State<SellerForgotPasswordPage> createState() =>
      _SellerForgotPasswordPageState();
}

class _SellerForgotPasswordPageState extends State<SellerForgotPasswordPage> {
  static const _primary = AppColors.primary;
  static const _textDark = Color(0xFF111827);
  static const _textMid = Color(0xFF6B7280);

  final _identifierController = TextEditingController();
  final _otpController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  SellerRecoveryService? _service;

  int _method = 0;
  bool _busy = false;
  bool _phoneOtpSent = false;
  bool _obscurePassword = true;
  bool _ctaPressed = false;
  String? _successTitle;
  String? _successBody;

  @override
  void initState() {
    super.initState();
    _identifierController.text = widget.initialEmail;
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _otpController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  SellerRecoveryService get _recovery =>
      _service ??= SellerRecoveryService();
  Color get _primaryLight => _primary.withValues(alpha: 0.10);
  Color get _purpleBorder => _primary.withValues(alpha: 0.25);

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    IbulRouter.go(context, '/seller-login');
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString().replaceFirst('Exception: ', '')),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _complete(Future<void> Function() action, String title, String body) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      setState(() {
        _successTitle = title;
        _successBody = body;
      });
    } catch (error) {
      if (!mounted) return;
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final identifier = _identifierController.text.trim();
    if (_method == 0) {
      await _complete(
        () => _recovery.sendEmailReset(identifier),
        'E-posta gönderildi',
        'Şifre sıfırlama bağlantısı $identifier adresine iletildi. Gelen kutusu ve spam klasörünü kontrol edin.',
      );
      return;
    }
    if (_method == 1) {
      if (!_phoneOtpSent) {
        if (_busy) return;
        setState(() => _busy = true);
        try {
          await _recovery.sendPhoneOtp(identifier);
          if (!mounted) return;
          setState(() => _phoneOtpSent = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('SMS kodu gönderildi.')),
          );
        } catch (error) {
          if (!mounted) return;
          _showError(error);
        } finally {
          if (mounted) setState(() => _busy = false);
        }
        return;
      }
      await _complete(
        () => _recovery.verifyPhoneOtpAndSetPassword(
          phone: identifier,
          otp: _otpController.text,
          newPassword: _passwordController.text,
        ),
        'Şifre güncellendi',
        'Telefon doğrulandı. Yeni şifrenizle satıcı paneline giriş yapabilirsiniz.',
      );
      return;
    }
    await _complete(
      () => _recovery.resetWithStoreCode(
        identifier: identifier,
        code: _codeController.text,
        newPassword: _passwordController.text,
      ),
      'Şifre güncellendi',
      'Mağaza kodu doğrulandı. Yeni şifrenizle satıcı paneline giriş yapabilirsiniz.',
    );
  }

  InputDecoration _fieldDeco({
    required String label,
    required String hint,
    required Widget prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(fontSize: 13, color: _textMid),
      hintStyle: TextStyle(
        fontSize: 13,
        color: _textMid.withValues(alpha: 0.55),
      ),
      prefixIcon: prefix,
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: _purpleBorder, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _primary, width: 1.8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 390;
    final hPad = compact ? 20.0 : 24.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(left: hPad - 8, top: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _goBack,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: _textDark.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    hPad,
                    8,
                    hPad,
                    24 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: _successTitle != null
                        ? SellerForgotSuccessView(
                            title: _successTitle!,
                            body: _successBody!,
                            compact: compact,
                            onBack: _goBack,
                          )
                        : _buildForm(compact),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(bool compact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: compact ? 76 : 84,
            height: compact ? 76 : 84,
            decoration: BoxDecoration(
              color: _primaryLight,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _primary.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              Icons.lock_reset_rounded,
              size: compact ? 36 : 40,
              color: _primary,
            ),
          ),
        ),
        SizedBox(height: compact ? 18 : 20),
        Text(
          'Şifrenizi sıfırlayın',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 20 : 22,
            fontWeight: FontWeight.w700,
            color: _textDark,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _methodHint,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 13 : 14,
            color: _textMid.withValues(alpha: 0.75),
            height: 1.45,
          ),
        ),
        SizedBox(height: compact ? 24 : 28),
        Row(
          children: [
            Expanded(
              child: SellerForgotMethodCard(
                selected: _method == 0,
                icon: Icons.mail_outline_rounded,
                title: 'E-posta',
                subtitle: 'Bağlantı',
                onTap: () => setState(() {
                  _method = 0;
                  _phoneOtpSent = false;
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SellerForgotMethodCard(
                selected: _method == 1,
                icon: Icons.sms_outlined,
                title: 'Telefon',
                subtitle: 'SMS kodu',
                onTap: () => setState(() {
                  _method = 1;
                  _phoneOtpSent = false;
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SellerForgotMethodCard(
                selected: _method == 2,
                icon: Icons.vpn_key_outlined,
                title: 'Mağaza',
                subtitle: 'Kurtarma',
                onTap: () => setState(() {
                  _method = 2;
                  _phoneOtpSent = false;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _identifierController,
          keyboardType: _method == 1
              ? TextInputType.phone
              : TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          style: const TextStyle(fontSize: 14, color: _textDark),
          decoration: _fieldDeco(
            label: _method == 1 ? 'Telefon' : 'E-posta veya telefon',
            hint: _method == 1 ? '05xx xxx xx xx' : 'magaza@ornek.com',
            prefix: Icon(
              _method == 1 ? Icons.phone_outlined : Icons.email_outlined,
              size: 18,
              color: _textMid,
            ),
          ),
        ),
        if (_method == 1 && _phoneOtpSent) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 14, color: _textDark),
            decoration: _fieldDeco(
              label: 'SMS kodu',
              hint: '6 haneli kod',
              prefix: const Icon(
                Icons.pin_outlined,
                size: 18,
                color: _textMid,
              ),
            ),
          ),
        ],
        if (_method == 2) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.next,
            style: const TextStyle(
              fontSize: 15,
              color: _textDark,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w600,
            ),
            decoration: _fieldDeco(
              label: 'Mağaza doğrulama kodu',
              hint: 'ABCD-EFGH',
              prefix: const Icon(
                Icons.vpn_key_outlined,
                size: 18,
                color: _textMid,
              ),
            ),
          ),
        ],
        if (_method == 2 || (_method == 1 && _phoneOtpSent)) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _busy ? null : _submit(),
            style: const TextStyle(fontSize: 14, color: _textDark),
            decoration: _fieldDeco(
              label: 'Yeni şifre',
              hint: 'En az 6 karakter',
              prefix: const Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: _textMid,
              ),
              suffix: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                  color: _textMid,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
        ],
        const SizedBox(height: 22),
        GestureDetector(
          onTapDown: (_) => setState(() => _ctaPressed = true),
          onTapUp: (_) => setState(() => _ctaPressed = false),
          onTapCancel: () => setState(() => _ctaPressed = false),
          child: SellerForgotGradientButton(
            label: _submitLabel,
            busy: _busy,
            pressed: _ctaPressed,
            onTap: _busy ? null : _submit,
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _goBack,
          child: const Text(
            'Giriş ekranına dön',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _primary,
            ),
          ),
        ),
      ],
    );
  }

  String get _methodHint {
    if (_method == 0) {
      return 'Kayıtlı e-postanıza şifre sıfırlama bağlantısı gönderilir.';
    }
    if (_method == 1) {
      return 'Kayıtlı telefonunuza SMS doğrulama kodu gönderilir.';
    }
    return 'Admin Mağaza Yönetimi’nden üretilen 5 kurtarma kodundan birini kullanın.';
  }

  String get _submitLabel {
    if (_method == 0) return 'Sıfırlama bağlantısı gönder';
    if (_method == 1) {
      return _phoneOtpSent ? 'Doğrula ve şifreyi kaydet' : 'SMS kodu gönder';
    }
    return 'Kodu doğrula ve şifreyi kaydet';
  }
}
