import 'package:flutter/material.dart';

import '../../../models/courier_application_data.dart';
import '../../../services/ihiz_courier_auth_service.dart';
import '../apply/ihiz_courier_apply_page.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-posta ve şifre zorunlu.')),
      );
      return;
    }
    if (!identifier.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Giriş için başvurudaki e-posta adresinizi kullanın.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_auth.cleanErrorMessage(error)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openApply() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const IhizCourierApplyPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF163B73),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Geri',
        ),
        title: const Text(
          'Giriş Yap',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 900;
                  return isMobile
                      ? Column(
                          children: [
                            _loginForm(),
                            const SizedBox(height: 18),
                            const IhizCourierLoginMarketingSection(),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Expanded(
                              flex: 6,
                              child: IhizCourierLoginMarketingSection(),
                            ),
                            const SizedBox(width: 18),
                            Expanded(flex: 5, child: _loginForm()),
                          ],
                        );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loginForm() {
    return IhizCourierSectionShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Giriş Yap',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Color(0xFF163B73),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Onaylı kurye hesabınızla giriş yapın. Onaylanmayan hesaplar panele erişemez.',
            style: TextStyle(color: Color(0xFF5B6B86), height: 1.5),
          ),
          const SizedBox(height: 20),
          const IhizCourierFieldLabel('E-posta'),
          const SizedBox(height: 8),
          IhizCourierInput(
            hint: 'ornek@ihiz.com',
            controller: _identifierController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          const IhizCourierFieldLabel('Şifre'),
          const SizedBox(height: 8),
          IhizCourierInput(
            hint: '••••••••',
            obscure: true,
            controller: _passwordController,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleLogin(),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF163B73),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
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
                      'Kurye Paneline Gir',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _openApply,
            child: const Text('Kayıt Ol / Başvur'),
          ),
        ],
      ),
    );
  }
}

typedef IhizCourierLoginResult = CourierApplicationData;
