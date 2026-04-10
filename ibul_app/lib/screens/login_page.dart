import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/app_motion.dart';
import '../core/constants.dart';
import 'register_page.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'seller_panel_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // Button press scale states
  bool _loginPressed = false;
  bool _registerPressed = false;
  bool _googlePressed = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        await _authService.signInWithEmailPassword(
          _emailController.text.trim(),
          _passwordController.text,
          authArea: 'user',
        );

        final resolution = await _authService.resolveLoginRoute(
          diagnosticContext: 'user_login',
        );

        if (!mounted) return;

        if (resolution.resolvedRole == LoginResolvedRole.seller) {
          if (resolution.isSellerApproved) {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/seller', (route) => false);
            return;
          } else {
            // Not approved yet
            await _authService.signOut(); // Logout
            throw Exception(
              'Satıcı hesabınız henüz onaylanmadı. Lütfen yönetici onayını bekleyin.',
            );
          }
        }

        if (resolution.resolvedRole == LoginResolvedRole.waiter) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/seller',
            (route) => false,
            arguments: SellerPanelEntryRole.waiter,
          );
          return;
        }

        if (resolution.resolvedRole == LoginResolvedRole.unknown) {
          await _authService.signOut();
          throw Exception('Rol bilgisi çözümlenemedi. Lütfen tekrar deneyin.');
        }

        // Login successful (Regular User)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Giriş başarılı!'),
            backgroundColor: Colors.green,
          ),
        );

        final appState = Provider.of<AppState>(context, listen: false);
        for (int i = 0; i < 20; i++) {
          if (!mounted) return;
          if (appState.isLoggedIn) break;
          await Future.delayed(const Duration(milliseconds: 100));
        }
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          buildAppPageRoute<void>(
            builder: (context) => const HomeScreen(initialIndex: 4),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        final message = _authService.describeSignInError(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Giriş başarısız: $message'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompactMobile = screenWidth < 390;
    final contentMaxWidth = 420.0;
    final hPad = isCompactMobile ? 20.0 : 24.0;

    // ── colour tokens ──────────────────────────────────────────────
    const primary = AppColors.primary;
    final primaryLight = primary.withValues(alpha: 0.10);
    final grey200 = const Color(0xFFE5E7EB);
    const textDark = Color(0xFF111827);
    const textMid = Color(0xFF6B7280);

    // ── field decoration factory ───────────────────────────────────
    final purpleBorder = primary.withValues(alpha: 0.25);
    InputDecoration fieldDeco({
      required String label,
      required String hint,
      required Widget prefix,
      Widget? suffix,
    }) => InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(fontSize: 13, color: textMid),
      hintStyle: TextStyle(
        fontSize: 13,
        color: textMid.withValues(alpha: 0.55),
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
        borderSide: BorderSide(color: purpleBorder, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: primary, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      // No AppBar — clean full-bleed layout
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── TOP NAV ROW ─────────────────────────────────
            Padding(
              padding: EdgeInsets.only(left: hPad - 8, top: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.maybePop(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: textDark.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ),
            // ── SCROLLABLE CONTENT ───────────────────────────
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: hPad,
                        vertical: 24,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: contentMaxWidth),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ── HERO ───────────────────────────────────
                              Center(
                                child: Container(
                                  width: isCompactMobile ? 76 : 84,
                                  height: isCompactMobile ? 76 : 84,
                                  decoration: BoxDecoration(
                                    color: primaryLight,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: primary.withValues(alpha: 0.12),
                                        blurRadius: 20,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.shopping_bag_outlined,
                                    size: isCompactMobile ? 36 : 40,
                                    color: primary,
                                  ),
                                ),
                              ),

                              SizedBox(height: isCompactMobile ? 18 : 20),

                              // ── TITLE ──────────────────────────────────
                              Text(
                                'İbul\'a Hoş Geldiniz',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: isCompactMobile ? 20 : 22,
                                  fontWeight: FontWeight.w700,
                                  color: textDark,
                                  letterSpacing: -0.3,
                                ),
                              ),

                              const SizedBox(height: 6),

                              Text(
                                'Devam etmek için giriş yapın.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: isCompactMobile ? 13 : 14,
                                  color: textMid.withValues(alpha: 0.75),
                                  height: 1.4,
                                ),
                              ),

                              SizedBox(height: isCompactMobile ? 28 : 32),

                              // ── EMAIL ──────────────────────────────────
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: textDark,
                                ),
                                decoration: fieldDeco(
                                  label: 'E-posta veya Telefon',
                                  hint: 'ornek@email.com',
                                  prefix: const Icon(
                                    Icons.person_outline_rounded,
                                    size: 18,
                                    color: textMid,
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Lütfen e-posta veya telefon girin';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 12),

                              // ── PASSWORD ───────────────────────────────
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: textDark,
                                ),
                                decoration: fieldDeco(
                                  label: 'Şifre',
                                  hint: '••••••••',
                                  prefix: const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 18,
                                    color: textMid,
                                  ),
                                  suffix: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 18,
                                      color: textMid,
                                    ),
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Lütfen şifrenizi girin';
                                  }
                                  return null;
                                },
                              ),

                              SizedBox(height: isCompactMobile ? 20 : 24),

                              // ── PRIMARY ACTIONS ROW ────────────────────
                              Row(
                                children: [
                                  // Giriş Yap
                                  Expanded(
                                    child: GestureDetector(
                                      onTapDown: (_) =>
                                          setState(() => _loginPressed = true),
                                      onTapUp: (_) =>
                                          setState(() => _loginPressed = false),
                                      onTapCancel: () =>
                                          setState(() => _loginPressed = false),
                                      onTap: _isLoading ? null : _handleLogin,
                                      child: AnimatedScale(
                                        scale: _loginPressed ? 0.97 : 1.0,
                                        duration: const Duration(
                                          milliseconds: 80,
                                        ),
                                        child: Container(
                                          height: 44,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF8B3FF5),
                                                Color(0xFF6A1FD8),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: primary.withValues(
                                                  alpha: 0.28,
                                                ),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          alignment: Alignment.center,
                                          child: _isLoading
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Text(
                                                  'Giriş Yap',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                    letterSpacing: 0.2,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 10),

                                  // Üye Ol
                                  Expanded(
                                    child: GestureDetector(
                                      onTapDown: (_) => setState(
                                        () => _registerPressed = true,
                                      ),
                                      onTapUp: (_) => setState(
                                        () => _registerPressed = false,
                                      ),
                                      onTapCancel: () => setState(
                                        () => _registerPressed = false,
                                      ),
                                      onTap: _isLoading
                                          ? null
                                          : () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const RegisterPage(),
                                              ),
                                            ),
                                      child: AnimatedScale(
                                        scale: _registerPressed ? 0.97 : 1.0,
                                        duration: const Duration(
                                          milliseconds: 80,
                                        ),
                                        child: Container(
                                          height: 44,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: primary,
                                              width: 1.5,
                                            ),
                                            color: Colors.white,
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            'Üye Ol',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: primary,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: isCompactMobile ? 20 : 24),

                              // ── DIVIDER ────────────────────────────────
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: grey200,
                                      thickness: 1,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    child: Text(
                                      'veya',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: textMid.withValues(alpha: 0.6),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: grey200,
                                      thickness: 1,
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: isCompactMobile ? 20 : 24),

                              // ── GOOGLE ─────────────────────────────────
                              GestureDetector(
                                onTapDown: (_) =>
                                    setState(() => _googlePressed = true),
                                onTapUp: (_) =>
                                    setState(() => _googlePressed = false),
                                onTapCancel: () =>
                                    setState(() => _googlePressed = false),
                                onTap: _isLoading
                                    ? null
                                    : () async {
                                        setState(() => _isLoading = true);
                                        final navigator = Navigator.of(context);
                                        final messenger = ScaffoldMessenger.of(
                                          context,
                                        );
                                        try {
                                          final appState =
                                              Provider.of<AppState>(
                                                context,
                                                listen: false,
                                              );
                                          await appState.loginWithGoogle();
                                          if (!mounted) return;
                                          navigator.pushReplacement(
                                            buildAppPageRoute<void>(
                                              builder: (context) =>
                                                  const HomeScreen(
                                                    initialIndex: 4,
                                                  ),
                                            ),
                                          );
                                        } catch (e) {
                                          if (!mounted) return;
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Giriş başarısız: ${e.toString()}',
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        } finally {
                                          if (mounted) {
                                            setState(() => _isLoading = false);
                                          }
                                        }
                                      },
                                child: AnimatedScale(
                                  scale: _googlePressed ? 0.97 : 1.0,
                                  duration: const Duration(milliseconds: 80),
                                  child: Container(
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: grey200,
                                        width: 1.2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.04,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.g_mobiledata_rounded,
                                          size: 22,
                                          color: Colors.red,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Google ile giriş yap',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color: textDark.withValues(
                                              alpha: 0.85,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
