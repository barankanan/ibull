import 'package:flutter/material.dart';

import '../theme/ihiz_brand.dart';

/// İHIZ operations (admin) sign-in screen.
///
/// UI only for now — a professional entry point that will later connect to the
/// real admin panel. It intentionally does not authenticate; submitting shows
/// an informational message.
class IhizAdminLoginPage extends StatefulWidget {
  const IhizAdminLoginPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<IhizAdminLoginPage> createState() => _IhizAdminLoginPageState();
}

class _IhizAdminLoginPageState extends State<IhizAdminLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = true;
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Admin paneli yakında bağlanacak. Bu ekran şimdilik giriş '
          'arayüzüdür.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: IhizBrand.adminGradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = IhizBrand.isCompact(constraints.maxWidth);
              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(compact ? 14 : 24, 14, 14, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: widget.onBack,
                          icon: const Icon(Icons.arrow_back_rounded),
                          color: IhizBrand.ink,
                          tooltip: 'Geri',
                        ),
                        const SizedBox(width: 4),
                        const IhizLogoLockup(
                          size: 22,
                          color: IhizBrand.ink,
                          onDark: false,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(compact ? 18 : 24),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: _card(compact),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _card(bool compact) {
    return Container(
      padding: EdgeInsets.all(compact ? 24 : 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: IhizBrand.line),
        boxShadow: [
          BoxShadow(
            color: IhizBrand.navy.withValues(alpha: 0.12),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: IhizBrand.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.shield_moon_outlined,
              color: IhizBrand.blue,
              size: 28,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'İHIZ Operasyon Merkezi',
            style: TextStyle(
              color: IhizBrand.ink,
              fontWeight: FontWeight.w900,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Yönetim ve operasyon ekibi girişi.',
            style: TextStyle(
              color: IhizBrand.inkSoft,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 22),
          const _FieldLabel('E-posta'),
          const SizedBox(height: 8),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDecoration('operasyon@ihiz.com', Icons.mail_outline),
          ),
          const SizedBox(height: 16),
          const _FieldLabel('Şifre'),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: _obscure,
            decoration:
                _inputDecoration('••••••••', Icons.lock_outline).copyWith(
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: IhizBrand.inkSoft,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Checkbox(
                value: _rememberMe,
                onChanged: (v) => setState(() => _rememberMe = v ?? false),
                activeColor: IhizBrand.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const Text(
                'Beni hatırla',
                style: TextStyle(
                  color: IhizBrand.ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: IhizBrand.navy,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              child: const Text('Giriş Yap'),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: IhizBrand.inkSoft, size: 20),
      filled: true,
      fillColor: const Color(0xFFF5F8FD),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: IhizBrand.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: IhizBrand.blue, width: 1.6),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: IhizBrand.ink,
        fontWeight: FontWeight.w800,
        fontSize: 13.5,
      ),
    );
  }
}
