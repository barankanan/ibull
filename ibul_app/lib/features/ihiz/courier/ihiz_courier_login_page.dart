import 'package:flutter/material.dart';

import '../../../models/courier_application_data.dart';
import '../../../screens/legal/legal_document.dart';
import '../../../screens/legal/legal_document_page.dart';
import '../../../services/ihiz_courier_auth_service.dart';
import '../apply/ihiz_courier_apply_page.dart';
import '../theme/ihiz_brand.dart';
import 'ihiz_courier_dashboard_page.dart';
import 'models/ihiz_pricing_config.dart';
import 'widgets/ihiz_courier_login_chrome.dart';

/// İHIZ kurye giriş — ihiz_web `_IhizLoginPage` karşılığı (genel iBul LoginPage değil).
class IhizCourierLoginPage extends StatefulWidget {
  const IhizCourierLoginPage({
    super.key,
    this.authService,
  });

  final IhizCourierAuthService? authService;

  @override
  State<IhizCourierLoginPage> createState() => _IhizCourierLoginPageState();
}

class _IhizCourierLoginPageState extends State<IhizCourierLoginPage> {
  late final IhizCourierAuthService _auth =
      widget.authService ?? IhizCourierAuthService();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;
  String? _formError;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      setState(() => _formError = 'E-posta ve şifre zorunlu.');
      return;
    }
    if (!identifier.contains('@')) {
      setState(
        () => _formError = 'Giriş için başvurudaki e-posta adresinizi kullanın.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _formError = null;
    });
    try {
      final data = await _auth.signInApprovedCourier(
        email: identifier,
        password: password,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (ctx) => IhizCourierDashboardPage(
            applicationData: data,
            pricingConfig: IhizPricingConfig.defaults,
            onExit: () async {
              await _auth.signOut();
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
            },
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _formError = _auth.cleanErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _identifierController.text.trim();
    if (!email.contains('@')) {
      setState(
        () => _formError = 'Şifre sıfırlama için e-posta adresinizi yazın.',
      );
      return;
    }
    try {
      await _auth.sendPasswordResetEmail(email);
      if (!mounted) return;
      setState(() => _formError = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sıfırlama bağlantısı e-posta adresine gönderildi.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _formError = _auth.cleanErrorMessage(error));
    }
  }

  void _openApply() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const IhizCourierApplyPage()),
    );
  }

  void _openLegal(LegalDocumentId id) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentPage(documentId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IhizBrand.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final form = _loginForm();
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: wide ? 32 : 20,
                vertical: wide ? 28 : 16,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Expanded(
                              child: IhizCourierLoginMarketingSection(),
                            ),
                            const SizedBox(width: 28),
                            Expanded(child: form),
                          ],
                        )
                      : form,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _loginForm() {
    return IhizCourierSectionShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: IhizLogoLockup(size: 22, color: IhizBrand.ink),
          ),
          const SizedBox(height: 18),
          const Text(
            'Tekrar hoş geldin',
            style: TextStyle(
              color: IhizBrand.ink,
              fontWeight: FontWeight.w900,
              fontSize: 28,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Kurye hesabına giriş yap',
            style: TextStyle(
              color: IhizBrand.inkSoft,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _identifierController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            cursorColor: IhizBrand.blue,
            decoration: _fieldDecoration('ornek@ihiz.com').copyWith(
              labelText: 'Telefon / E-posta',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            cursorColor: IhizBrand.blue,
            onSubmitted: (_) => _handleLogin(),
            decoration: _fieldDecoration('Şifre').copyWith(
              labelText: 'Şifre',
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Şifreyi göster' : 'Şifreyi gizle',
                color: IhizBrand.blue,
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isLoading ? null : _forgotPassword,
              style: TextButton.styleFrom(foregroundColor: IhizBrand.blue),
              child: const Text('Şifremi Unuttum'),
            ),
          ),
          if (_formError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _formError!,
                style: const TextStyle(
                  color: Color(0xFFB42318),
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: FilledButton.styleFrom(
                backgroundColor: IhizBrand.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Giriş Yap',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _isLoading ? null : _openApply,
            style: OutlinedButton.styleFrom(
              foregroundColor: IhizBrand.blue,
              minimumSize: const Size.fromHeight(52),
              side: const BorderSide(color: IhizBrand.blue),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Kurye Ol',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            children: [
              TextButton(
                onPressed: () => _openLegal(LegalDocumentId.privacy),
                style: TextButton.styleFrom(foregroundColor: IhizBrand.blue),
                child: const Text('Gizlilik'),
              ),
              TextButton(
                onPressed: () => _openLegal(LegalDocumentId.terms),
                style: TextButton.styleFrom(foregroundColor: IhizBrand.blue),
                child: const Text('Kullanım Şartları'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: IhizBrand.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: IhizBrand.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: IhizBrand.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: IhizBrand.blue, width: 1.4),
      ),
      labelStyle: const TextStyle(color: IhizBrand.inkSoft),
      floatingLabelStyle: const TextStyle(color: IhizBrand.blue),
    );
  }
}

typedef IhizCourierLoginResult = CourierApplicationData;
